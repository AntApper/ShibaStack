# Apple Private Container (APC) Technical Architecture

This document describes the architectural layout, core systems, networking layers, and hardware passthrough protocols implemented in the Apple Private Container (APC) hypervisor suite.

## 1. Core Virtualization Layer (apc-core)

The virtualization layer leverages Apple's `Virtualization.framework` to execute lightweight, optimized Alpine-based guests on Apple Silicon.

### 1.1 Hypervisor Configuration & Lifecyle
The virtual machine is configured and instantiated programmatically in Swift using `VZVirtualMachineConfiguration`. 

```swift
let config = VZVirtualMachineConfiguration()
config.cpuCount = computeCpuCount()
config.memorySize = computeMemoryAllocation()
```

- **Boot Loader:** Uses standard Linux boot loading configurations (`VZLinuxBootLoader`) specifying the guest kernel, initrd, and command-line arguments to bypass monolithic storage boots.
- **Memory Ballooning:** Configured with `VZVirtioTraditionalMemoryBalloonDeviceConfiguration` to handle dynamic memory allocation. This allows the host macOS to reclaim unused physical RAM from the guest VM on demand, reducing inactive resource overhead.
- **Host Sharing (VirtioFS):** Employs `VZVirtioFileSystemDeviceConfiguration` with `VZSingleDirectoryShare` targeting `/Users` on the host. The directory share mounts `/Users` inside the Alpine environment with native performance, allowing containers to bind-mount host folders seamlessly.

### 1.2 Hardware Passthrough (USB 3.0 XHCI Bus)
APC configures a virtualized USB controller using Apple's new macOS 15+ `VZXHCIControllerConfiguration`.

```swift
let usbControllerConfig = VZXHCIControllerConfiguration()
config.usbControllers = [usbControllerConfig]
```

- **Scan Engine:** Connected physical accessories are monitored via `IOKit`. The `USBManager` queries the I/O Registry matching the `"IOUSBDevice"` service class, extracting vendor IDs, product IDs, and serial numbers.
- **Dynamic Connection:** When a device attachment is requested, the manager fetches the active `VZXHCIController` from the running `VZVirtualMachine`. It exposes native API attachments (`VZUSBDevice` or runtime emulations) to map host physical USB ports directly into the guest PCI-USB bus without rebooting the VM.

---

## 2. User-Space Networking & DNS Resolution (apc-network)

To provide developer-friendly routing with zero root (sudo) privileges, APC operates a lightweight custom user-space gateway.

```
                  +-----------------------------------------+
                  |               macOS Host                |
                  +-----------------------------------------+
                                       |
                   HTTP Request: web-app.apc.local (Port 80)
                                       v
                  +-----------------------------------------+
                  |  Local DNS Server (127.0.0.1:15353)     | -> Resolves *.apc.local to 127.0.0.1
                  +-----------------------------------------+
                                       |
                                       v
                  +-----------------------------------------+
                  |  HTTP Reverse Proxy (127.0.0.1:8080)    | -> Inspects Host header
                  +-----------------------------------------+
                                       | Looks up port in
                                       | ~/.apc/routing.json
                                       v
                  +-----------------------------------------+
                  |      Alpine VM (Guest Virtual Port)     |
                  +-----------------------------------------+
```

### 2.1 Local DNS Resolver
A lightweight DNS engine is compiled in Go and binds to `127.0.0.1:15353` (UDP).
- Every query ending in `.apc.local` is intercepted and immediately responded to with a loopback IP (`127.0.0.1`).
- macOS integration is achieved by placing a simple resolver rule in `/etc/resolver/apc.local` which delegates `.apc.local` lookups directly to port `15353`.

### 2.2 HTTP Reverse Proxy & Port Forwarding
The networking helper runs a TCP reverse proxy listening on port `8080` (with attempt to bind to `80`).
- It periodically parses `~/.apc/routing.json`, which tracks container domains and their guest ports.
- When a developer accesses `http://web-app.apc.local`, the proxy reads the HTTP `Host` header, queries the routing registry, and proxies TCP traffic directly to the guest port.

---

## 3. Communication Protocols & VSOCK

For low-level hypervisor-to-guest communications, APC utilizes `VZVirtioSocketConnection` (VSOCK).
- The host opens a listening VSOCK socket on a designated port.
- A daemon (`vminitd`) running inside the Alpine guest connects to the host socket.
- This secure channel is utilized to forward terminal inputs, exchange statistics, and trigger container launches without opening standard network ports to external interfaces.
