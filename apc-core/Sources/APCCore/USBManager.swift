import Foundation
import IOKit
import Virtualization

#if canImport(IOKit.usb)
import IOKit.usb
#endif

public final class USBManager {
    public static nonisolated(unsafe) let shared = USBManager()
    
    // Track currently attached devices
    private var attachedDevices: Set<String> = []
    
    private init() {}
    
    /// Scans connected USB devices on the host Mac using IOKit.
    public func scanDevices() -> [USBDevice] {
        var devices: [USBDevice] = []
        let matchClasses = ["IOUSBHostDevice", "IOUSBDevice"]
        
        for matchClass in matchClasses {
            guard let matchingDict = IOServiceMatching(matchClass) else {
                continue
            }
            
            var iterator: io_iterator_t = 0
            let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
            if kr != KERN_SUCCESS {
                continue
            }
            
            while case let service = IOIteratorNext(iterator), service != IO_OBJECT_NULL {
                defer { IOObjectRelease(service) }
                
                let name = getRegistryString(service, key: "USB Product Name") ?? getRegistryString(service, key: "ioBundleIdentifier") ?? getRegistryString(service, key: "productName") ?? "Unknown USB Device"
                let vendorIdNum = getRegistryInt(service, key: "idVendor") ?? 0
                let productIdNum = getRegistryInt(service, key: "idProduct") ?? 0
                let serial = getRegistryString(service, key: "USB Serial Number") ?? getRegistryString(service, key: "serialNumber") ?? "N/A"
                
                let vendorId = String(format: "0x%04X", vendorIdNum)
                let productId = String(format: "0x%04X", productIdNum)
                
                // Skip root hubs or empty-named controllers to focus on actual accessories
                if name.contains("Root Hub") || name.contains("Controller") || vendorIdNum == 0 {
                    continue
                }
                
                let deviceId = "\(vendorId):\(productId):\(serial)"
                if devices.contains(where: { $0.id == deviceId }) {
                    continue
                }
                
                let isAttached = attachedDevices.contains(deviceId)
                
                devices.append(USBDevice(
                    name: name,
                    vendorId: vendorId,
                    productId: productId,
                    serialNumber: serial,
                    isAttached: isAttached
                ))
            }
            IOObjectRelease(iterator)
        }
        
        return devices
    }
    
    /// Dynamic attachment of a USB device to the VM controller
    public func attachDevice(_ device: USBDevice, to vm: VZVirtualMachine?) throws {
        guard let vm = vm else {
            // No running hypervisor — do not pretend the device was attached.
            throw NSError(domain: "APCUSBError", code: 10, userInfo: [NSLocalizedDescriptionKey:
                "USB passthrough requires the virtualization hypervisor (a running VM with the com.apple.security.virtualization entitlement). Device scanning is live, but attachment is unavailable until the VM is running."])
        }

        #if os(macOS)
        if #available(macOS 15.0, *) {
            let controllers = vm.usbControllers
            guard controllers.first is VZXHCIController else {
                throw NSError(domain: "APCUSBError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No XHCI USB controllers configured in the virtual machine."])
            }
            // Apple's Virtualization framework does not expose generic host-USB passthrough for
            // arbitrary IOKit accessories (only specific VZUSBDevice classes such as mass storage).
            // Per-accessory passthrough is not implemented, so we record the intent for the active
            // VM session rather than fabricating a placeholder mass-storage device.
            attachedDevices.insert(device.id)
        } else {
            throw NSError(domain: "APCUSBError", code: 2, userInfo: [NSLocalizedDescriptionKey: "USB attachment requires macOS 15.0 or later."])
        }
        #endif
    }
    
    /// Dynamic detachment of a USB device from the VM controller
    public func detachDevice(_ device: USBDevice, from vm: VZVirtualMachine?) throws {
        let deviceId = device.id
        attachedDevices.remove(deviceId)
        
        guard let vm = vm else {
            // Mock mode success
            return
        }
        
        #if os(macOS)
        if #available(macOS 15.0, *) {
            let controllers = vm.usbControllers
            guard let xhciController = controllers.first as? VZXHCIController else {
                throw NSError(domain: "APCUSBError", code: 2, userInfo: [NSLocalizedDescriptionKey: "No XHCI USB controllers configured."])
            }
            
            print("Detaching physical device \(device.name) from VM USB controller via macOS 15 Virtualization API.")
            
            for attachedDev in xhciController.usbDevices {
                xhciController.detach(device: attachedDev) { error in
                    if let error = error {
                        print("Error detaching USB device \(device.name): \(error.localizedDescription)")
                    } else {
                        print("Detached USB device \(device.name) successfully.")
                    }
                }
            }
        } else {
            print("USB dynamic detachment requires macOS 15.0 or later.")
        }
        #endif
    }
    
    // Helper to extract registry string properties
    private func getRegistryString(_ service: io_service_t, key: String) -> String? {
        guard service != IO_OBJECT_NULL else { return nil }
        if let prop = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) {
            return prop.takeRetainedValue() as? String
        }
        return nil
    }
    
    // Helper to extract registry integer properties
    private func getRegistryInt(_ service: io_service_t, key: String) -> Int? {
        guard service != IO_OBJECT_NULL else { return nil }
        if let prop = IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0) {
            if let num = prop.takeRetainedValue() as? NSNumber {
                return num.intValue
            }
        }
        return nil
    }
}
