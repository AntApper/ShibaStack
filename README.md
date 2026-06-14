# ShibaStack - Apple Private Container (APC)

Apple Private Container (APC) is an open-source, lightweight macOS Menu Bar application and companion suite for Apple's native container project. APC wraps Apple's Swift `Containerization` and `Virtualization` APIs to manage OCI-compliant containers natively on Apple Silicon with near-zero overhead.

It does not require Docker to be installed, utilizes Alpine-based native environments, runs a custom user-space DNS resolver, supports USB 3.0 hardware accessory passthrough (macOS 15+), and compiles into a native macOS app bundle packaged in a distributable DMG.

---

## Technical Features

- **Native Hypervisor Engine:** Leverages Apple's native `Virtualization.framework` with optimized Alpine kernels, dynamic memory ballooning, and VirtioFS sharing of the host `/Users` directory.
- **Hardware Passthrough:** Supports dynamic scan, attachment, and detachment of physical USB accessories from the Mac host to the guest container via USB 3.0 XHCI.
- **Zero-Privilege Networking:** Custom DNS resolver and reverse proxy routed through a user-space listener. No root or sudo modifications are required.
- **Dynamic Local DNS:** Automatic resolution of running container domains (e.g., `http://web-app.apc.local` maps directly to the container's guest port).
- **Native SwiftUI App:** A clean, multi-pane macOS dashboard with a sidebar menu, real-time CPU/RAM progress charts, container logs viewer, persistent volume managers, and a Menu Bar controller.

---

## Project Structure

```
.
├── README.md                           # Project introduction & overview
├── apc-core                            # Virtualization core engine (Swift Package)
│   ├── Package.swift                   # Swift Package Manager configuration
│   └── Sources
│       ├── APCCore                     # Core shared library targets
│       │   ├── ContainerManager.swift  # Local container manager & state persistence
│       │   ├── Models.swift            # Standard JSON & SwiftUI models
│       │   ├── USBManager.swift        # IOKit USB scanning & Virtualization attachment
│       │   └── VMManager.swift         # Hypervisor boots, ballooning, & directory sharing
│       ├── apc-cli                     # command-line interface executable
│       │   └── main.swift              # CLI command parser and outputs
│       └── apc-daemon                  # Background daemon target
│           └── main.swift              # Daemon virtualization event loop
├── apc-gui                             # SwiftUI macOS Dashboard & Menu Bar Extra
│   └── main.swift                      # Multi-pane dashboard layouts and state bridges
├── apc-network                         # High-performance networking helper
│   └── main.go                         # Go UDP DNS server & HTTP proxy
├── docs
│   ├── ARCHITECTURE.md                 # Detailed VM, networking, and USB designs
│   └── DEVELOPER.md                    # Local build instructions and debugging
└── scripts
    ├── build-dmg.sh                    # Complete compiler and packaging pipeline
    └── test-integration.sh             # End-to-end integration test runner
```

---

## Installation & Compilation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ant/ShibaStack.git
   cd ShibaStack
   ```

2. **Compile and Package into a DMG:**
   Ensure Go and Xcode/Swift are installed, and execute the automated packaging pipeline:
   ```bash
   ./scripts/build-dmg.sh
   ```
   This generates a polished, ready-to-use `ApplePrivateContainer.dmg` file in the root directory.

3. **Install the Application:**
   Open the generated DMG and drag `Apple Private Container.app` into your `/Applications` directory.

---

## CLI Usage Guide

The suite includes the `apc` command-line helper, which provides quick control over virtual machines and containers.

```bash
# Start/Stop the hypervisor core
apc start
apc stop
apc status

# Manage containers
apc ps
apc run web-app alpine-nginx 80:8080
apc logs web-app

# List and route physical USB accessories
apc usb list
apc usb attach 0x05AC:0x0322:F0THC70UCSA00007

# Clean storage and unused persistent cache
apc prune
```

---

## Development & Contribution

Refer to the internal documentation for advanced setups:
- To understand VM and network routing architectures, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
- For details on debugging Swift Virtualization binaries and running integration tests, see [docs/DEVELOPER.md](docs/DEVELOPER.md).
