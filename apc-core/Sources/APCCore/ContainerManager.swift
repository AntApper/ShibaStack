import Foundation

public final class ContainerManager: @unchecked Sendable {
    public static let shared = ContainerManager()

    private let engine: ContainerEngine
    private let routingConfigURL: URL

    // Live-stats sampling state (cgroup CPU needs a delta between two reads).
    private let statsLock = NSLock()
    private var cpuSamples: [String: (usageUsec: UInt64, at: Date)] = [:]
    private var lastHostCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

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

        // Sync routing initially
        syncRoutingConfig()
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

                // Real allocated resources reported by the runtime.
                let cores = config.resources?.cpus ?? 0
                let memoryLimitMB = Double(config.resources?.memoryInBytes ?? 0) / (1024.0 * 1024.0)

                // Real container logs — empty if the container has produced none yet.
                var containerLogs: [String] = []
                if let logOutput = engine.run(["logs", id]) {
                    containerLogs = logOutput.components(separatedBy: "\n").filter { !$0.isEmpty }
                }

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
                    logs: containerLogs
                )
            }
            
            // Sync routing config with host whenever containers refresh
            DispatchQueue.global(qos: .background).async {
                self.syncRoutingConfig()
            }
            
            return result
        } catch {
            print("[ContainerManager] JSON decoding failed for containers list: \(error)")
            return []
        }
    }
    
    public func startContainer(id: String) throws {
        _ = engine.run(["start", id])
        syncRoutingConfig()
    }
    
    public func stopContainer(id: String) {
        _ = engine.run(["stop", id])
        syncRoutingConfig()
    }
    
    public func runNewContainer(name: String, image: String, portMap: String) throws -> Container {
        var args = ["run", "-d", "--name", name]
        
        // Parse port map (e.g., 8085:8080)
        if !portMap.isEmpty {
            args.append(contentsOf: ["-p", portMap])
        }
        args.append(image)
        
        _ = engine.run(args)
        syncRoutingConfig()
        
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
        syncRoutingConfig()
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
                let ref = item.reference
                
                // Extract repository name and tag
                var cleanRef = ref
                if cleanRef.hasPrefix("docker.io/library/") {
                    cleanRef = String(cleanRef.dropFirst("docker.io/library/".count))
                } else if cleanRef.hasPrefix("docker.io/") {
                    cleanRef = String(cleanRef.dropFirst("docker.io/".count))
                }
                
                let parts = cleanRef.split(separator: ":")
                let repo = String(parts.first ?? "unknown")
                let tag = parts.count > 1 ? String(parts[1]) : "latest"
                
                // Format size
                let sizeInMB = Double(item.descriptor.size) / (1024.0 * 1024.0)
                let sizeStr = sizeInMB > 1.0 ? String(format: "%.1f MB", sizeInMB) : "N/A"
                
                return ContainerImage(
                    id: ref,
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
    
    public func addImage(repository: String, tag: String) {
        let imageRef = tag.isEmpty ? repository : "\(repository):\(tag)"
        // Run pull synchronously or in background
        _ = engine.run(["image", "pull", imageRef])
    }
    
    public func removeImage(id: String) {
        _ = engine.run(["image", "rm", id])
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
        _ = engine.run(["volume", "create", name])
    }

    public func removeVolume(id: String) throws {
        _ = engine.run(["volume", "rm", id])
    }

    /// Reclaim disk by removing unreferenced images and snapshots.
    /// The runtime has no `volume prune`; image prune is the real disk-reclaim path.
    public func pruneStorage() {
        _ = engine.run(["image", "prune"])
    }
    
    // MARK: - Hardware Stats API
    
    public func getStats() -> APCHardwareStats {
        // Real figures: live host CPU, and memory committed by running containers
        // against the VM's configured ceiling.
        let active = getContainers().filter { $0.state == "running" }
        let committedMemoryMB = active.reduce(0.0) { $0 + $1.memoryLimitMB }
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
    
    private func syncRoutingConfig() {
        var routes: [String: Int] = [:]

        for container in getContainers() where container.state == "running" {
            routes.merge(container.routeMappings) { _, new in new }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(RoutingConfig(routes: routes)) {
            try? data.write(to: routingConfigURL)
        }
    }
    
    private func getTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}
