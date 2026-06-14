# Apple Private Container (APC) Developer Guide

This document describes how to set up, build, debug, and test the Apple Private Container (APC) project locally on macOS.

## 1. Prerequisites

To build and run APC, you need:
- Apple Silicon Mac (M1, M2, M3, or newer).
- macOS 15.0 or later.
- Xcode 16.0 or later (includes `swiftc` compiler).
- Go 1.22 or later.

---

## 2. Repository Layout

The codebase is structured into self-contained, modular directories:
- `apc-core/`: Swift Package containing the virtualization engine and CLI targets.
  - `Sources/APCCore/`: Virtualization, volume sharing, and USB IOKit managers.
  - `Sources/apc-daemon/`: Daemon executing the VM hypervisor.
  - `Sources/apc-cli/`: Client CLI implementing the commands.
- `apc-network/`: Go-based user-space network DNS resolver and reverse proxy.
- `apc-gui/`: SwiftUI desktop companion application and menu bar controller.
- `scripts/`: Integration test runner and release packaging scripts.

---

## 3. Compilation Guide

### 3.1 Manual Compilation of Components
You can compile individual components during development:

**Compile Go Networking Helper:**
```bash
go build -o build/apc-network apc-network/main.go
```

**Compile Swift core and CLI package:**
```bash
cd apc-core
swift build -c release
cd ..
```

**Compile SwiftUI Dashboard:**
```bash
swiftc -O -sdk $(xcrun --show-sdk-path) -parse-as-library \
    -framework SwiftUI -framework AppKit -framework Virtualization -framework IOKit \
    -o apc-gui/APC-GUI \
    apc-gui/main.swift apc-core/Sources/APCCore/*.swift
```

### 3.2 Standard Release Build Pipeline
To compile all modules and build the final DMG package, run:
```bash
./scripts/build-dmg.sh
```
This compiles release versions, sets up the `.app` bundle, codesigns the bundle, and outputs `ApplePrivateContainer.dmg`.

---

## 4. Debugging and Profiling

### 4.1 Debugging Virtualization Binaries via LLDB
When debugging native Swift virtualization binaries, use `lldb` to catch runtime segmentation faults or exceptions:

```bash
lldb -- ./build/APC.app/Contents/Resources/bin/apc ps
(lldb) run
(lldb) bt
```

Common pitfalls include:
- Passing Swift strings to C format string specifiers (like `%s`), causing segmentation faults in `strlen` (resolved in this project by using manual Swift padding helpers).
- Entitlement conflicts. Running real `VZVirtualMachine` virtualization requires the `com.apple.security.virtualization` entitlement. In sandbox/local debugging without certificates, the codebase gracefully redirects to a fully simulated mock engine.

### 4.2 Inspecting Application Logs & Settings
Review active configuration registries in:
- VM Resource allocations: `~/.apc/config.json`
- VM/Container Registry: `~/.apc/containers.json`
- Local Router Entries: `~/.apc/routing.json`
- State File: `~/.apc/vm_state`

### 4.3 Programmatic Health Checks (apc doctor)
Developers can run system-level dependency checks directly from their terminal using:
```bash
./build/ShibaStack.app/Contents/Resources/bin/apc doctor
```
This utility validates:
1. Xcode Command Line Tools availability.
2. Go Compiler status.
3. Path configurations and sandbox initialization of `~/.apc/`.
4. macOS DNS Resolver Delegation rules under `/etc/resolver/apc.local`.

---

## 5. Running Integration Tests

APC includes an end-to-end integration test runner validating hypervisor states, VirtioFS directories, DNS resolution, and IOKit USB scans.

Execute the test bench using:
```bash
./scripts/test-integration.sh
```
The test suite compiles resources, boots the VM, launches a test container, checks routing entries, scans the physical USB bus, and performs automatic teardown cleanup.
