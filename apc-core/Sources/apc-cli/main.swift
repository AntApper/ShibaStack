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
  logs <container_id>       Stream/view active container logs
  prune                     Perform a one-click disk and unused volume clean

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
        return
    }
    
    let command = args[1].lowercased()
    let vmManager = VMManager.shared
    let containerManager = ContainerManager.shared
    let usbManager = USBManager.shared
    
    switch command {
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
        let newCont = containerManager.runNewContainer(name: name, image: image, portMap: portMap)
        print("Successfully created and launched container \(newCont.id).")
        print("Accessible via: http://\(name).apc.local")
        
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
                }
            } else {
                print("Error: Device '\(devId)' not found in host USB scan.")
            }
        case "detach":
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
                }
            } else {
                print("Error: Device '\(devId)' not found.")
            }
        default:
            print("Unknown USB command: \(subCommand)")
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

main()
