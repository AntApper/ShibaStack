import Foundation

public final class ContainerManager {
    public static nonisolated(unsafe) let shared = ContainerManager()
    
    private var containers: [Container] = []
    private var images: [ContainerImage] = []
    private var volumes: [Volume] = []
    
    private let routingConfigURL: URL
    private let containersFileURL: URL
    private let imagesFileURL: URL
    private let volumesFileURL: URL
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let apcDir = home.appendingPathComponent(".apc")
        try? FileManager.default.createDirectory(at: apcDir, withIntermediateDirectories: true)
        self.routingConfigURL = apcDir.appendingPathComponent("routing.json")
        self.containersFileURL = apcDir.appendingPathComponent("containers.json")
        self.imagesFileURL = apcDir.appendingPathComponent("images.json")
        self.volumesFileURL = apcDir.appendingPathComponent("volumes.json")
        
        loadInitialData()
    }
    
    private func saveState() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(containers) {
            try? data.write(to: containersFileURL, options: .atomic)
        }
        if let data = try? encoder.encode(images) {
            try? data.write(to: imagesFileURL, options: .atomic)
        }
        if let data = try? encoder.encode(volumes) {
            try? data.write(to: volumesFileURL, options: .atomic)
        }
        syncRoutingConfig()
    }
    
    private func loadInitialData() {
        let decoder = JSONDecoder()
        
        // Try loading containers
        if let data = try? Data(contentsOf: containersFileURL),
           let list = try? decoder.decode([Container].self, from: data) {
            self.containers = list
        } else {
            self.containers = []
        }
        
        // Try loading images
        if let data = try? Data(contentsOf: imagesFileURL),
           let list = try? decoder.decode([ContainerImage].self, from: data) {
            self.images = list
        } else {
            self.images = []
        }
        
        // Try loading volumes
        if let data = try? Data(contentsOf: volumesFileURL),
           let list = try? decoder.decode([Volume].self, from: data) {
            self.volumes = list
        } else {
            self.volumes = []
        }
        
        // Sync & Save
        saveState()
    }
    
    // MARK: - Port Collision Helpers
    
    private func getHostPorts(for container: Container) -> Set<Int> {
        var hostPorts = Set<Int>()
        for portStr in container.ports {
            let parts = portStr.split(separator: ":")
            if let first = parts.first, let parsed = Int(first) {
                hostPorts.insert(parsed)
            } else if let parsed = Int(portStr) {
                hostPorts.insert(parsed)
            }
        }
        return hostPorts
    }
    
    public func hasPortCollision(for ports: [String], excludingContainerID: String? = nil) -> String? {
        var prospectivePorts = Set<Int>()
        for portStr in ports {
            let parts = portStr.split(separator: ":")
            if let first = parts.first, let parsed = Int(first) {
                prospectivePorts.insert(parsed)
            } else if let parsed = Int(portStr) {
                prospectivePorts.insert(parsed)
            }
        }
        
        for cont in containers {
            guard cont.state == "running" else { continue }
            if let exclude = excludingContainerID, cont.id == exclude { continue }
            
            let activePorts = getHostPorts(for: cont)
            let intersection = prospectivePorts.intersection(activePorts)
            if !intersection.isEmpty {
                let portsStr = intersection.map { String($0) }.joined(separator: ", ")
                return "Port collision: Port(s) \(portsStr) already in use by running container '\(cont.name)'."
            }
        }
        return nil
    }
    
    // MARK: - Container APIs
    
    public func getContainers() -> [Container] {
        return containers
    }
    
    public func startContainer(id: String) throws {
        guard let idx = containers.firstIndex(where: { $0.id == id }) else { return }
        let container = containers[idx]
        
        if let collisionMessage = hasPortCollision(for: container.ports, excludingContainerID: id) {
            throw NSError(domain: "ContainerManager", code: 1, userInfo: [NSLocalizedDescriptionKey: collisionMessage])
        }
        
        containers[idx].state = "running"
        containers[idx].cpuUsage = 0.5
        containers[idx].memoryUsage = 35.0
        containers[idx].logs.append("\(getTimestamp()) [info] Container started by user request.")
        saveState()
    }
    
    public func stopContainer(id: String) {
        if let idx = containers.firstIndex(where: { $0.id == id }) {
            containers[idx].state = "stopped"
            containers[idx].cpuUsage = 0.0
            containers[idx].memoryUsage = 0.0
            containers[idx].logs.append("\(getTimestamp()) [info] Container stopped by user request.")
            saveState()
        }
    }
    
    public func runNewContainer(name: String, image: String, portMap: String) throws -> Container {
        if let collisionMessage = hasPortCollision(for: [portMap]) {
            throw NSError(domain: "ContainerManager", code: 2, userInfo: [NSLocalizedDescriptionKey: collisionMessage])
        }
        
        let id = "c_custom_" + UUID().uuidString.prefix(6).lowercased()
        
        let newCont = Container(
            id: id,
            name: name,
            image: image,
            state: "running",
            ports: [portMap],
            cpuUsage: 0.6,
            memoryUsage: 45.0,
            logs: [
                "\(getTimestamp()) [info] Initializing container \(name)...",
                "\(getTimestamp()) [info] Container is now running."
            ]
        )
        containers.append(newCont)
        saveState()
        return newCont
    }
    
    public func addPortForward(containerName: String, portMap: String) {
        if let idx = containers.firstIndex(where: { $0.name == containerName }) {
            containers[idx].ports.append(portMap)
            saveState()
        }
    }
    
    public func removeContainer(id: String) {
        containers.removeAll(where: { $0.id == id })
        saveState()
    }
    
    // MARK: - Image APIs
    
    public func getImages() -> [ContainerImage] {
        return images
    }
    
    public func addImage(repository: String, tag: String) {
        let id = "img_" + UUID().uuidString.prefix(6).lowercased()
        let newImage = ContainerImage(id: id, repository: repository, tag: tag, size: "24.1 MB", created: "Just now")
        images.append(newImage)
        saveState()
    }
    
    public func removeImage(id: String) {
        images.removeAll(where: { $0.id == id })
        saveState()
    }
    
    // MARK: - Volume APIs
    
    public func getVolumes() -> [Volume] {
        return volumes
    }
    
    // Creates a new persistent storage volume inside the registry.
    public func createVolume(name: String, mountPoint: String) throws {
        if volumes.contains(where: { $0.name == name }) {
            throw NSError(domain: "ContainerManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Volume '\(name)' already exists."])
        }
        let newVolume = Volume(name: name, size: "0.0 MB", mountPoint: mountPoint)
        volumes.append(newVolume)
        saveState()
    }
    
    public func removeVolume(id: String) throws {
        if !volumes.contains(where: { $0.id == id }) {
            throw NSError(domain: "ContainerManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Volume '\(id)' not found."])
        }
        volumes.removeAll { $0.id == id }
        saveState()
    }
    
    public func pruneVolumes() {
        // Keeps active postgres_data, prunes unused ones
        volumes.removeAll { $0.name == "nginx_logs" || $0.name == "redis_data" }
        saveState()
    }
    
    // MARK: - Hardware Stats API
    
    public func getStats() -> APCHardwareStats {
        let activeContainers = containers.filter { $0.state == "running" }
        let totalCpu = activeContainers.reduce(0.2) { $0 + $1.cpuUsage }
        let totalMem = activeContainers.reduce(84.0) { $0 + $1.memoryUsage }
        return APCHardwareStats(cpuUsage: min(totalCpu, 100.0), memoryUsage: totalMem, maxMemory: 4096.0)
    }
    
    // MARK: - Internal Routing sync
    
    private func syncRoutingConfig() {
        var routes: [String: Int] = [:]
        
        for container in containers {
            guard container.state == "running" else { continue }
            
            // Generate routing domains for all configured port mappings
            for (idx, portStr) in container.ports.enumerated() {
                var targetPort = 8080
                if let hostPort = portStr.split(separator: ":").first, let parsed = Int(hostPort) {
                    targetPort = parsed
                } else if let parsed = Int(portStr) {
                    targetPort = parsed
                }
                
                if idx == 0 {
                    let domain = "\(container.name).apc.local"
                    routes[domain] = targetPort
                } else {
                    let domain = "\(container.name)-\(targetPort).apc.local"
                    routes[domain] = targetPort
                }
            }
        }
        
        // Write routes to json file
        let config = ["routes": routes]
        if let data = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            try? data.write(to: routingConfigURL)
        }
    }
    
    private func getTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: Date())
    }
}
