import Foundation

public struct Container: Codable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var image: String
    public var state: String // "running", "stopped", "paused"
    public var ports: [String] // e.g., ["80:8080"]
    public var cpuUsage: Double // Percentage, e.g., 1.5
    public var memoryUsage: Double // MB, e.g., 128.0
    public var logs: [String]
    
    public init(id: String, name: String, image: String, state: String, ports: [String], cpuUsage: Double, memoryUsage: Double, logs: [String]) {
        self.id = id
        self.name = name
        self.image = image
        self.state = state
        self.ports = ports
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.logs = logs
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
    
    public init(allocatedCPUs: Int, allocatedMemoryGB: Int) {
        self.allocatedCPUs = allocatedCPUs
        self.allocatedMemoryGB = allocatedMemoryGB
    }
}
