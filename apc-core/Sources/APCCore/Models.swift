import Foundation

public struct Container: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var image: String
    public var state: String // "running", "stopped", "paused"
    public var ports: [String] // e.g., ["80:8080"]
    public var cpuUsage: Double // Live CPU %, 0 when no live sample is available
    public var memoryUsage: Double // Live memory MB, 0 when no live sample is available
    public var cpuCores: Int // Allocated vCPUs (real, from the runtime)
    public var memoryLimitMB: Double // Allocated memory limit in MB (real, from the runtime)
    public var logs: [String]

    public init(id: String, name: String, image: String, state: String, ports: [String], cpuUsage: Double, memoryUsage: Double, cpuCores: Int = 0, memoryLimitMB: Double = 0, logs: [String]) {
        self.id = id
        self.name = name
        self.image = image
        self.state = state
        self.ports = ports
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.cpuCores = cpuCores
        self.memoryLimitMB = memoryLimitMB
        self.logs = logs
    }
}

// MARK: - Port mapping & developer-facing domains
//
// Published ports arrive as "host:guest" strings (e.g. "8081:80"). The host side
// is what the developer reaches; the guest side is internal. This is the single
// place that knows how to read that format and how a container's name becomes an
// `*.apc.local` domain — callers ask the container instead of re-parsing.
extension Container {
    /// Host-side port of one published-port string ("8081:80" -> 8081, or a bare "8081").
    static func hostPort(of portString: String) -> Int? {
        if let head = portString.split(separator: ":").first, let port = Int(head) { return port }
        return Int(portString)
    }

    /// Host port the container's first published port maps to, if any.
    public var hostPort: Int? {
        ports.lazy.compactMap(Container.hostPort(of:)).first
    }

    /// The container's primary developer-facing domain, e.g. `web.apc.local`.
    public var primaryDomain: String { "\(name).apc.local" }

    /// Every `*.apc.local` domain this container publishes, mapped to its host port.
    /// The first published port owns the bare `name.apc.local`; each later port gets
    /// `name-<hostPort>.apc.local`, matching the reverse proxy's routing table.
    public var routeMappings: [String: Int] {
        var routes: [String: Int] = [:]
        for (index, portString) in ports.enumerated() {
            let port = Container.hostPort(of: portString) ?? 8080
            let domain = index == 0 ? primaryDomain : "\(name)-\(port).apc.local"
            routes[domain] = port
        }
        return routes
    }
}

public struct ContainerImage: Codable, Identifiable, Hashable {
    public var id: String
    public var repository: String
    public var tag: String
    public var size: String // e.g., "7.5 MB"
    public var created: String
    
    public init(id: String, repository: String, tag: String, size: String, created: String) {
        self.id = id
        self.repository = repository
        self.tag = tag
        self.size = size
        self.created = created
    }
}

public struct Volume: Codable, Identifiable, Hashable {
    public var id: String { name }
    public var name: String
    public var size: String // e.g., "12.4 MB"
    public var mountPoint: String
    
    public init(name: String, size: String, mountPoint: String) {
        self.name = name
        self.size = size
        self.mountPoint = mountPoint
    }
}

public struct USBDevice: Codable, Identifiable, Hashable {
    public var id: String { "\(vendorId):\(productId):\(serialNumber)" }
    public var name: String
    public var vendorId: String
    public var productId: String
    public var serialNumber: String
    public var isAttached: Bool
    
    public init(name: String, vendorId: String, productId: String, serialNumber: String, isAttached: Bool) {
        self.name = name
        self.vendorId = vendorId
        self.productId = productId
        self.serialNumber = serialNumber
        self.isAttached = isAttached
    }
}

/// On-disk schema of `routing.json`, mirrored by `Config` in apc-network/routing.go.
/// The container layer is its only writer; the reverse proxy's routing registry reads it.
public struct RoutingConfig: Codable, Equatable {
    public var routes: [String: Int]

    public init(routes: [String: Int]) {
        self.routes = routes
    }
}

/// One entry in a container's filesystem, parsed from `ls -la` inside the guest.
public struct ContainerFileEntry: Sendable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let isDirectory: Bool
    public let size: String
    public let modified: String

    public init(name: String, isDirectory: Bool, size: String, modified: String) {
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modified = modified
    }
}

/// A real mount on a container, from inspect JSON.
public struct ContainerMount: Sendable, Hashable {
    public let source: String
    public let destination: String

    public init(source: String, destination: String) {
        self.source = source
        self.destination = destination
    }
}

/// Real environment + mounts for a container, decoded from `container inspect`.
public struct ContainerInfo: Sendable {
    public let environment: [String]
    public let mounts: [ContainerMount]

    public init(environment: [String], mounts: [ContainerMount]) {
        self.environment = environment
        self.mounts = mounts
    }
}

/// A live, real-time resource sample for a single running container, read from
/// the guest cgroup v2 files via `container exec`.
public struct LiveContainerStats: Sendable, Equatable {
    public let memoryBytes: UInt64
    public let cpuPercent: Double // normalized to allocated cores (0...100)

    public init(memoryBytes: UInt64, cpuPercent: Double) {
        self.memoryBytes = memoryBytes
        self.cpuPercent = cpuPercent
    }
}

public struct APCHardwareStats: Codable {
    public var cpuUsage: Double
    public var memoryUsage: Double
    public var maxMemory: Double
    
    public init(cpuUsage: Double, memoryUsage: Double, maxMemory: Double) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.maxMemory = maxMemory
    }
}

public struct VMConfig: Codable, Hashable {
    public var allocatedCPUs: Int
    public var allocatedMemoryGB: Int
    public var enableRosetta: Bool
    
    public init(allocatedCPUs: Int, allocatedMemoryGB: Int, enableRosetta: Bool = true) {
        self.allocatedCPUs = allocatedCPUs
        self.allocatedMemoryGB = allocatedMemoryGB
        self.enableRosetta = enableRosetta
    }
    
    enum CodingKeys: String, CodingKey {
        case allocatedCPUs
        case allocatedMemoryGB
        case enableRosetta
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        allocatedCPUs = try container.decode(Int.self, forKey: .allocatedCPUs)
        allocatedMemoryGB = try container.decode(Int.self, forKey: .allocatedMemoryGB)
        enableRosetta = try container.decodeIfPresent(Bool.self, forKey: .enableRosetta) ?? true
    }
}
