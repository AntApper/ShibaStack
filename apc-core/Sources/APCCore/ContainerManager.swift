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
            // Load default containers
            containers = [
                Container(id: "c_alpine_web", name: "web-app", image: "alpine-nginx:3.18", state: "running", ports: ["80:8080"], cpuUsage: 0.8, memoryUsage: 42.1, logs: [
                    "2026-06-14 10:00:01 [info] Starting nginx/1.25.1",
                    "2026-06-14 10:00:02 [info] Listening on port 8080",
                    "2026-06-14 10:00:05 [info] Ready to serve HTTP traffic",
                    "2026-06-14 10:01:23 [info] GET / index.html 200 OK - Mozilla/5.0"
                ]),
                Container(id: "c_alpine_db", name: "postgres-db", image: "alpine-postgres:15", state: "running", ports: ["5432:5432"], cpuUsage: 0.4, memoryUsage: 112.5, logs: [
                    "2026-06-14 10:00:01 [info] Database system is ready to accept connections",
                    "2026-06-14 10:00:01 [info] listening on IPv4 address 0.0.0.0, port 5432",
                    "2026-06-14 10:10:45 [info] Autovacuum launcher started"
                ]),
                Container(id: "c_alpine_redis", name: "redis-cache", image: "alpine-redis:7.0", state: "stopped", ports: ["6379:6379"], cpuUsage: 0.0, memoryUsage: 0.0, logs: [
                    "2026-06-14 09:12:00 [info] Redis version=7.0.11, bits=64",
                    "2026-06-14 09:12:00 [warning] Warning: 32bit synthesis overridden",
                    "2026-06-14 09:12:01 [info] Server initialized",
                    "2026-06-14 09:30:00 [info] Connection closed by daemon"
                ])
            ]
        }
        
        // Try loading images
        if let data = try? Data(contentsOf: imagesFileURL),
           let list = try? decoder.decode([ContainerImage].self, from: data) {
            self.images = list
        } else {
            // Load default images
            images = [
                ContainerImage(id: "img_nginx", repository: "alpine-nginx", tag: "3.18", size: "18.4 MB", created: "2 days ago"),
                ContainerImage(id: "img_postgres", repository: "alpine-postgres", tag: "15", size: "124.2 MB", created: "1 week ago"),
                ContainerImage(id: "img_redis", repository: "alpine-redis", tag: "7.0", size: "32.1 MB", created: "3 weeks ago"),
                ContainerImage(id: "img_alpine_base", repository: "alpine", tag: "latest", size: "7.5 MB", created: "1 month ago")
            ]
        }
        
        // Try loading volumes
        if let data = try? Data(contentsOf: volumesFileURL),
           let list = try? decoder.decode([Volume].self, from: data) {
            self.volumes = list
        } else {
            // Load default volumes
            volumes = [
                Volume(name: "postgres_data", size: "154.2 MB", mountPoint: "/var/lib/postgresql/data"),
                Volume(name: "redis_data", size: "1.2 MB", mountPoint: "/data"),
                Volume(name: "nginx_logs", size: "0.4 MB", mountPoint: "/var/log/nginx")
            ]
        }
        
        // Sync & Save
        saveState()
    }
    
    // MARK: - Container APIs
    
    public func getContainers() -> [Container] {
        return containers
    }
    
    public func startContainer(id: String) {
        if let idx = containers.firstIndex(where: { $0.id == id }) {
            containers[idx].state = "running"
            containers[idx].cpuUsage = 0.5
            containers[idx].memoryUsage = 35.0
            containers[idx].logs.append("\(getTimestamp()) [info] Container started by user request.")
            saveState()
        }
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
    
    public func runNewContainer(name: String, image: String, portMap: String) -> Container {
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
