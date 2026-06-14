import Foundation
import APCCore

print("--------------------------------------------------")
print("ShibaStack: Apple Private Container (APC) Daemon")
print("--------------------------------------------------")
print("Initializing APC virtualization components...")

let vmManager = VMManager.shared
let containerManager = ContainerManager.shared
let usbManager = USBManager.shared

do {
    // Start VM in background mode (utilizes automatic Mock fallback if entitlements are not present)
    try vmManager.startVM()
    print("VM status: \(vmManager.getVMState())")
    
    let usbDevices = usbManager.scanDevices()
    print("Found \(usbDevices.count) host USB accessories:")
    for dev in usbDevices {
        print("  - \(dev.name) [\(dev.vendorId):\(dev.productId)] Serial: \(dev.serialNumber)")
    }
    
    print("\nRunning containers:")
    for cont in containerManager.getContainers() {
        print("  - \(cont.name) (\(cont.image)) Status: \(cont.state) Ports: \(cont.ports.joined(separator: ", "))")
    }
    
    // Start the Host Command Dispatcher over VSOCK on port 1024
    print("\n[APC-Daemon] Binding Host-Guest VSOCK command listener on port 1024...")
    VSOCKManager.shared.registerListener(onPort: 1024, vm: vmManager.getUnderlyingVM()) { fd in
        print("[APC-Daemon] Accepted connection from guest agent (fd: \(fd)). Ready for command routing.")
    }
    
    print("\nPress Ctrl+C to terminate the APC daemon.")
    
    // Main run loop to keep daemon alive
    let runLoop = RunLoop.current
    while runLoop.run(mode: .default, before: Date(timeIntervalSinceNow: 5.0)) {
        let stats = containerManager.getStats()
        print("[Stats Monitor] CPU: \(String(format: "%.1f", stats.cpuUsage))% | RAM: \(String(format: "%.1f", stats.memoryUsage)) MB / \(String(format: "%.0f", stats.maxMemory)) MB | VM Engine: \(vmManager.getVMState())")
        fflush(stdout)
    }
} catch {
    print("Failed to start APC daemon: \(error.localizedDescription)")
    exit(1)
}
