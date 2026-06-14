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

#### 2.2.1 Multi-Port Routing
ShibaStack natively supports mapping multiple guest ports per container. 
- The primary port maps to: `container-name.apc.local`
- All secondary ports are automatically mapped to: `container-name-<port>.apc.local`

#### 2.2.2 Loopback Loop Guard (Anti-Routing Loops)
To prevent infinite request amplification loops where the proxy requests traffic from itself on port `8080`, the proxy utilizes a loop-detection middleware. Mappings resolving directly to the active proxy listener port are automatically intercepted and terminated with a standard HTTP `508 Loop Detected` status.

---

## 3. Communication Protocols & VSOCK (Guest Execution Spine)

For low-level hypervisor-to-guest communications, APC utilizes `VZVirtioSocketConnection` (VSOCK).
- **Socket Listener:** The host opens a listening VSOCK socket on a designated port (such as `1024`).
- **Guest Daemon (`guest-vminitd`):** A platform-isolated daemon compiled in Go runs inside the Alpine guest and establishes a connection handshake to the host's CID (`2`) over native Linux `AF_VSOCK` socket interfaces.
- **Mock Loopback Bridge:** To ensure robust local developments and CI test passes on macOS where real virtualization configurations might be restricted, `VSOCKManager` sets up a mock loopback fallback. A host-side TCP listener on port `10124` handles loopback connection handshakes from `guest-vminitd` running in the background.
- **Real-Time Command Dispatch (PTY Console):** When a developer inputs commands inside the interactive terminal, they are serialized to JSON payloads containing the executable action (`exec`) and commands. The guest daemon parses these payloads, executes the requested command natively via the underlying operating system shell (`sh -c "<command>"`), and streams combined stdout/stderr output back over the socket tunnel to render in real-time in the GUI console.

---

## 4. Persistent Configuration & State Management (config.json)

ShibaStack unifies hypervisor settings across CLI commands and SwiftUI panels using a centralized JSON configuration database.
- **Location:** State configurations reside at `~/.apc/config.json`.
- **Properties:**
  - `allocatedCPUs`: Count of CPU cores to allocate to the virtual machine.
  - `allocatedMemoryGB`: In-memory limit for memory allocations in GB.
- **CLI Commands:** The `apc config` command suite reads and writes directly to this state database, ensuring complete resource control.
- **GUI Integration:** Sliders dynamically modify in-memory resource allocations and commit them to `config.json` upon booting/restarting the virtual machine.
