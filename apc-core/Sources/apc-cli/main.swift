import Foundation
import APCCore

func pad(_ string: String, toWidth width: Int) -> String {
    let paddingAmount = width - string.count
    if paddingAmount > 0 {
        return string + String(repeating: " ", count: paddingAmount)
    } else {
        return String(string.prefix(width))
    }
}

func printUsage() {
    print("""
Apple Private Container (APC) CLI Tool

Usage:
  apc <command> [options]

Core Commands:
  start                     Start the native APC virtualization environment
  stop                      Stop the native APC virtualization environment
  status                    Check the current status of the APC hypervisor
  ps                        List all active/stopped Alpine-based containers
  run <name> <image> <port> Spin up a new Alpine-based OCI container
  rm <container_id>         Remove/delete an inactive container
  logs <container_id>       Stream/view active container logs
  prune                     Perform a one-click disk and unused volume clean
  doctor                    Perform system diagnostic check of dependencies
  config                    Manage persistent VM resource allocations

Hardware & Network Commands:
  usb list                  Scan and list connected host USB devices
  usb attach <device_id>    Attach/forward a host USB device into the VM
  usb detach <device_id>    Detach/disconnect a host USB device from the VM
  network                   List active port mappings and local DNS domains

Run 'apc <command> --help' for details on a specific command.
""")
}

func main() {
    let args = CommandLine.arguments
    guard args.count > 1 else {
        printUsage()
        exit(64) // Standard EX_USAGE exit code for missing command parameters
    }
    
    let command = args[1].lowercased()
    let vmManager = VMManager.shared
    let containerManager = ContainerManager.shared
    let usbManager = USBManager.shared
    
    switch command {
    case "doctor":
        runDoctor()
        
    case "config":
        guard args.count > 2 else {
            let config = vmManager.loadVMConfig()
            print("--- ShibaStack Virtual Machine Allocation Configuration ---")
            print("  CPU Allocation   : \(config.allocatedCPUs) Cores")
            print("  Memory Allocation: \(config.allocatedMemoryGB) GB")
            print("")
            print("Usage:")
            print("  apc config set cpu <count>     (Set allocated CPU cores)")
            print("  apc config set memory <gb>     (Set allocated memory in GB)")
            exit(0)
        }
        let subCommand = args[2].lowercased()
        if subCommand == "set" {
            guard args.count > 4 else {
                print("Error: Missing key and value.")
                print("Usage: apc config set <cpu|memory> <value>")
                exit(1)
            }
            let key = args[3].lowercased()
            let valStr = args[4]
            guard let val = Int(valStr) else {
                print("Error: Value must be an integer.")
                exit(1)
            }
            
            var currentConfig = vmManager.loadVMConfig()
            if key == "cpu" {
                currentConfig.allocatedCPUs = val
                vmManager.saveVMConfig(currentConfig)
                print("Successfully updated CPU allocation to \(val) cores. (Restart ShibaStack to apply changes)")
            } else if key == "memory" {
                currentConfig.allocatedMemoryGB = val
                vmManager.saveVMConfig(currentConfig)
                print("Successfully updated Memory allocation to \(val) GB. (Restart ShibaStack to apply changes)")
            } else {
                print("Error: Unknown configuration key '\(key)'. Supported: cpu, memory")
                exit(1)
            }
        } else {
            print("Unknown config command: \(subCommand). Supported: set")
            exit(1)
        }
        
    case "start":
        print("Starting Apple Private Container (APC) VM engine...")
        do {
            try vmManager.startVM()
            print("Successfully started APC virtualization engine. State: \(vmManager.getVMState())")
        } catch {
            print("Error starting APC engine: \(error.localizedDescription)")
            exit(1)
        }
        
    case "stop":
        print("Stopping Apple Private Container (APC) VM engine...")
        do {
            try vmManager.stopVM()
            print("Successfully stopped APC virtualization engine.")
        } catch {
            print("Error stopping APC engine: \(error.localizedDescription)")
            exit(1)
        }
        
    case "status":
        print("APC Virtualization Engine State: \(vmManager.getVMState().uppercased())")
        
    case "rm":
        guard args.count > 2 else {
            print("Error: Please specify container ID to remove.")
            print("Usage: apc rm <container_id>")
            exit(1)
        }
        let targetId = args[2]
        if let cont = containerManager.getContainers().first(where: { $0.id == targetId || $0.name == targetId }) {
            containerManager.removeContainer(id: cont.id)
            print("Successfully removed container \(cont.name) (\(cont.id)).")
        } else {
            print("Error: Container '\(targetId)' not found.")
            exit(1)
        }
        
    case "ps":
        let list = containerManager.getContainers()
        print("\(pad("CONTAINER ID", toWidth: 16)) \(pad("NAME", toWidth: 20)) \(pad("IMAGE", toWidth: 22)) \(pad("STATUS", toWidth: 12)) \(pad("PORTS", toWidth: 12))")
        print(String(repeating: "-", count: 85))
        for cont in list {
            print("\(pad(cont.id, toWidth: 16)) \(pad(cont.name, toWidth: 20)) \(pad(cont.image, toWidth: 22)) \(pad(cont.state.uppercased(), toWidth: 12)) \(pad(cont.ports.joined(separator: ", "), toWidth: 12))")
        }
        
    case "run":
        guard args.count >= 5 else {
            print("Error: Missing parameters for 'run' command.")
            print("Usage: apc run <name> <image> <host_port:container_port>")
            exit(1)
        }
        let name = args[2]
        let image = args[3]
        let portMap = args[4]
        
        print("Spinning up new container '\(name)' from image '\(image)'...")
        do {
            let newCont = try containerManager.runNewContainer(name: name, image: image, portMap: portMap)
            print("Successfully created and launched container \(newCont.id).")
            print("Accessible via: http://\(name).apc.local")
        } catch {
            print("Failed to run container: \(error.localizedDescription)")
            exit(1)
        }
        
    case "logs":
        guard args.count > 2 else {
            print("Error: Please specify container ID.")
            print("Usage: apc logs <container_id>")
            exit(1)
        }
        let targetId = args[2]
        if let cont = containerManager.getContainers().first(where: { $0.id == targetId || $0.name == targetId }) {
            print("--- Logs for \(cont.name) (\(cont.id)) ---")
            for logLine in cont.logs {
                print(logLine)
            }
        } else {
            print("Error: Container '\(targetId)' not found.")
            exit(1)
        }
        
    case "prune":
        print("Performing system disk and volume prune...")
        let beforeCount = containerManager.getVolumes().count
        containerManager.pruneVolumes()
        let afterCount = containerManager.getVolumes().count
        print("Prune completed successfully. Reclaimed volumes: \(beforeCount - afterCount).")
        
    case "usb":
        guard args.count > 2 else {
            print("Usage:")
            print("  apc usb list")
            print("  apc usb attach <vendor_id:product_id:serial>")
            print("  apc usb detach <vendor_id:product_id:serial>")
            exit(1)
        }
        let subCommand = args[2].lowercased()
        switch subCommand {
        case "list":
            let usbList = usbManager.scanDevices()
            print("\(pad("DEVICE NAME", toWidth: 24)) \(pad("VENDOR ID", toWidth: 12)) \(pad("PRODUCT ID", toWidth: 12)) \(pad("SERIAL NUMBER", toWidth: 16)) \(pad("ATTACHED", toWidth: 10))")
            print(String(repeating: "-", count: 80))
            for dev in usbList {
                print("\(pad(dev.name, toWidth: 24)) \(pad(dev.vendorId, toWidth: 12)) \(pad(dev.productId, toWidth: 12)) \(pad(dev.serialNumber, toWidth: 16)) \(pad(dev.isAttached ? "YES" : "NO", toWidth: 10))")
            }
        case "attach":
            guard vmManager.getVMState() == "running" else {
                print("Error: The ShibaStack VM engine is not running. Start it with 'apc start' before attaching devices.")
                exit(1)
            }
            guard args.count > 3 else {
                print("Error: Specify device ID to attach.")
                exit(1)
            }
            let devId = args[3]
            let usbList = usbManager.scanDevices()
            if let targetDev = usbList.first(where: { $0.id == devId }) {
                do {
                    try usbManager.attachDevice(targetDev, to: vmManager.getUnderlyingVM())
                    print("Successfully attached USB device: \(targetDev.name)")
                } catch {
                    print("Failed to attach USB device: \(error.localizedDescription)")
                    exit(1)
                }
            } else {
                print("Error: Device '\(devId)' not found in host USB scan.")
                exit(1)
            }
        case "detach":
            guard vmManager.getVMState() == "running" else {
                print("Error: The ShibaStack VM engine is not running. Start it with 'apc start' before detaching devices.")
                exit(1)
            }
            guard args.count > 3 else {
                print("Error: Specify device ID to detach.")
                exit(1)
            }
            let devId = args[3]
            let usbList = usbManager.scanDevices()
            if let targetDev = usbList.first(where: { $0.id == devId }) {
                do {
                    try usbManager.detachDevice(targetDev, from: vmManager.getUnderlyingVM())
                    print("Successfully detached USB device: \(targetDev.name)")
                } catch {
                    print("Failed to detach USB device: \(error.localizedDescription)")
                    exit(1)
                }
            } else {
                print("Error: Device '\(devId)' not found.")
                exit(1)
            }
        default:
            print("Unknown USB command: \(subCommand)")
            exit(1)
        }
        
    case "network":
        print("Active Port Mappings & Domains:")
        print(String(repeating: "-", count: 60))
        for cont in containerManager.getContainers() {
            if cont.state == "running" {
                print("\(pad(cont.ports.joined(separator: ", "), toWidth: 20)) -> \(pad(cont.name, toWidth: 16)) (Local Domain: http://\(cont.name).apc.local)")
            }
        }
        
    case "--help", "help":
        printUsage()
        
    default:
        print("Unknown command: \(command)")
        printUsage()
        exit(1)
    }
}

func runDoctor() {
    print("--------------------------------------------------")
    print("🐕 ShibaStack: Apple Private Container (APC) Doctor")
    print("--------------------------------------------------")
    print("Checking system dependencies and environment:")
    
    // 1. Check Swift/Xcode CLI Tools
    let swiftPath = checkCommandExists("swift")
    if swiftPath {
        print("  [✓] Xcode Command Line Tools (Swift): Installed")
    } else {
        print("  [✗] Xcode Command Line Tools (Swift): NOT Found")
    }
    
    // 2. Check Go Compiler
    let goPath = checkCommandExists("go")
    if goPath {
        print("  [✓] Go Compiler: Installed")
    } else {
        print("  [✗] Go Compiler: NOT Found (Required for local DNS/reverse proxy)")
    }
    
    // 3. Check State Directory
    let home = FileManager.default.homeDirectoryForCurrentUser
    let apcDir = home.appendingPathComponent(".apc")
    let envExists = FileManager.default.fileExists(atPath: apcDir.path)
    if envExists {
        print("  [✓] Local State Folder (~/.apc): Initialized")
    } else {
        print("  [✗] Local State Folder (~/.apc): NOT Initialized (Run 'apc start' or launch ShibaStack app)")
    }
    
    // 4. Check DNS Resolver Rule
    let resolverExists = FileManager.default.fileExists(atPath: "/etc/resolver/apc.local")
    if resolverExists {
        print("  [✓] macOS DNS Resolver Rule (/etc/resolver/apc.local): Configured")
    } else {
        print("  [✗] macOS DNS Resolver Rule (/etc/resolver/apc.local): NOT Configured")
    }
    
    print("--------------------------------------------------")
    if swiftPath && goPath && envExists && resolverExists {
        print("Everything is healthy! ShibaStack is ready to manage containers.")
    } else {
        print("Some dependencies are missing. Please launch the ShibaStack GUI application to automatically install and configure these components.")
    }
    print("--------------------------------------------------")
}

func checkCommandExists(_ command: String) -> Bool {
    if command == "go" {
        let standardPaths = [
            "/opt/homebrew/bin/go",
            "/usr/local/bin/go",
            "/usr/local/go/bin/go",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/go/bin/go"
        ]
        for path in standardPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
    } else if command == "swift" {
        let standardPaths = [
            "/usr/bin/swift",
            "/opt/homebrew/bin/swift",
            "/usr/local/bin/swift"
        ]
        for path in standardPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
    }

    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    task.arguments = [command]
    let pipe = Pipe()
    task.standardOutput = pipe
    
    do {
        try task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    } catch {
        print("[APC-Core] Warning: Failed to spawn '/usr/bin/which' process: \(error.localizedDescription)")
        return false
    }
}

main()
