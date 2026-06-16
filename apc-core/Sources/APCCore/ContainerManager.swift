import Foundation

public final class ContainerManager: @unchecked Sendable {
    public static let shared = ContainerManager()

    private let engine: ContainerEngine
    private let routingConfigURL: URL

    // Live-stats sampling state (cgroup CPU needs a delta between two reads).
    private let statsLock = NSLock()
    private var cpuSamples: [String: (usageUsec: UInt64, at: Date)] = [:]
    private var lastHostCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    // Short-TTL cache for the engine liveness probe (guarded by statsLock).
    private var runtimeStatusCache: (value: Bool, at: Date)?

    // Last routing config written to disk; skip redundant encode+write when unchanged (guarded by routingLock).
    private let routingLock = NSLock()
    private var lastWrittenRouting: RoutingConfig?

    // Decodable structs for CLI json parsing
    private struct CLIContainerListItem: Codable {
        struct Configuration: Codable {
            struct Image: Codable {
                let reference: String
            }
            struct PublishedPort: Codable {
                let hostPort: Int
                let containerPort: Int
            }
            struct Resources: Codable {
                let cpus: Int?
                let memoryInBytes: Int64?
            }
            let id: String
            let image: Image
            let publishedPorts: [PublishedPort]?
            let resources: Resources?
        }
        let configuration: Configuration
        let status: String
    }
    
    private struct CLIImageListItem: Codable {
        struct Descriptor: Codable {
            let size: Int64
        }
        let descriptor: Descriptor
        let reference: String
    }
    
    private struct CLIVolumeListItem: Codable {
        let name: String
        let source: String
    }
    
    /// - Parameters:
    ///   - engine: the runtime adapter (defaults to the native `container` CLI).
    ///   - stateDirectory: where routing state is persisted (defaults to `~/.apc`).
    ///     Tests pass a temp directory so they never touch the real config.
    public init(engine: ContainerEngine = ProcessContainerEngine(), stateDirectory: URL? = nil) {
        self.engine = engine
        let apcDir = stateDirectory ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".apc")
        try? FileManager.default.createDirectory(at: apcDir, withIntermediateDirectories: true)
        self.routingConfigURL = apcDir.appendingPathComponent("routing.json")

        // Sync routing initially from current real state.
        syncRoutingConfig(using: getContainers())
    }

    // MARK: - Container APIs
    
    public func getContainers() -> [Container] {
        guard let output = engine.run(["list", "--all", "--format", "json"]),
              let data = output.data(using: .utf8) else {
            return []
        }
        
        let decoder = JSONDecoder()
        do {
            let list = try decoder.decode([CLIContainerListItem].self, from: data)
            // VM core budget is only needed as a fallback when the runtime omits a cpu
            // count — read it lazily so a normal refresh does no disk I/O (keeps this a pure read).
            let needsCPUFallback = list.contains { $0.configuration.resources?.cpus == nil }
            let vmCPUs = needsCPUFallback ? VMManager.shared.loadVMConfig().allocatedCPUs : 0
            let result = list.map { item -> Container in
                let config = item.configuration
                let id = config.id
                let name = id
                
                // Parse image name (strip registry prefixes for clean GUI display)
                var displayImage = config.image.reference
                if displayImage.hasPrefix("docker.io/library/") {
                    displayImage = String(displayImage.dropFirst("docker.io/library/".count))
                } else if displayImage.hasPrefix("docker.io/") {
                    displayImage = String(displayImage.dropFirst("docker.io/".count))
                }
                
                let state = item.status.lowercased() == "running" ? "running" : "stopped"

                // Parse ports
                var portsList: [String] = []
                if let publishedPorts = config.publishedPorts {
                    for port in publishedPorts {
                        portsList.append("\(port.hostPort):\(port.containerPort)")
                    }
                }

                // Real allocated resources reported by the runtime; fall back to the VM's
                // configured core budget so live CPU% isn't normalized against a single core.
                let cores = config.resources?.cpus ?? vmCPUs
                let memoryLimitMB = Double(config.resources?.memoryInBytes ?? 0) / (1024.0 * 1024.0)

                return Container(
                    id: id,
                    name: name,
                    image: displayImage,
                    state: state,
                    ports: portsList,
                    cpuUsage: 0.0,        // live CPU sampling not yet wired (no stats plugin)
                    memoryUsage: 0.0,     // live memory sampling not yet wired
                    cpuCores: cores,
                    memoryLimitMB: memoryLimitMB,
                    logs: []              // fetched on demand via getContainerLogs(id:); see below
                )
            }

            // `getContainers()` is a pure read — it no longer fetches per-container logs
            // or triggers a routing sync. Routing is re-synced only on real mutations
            // (start/stop/run/remove/kill), each passing the freshly fetched list.
            return result
        } catch {
            print("[ContainerManager] JSON decoding failed for containers list: \(error)")
            return []
        }
    }

    /// One-shot fetch of a container's current logs. Used for the Logs view of a
    /// *stopped* container; running containers stream live via `LogStreamer`, and the
    /// hot refresh path no longer fetches logs at all. Empty if there are none.
    public func getContainerLogs(id: String) -> [String] {
        guard let out = engine.run(["logs", id]) else { return [] }
        return out.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    public func startContainer(id: String) throws {
        let result = runCapturing(["start", id])
        guard result.success else { throw Self.cliError(result.output, fallback: "Failed to start container '\(id)'.") }
        syncRoutingConfig(using: getContainers())
    }

    public func stopContainer(id: String) throws {
        let result = runCapturing(["stop", id])
        guard result.success else { throw Self.cliError(result.output, fallback: "Failed to stop container '\(id)'.") }
        syncRoutingConfig(using: getContainers())
    }

    /// Build an NSError carrying the real CLI stderr/stdout, or a fallback message.
    static func cliError(_ output: String, fallback: String) -> NSError {
        let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return NSError(domain: "ContainerManager", code: 1,
                       userInfo: [NSLocalizedDescriptionKey: message.isEmpty ? fallback : message])
    }
    
    public func runNewContainer(name: String, image: String, portMap: String) throws -> Container {
        var args = ["run", "-d", "--name", name]

        // Parse port map (e.g., 8085:8080)
        if !portMap.isEmpty {
            args.append(contentsOf: ["-p", portMap])
        }
        args.append(image)

        // Capture exit status + stderr so real failures (bad image, duplicate name,
        // bad port) surface to the caller instead of failing silently.
        let result = runCapturing(args)
        guard result.success else {
            let message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "ContainerManager", code: 1, userInfo: [NSLocalizedDescriptionKey:
                message.isEmpty ? "Failed to create container '\(name)'." : message])
        }
        syncRoutingConfig(using: getContainers())

        // Provisional representation; the next refresh replaces it with real runtime data.
        return Container(
            id: name,
            name: name,
            image: image,
            state: "running",
            ports: [portMap],
            cpuUsage: 0.0,
            memoryUsage: 0.0,
            logs: ["\(getTimestamp()) [info] Container created."]
        )
    }
    
    public func removeContainer(id: String) {
        _ = engine.run(["stop", id])
        _ = engine.run(["rm", id])
        syncRoutingConfig(using: getContainers())
    }

    /// Force-kill a container (sends SIGKILL), distinct from a graceful stop.
    public func killContainer(id: String) throws {
        let result = runCapturing(["kill", id])
        guard result.success else { throw Self.cliError(result.output, fallback: "Failed to kill container '\(id)'.") }
        syncRoutingConfig(using: getContainers())
    }
    
    // MARK: - Image APIs
    
    public func getImages() -> [ContainerImage] {
        guard let output = engine.run(["image", "list", "--format", "json"]),
              let data = output.data(using: .utf8) else {
            return []
        }
        
        let decoder = JSONDecoder()
        do {
            let list = try decoder.decode([CLIImageListItem].self, from: data)
            return list.map { item -> ContainerImage in
                let (repo, tag) = Self.splitImageReference(item.reference)
                // `descriptor.size` is usually KB-scale; show real bytes humanised, not "N/A".
                let sizeStr = item.descriptor.size > 0
                    ? Self.humanFileSize(String(item.descriptor.size))
                    : "N/A"
                return ContainerImage(
                    id: item.reference,
                    repository: repo,
                    tag: tag,
                    size: sizeStr,
                    created: "N/A"
                )
            }
        } catch {
            print("[ContainerManager] JSON decoding failed for images list: \(error)")
            return []
        }
    }
    
    /// Split an OCI image reference into `(repository, tag)`. Handles the docker.io
    /// prefixes, registry `host:port` (a tag never contains `/`, so a `:` only counts
    /// after the last `/`), and `@sha256:` digest references.
    static func splitImageReference(_ reference: String) -> (repository: String, tag: String) {
        var cleanRef = reference
        if cleanRef.hasPrefix("docker.io/library/") {
            cleanRef = String(cleanRef.dropFirst("docker.io/library/".count))
        } else if cleanRef.hasPrefix("docker.io/") {
            cleanRef = String(cleanRef.dropFirst("docker.io/".count))
        }

        // Digest reference: repo@sha256:<hex> — keep the repo, show a short digest as the tag.
        if let at = cleanRef.range(of: "@") {
            let repo = String(cleanRef[..<at.lowerBound])
            var digest = String(cleanRef[at.upperBound...])
            if let colon = digest.range(of: ":") {
                digest = "@" + String(digest[colon.upperBound...].prefix(12))
            }
            return (repo, digest)
        }

        // A tag separator ':' only counts after the last '/' (else it's a host:port).
        let lastSlash = cleanRef.lastIndex(of: "/")
        let searchStart = lastSlash.map { cleanRef.index(after: $0) } ?? cleanRef.startIndex
        if let colon = cleanRef.range(of: ":", range: searchStart..<cleanRef.endIndex) {
            let repo = String(cleanRef[..<colon.lowerBound])
            let tag = String(cleanRef[colon.upperBound...])
            return (repo, tag.isEmpty ? "latest" : tag)
        }
        return (cleanRef, "latest")
    }

    /// Pull an image. Returns whether the pull exited cleanly + the combined output,
    /// so the caller can surface real failures (bad tag, auth, network) honestly.
    /// No timeout — a real pull legitimately takes minutes.
    public func addImage(repository: String, tag: String) -> (success: Bool, output: String) {
        let imageRef = tag.isEmpty ? repository : "\(repository):\(tag)"
        return runCapturing(["image", "pull", imageRef], timeout: nil)
    }

    /// Build an image from a Dockerfile via real `container build`. Blocking — call
    /// off the main thread. Returns whether the build exited cleanly plus the full
    /// combined build log (the CLI buffers output and writes it at completion).
    public func buildImage(tag: String, dockerfilePath: String?, contextDir: String) -> (success: Bool, log: String) {
        // `container build` resolves -f relative to CWD, so always pass an absolute Dockerfile path.
        let dockerfile = (dockerfilePath?.isEmpty == false) ? dockerfilePath! : "\(contextDir)/Dockerfile"
        // No timeout — a real build legitimately takes minutes.
        let result = runCapturing(["build", "-t", tag, "-f", dockerfile, contextDir], timeout: nil)
        return (result.success, result.output)
    }

    /// Create a new reference for an existing image: `container image tag <source> <target>`.
    public func tagImage(source: String, target: String) -> (success: Bool, output: String) {
        return runCapturing(["image", "tag", source, target])
    }

    /// Push an image to its registry: `container image push <reference>`. Requires a prior
    /// `container registry login`; returns the real failure (e.g. unauthorized) honestly.
    public func pushImage(reference: String) -> (success: Bool, output: String) {
        // No timeout — a real push legitimately takes minutes.
        return runCapturing(["image", "push", reference], timeout: nil)
    }

    /// Log in to a registry. The password is written to the process's STDIN via
    /// `--password-stdin` — it never appears in the argument list and is never logged or stored.
    public func registryLogin(server: String, username: String, password: String) -> (success: Bool, output: String) {
        var arguments = ["registry", "login"]
        if !username.isEmpty { arguments.append(contentsOf: ["--username", username]) }
        arguments.append(contentsOf: ["--password-stdin", server])

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/container")
        process.arguments = arguments

        let outPipe = Pipe()
        let inPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = outPipe
        process.standardInput = inPipe

        do {
            try process.run()
            // Feed the password over stdin, then close to signal EOF. Not in argv.
            if let data = password.data(using: .utf8) {
                inPipe.fileHandleForWriting.write(data)
            }
            try? inPipe.fileHandleForWriting.close()
            let out = outPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus == 0, String(data: out, encoding: .utf8) ?? "")
        } catch {
            return (false, "Failed to launch container: \(error.localizedDescription)")
        }
    }

    /// Log out from a registry: `container registry logout <server>`.
    public func registryLogout(server: String) -> (success: Bool, output: String) {
        return runCapturing(["registry", "logout", server])
    }

    /// Run the real `container` binary capturing combined stdout+stderr and the exit status.
    /// Blocking — call off the main thread. `timeout` bounds short commands so a wedged
    /// call can't hang forever; pass `nil` for legitimately long operations (build/pull/push).
    private func runCapturing(_ arguments: [String], timeout: TimeInterval? = 15) -> (success: Bool, output: String) {
        let result = ProcessRunner.run(executableURL: URL(fileURLWithPath: "/usr/local/bin/container"),
                                       arguments: arguments, timeout: timeout)
        if let error = result.launchError {
            return (false, "Failed to launch container: \(error.localizedDescription)")
        }
        if result.timedOut {
            return (false, "The container command timed out.")
        }
        return (result.exitCode == 0, result.output)
    }

    public func removeImage(id: String) throws {
        let result = runCapturing(["image", "rm", id])
        guard result.success else { throw Self.cliError(result.output, fallback: "Failed to remove image '\(id)'.") }
    }
    
    // MARK: - Volume APIs
    
    public func getVolumes() -> [Volume] {
        guard let output = engine.run(["volume", "list", "--format", "json"]),
              let data = output.data(using: .utf8) else {
            return []
        }
        
        let decoder = JSONDecoder()
        do {
            let list = try decoder.decode([CLIVolumeListItem].self, from: data)
            return list.map { item -> Volume in
                let fm = FileManager.default
                var sizeStr = "--"
                
                // Check real disk size of volume file if accessible
                if let attrs = try? fm.attributesOfItem(atPath: item.source),
                   let bytes = attrs[.size] as? Int64 {
                    let megabytes = Double(bytes) / (1024.0 * 1024.0)
                    sizeStr = String(format: "%.1f MB", megabytes)
                }
                
                return Volume(
                    name: item.name,
                    size: sizeStr,
                    mountPoint: item.source
                )
            }
        } catch {
            print("[ContainerManager] JSON decoding failed for volumes list: \(error)")
            return []
        }
    }
    
    public func createVolume(name: String, mountPoint: String) throws {
        // `container volume create` takes the name positionally — there is no --name flag.
        // Capture exit + stderr so duplicates and other failures surface honestly.
        let result = runCapturing(["volume", "create", name])
        guard result.success else {
            throw Self.cliError(result.output, fallback: "Failed to create volume '\(name)'.")
        }
    }

    public func removeVolume(id: String) throws {
        // Surface real failures (volume in use, not found) instead of swallowing them.
        let result = runCapturing(["volume", "rm", id])
        guard result.success else {
            throw Self.cliError(result.output, fallback: "Failed to remove volume '\(id)'.")
        }
    }

    /// True if the Apple container apiserver is running. When it isn't, list/stats
    /// calls return nothing — so the UI can say "engine off" instead of "no containers".
    /// Cached for a few seconds: engine up/down transitions are rare, so the hot refresh
    /// path shouldn't spawn `system status` on every 1.5s tick.
    public func isRuntimeRunning() -> Bool {
        let now = Date()
        statsLock.lock()
        if let cache = runtimeStatusCache, now.timeIntervalSince(cache.at) < 4.0 {
            defer { statsLock.unlock() }
            return cache.value
        }
        statsLock.unlock()

        // Short timeout: this is a liveness probe, not a long operation.
        let running = runCapturing(["system", "status"], timeout: 3).output.contains("apiserver is running")

        statsLock.lock()
        runtimeStatusCache = (running, now)
        statsLock.unlock()
        return running
    }

    /// Reclaim disk by removing unreferenced images and snapshots.
    /// The runtime has no `volume prune`; image prune is the real disk-reclaim path.
    /// Real total bytes used by all volume images on disk (sum of each volume's
    /// backing `.img` file size). 0 if none.
    public func volumeStorageBytes(_ volumes: [Volume]? = nil) -> Int64 {
        let fm = FileManager.default
        return (volumes ?? getVolumes()).reduce(Int64(0)) { total, volume in
            guard let attrs = try? fm.attributesOfItem(atPath: volume.mountPoint),
                  let bytes = attrs[.size] as? Int64 else { return total }
            return total + bytes
        }
    }

    /// Reclaim disk by removing unreferenced images/snapshots. Unbounded — a real prune
    /// over a large store legitimately takes a while; returns the real outcome.
    @discardableResult
    public func pruneStorage() -> (success: Bool, output: String) {
        return runCapturing(["image", "prune"], timeout: nil)
    }

    /// Re-sync `routing.json` from current real container state. Cheap in steady state
    /// (the route set is compared and written only when it changed). Because
    /// `getContainers()` is now a pure read, this is the hook that prunes routes for
    /// containers that crashed or exited out-of-band; the daemon and GUI call it each tick.
    public func reconcileRouting(using containers: [Container]? = nil) {
        syncRoutingConfig(using: containers ?? getContainers())
    }
    
    // MARK: - Hardware Stats API
    
    public func getStats() -> APCHardwareStats {
        // Convenience for callers without a list in hand (e.g. the daemon): fetch once.
        return getStats(containers: getContainers())
    }

    /// Stats derived from an already-fetched container list — avoids a second
    /// `getContainers()` enumeration within the same refresh tick.
    public func getStats(containers: [Container]) -> APCHardwareStats {
        // Real figures: live host CPU, and memory committed by running containers
        // against the VM's configured ceiling.
        let committedMemoryMB = containers
            .filter { $0.state == "running" }
            .reduce(0.0) { $0 + $1.memoryLimitMB }
        let maxMemoryMB = Double(VMManager.shared.loadVMConfig().allocatedMemoryGB) * 1024.0
        return APCHardwareStats(cpuUsage: hostCPUUsage(), memoryUsage: committedMemoryMB, maxMemory: maxMemoryMB)
    }

    // MARK: - Live stats (real, sampled from cgroup + Mach host metrics)

    /// Live per-container CPU% (normalized to allocated cores) and memory bytes,
    /// read from the guest cgroup v2 files. CPU% is 0 on the first sample (it needs
    /// a delta) and real thereafter. Nil if the container is not exec-able.
    public func liveStats(id: String, cores: Int) -> LiveContainerStats? {
        guard let out = engine.run(["exec", id, "sh", "-c",
            "cat /sys/fs/cgroup/memory.current; echo ---; cat /sys/fs/cgroup/cpu.stat"]) else {
            return nil
        }
        let sections = out.components(separatedBy: "---")
        guard sections.count >= 2,
              let memory = UInt64(sections[0].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        var usageUsec: UInt64 = 0
        for line in sections[1].split(separator: "\n") {
            let fields = line.split(separator: " ")
            if fields.count == 2, fields[0] == "usage_usec", let value = UInt64(fields[1]) {
                usageUsec = value
            }
        }

        let now = Date()
        var cpuPercent = 0.0
        statsLock.lock()
        if let prev = cpuSamples[id] {
            let cpuDeltaUsec = Double(usageUsec &- prev.usageUsec)
            let wallDeltaUsec = now.timeIntervalSince(prev.at) * 1_000_000.0
            let coreCount = Double(max(cores, 1))
            if wallDeltaUsec > 0 {
                cpuPercent = min(cpuDeltaUsec / (wallDeltaUsec * coreCount) * 100.0, 100.0)
            }
        }
        cpuSamples[id] = (usageUsec, now)
        statsLock.unlock()

        return LiveContainerStats(memoryBytes: memory, cpuPercent: cpuPercent)
    }

    /// Live host CPU utilization (%), sampled from Mach `host_statistics`. Returns
    /// 0 on the first call (needs a tick delta) and real values thereafter.
    public func hostCPUUsage() -> Double {
        // HOST_CPU_LOAD_INFO_COUNT is not importable into Swift; compute it.
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        var info = host_cpu_load_info_data_t()
        let kr = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, intPointer, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }

        let user = info.cpu_ticks.0, system = info.cpu_ticks.1
        let idle = info.cpu_ticks.2, nice = info.cpu_ticks.3

        statsLock.lock()
        defer {
            lastHostCPUTicks = (user, system, idle, nice)
            statsLock.unlock()
        }
        guard let prev = lastHostCPUTicks else { return 0 }
        let dUser = Double(user &- prev.user)
        let dSystem = Double(system &- prev.system)
        let dIdle = Double(idle &- prev.idle)
        let dNice = Double(nice &- prev.nice)
        let total = dUser + dSystem + dIdle + dNice
        guard total > 0 else { return 0 }
        return (dUser + dSystem + dNice) / total * 100.0
    }

    /// Run a shell command inside a running container via real `container exec`,
    /// scoped to that container's namespace. stderr is merged into stdout so the
    /// terminal shows real error text. Returns nil only if exec itself can't run
    /// (e.g. the container isn't running); an empty string means "ran, no output".
    public func execInContainer(id: String, command: String) -> String? {
        return engine.run(["exec", id, "sh", "-c", "\(command) 2>&1"])
    }

    /// Real environment variables + mounts for a container, decoded from inspect.
    public func containerInfo(id: String) -> ContainerInfo? {
        guard let output = engine.run(["inspect", id]), let data = output.data(using: .utf8) else {
            return nil
        }
        struct InspectItem: Codable {
            struct Configuration: Codable {
                struct InitProcess: Codable { let environment: [String]? }
                struct Mount: Codable { let source: String?; let destination: String? }
                let initProcess: InitProcess?
                let mounts: [Mount]?
            }
            let configuration: Configuration
        }
        guard let items = try? JSONDecoder().decode([InspectItem].self, from: data),
              let item = items.first else {
            return nil
        }
        let env = item.configuration.initProcess?.environment ?? []
        let mounts = (item.configuration.mounts ?? []).compactMap { mount -> ContainerMount? in
            guard let source = mount.source, let destination = mount.destination else { return nil }
            return ContainerMount(source: source, destination: destination)
        }
        return ContainerInfo(environment: env, mounts: mounts)
    }

    /// List a directory inside a running container via `ls -la`. Empty if the
    /// container is not running or the path is unreadable.
    public func listContainerDirectory(id: String, path: String) -> [ContainerFileEntry] {
        guard let out = engine.run(["exec", id, "ls", "-la", path]) else { return [] }
        var entries: [ContainerFileEntry] = []
        for raw in out.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            if line.hasPrefix("total ") { continue }
            let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard parts.count >= 9 else { continue }
            let perms = parts[0]
            let isDir = perms.hasPrefix("d")
            let isLink = perms.hasPrefix("l")
            let modified = parts[5...7].joined(separator: " ")
            var name = parts[8...].joined(separator: " ")
            if name == "." { continue }
            if isLink, let arrow = name.range(of: " -> ") { name = String(name[..<arrow.lowerBound]) }
            let size = (isDir || isLink) ? "—" : Self.humanFileSize(parts[4])
            entries.append(ContainerFileEntry(name: name, isDirectory: isDir, size: size, modified: modified))
        }
        return entries.sorted { a, b in
            if a.name == ".." { return b.name != ".." }
            if b.name == ".." { return false }
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.lowercased() < b.name.lowercased()
        }
    }

    private static func humanFileSize(_ raw: String) -> String {
        guard let bytes = Double(raw) else { return raw }
        if bytes >= 1_073_741_824 { return String(format: "%.1f GB", bytes / 1_073_741_824) }
        if bytes >= 1_048_576 { return String(format: "%.1f MB", bytes / 1_048_576) }
        if bytes >= 1024 { return String(format: "%.1f KB", bytes / 1024) }
        return "\(Int(bytes)) B"
    }

    /// Real `container inspect <id>` output, pretty-printed. Nil if the container
    /// is unknown or the runtime returns nothing.
    public func inspectContainer(id: String) -> String? {
        guard let output = engine.run(["inspect", id]), !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        // Re-serialize for stable, pretty-printed display.
        if let data = output.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: pretty, encoding: .utf8) {
            return prettyString
        }
        return output
    }
    
    // MARK: - Internal Routing sync
    
    /// Rebuild `routing.json` from an already-fetched container list (no re-enumeration),
    /// writing only when the route set actually changed.
    private func syncRoutingConfig(using containers: [Container]) {
        var routes: [String: Int] = [:]
        for container in containers where container.state == "running" {
            routes.merge(container.routeMappings) { _, new in new }
        }
        let config = RoutingConfig(routes: routes)

        routingLock.lock()
        defer { routingLock.unlock() }
        // Skip the write only when nothing changed AND the file is still on disk — so an
        // out-of-band deletion is recovered rather than masked by the dedup.
        if config == lastWrittenRouting && FileManager.default.fileExists(atPath: routingConfigURL.path) {
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(config) {
            do {
                try data.write(to: routingConfigURL)
                lastWrittenRouting = config   // only record success on an actual successful write
            } catch {
                // Leave lastWrittenRouting unchanged so a transient failure retries next tick.
            }
        }
    }
    
    private func getTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}
