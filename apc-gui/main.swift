import SwiftUI
import AppKit

#if canImport(APCCore)
import APCCore
#endif

// MARK: - Brand Color Extensions
extension Color {
    static let shibaOrange = Color(red: 224/255, green: 109/255, blue: 58/255)
    static let shibaCream = Color(red: 247/255, green: 234/255, blue: 211/255)
    static let shibaCharcoal = Color(red: 28/255, green: 28/255, blue: 30/255)
    static let shibaGold = Color(red: 234/255, green: 168/255, blue: 58/255)
}

// MARK: - Programmatic Shiba Mascot Vector Icon (Premium Brand Compliance)
struct ShibaIconView: View {
    var body: some View {
        ZStack {
            // Ears (Shiba Orange and Cream)
            HStack(spacing: 12) {
                // Left Ear
                Path { path in
                    path.move(to: CGPoint(x: 2, y: 10))
                    path.addLine(to: CGPoint(x: 5, y: 0))
                    path.addLine(to: CGPoint(x: 10, y: 8))
                    path.closeSubpath()
                }
                .fill(Color.shibaOrange)
                
                Spacer()
                
                // Right Ear
                Path { path in
                    path.move(to: CGPoint(x: 8, y: 10))
                    path.addLine(to: CGPoint(x: 5, y: 0))
                    path.addLine(to: CGPoint(x: 0, y: 8))
                    path.closeSubpath()
                }
                .fill(Color.shibaOrange)
            }
            .frame(width: 18, height: 10)
            .offset(y: -4)
            
            // Face Base (Shiba Orange)
            Circle()
                .fill(Color.shibaOrange)
                .frame(width: 18, height: 18)
            
            // Cheeks (Shiba Cream)
            HStack(spacing: 2) {
                Circle()
                    .fill(Color.shibaCream)
                    .frame(width: 7, height: 7)
                Spacer()
                Circle()
                    .fill(Color.shibaCream)
                    .frame(width: 7, height: 7)
            }
            .frame(width: 14)
            .offset(y: 2)
            
            // Muzzle (Shiba Cream)
            Ellipse()
                .fill(Color.shibaCream)
                .frame(width: 8, height: 6)
                .offset(y: 4)
            
            // Nose (Charcoal)
            Circle()
                .fill(Color.shibaCharcoal)
                .frame(width: 2, height: 2)
                .offset(y: 2)
            
            // Eyes (Charcoal)
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.shibaCharcoal)
                    .frame(width: 1.5, height: 1.5)
                Circle()
                    .fill(Color.shibaCharcoal)
                    .frame(width: 1.5, height: 1.5)
            }
            .offset(y: -1)
        }
        .frame(width: 20, height: 20)
    }
}

// MARK: - Template-Based Crisp Menu Bar Shiba Icon (Adapts perfectly to light/dark themes)
func createMenuBarIcon() -> NSImage {
    let size = NSSize(width: 18, height: 18)
    let image = NSImage(size: size)
    image.lockFocus()
    
    let color = NSColor.black
    color.setStroke()
    color.setFill()
    
    // 1. Draw outer silhouette (head and ears)
    let path = NSBezierPath()
    path.move(to: NSPoint(x: 3, y: 11))
    path.line(to: NSPoint(x: 5, y: 17))
    path.line(to: NSPoint(x: 8.5, y: 12.5))
    path.line(to: NSPoint(x: 9.5, y: 12.5))
    path.line(to: NSPoint(x: 13, y: 17))
    path.line(to: NSPoint(x: 15, y: 11))
    
    // Right cheek curved down to chin
    path.curve(to: NSPoint(x: 14.5, y: 3), controlPoint1: NSPoint(x: 16, y: 7), controlPoint2: NSPoint(x: 15.5, y: 4))
    
    // Bottom chin/muzzle
    path.line(to: NSPoint(x: 3.5, y: 3))
    
    // Left cheek curved up to left ear base
    path.curve(to: NSPoint(x: 3, y: 11), controlPoint1: NSPoint(x: 2.5, y: 4), controlPoint2: NSPoint(x: 2, y: 7))
    
    path.close()
    path.fill()
    
    // 2. Clear out Inner Ear holes
    let innerEars = NSBezierPath()
    innerEars.move(to: NSPoint(x: 4.5, y: 11.5))
    innerEars.line(to: NSPoint(x: 5.5, y: 14.5))
    innerEars.line(to: NSPoint(x: 7.2, y: 12.5))
    innerEars.close()
    
    innerEars.move(to: NSPoint(x: 13.5, y: 11.5))
    innerEars.line(to: NSPoint(x: 12.5, y: 14.5))
    innerEars.line(to: NSPoint(x: 10.8, y: 12.5))
    innerEars.close()
    
    NSColor.clear.set()
    NSGraphicsContext.current?.compositingOperation = .destinationOut
    innerEars.fill()
    
    // 3. Clear out Eyes and Nose
    let eyesAndNose = NSBezierPath()
    eyesAndNose.append(NSBezierPath(ovalIn: NSRect(x: 5.2, y: 7.5, width: 2, height: 2)))
    eyesAndNose.append(NSBezierPath(ovalIn: NSRect(x: 10.8, y: 7.5, width: 2, height: 2)))
    eyesAndNose.append(NSBezierPath(ovalIn: NSRect(x: 8.0, y: 4.8, width: 2, height: 1.5)))
    eyesAndNose.fill()
    
    image.unlockFocus()
    image.isTemplate = true
    return image
}

// MARK: - App Entry Point
@main
struct APCApp: App {
    @StateObject private var stateManager = GUIStateManager()
    
    var body: some Scene {
        // 1. Core GUI Dashboard Window
        Window("ShibaStack Dashboard", id: "dashboard") {
            MainDashboardView()
                .environmentObject(stateManager)
                .frame(minWidth: 1000, minHeight: 650)
                .tint(.shibaOrange)
        }
        .windowStyle(.titleBar)
        .commands {
            SidebarCommands() // Standard Cmd+Option+S sidebar toggle
        }
        
        // 2. Menu Bar Extra Status Item (using custom Shiba dog icon for premium branding)
        MenuBarExtra {
            MenuBarView()
                .environmentObject(stateManager)
                .tint(.shibaOrange)
        } label: {
            Image(nsImage: createMenuBarIcon())
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - State Manager (Unifies APCCore with SwiftUI)
class GUIStateManager: ObservableObject {
    @Published var vmState: String = "stopped"
    @Published var containers: [Container] = []
    @Published var images: [ContainerImage] = []
    @Published var volumes: [Volume] = []
    @Published var usbDevices: [USBDevice] = []
    @Published var hardwareStats = APCHardwareStats(cpuUsage: 0.0, memoryUsage: 0.0, maxMemory: 4096.0)

    // Live per-container stats (real cgroup samples), keyed by container id.
    @Published var liveStatsById: [String: LiveContainerStats] = [:]
    private var statsTimer: Timer?

    // Hardware configuration allocations
    @Published var allocatedCPUs: Int = 2
    @Published var allocatedMemoryGB: Int = 4
    @Published var enableRosetta: Bool = true
    
    // Dependency Status State
    @Published var swiftInstalled: Bool = false
    @Published var goInstalled: Bool = false
    @Published var envInitialized: Bool = false
    @Published var resolverConfigured: Bool = false
    @Published var kernelsInstalled: Bool = false
    @Published var appleContainerInstalled: Bool = false
    
    // Installation progress triggers
    @Published var installingGo: Bool = false
    @Published var installingTools: Bool = false
    @Published var configuringResolver: Bool = false
    @Published var downloadingKernels: Bool = false
    @Published var installingAppleContainer: Bool = false
    @Published var isPullingImage: Bool = false
    @Published var isBuildingImage: Bool = false
    @Published var isPushingImage: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var lastBuildLog: String = ""
    
    @Published var selectedSidebarItem: SidebarItem? = .overview
    // Set by "Run from image" in the Images view; consumed by the Containers view to open the create sheet prefilled.
    @Published var pendingRunImage: String? = nil
    @Published var selectedContainerIDs = Set<String>() {
        didSet {
            if !selectedContainerIDs.contains(selectedContainerID ?? "") {
                selectedContainerID = selectedContainerIDs.first
            }
        }
    }
    @Published var selectedContainerID: String?
    
    var selectedContainer: Container? {
        guard let id = selectedContainerID else { return nil }
        return containers.first(where: { $0.id == id })
    }
    
    // Global App Alert Message State
    @Published var alertMessage: String?
    @Published var showingAlert: Bool = false
    
    private var timer: Timer?
    
    init() {
        let savedConfig = VMManager.shared.loadVMConfig()
        self.allocatedCPUs = savedConfig.allocatedCPUs
        self.allocatedMemoryGB = savedConfig.allocatedMemoryGB
        self.enableRosetta = savedConfig.enableRosetta
        
        refreshAll()
        checkDependencies() // Check dependencies once on startup
        startPeriodicRefresh()
    }
    
    func refreshAll() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let state = VMManager.shared.getVMState()
            let conts = ContainerManager.shared.getContainers()
            let imgs = ContainerManager.shared.getImages()
            let vols = ContainerManager.shared.getVolumes()
            let usb = USBManager.shared.scanDevices()
            let stats = ContainerManager.shared.getStats()
            
            DispatchQueue.main.async {
                self.vmState = state
                self.containers = conts
                self.images = imgs
                self.volumes = vols
                self.usbDevices = usb
                self.hardwareStats = stats
                
                // Auto-select first container if none selected
                if self.selectedContainerID == nil, let first = conts.first {
                    self.selectedContainerID = first.id
                    self.selectedContainerIDs = [first.id]
                } else if let activeID = self.selectedContainerID {
                    if !conts.contains(where: { $0.id == activeID }) {
                        if let first = conts.first {
                            self.selectedContainerID = first.id
                            self.selectedContainerIDs = [first.id]
                        } else {
                            self.selectedContainerID = nil
                            self.selectedContainerIDs = []
                        }
                    }
                }
            }
        }
    }
    
    private func startPeriodicRefresh() {
        // Keep stats and containers dynamically updated every 1.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshAll()
            }
        }
        // Sample live per-container cgroup stats on a steady 3s cadence (clean CPU% deltas).
        statsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.sampleLiveStats()
        }
    }

    private func sampleLiveStats() {
        let running = containers.filter { $0.state == "running" }
        guard !running.isEmpty else {
            if !liveStatsById.isEmpty { liveStatsById = [:] }
            return
        }
        DispatchQueue.global(qos: .utility).async {
            var result: [String: LiveContainerStats] = [:]
            for container in running {
                if let stats = ContainerManager.shared.liveStats(id: container.id, cores: container.cpuCores) {
                    result[container.id] = stats
                }
            }
            DispatchQueue.main.async { self.liveStatsById = result }
        }
    }
    
    // Actions
    func toggleVM() {
        if vmState == "running" {
            try? VMManager.shared.stopVM { [weak self] in
                DispatchQueue.main.async {
                    self?.refreshAll()
                }
            }
        } else {
            let currentConfig = VMConfig(allocatedCPUs: allocatedCPUs, allocatedMemoryGB: allocatedMemoryGB, enableRosetta: enableRosetta)
            VMManager.shared.saveVMConfig(currentConfig)
            try? VMManager.shared.startVM()
            refreshAll()
        }
    }
    
    func restartVM() {
        let currentConfig = VMConfig(allocatedCPUs: allocatedCPUs, allocatedMemoryGB: allocatedMemoryGB, enableRosetta: enableRosetta)
        VMManager.shared.saveVMConfig(currentConfig)
        
        try? VMManager.shared.stopVM { [weak self] in
            DispatchQueue.main.async {
                try? VMManager.shared.startVM()
                self?.refreshAll()
            }
        }
    }
    
    func startContainer(_ id: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try ContainerManager.shared.startContainer(id: id)
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = error.localizedDescription
                    self.showingAlert = true
                }
            }
            DispatchQueue.main.async {
                self.refreshAll()
            }
        }
    }
    
    func stopContainer(_ id: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do { try ContainerManager.shared.stopContainer(id: id) }
            catch { DispatchQueue.main.async { self.alertMessage = error.localizedDescription; self.showingAlert = true } }
            DispatchQueue.main.async { self.refreshAll() }
        }
    }

    func killContainer(_ id: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do { try ContainerManager.shared.killContainer(id: id) }
            catch { DispatchQueue.main.async { self.alertMessage = error.localizedDescription; self.showingAlert = true } }
            DispatchQueue.main.async { self.refreshAll() }
        }
    }

    func createContainer(name: String, image: String, ports: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                _ = try ContainerManager.shared.runNewContainer(name: name, image: image, portMap: ports)
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = error.localizedDescription
                    self.showingAlert = true
                }
            }
            DispatchQueue.main.async {
                self.refreshAll()
            }
        }
    }
    
    func deleteContainer(id: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            ContainerManager.shared.removeContainer(id: id)
            DispatchQueue.main.async {
                if self.selectedContainerID == id {
                    self.selectedContainerID = nil
                    self.selectedContainerIDs.removeAll()
                }
                self.refreshAll()
            }
        }
    }
    
    func startSelectedContainers() {
        DispatchQueue.global(qos: .userInitiated).async {
            var errors: [String] = []
            for id in self.selectedContainerIDs {
                do {
                    try ContainerManager.shared.startContainer(id: id)
                } catch {
                    errors.append(error.localizedDescription)
                }
            }
            DispatchQueue.main.async {
                if !errors.isEmpty {
                    self.alertMessage = errors.joined(separator: "\n")
                    self.showingAlert = true
                }
                self.refreshAll()
            }
        }
    }
    
    func stopSelectedContainers() {
        DispatchQueue.global(qos: .userInitiated).async {
            var errors: [String] = []
            for id in self.selectedContainerIDs {
                do { try ContainerManager.shared.stopContainer(id: id) }
                catch { errors.append("\(id): \(error.localizedDescription)") }
            }
            DispatchQueue.main.async {
                if !errors.isEmpty {
                    self.alertMessage = "Some containers failed to stop:\n" + errors.joined(separator: "\n")
                    self.showingAlert = true
                }
                self.refreshAll()
            }
        }
    }
    
    func deleteSelectedContainers() {
        DispatchQueue.global(qos: .userInitiated).async {
            for id in self.selectedContainerIDs {
                ContainerManager.shared.removeContainer(id: id)
            }
            DispatchQueue.main.async {
                self.selectedContainerIDs.removeAll()
                self.refreshAll()
            }
        }
    }
    
    func pullNewImage(repo: String, tag: String) {
        self.isPullingImage = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ContainerManager.shared.addImage(repository: repo, tag: tag)
            DispatchQueue.main.async {
                self.isPullingImage = false
                if !result.success {
                    self.alertMessage = "Pull failed: \(result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "unknown error" : result.output)"
                    self.showingAlert = true
                }
                self.refreshAll()
            }
        }
    }

    func buildImage(tag: String, dockerfile: String, context: String) {
        self.isBuildingImage = true
        self.lastBuildLog = ""
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ContainerManager.shared.buildImage(
                tag: tag,
                dockerfilePath: dockerfile.isEmpty ? nil : dockerfile,
                contextDir: context
            )
            DispatchQueue.main.async {
                self.isBuildingImage = false
                self.lastBuildLog = result.log
                self.alertMessage = result.success
                    ? "Image '\(tag)' built successfully."
                    : "Build failed — see the build log for details."
                self.showingAlert = true
                self.refreshAll()
            }
        }
    }

    func tagImage(source: String, target: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ContainerManager.shared.tagImage(source: source, target: target)
            DispatchQueue.main.async {
                self.alertMessage = result.success
                    ? "Tagged \(source) → \(target)."
                    : "Tag failed: \(result.output.isEmpty ? "unknown error" : result.output)"
                self.showingAlert = true
                self.refreshAll()
            }
        }
    }

    func pushImage(reference: String) {
        self.isPushingImage = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ContainerManager.shared.pushImage(reference: reference)
            DispatchQueue.main.async {
                self.isPushingImage = false
                self.alertMessage = result.success
                    ? "Pushed \(reference)."
                    : "Push failed (registry login may be required):\n\(result.output.isEmpty ? "unknown error" : result.output)"
                self.showingAlert = true
            }
        }
    }

    func registryLogin(server: String, username: String, password: String) {
        self.isAuthenticating = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ContainerManager.shared.registryLogin(server: server, username: username, password: password)
            DispatchQueue.main.async {
                self.isAuthenticating = false
                self.alertMessage = result.success
                    ? "Logged in to \(server)."
                    : "Login failed: \(result.output.isEmpty ? "unknown error" : result.output)"
                self.showingAlert = true
            }
        }
    }

    func registryLogout(server: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ContainerManager.shared.registryLogout(server: server)
            DispatchQueue.main.async {
                self.alertMessage = result.success
                    ? "Logged out of \(server)."
                    : "Logout failed: \(result.output.isEmpty ? "unknown error" : result.output)"
                self.showingAlert = true
            }
        }
    }

    func removeImage(_ id: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do { try ContainerManager.shared.removeImage(id: id) }
            catch { DispatchQueue.main.async { self.alertMessage = error.localizedDescription; self.showingAlert = true } }
            DispatchQueue.main.async { self.refreshAll() }
        }
    }
    
    func pruneStorage() {
        ContainerManager.shared.pruneStorage()
        refreshAll()
    }

    // Persist allocation settings immediately so slider/toggle changes stick (applied on next VM start).
    func persistVMConfig() {
        let config = VMConfig(allocatedCPUs: allocatedCPUs, allocatedMemoryGB: allocatedMemoryGB, enableRosetta: enableRosetta)
        VMManager.shared.saveVMConfig(config)
    }
    
    // USB passthrough needs a running hypervisor (the VM); scanning is always live.
    var usbPassthroughAvailable: Bool {
        VMManager.shared.getUnderlyingVM() != nil
    }

    func toggleUSBDevice(_ device: USBDevice) {
        do {
            if device.isAttached {
                try USBManager.shared.detachDevice(device, from: VMManager.shared.getUnderlyingVM())
            } else {
                try USBManager.shared.attachDevice(device, to: VMManager.shared.getUnderlyingVM())
            }
        } catch {
            // Surface the real reason (e.g. "passthrough requires the hypervisor") instead of failing silently.
            self.alertMessage = error.localizedDescription
            self.showingAlert = true
        }
        refreshAll()
    }
    
    // MARK: - Dependency and Installation Actions
    
    func checkDependencies() {
        DispatchQueue.global(qos: .background).async {
            let swiftPath = self.checkCommandExists("swift")
            let goPath = self.checkCommandExists("go")
            
            let home = FileManager.default.homeDirectoryForCurrentUser
            let apcDir = home.appendingPathComponent(".apc")
            let envExists = FileManager.default.fileExists(atPath: apcDir.path)
            
            let resolverExists = FileManager.default.fileExists(atPath: "/etc/resolver/apc.local")
            let kernelExists = FileManager.default.fileExists(atPath: home.appendingPathComponent(".apc/boot/vmlinuz").path)
            let appleContainerExists = self.checkCommandExists("container") || FileManager.default.fileExists(atPath: "/usr/local/bin/container")
            
            DispatchQueue.main.async {
                self.swiftInstalled = swiftPath
                self.goInstalled = goPath
                self.envInitialized = envExists
                self.resolverConfigured = resolverExists
                self.kernelsInstalled = kernelExists
                self.appleContainerInstalled = appleContainerExists
            }
        }
    }
    
    private func checkCommandExists(_ command: String) -> Bool {
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
            return false
        }
    }
    
    func installCommandLineTools() {
        self.installingTools = true
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
            task.arguments = ["--install"]
            try? task.run()
            task.waitUntilExit()
            
            DispatchQueue.main.async {
                self.installingTools = false
                self.checkDependencies()
            }
        }
    }
    
    func installGo() {
        self.installingGo = true
        DispatchQueue.global(qos: .userInitiated).async {
            // Attempt brew installation first by checking absolute paths directly
            let brewPathAppleSilicon = "/opt/homebrew/bin/brew"
            let brewPathIntel = "/usr/local/bin/brew"
            
            let brewPath: String?
            if FileManager.default.fileExists(atPath: brewPathAppleSilicon) {
                brewPath = brewPathAppleSilicon
            } else if FileManager.default.fileExists(atPath: brewPathIntel) {
                brewPath = brewPathIntel
            } else {
                brewPath = nil
            }
            
            if let path = brewPath {
                let brewInstall = Process()
                brewInstall.executableURL = URL(fileURLWithPath: path)
                brewInstall.arguments = ["install", "go"]
                try? brewInstall.run()
                brewInstall.waitUntilExit()
            } else {
                // Fallback: Download official Arm64 .pkg to a guaranteed writable temp folder and run macOS installer with elevations
                let tempDir = FileManager.default.temporaryDirectory
                let pkgURL = tempDir.appendingPathComponent("go-installer.pkg")
                
                let downloadTask = Process()
                downloadTask.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                downloadTask.arguments = ["-L", "https://dl.google.com/go/go1.22.4.darwin-arm64.pkg", "-o", pkgURL.path]
                try? downloadTask.run()
                downloadTask.waitUntilExit()
                
                let script = "do shell script \"installer -pkg \(pkgURL.path) -target /\" with administrator privileges"
                let osascript = Process()
                osascript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                osascript.arguments = ["-e", script]
                try? osascript.run()
                osascript.waitUntilExit()
            }
            
            DispatchQueue.main.async {
                self.installingGo = false
                self.checkDependencies()
            }
        }
    }
    
    func configureResolverRule() {
        self.configuringResolver = true
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "do shell script \"mkdir -p /etc/resolver && echo 'nameserver 127.0.0.1\\nport 15353' > /etc/resolver/apc.local\" with administrator privileges"
            let osascript = Process()
            osascript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            osascript.arguments = ["-e", script]
            try? osascript.run()
            osascript.waitUntilExit()
            
            DispatchQueue.main.async {
                self.configuringResolver = false
                self.checkDependencies()
            }
        }
    }
    
    func initializeEnvironment() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let apcDir = home.appendingPathComponent(".apc")
        try? FileManager.default.createDirectory(at: apcDir, withIntermediateDirectories: true, attributes: nil)
        
        // Instantiates ContainerManager to generate files
        _ = ContainerManager.shared
        self.checkDependencies()
    }
    
    func downloadBootImages() {
        self.downloadingKernels = true
        DispatchQueue.global(qos: .userInitiated).async {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let bootDir = home.appendingPathComponent(".apc/boot")
            try? FileManager.default.createDirectory(at: bootDir, withIntermediateDirectories: true, attributes: nil)
            
            let kernelURL = bootDir.appendingPathComponent("vmlinuz")
            let initrdURL = bootDir.appendingPathComponent("initrd.img")
            
            // Download Kernel (vmlinuz) using curl with safety timeout
            let downloadKernel = Process()
            downloadKernel.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            downloadKernel.arguments = ["--connect-timeout", "15", "--max-time", "120", "-L", "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/aarch64/netboot/vmlinuz-virt", "-o", kernelURL.path]
            try? downloadKernel.run()
            downloadKernel.waitUntilExit()
            
            let kernelSuccess = downloadKernel.terminationStatus == 0
            
            // Download Initramfs (initrd) using curl with safety timeout
            let downloadInitrd = Process()
            downloadInitrd.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            downloadInitrd.arguments = ["--connect-timeout", "15", "--max-time", "120", "-L", "https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/aarch64/netboot/initramfs-virt", "-o", initrdURL.path]
            try? downloadInitrd.run()
            downloadInitrd.waitUntilExit()
            
            let initrdSuccess = downloadInitrd.terminationStatus == 0
            
            if !kernelSuccess || !initrdSuccess {
                // Do not write fake boot files — placeholder text cannot boot a VM.
                // Remove the partial/empty download(s) that failed so a stale file isn't mistaken for a real kernel.
                if !kernelSuccess { try? FileManager.default.removeItem(at: kernelURL) }
                if !initrdSuccess { try? FileManager.default.removeItem(at: initrdURL) }
                DispatchQueue.main.async {
                    self.alertMessage = "Kernel download failed (offline, or the Alpine CDN was unreachable). No boot images were written — check your connection and try again."
                    self.showingAlert = true
                }
            }
            
            DispatchQueue.main.async {
                self.downloadingKernels = false
                self.checkDependencies()
            }
        }
    }
    
    func installAppleContainer() {
        self.installingAppleContainer = true
        DispatchQueue.global(qos: .userInitiated).async {
            // The real Apple container runtime is the `container` binary. If it's already
            // installed we just mark the dependency satisfied; otherwise open Apple's
            // official releases so the user can install the real .pkg (no fake stub).
            let alreadyInstalled = FileManager.default.fileExists(atPath: "/usr/local/bin/container")
                || self.checkCommandExists("container")
            DispatchQueue.main.async {
                self.installingAppleContainer = false
                if !alreadyInstalled, let url = URL(string: "https://github.com/apple/container/releases") {
                    NSWorkspace.shared.open(url)
                }
                self.checkDependencies()
            }
        }
    }
    
    func resetEnvironment() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let apcDir = home.appendingPathComponent(".apc")
        try? FileManager.default.removeItem(at: apcDir)
        initializeEnvironment()
    }
    
    func generateDiagnosticsReport() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let desktop = home.appendingPathComponent("Desktop")
        let reportURL = desktop.appendingPathComponent("shibastack-diagnostics.md")
        
        let fm = FileManager.default
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        
        var md = """
        # ShibaStack Diagnostics Report
        
        Generated: \(timestamp)
        Host: \(Host.current().localizedName ?? "Local Mac")
        macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
        
        ---
        
        ## 1. System Dependencies & Environment
        - **Swift Compiler:** \(swiftInstalled ? "Installed" : "Missing")
        - **Go Compiler:** \(goInstalled ? "Installed" : "Missing")
        - **Local APC Directory (~/.apc):** \(envInitialized ? "Initialized" : "Missing")
        - **DNS Resolver Rule (/etc/resolver/apc.local):** \(resolverConfigured ? "Configured" : "Missing")
        - **Native OCI CLI (/usr/local/bin/container):** \(fm.fileExists(atPath: "/usr/local/bin/container") ? "Available" : "Missing")
        
        ---
        
        ## 2. Dynamic Resource Configuration
        - **Cores Allocated:** \(allocatedCPUs) Cores
        - **RAM Allocated:** \(allocatedMemoryGB) GB
        - **Rosetta 2 Emulation:** \(enableRosetta ? "Enabled" : "Disabled")
        - **Active Hypervisor Mode:** \(vmState == "running" ? "RUNNING" : "STOPPED")
        
        ---
        
        ## 3. Active Container Listings (Real OCI Engine)
        """
        
        let conts = ContainerManager.shared.getContainers()
        if conts.isEmpty {
            md += "\n*No containers active or registered.*\n"
        } else {
            md += "\n| Name | Image | State | Ports |\n|---|---|---|---|\n"
            for c in conts {
                md += "| \(c.name) | \(c.image) | \(c.state.uppercased()) | \(c.ports.joined(separator: ", ")) |\n"
            }
        }
        
        md += "\n---\n\n## 4. Local Images Store\n"
        let imgs = ContainerManager.shared.getImages()
        if imgs.isEmpty {
            md += "*No container images pulled.*"
        } else {
            md += "\n| Repository | Tag | Image ID | Size |\n|---|---|---|---|\n"
            for img in imgs {
                md += "| \(img.repository) | \(img.tag) | \(img.id.prefix(12)) | \(img.size) |\n"
            }
        }
        
        md += "\n---\n\n## 5. Local Persistent Volumes\n"
        let vols = ContainerManager.shared.getVolumes()
        if vols.isEmpty {
            md += "*No persistent volumes configured.*"
        } else {
            md += "\n| Name | Size | Mount Source |\n|---|---|---|\n"
            for vol in vols {
                md += "| \(vol.name) | \(vol.size) | \(vol.mountPoint) |\n"
            }
        }
        
        md += "\n---\n\n## 6. Physical USB Accessories Scanning (IOKit)\n"
        let usb = USBManager.shared.scanDevices()
        if usb.isEmpty {
            md += "*No physical USB accessories discovered.*"
        } else {
            md += "\n| Name | Vendor ID | Product ID | Serial Number | Attached |\n|---|---|---|---|---|\n"
            for dev in usb {
                md += "| \(dev.name) | \(dev.vendorId) | \(dev.productId) | \(dev.serialNumber) | \(dev.isAttached ? "YES" : "NO") |\n"
            }
        }
        
        md += "\n\n--- End of Report ---\n"
        
        do {
            try md.write(to: reportURL, atomically: true, encoding: .utf8)
            self.alertMessage = "Diagnostics Report successfully saved to Desktop as 'shibastack-diagnostics.md'."
            self.showingAlert = true
        } catch {
            self.alertMessage = "Failed to collect diagnostics: \(error.localizedDescription)"
            self.showingAlert = true
        }
    }
    
    func getContainerURL(_ cont: Container) -> URL {
        let hostPort = cont.hostPort ?? 8080
        if resolverConfigured {
            // Append :8080 (the non-root proxy port) to resolve the *.apc.local domain properly!
            return URL(string: "http://\(cont.primaryDomain):8080") ?? URL(string: "http://localhost:\(hostPort)")!
        }
        return URL(string: "http://localhost:\(hostPort)")!
    }
    
    deinit {
        timer?.invalidate()
        statsTimer?.invalidate()
    }
}

// MARK: - Navigation Definitions
enum SidebarItem: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case containers = "Containers"
    case images = "Images"
    case storage = "Storage"
    case network = "Network"
    case usb = "USB Passthrough"
    case settings = "Settings"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .overview: return "sparkles"
        case .containers: return "square.stack.3d.up.fill"
        case .images: return "photo.fill"
        case .storage: return "internaldrive.fill"
        case .network: return "network"
        case .usb: return "point.3.connected.trianglepath.dotted"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Main Dashboard View
struct MainDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var showingPruneConfirmation = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar Panel
            List(SidebarItem.allCases, id: \.self, selection: $state.selectedSidebarItem) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                        .font(.headline)
                        .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("ShibaStack")
            
            // Bottom-of-sidebar Status bar
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Divider()
                    HStack {
                        Circle()
                            .fill(state.vmState == "running" ? Color.green : Color.red)
                            .frame(width: 10, height: 10)
                        
                        Text("ShibaStack: \(state.vmState.uppercased())")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        
                        Button(action: state.toggleVM) {
                            Text(state.vmState == "running" ? "Shutdown" : "Boot")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(state.vmState == "running" ? .red : .shibaOrange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        } detail: {
            // Detail Panels based on selection
            if let selection = state.selectedSidebarItem {
                switch selection {
                case .overview:
                    GetStartedView()
                case .containers:
                    ContainersDashboardView()
                case .images:
                    ImagesDashboardView()
                case .storage:
                    VolumesDashboardView()
                case .network:
                    NetworkDashboardView()
                case .usb:
                    USBDashboardView()
                case .settings:
                    SettingsDashboardView()
                }
            } else {
                Text("Select an item from the sidebar")
                    .foregroundColor(.secondary)
            }
        }
        // Custom Window Toolbar Actions (Matches OrbStack style top-level controls)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(state.vmState == "running" ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text("ShibaStack VM")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: state.toggleVM) {
                    HStack {
                        Image(systemName: state.vmState == "running" ? "stop.fill" : "play.fill")
                        Text(state.vmState == "running" ? "Stop Engine" : "Boot Engine")
                    }
                }
                .help("Boot/Shutdown Virtual Machine")
                
                Button(action: state.restartVM) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Restart")
                    }
                }
                .help("Restart ShibaStack Engine")
                .disabled(state.vmState != "running")
                
                Button(action: { showingPruneConfirmation = true }) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Prune Storage")
                    }
                }
                .help("One-Click Disk Clean")
            }
        }
        .alert("Prune Unused Storage?", isPresented: $showingPruneConfirmation) {
            Button("Prune", role: .destructive) {
                state.pruneStorage()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all inactive container volumes, caches, and unused images. This action cannot be undone.")
        }
        .alert("ShibaStack Error", isPresented: $state.showingAlert) {
            Button("OK", role: .cancel) {
                state.alertMessage = nil
            }
        } message: {
            Text(state.alertMessage ?? "An unknown error occurred.")
        }
    }
}

// MARK: - Sub-tab definitions for Container Details (OrbStack 1-to-1 matching)
enum ContainerTab: String, CaseIterable {
    case logs = "Logs"
    case terminal = "Terminal"
    case files = "Files"
    case inspect = "Inspect"
}

// MARK: - Containers View
struct ContainersDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var showingCreateSheet = false
    @State private var prefillImage: String? = nil
    @State private var activeDetailTab: ContainerTab = .logs
    @State private var pinToBottom = true
    
    // Interactive Terminal states
    @State private var terminalInput = ""
    @State private var terminalLogs: [String] = ["shiba-guest:~$ "]

    // Real container inspect output (loaded on demand from the runtime)
    @State private var inspectJSON = ""
    @State private var detailInfo: ContainerInfo? = nil

    // Live per-container resource sample (real, from cgroup via the runtime)
    // Live-streamed log lines (real `container logs -f`) for the running container
    @State private var streamedLogs: [String] = []

    // Container filesystem explorer states
    @State private var currentPath = "/"
    @State private var filesList: [FileItem] = []
    
    var body: some View {
        HSplitView {
            // Containers List
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Containers")
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: { showingCreateSheet = true }) {
                        Label("Run", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                
                List(state.containers, selection: $state.selectedContainerIDs) { cont in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(cont.state == "running" ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cont.name)
                                .font(.headline)
                            Text(cont.image)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        // Inline live resource indicators (real cgroup sample; falls back to allocated)
                        if cont.state == "running" {
                            let live = state.liveStatsById[cont.id]
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(live.map { String(format: "%.1f%% CPU", $0.cpuPercent) } ?? "\(cont.cpuCores) vCPU")
                                    .font(.system(size: 10, design: .monospaced))
                                Text(live.map { memUsedString($0.memoryBytes) } ?? formatMemoryLimit(cont.memoryLimitMB))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tag(cont.id)
                    .padding(.vertical, 4)
                    .contextMenu {
                        if state.selectedContainerIDs.count > 1 {
                            Text("\(state.selectedContainerIDs.count) Containers Selected")
                                .font(.caption)
                            
                            Button(action: { state.startSelectedContainers() }) {
                                Label("Start Selected", systemImage: "play.fill")
                            }
                            
                            Button(action: { state.stopSelectedContainers() }) {
                                Label("Stop Selected", systemImage: "stop.fill")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive, action: { state.deleteSelectedContainers() }) {
                                Label("Delete Selected", systemImage: "trash.fill")
                            }
                        } else {
                            Button(action: { state.startContainer(cont.id) }) {
                                Label("Start", systemImage: "play.fill")
                            }
                            .disabled(cont.state == "running")
                            
                            Button(action: { state.stopContainer(cont.id) }) {
                                Label("Stop", systemImage: "stop.fill")
                            }
                            .disabled(cont.state != "running")
                            
                            Divider()
                            
                            Button(role: .destructive, action: { state.deleteContainer(id: cont.id) }) {
                                Label("Delete", systemImage: "trash.fill")
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 350, maxWidth: 450)
            
            // Container Details (Tabs: Logs, Terminal, Files, Inspect) - Always present to prevent HSplitView collapsing bug
            Group {
                if let selected = state.selectedContainer {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header Area
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selected.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Text("ID: \(selected.id) | Image: \(selected.image)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            // State Action buttons (OrbStack style top action headers with Delete action)
                            HStack(spacing: 8) {
                                if selected.state == "running" {
                                    if !selected.ports.isEmpty {
                                        Button(action: {
                                            let url = state.getContainerURL(selected)
                                            NSWorkspace.shared.open(url)
                                        }) {
                                            Label("Open Site", systemImage: "safari")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.shibaOrange)
                                    }
                                    
                                    Button(action: { state.stopContainer(selected.id) }) {
                                        Label("Stop", systemImage: "stop.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button(action: {
                                        state.stopContainer(selected.id)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                            state.startContainer(selected.id)
                                        }
                                    }) {
                                        Label("Restart", systemImage: "arrow.clockwise")
                                    }
                                    .buttonStyle(.bordered)

                                    Button(action: { state.killContainer(selected.id) }) {
                                        Label("Force Kill", systemImage: "bolt.fill")
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                    .help("Send SIGKILL (immediate, ungraceful)")
                                } else {
                                    Button(action: { state.startContainer(selected.id) }) {
                                        Label("Start", systemImage: "play.fill")
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                
                                Menu {
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(selected.id, forType: .string)
                                    } label: { Label("Copy ID", systemImage: "doc.on.doc") }
                                    Button {
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(runCommand(for: selected), forType: .string)
                                    } label: { Label("Copy Run Command", systemImage: "terminal") }
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                .menuStyle(.borderlessButton)
                                .frame(width: 64)
                                .help("Copy the container ID or its run command")

                                Button(role: .destructive, action: { state.deleteContainer(id: selected.id) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    .padding()

                    // Live resource strip (real cgroup sample for the running container)
                    if selected.state == "running" {
                        let live = state.liveStatsById[selected.id]
                        HStack(spacing: 18) {
                            Label(live.map { String(format: "%.1f%% CPU", $0.cpuPercent) } ?? "— CPU",
                                  systemImage: "cpu")
                            Label(live.map { "\(memUsedString($0.memoryBytes)) / \(formatMemoryLimit(selected.memoryLimitMB))" } ?? "— RAM",
                                  systemImage: "memorychip")
                            Text("\(selected.cpuCores) vCPU allocated")
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                        .padding(.bottom, 6)
                    }

                    // Detail Segment Picker tabs
                    Picker("", selection: $activeDetailTab) {
                        ForEach(ContainerTab.allCases, id: \.self) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    Divider()
                    
                    // Dynamic detail panel views
                    switch activeDetailTab {
                    case .logs:
                        VStack(spacing: 0) {
                            HStack {
                                Toggle("Auto-scroll", isOn: $pinToBottom)
                                    .toggleStyle(.checkbox)
                                    .font(.caption)
                                    .padding(.leading, 8)
                                if selected.state == "running" {
                                    Label("Live", systemImage: "dot.radiowaves.left.and.right")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                        .padding(.leading, 6)
                                }
                                Spacer()
                                Button(action: {
                                    let allLogs = displayLogs(for: selected).joined(separator: "\n")
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.clearContents()
                                    pasteboard.setString(allLogs, forType: .string)
                                }) {
                                    Label("Copy Logs", systemImage: "doc.on.doc")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .padding(6)
                            }
                            .background(Color(NSColor.windowBackgroundColor))

                            Divider()

                            ScrollView {
                                ScrollViewReader { scrollProxy in
                                    LazyVStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(displayLogs(for: selected).enumerated()), id: \.offset) { index, log in
                                            Text(log)
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundColor(.shibaCream)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .id(index)
                                        }
                                    }
                                    .padding()
                                    .onChange(of: streamedLogs.count) { _, newCount in
                                        if pinToBottom, newCount > 0 {
                                            scrollProxy.scrollTo(newCount - 1, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                            .background(Color.shibaCharcoal)
                        }
                        .task(id: selected.id) {
                            // Stream real `container logs -f` while this running container's Logs tab is open.
                            streamedLogs = []
                            guard selected.state == "running" else { return }
                            let streamer = LogStreamer()
                            await withTaskCancellationHandler {
                                streamer.start(containerId: selected.id, tail: 200) { line in
                                    DispatchQueue.main.async {
                                        streamedLogs.append(line)
                                        if streamedLogs.count > 3000 {
                                            streamedLogs.removeFirst(streamedLogs.count - 3000)
                                        }
                                    }
                                }
                                while !Task.isCancelled {
                                    try? await Task.sleep(nanoseconds: 500_000_000)
                                }
                            } onCancel: {
                                streamer.stop()
                            }
                        }
                        
                    case .terminal:
                        // Real alpine interactive shell terminal simulation
                        VStack(alignment: .leading, spacing: 0) {
                            ScrollView {
                                ScrollViewReader { scrollProxy in
                                    LazyVStack(alignment: .leading, spacing: 6) {
                                        ForEach(Array(terminalLogs.enumerated()), id: \.offset) { index, line in
                                            logLineColored(line)
                                                .font(.system(.caption, design: .monospaced))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .id(index)
                                        }
                                    }
                                    .padding()
                                    .onChange(of: terminalLogs) { oldValue, newValue in
                                        if !newValue.isEmpty {
                                            scrollProxy.scrollTo(newValue.count - 1, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Input field - only enabled when container is running
                            if selected.state == "running" {
                                HStack {
                                    Text("shiba-guest:~$")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.shibaOrange)
                                    
                                    TextField("", text: $terminalInput, onCommit: executeTerminalCommand)
                                        .font(.system(.caption, design: .monospaced))
                                        .textFieldStyle(.plain)
                                        .foregroundColor(.white)
                                        .onSubmit(executeTerminalCommand)
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.4))
                            } else {
                                HStack {
                                    Image(systemName: "terminal.fill")
                                        .foregroundColor(.secondary)
                                    Text("Terminal offline. Please start the container to run shell commands securely inside its OCI namespace.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.2))
                            }
                        }
                        .background(Color.shibaCharcoal)
                        
                    case .files:
                        // Real container rootfs browser via `container exec ls -la`
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Button(action: {
                                    if currentPath != "/" {
                                        currentPath = "/"
                                        loadContainerFiles(selected)
                                    }
                                }) {
                                    Label("Root (/)", systemImage: "folder.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.shibaOrange)

                                Text(">  \(currentPath)")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(10)
                            .background(Color(NSColor.controlBackgroundColor))

                            Divider()

                            if selected.state != "running" {
                                ContentUnavailableView("Container Stopped", systemImage: "folder.badge.questionmark", description: Text("Start the container to browse its filesystem."))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                List(filesList) { file in
                                    HStack {
                                        Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                                            .foregroundColor(file.isDirectory ? .shibaOrange : .secondary)

                                        Text(file.name)
                                            .font(.system(.body, design: .monospaced))

                                        Spacer()

                                        Text(file.size)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)

                                        Text(file.modDate)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .frame(width: 90, alignment: .trailing)
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if file.isDirectory {
                                            enterFileDirectory(file.name, in: selected)
                                        }
                                    }
                                }
                            }
                        }
                        .onAppear {
                            currentPath = "/"
                            loadContainerFiles(selected)
                        }
                        .onChange(of: selected.id) {
                            currentPath = "/"
                            loadContainerFiles(selected)
                        }
                        
                    case .inspect:
                        // Real `container inspect`: structured env + mounts, then raw JSON
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                if let info = detailInfo {
                                    if !info.mounts.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("MOUNTS").font(.caption2).foregroundColor(.shibaOrange)
                                            ForEach(info.mounts, id: \.destination) { mount in
                                                Text("\(mount.destination)  ←  \(mount.source)")
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundColor(.shibaCream)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                    }
                                    if !info.environment.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("ENVIRONMENT").font(.caption2).foregroundColor(.shibaOrange)
                                            ForEach(info.environment, id: \.self) { env in
                                                Text(env)
                                                    .font(.system(.caption2, design: .monospaced))
                                                    .foregroundColor(.shibaCream)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                    }
                                    Divider()
                                    Text("RAW INSPECT").font(.caption2).foregroundColor(.shibaOrange)
                                }
                                Text(inspectJSON.isEmpty ? "Loading inspect data…" : inspectJSON)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.teal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .textSelection(.enabled)
                            }
                            .padding()
                        }
                        .background(Color.shibaCharcoal)
                        .onAppear { loadInspect(selected) }
                        .onChange(of: selected.id) { loadInspect(selected) }
                    }
                }
            } else {
                ContentUnavailableView("No Container Selected", systemImage: "square.stack.3d.up", description: Text("Select a container from the list or launch a new one."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
            }
        } // Closes Group
        .frame(minWidth: 450, maxWidth: .infinity)
        } // Closes HSplitView
        .sheet(isPresented: $showingCreateSheet) {
            CreateContainerSheet(isPresented: $showingCreateSheet, prefillImage: prefillImage)
        }
        .onAppear { consumePendingRunImage() }
        .onChange(of: state.pendingRunImage) { consumePendingRunImage() }
    } // Closes body
    
    // Command prompt executor
    private func executeTerminalCommand() {
        let input = terminalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        // Remove trailing prompt indicator from terminalLogs
        if let last = terminalLogs.last, last == "shiba-guest:~$ " {
            terminalLogs.removeLast()
        }
        
        terminalLogs.append("shiba-guest:~$ " + input)
        
        let lowercased = input.lowercased()
        if lowercased == "clear" {
            terminalLogs = ["shiba-guest:~$ "]
            terminalInput = ""
            return
        }
        
        guard let container = state.selectedContainer else {
            terminalLogs.append("No container selected.")
            terminalLogs.append("shiba-guest:~$ ")
            terminalInput = ""
            return
        }

        let id = container.id
        terminalInput = ""
        // Run directly inside the selected container via real `container exec`.
        DispatchQueue.global(qos: .userInitiated).async {
            let output = ContainerManager.shared.execInContainer(id: id, command: input)
            DispatchQueue.main.async {
                if let output = output {
                    for line in output.components(separatedBy: "\n") where !line.isEmpty {
                        self.terminalLogs.append(line)
                    }
                } else {
                    self.terminalLogs.append("Error: could not exec in '\(id)'. Is the container running?")
                }
                self.terminalLogs.append("shiba-guest:~$ ")
            }
        }
    }
    
    private func logLineColored(_ line: String) -> Text {
        if line.hasPrefix("shiba-guest:~$ ") {
            let cmd = line.replacingOccurrences(of: "shiba-guest:~$ ", with: "")
            let prompt = Text("shiba-guest:~$ ").foregroundColor(.shibaOrange)
            let command = Text(cmd).foregroundColor(.white)
            return Text("\(prompt)\(command)")
        } else if line.hasPrefix("Welcome") {
            return Text(line).foregroundColor(.green)
        }
        return Text(line).foregroundColor(.shibaCream)
    }
    
    // Browse the real container rootfs via `container exec ls -la`, off the main thread.
    private func loadContainerFiles(_ cont: Container) {
        guard cont.state == "running" else {
            filesList = []
            return
        }
        let id = cont.id
        let path = currentPath
        DispatchQueue.global(qos: .userInitiated).async {
            let entries = ContainerManager.shared.listContainerDirectory(id: id, path: path)
            let items = entries.map { FileItem(name: $0.name, isDirectory: $0.isDirectory, size: $0.size, modDate: $0.modified) }
            DispatchQueue.main.async { filesList = items }
        }
    }

    private func enterFileDirectory(_ dir: String, in cont: Container) {
        if dir == ".." {
            let parent = (currentPath as NSString).deletingLastPathComponent
            currentPath = parent.isEmpty ? "/" : parent
        } else {
            currentPath = (currentPath as NSString).appendingPathComponent(dir)
        }
        loadContainerFiles(cont)
    }
    
    // Open the create-container sheet prefilled when "Run from image" navigated here.
    private func consumePendingRunImage() {
        if let image = state.pendingRunImage {
            prefillImage = image
            showingCreateSheet = true
            state.pendingRunImage = nil
        }
    }

    // Reconstruct the real `container run` command that recreates this container.
    private func runCommand(for cont: Container) -> String {
        var parts = ["container run -d --name \(cont.name)"]
        for port in cont.ports where !port.isEmpty { parts.append("-p \(port)") }
        parts.append(cont.image)
        return parts.joined(separator: " ")
    }

    // Live streamed logs while running; otherwise the one-shot logs from the last refresh.
    private func displayLogs(for cont: Container) -> [String] {
        cont.state == "running" ? streamedLogs : cont.logs
    }

    // Format a live memory figure (bytes) for compact display.
    private func memUsedString(_ bytes: UInt64) -> String {
        let mb = Double(bytes) / (1024.0 * 1024.0)
        if mb >= 1024 {
            return String(format: "%.2f GB", mb / 1024.0)
        }
        return String(format: "%.0f MB", mb)
    }

    // Format an allocated-memory figure (MB) for compact display.
    private func formatMemoryLimit(_ mb: Double) -> String {
        guard mb > 0 else { return "—" }
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        }
        return String(format: "%.0f MB", mb)
    }

    // Load real `container inspect` output (raw JSON + structured env/mounts) off-thread.
    private func loadInspect(_ cont: Container) {
        inspectJSON = ""
        detailInfo = nil
        let id = cont.id
        DispatchQueue.global(qos: .userInitiated).async {
            let result = ContainerManager.shared.inspectContainer(id: id)
            let info = ContainerManager.shared.containerInfo(id: id)
            DispatchQueue.main.async {
                inspectJSON = result ?? "No inspect data available for \(id)."
                detailInfo = info
            }
        }
    }
}

// File Explorer helper model
struct FileItem: Identifiable {
    let id = UUID()
    let name: String
    let isDirectory: Bool
    let size: String
    let modDate: String
}

// Sheet view to launch containers
struct CreateContainerSheet: View {
    @Binding var isPresented: Bool
    var prefillImage: String? = nil
    @EnvironmentObject var state: GUIStateManager
    @State private var name = ""
    @State private var image = "alpine"
    @State private var ports = "80:8080"
    @State private var selectedImageIndex = 0

    // If opened via "Run from image", select that image (matching the picker, else custom).
    private func applyPrefill() {
        guard let prefill = prefillImage, !prefill.isEmpty else { return }
        image = prefill
        if let idx = state.images.firstIndex(where: { "\($0.repository):\($0.tag)" == prefill }) {
            selectedImageIndex = idx
        } else {
            selectedImageIndex = -1
        }
    }
    
    // Validation messages
    @State private var nameError: String? = nil
    @State private var portError: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header Area with Mascot and Branded Compliance
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.shibaOrange.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.title2)
                        .foregroundColor(.shibaOrange)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Launch New Container")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Deploys an isolated OCI namespace mapped to your host.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.bottom, 6)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // Container Name Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "pencil.and.outline")
                                .foregroundColor(.shibaOrange)
                            Text("Container ID / Name")
                                .font(.headline)
                        }
                        
                        TextField("e.g. web-server, dev-db", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: name) { _, newValue in
                                validateName(newValue)
                            }
                        
                        if let err = nameError {
                            Text(err)
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else {
                            Text("Must be alphanumeric characters, dashes, or underscores.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Container Image Picker Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundColor(.shibaOrange)
                            Text("OCI Image Source")
                                .font(.headline)
                        }
                        
                        if !state.images.isEmpty {
                            Picker("Select Pulled Image:", selection: $selectedImageIndex) {
                                ForEach(0..<state.images.count, id: \.self) { idx in
                                    let img = state.images[idx]
                                    Text("\(img.repository):\(img.tag)").tag(idx)
                                }
                                Text("Enter custom image...").tag(-1)
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedImageIndex) { _, newValue in
                                if newValue >= 0, newValue < state.images.count {
                                    let img = state.images[newValue]
                                    image = "\(img.repository):\(img.tag)"
                                }
                                // For custom (-1), keep whatever is in `image` (typed text or prefill).
                            }
                        }
                        
                        if state.images.isEmpty || selectedImageIndex == -1 {
                            TextField("e.g. alpine:latest, nginx:alpine", text: $image)
                                .textFieldStyle(.roundedBorder)
                                .padding(.top, 4)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Port Forwarding Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "network")
                                .foregroundColor(.shibaOrange)
                            Text("Port Forwarding")
                                .font(.headline)
                        }
                        
                        TextField("e.g. 80:8080, 5432:5432", text: $ports)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: ports) { _, newValue in
                                validatePorts(newValue)
                            }
                        
                        if let err = portError {
                            Text(err)
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else {
                            Text("Format 'host_port:container_port'. Binds container ports to host.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Buttons Bar
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Launch") {
                    guard !name.isEmpty && !image.isEmpty && nameError == nil && portError == nil else { return }
                    state.createContainer(name: name, image: image, ports: ports)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.shibaOrange)
                .controlSize(.large)
                .disabled(name.isEmpty || image.isEmpty || nameError != nil || portError != nil)
            }
        }
        .padding()
        .frame(width: 480, height: 500)
        .onAppear {
            // Single deterministic setup: honor a "Run from image" prefill, else default to the first image.
            if let prefill = prefillImage, !prefill.isEmpty {
                applyPrefill()
            } else if !state.images.isEmpty {
                let img = state.images[0]
                image = "\(img.repository):\(img.tag)"
                selectedImageIndex = 0
            } else {
                selectedImageIndex = -1
                image = ""
            }
        }
    }
    
    private func validateName(_ value: String) {
        if value.isEmpty {
            nameError = "Container name cannot be empty."
            return
        }
        
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        if value.unicodeScalars.first(where: { !allowed.contains($0) }) != nil {
            nameError = "Invalid characters. Use alphanumeric, dashes, and underscores only."
        } else {
            nameError = nil
        }
    }
    
    private func validatePorts(_ value: String) {
        if value.isEmpty {
            portError = nil
            return
        }
        
        let parts = value.split(separator: ":")
        if parts.count != 2 {
            portError = "Ports must be in the format 'host_port:container_port'."
            return
        }
        
        guard let hostPort = Int(parts[0]), let guestPort = Int(parts[1]),
              hostPort > 0 && hostPort < 65536, guestPort > 0 && guestPort < 65536 else {
            portError = "Ports must be valid integers between 1 and 65535."
            return
        }
        
        portError = nil
    }
}

// MARK: - Images View (With pull image animation)
struct ImagesDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var pullRepo = ""
    @State private var pullTag = "latest"
    @State private var buildTag = ""
    @State private var buildContext = ""
    @State private var buildDockerfile = ""
    @State private var showingTagSheet = false
    @State private var tagSource = ""
    @State private var tagTarget = ""
    @State private var showingLoginSheet = false
    @State private var loginServer = "docker.io"
    @State private var loginUsername = ""
    @State private var loginPassword = ""

    private func chooseContextFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Choose the build context folder (contains your Dockerfile)"
        if panel.runModal() == .OK, let url = panel.url {
            buildContext = url.path
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Container Images")
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: { showingLoginSheet = true }) {
                        Label("Registry Login", systemImage: "person.badge.key")
                    }
                    .buttonStyle(.bordered)
                }

                // Visual Pull Image Box (Matches OrbStack capabilities)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pull New Image")
                        .font(.headline)
                    
                    HStack {
                        TextField("Repository Name (e.g. alpine, redis)", text: $pullRepo)
                            .textFieldStyle(.roundedBorder)
                            .disabled(state.isPullingImage)
                        
                        TextField("Tag", text: $pullTag)
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                            .disabled(state.isPullingImage)
                        
                        Button(action: startPullImage) {
                            Text(state.isPullingImage ? "Pulling" : "Pull")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.isPullingImage || pullRepo.isEmpty)
                    }
                    
                    if state.isPullingImage {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Downloading and extracting real OCI registry layers asynchronously...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                // Build Image from a Dockerfile (real `container build`)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Build Image")
                        .font(.headline)

                    HStack {
                        TextField("Tag (e.g. myapp:latest)", text: $buildTag)
                            .textFieldStyle(.roundedBorder)
                            .disabled(state.isBuildingImage)

                        Button(action: chooseContextFolder) {
                            Label(buildContext.isEmpty ? "Choose Context…" : (buildContext as NSString).lastPathComponent,
                                  systemImage: "folder")
                        }
                        .disabled(state.isBuildingImage)

                        Button(action: { state.buildImage(tag: buildTag, dockerfile: buildDockerfile, context: buildContext) }) {
                            Text(state.isBuildingImage ? "Building" : "Build")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.isBuildingImage || buildTag.isEmpty || buildContext.isEmpty)
                    }

                    TextField("Dockerfile path (optional — defaults to <context>/Dockerfile)", text: $buildDockerfile)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .disabled(state.isBuildingImage)

                    if state.isBuildingImage {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("Building image via container build…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if !state.lastBuildLog.isEmpty {
                        ScrollView {
                            Text(state.lastBuildLog)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.shibaCream)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .padding(8)
                        }
                        .frame(maxHeight: 160)
                        .background(Color.shibaCharcoal)
                        .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)

                // Card list of local images
                VStack(spacing: 8) {
                    ForEach(state.images) { img in
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.shibaOrange)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(img.repository):\(img.tag)")
                                    .font(.headline)
                                Text("Image ID: \(img.id)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(img.size)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 12)

                            Menu {
                                Button {
                                    state.pendingRunImage = "\(img.repository):\(img.tag)"
                                    state.selectedSidebarItem = .containers
                                } label: { Label("Run…", systemImage: "play") }

                                Button {
                                    tagSource = "\(img.repository):\(img.tag)"
                                    tagTarget = ""
                                    showingTagSheet = true
                                } label: { Label("Tag…", systemImage: "tag") }

                                Button {
                                    state.pushImage(reference: "\(img.repository):\(img.tag)")
                                } label: { Label("Push", systemImage: "arrow.up.circle") }

                                Divider()

                                Button(role: .destructive) {
                                    state.removeImage(img.id)
                                } label: { Label("Delete", systemImage: "trash") }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 44)
                            .disabled(state.isPushingImage)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(alignment: .top) {
            if state.isPushingImage {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Pushing image to registry…").font(.caption)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
                .padding(.top, 8)
            }
        }
        .sheet(isPresented: $showingTagSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Tag Image").font(.title2).fontWeight(.bold)
                Text("Source: \(tagSource)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                TextField("New reference (e.g. registry.example.com/app:1.0)", text: $tagTarget)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { showingTagSheet = false }
                    Button("Tag") {
                        state.tagImage(source: tagSource, target: tagTarget)
                        showingTagSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tagTarget.isEmpty)
                }
            }
            .padding(20)
            .frame(width: 440)
        }
        .sheet(isPresented: $showingLoginSheet) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Registry Login").font(.title2).fontWeight(.bold)
                Text("Credentials are sent to the registry via the container runtime. The password is passed over stdin — never stored or logged by ShibaStack.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("Server (e.g. docker.io)", text: $loginServer)
                    .textFieldStyle(.roundedBorder)
                TextField("Username", text: $loginUsername)
                    .textFieldStyle(.roundedBorder)
                SecureField("Password or token", text: $loginPassword)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Log Out") {
                        state.registryLogout(server: loginServer)
                        showingLoginSheet = false
                    }
                    .disabled(loginServer.isEmpty || state.isAuthenticating)
                    Spacer()
                    Button("Cancel") { showingLoginSheet = false }
                    Button(state.isAuthenticating ? "Logging in…" : "Log In") {
                        state.registryLogin(server: loginServer, username: loginUsername, password: loginPassword)
                        loginPassword = ""
                        showingLoginSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(loginServer.isEmpty || loginPassword.isEmpty || state.isAuthenticating)
                }
            }
            .padding(20)
            .frame(width: 460)
        }
    }

    private func startPullImage() {
        state.pullNewImage(repo: pullRepo, tag: pullTag)
        pullRepo = ""
    }
}

// MARK: - Volumes View (With capacity storage ring indicators)
struct VolumesDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var showingCreateVolumeSheet = false
    @State private var newVolumeName = ""
    @State private var newVolumeMountPoint = ""
    @State private var volumeBytes: Int64 = 0

    private func loadVolumeBytes() {
        DispatchQueue.global(qos: .utility).async {
            let bytes = ContainerManager.shared.volumeStorageBytes()
            DispatchQueue.main.async { volumeBytes = bytes }
        }
    }

    private func formatStorageBytes(_ bytes: Int64) -> String {
        let b = Double(bytes)
        if b >= 1_073_741_824 { return String(format: "%.2f GB", b / 1_073_741_824) }
        if b >= 1_048_576 { return String(format: "%.1f MB", b / 1_048_576) }
        if b >= 1024 { return String(format: "%.1f KB", b / 1024) }
        return "\(bytes) B"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Persistent Volumes")
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: { showingCreateVolumeSheet = true }) {
                            Label("Create Volume", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                        
                        Button(action: state.pruneStorage) {
                            Label("One-Click Disk Prune", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.shibaGold)
                    }
                }
                
                // Real storage stats (sum of actual volume image sizes)
                HStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .stroke(Color.shibaOrange.opacity(0.25), lineWidth: 12)
                            .frame(width: 80, height: 80)
                        VStack(spacing: 0) {
                            Text("\(state.volumes.count)")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.shibaOrange)
                            Text(state.volumes.count == 1 ? "Volume" : "Volumes")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Disk Allocation Statistics")
                            .font(.headline)
                        Text("Total volume storage: \(formatStorageBytes(volumeBytes))")
                            .font(.subheadline)
                        Text("Reclaim unreferenced image layers with One-Click Disk Prune.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .onAppear { loadVolumeBytes() }
                
                // Card list of volumes
                VStack(spacing: 8) {
                    ForEach(state.volumes) { vol in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.shibaOrange)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(vol.name)
                                    .font(.headline)
                                Text("Mount Point: \(vol.mountPoint)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            HStack(spacing: 16) {
                                Text(vol.size)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                
                                Button(action: { deleteVolume(vol.name) }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .help("Remove Volume")
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
                
                // VirtioFS Host Folder Sharing
                VStack(alignment: .leading, spacing: 12) {
                    Text("VirtioFS Host Folder Sharing")
                        .font(.headline)
                        .padding(.top, 8)
                    
                    HStack {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundColor(.shibaOrange)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Host directory: /Users")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text("Shared into guests via VirtioFS tag \"users\" (active when the VM is running).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Text("VirtioFS (High Performance)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.shibaOrange.opacity(0.15))
                            .foregroundColor(.shibaOrange)
                            .cornerRadius(4)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showingCreateVolumeSheet) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Create Persistent Storage Volume")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Volume Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. redis_data", text: $newVolumeName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Mount Point inside guest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("e.g. /data", text: $newVolumeMountPoint)
                        .textFieldStyle(.roundedBorder)
                }
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingCreateVolumeSheet = false
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Create") {
                        createVolume()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.shibaOrange)
                    .disabled(newVolumeName.isEmpty || newVolumeMountPoint.isEmpty)
                }
            }
            .padding()
            .frame(width: 400)
        }
        .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    func createVolume() {
        guard !newVolumeName.isEmpty && !newVolumeMountPoint.isEmpty else { return }
        do {
            try ContainerManager.shared.createVolume(name: newVolumeName, mountPoint: newVolumeMountPoint)
            state.refreshAll()
            newVolumeName = ""
            newVolumeMountPoint = ""
            showingCreateVolumeSheet = false
        } catch {
            state.alertMessage = error.localizedDescription
            state.showingAlert = true
        }
    }
    
    func deleteVolume(_ name: String) {
        do {
            try ContainerManager.shared.removeVolume(id: name)
            state.refreshAll()
        } catch {
            state.alertMessage = error.localizedDescription
            state.showingAlert = true
        }
    }
}

// MARK: - Network View (With active port forward custom adding)
struct NetworkDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var showingAddRule = false
    @State private var dnsActive = false
    @State private var proxyActive = false

    @ViewBuilder
    private func statusBadge(_ active: Bool) -> some View {
        Text(active ? "ACTIVE" : "INACTIVE")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((active ? Color.green : Color.gray).opacity(0.15))
            .foregroundColor(active ? .green : .gray)
            .cornerRadius(4)
    }

    // Probe the real user-space services off the main thread.
    private func refreshNetworkStatus() {
        DispatchQueue.global(qos: .utility).async {
            let dns = NetworkStatus.isDNSResponding(port: 15353)
            let proxy = NetworkStatus.isTCPListening(port: 8080) || NetworkStatus.isTCPListening(port: 80)
            DispatchQueue.main.async {
                dnsActive = dns
                proxyActive = proxy
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("ShibaStack Network & Local DNS")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Automatic local DNS resolving is active. Any running container responds dynamically at its registered domain suffix '*.apc.local' without root modifications.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // Host Network Services Status Panel
                HStack(spacing: 16) {
                    // DNS Resolver status
                    HStack(spacing: 12) {
                        Image(systemName: "globe.americas.fill")
                            .foregroundColor(dnsActive ? .green : .secondary)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DNS Server")
                                .font(.headline)
                            Text("Port 15353 (UDP)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        statusBadge(dnsActive)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                    
                    // Proxy status
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                            .foregroundColor(proxyActive ? .green : .secondary)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reverse Proxy")
                                .font(.headline)
                            Text("Port 80/8080 (TCP)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        statusBadge(proxyActive)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                
                // Loop Guard Shield Banner (Informing user of loopback safety)
                HStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .foregroundColor(.teal)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Proxy Loopback Loop Guard Active")
                            .font(.headline)
                        Text("Protects ShibaStack from self-referential port forwarding loops. Mappings onto active listener ports are automatically intercepted with a standard HTTP 508 Loop Detected status.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.teal.opacity(0.08))
                .cornerRadius(10)
                
                // Add custom port forwarding rule (Matches OrbStack networking tab)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Custom Port Mappings")
                            .font(.headline)
                        Spacer()
                        Button(action: { showingAddRule.toggle() }) {
                            Label(showingAddRule ? "Hide" : "Add a Port?", systemImage: "questionmark.circle")
                        }
                    }

                    if showingAddRule {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Published ports are fixed when a container is created.", systemImage: "info.circle")
                                .font(.subheadline)
                            Text("Apple's container runtime has no live port update. To expose another port, recreate the container with the mapping added:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("container run -d --name <name> -p <hostPort>:<containerPort> <image>")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.shibaOrange)
                                .textSelection(.enabled)
                                .padding(8)
                                .background(Color.black.opacity(0.06))
                                .cornerRadius(6)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // List of active subdomains as card items
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Port Forwardings & Subdomains")
                        .font(.headline)
                        .padding(.bottom, 4)
                    
                    ForEach(state.containers.filter { $0.state == "running" }) { cont in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(cont.primaryDomain)
                                    .font(.headline)
                                    .foregroundColor(.shibaOrange)
                                Text("Container Port Mapping: \(cont.ports.joined(separator: ", "))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Link(destination: state.getContainerURL(cont)) {
                                Label("Open Domain", systemImage: "safari")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            // Probe real service status on appear, then refresh every few seconds.
            while !Task.isCancelled {
                refreshNetworkStatus()
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }
}

// MARK: - USB Passthrough View
struct USBDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("USB Device Passthrough")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Scan and dynamically connect physical USB hardware accessories on your Mac host directly to the Alpine guest virtual machine using Apple's virtualization bus.")
                    .font(.body)
                    .foregroundColor(.secondary)

                if !state.usbPassthroughAvailable {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Device scanning is live, but attachment needs a running VM (the virtualization entitlement is required for passthrough).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color.yellow.opacity(0.08))
                    .cornerRadius(8)
                }

                // Card list of USB devices
                VStack(spacing: 8) {
                    if state.usbDevices.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "usb")
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                Text("No USB devices detected")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    } else {
                        ForEach(state.usbDevices) { dev in
                            HStack {
                                Image(systemName: "usb")
                                    .foregroundColor(.shibaOrange)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(dev.name)
                                        .font(.headline)
                                    Text("ID: \(dev.vendorId):\(dev.productId) | Serial: \(dev.serialNumber)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                Toggle(dev.isAttached ? "Connected" : "Not Attached", isOn: Binding(
                                    get: { dev.isAttached },
                                    set: { _ in state.toggleUSBDevice(dev) }
                                ))
                                .toggleStyle(.switch)
                                .disabled(!state.usbPassthroughAvailable && !dev.isAttached)
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Settings Dashboard View
struct SettingsDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var showingResetAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings & Engine Allocation")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Dynamic VM Resource sliders (Matches OrbStack virtual machine configurations)
                VStack(alignment: .leading, spacing: 14) {
                    Text("Virtual Machine Resource Limits")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("CPU Allocation", systemImage: "cpu")
                            Spacer()
                            Text("\(state.allocatedCPUs) Cores")
                                .bold()
                                .foregroundColor(.shibaOrange)
                        }
                        Slider(value: Binding(
                            get: { Double(state.allocatedCPUs) },
                            set: { state.allocatedCPUs = Int($0) }
                        ), in: 1...8, step: 1)
                        .tint(.shibaOrange)
                        .onChange(of: state.allocatedCPUs) { state.persistVMConfig() }
                        
                        HStack {
                            Label("Memory Allocation", systemImage: "memorychip")
                            Spacer()
                            Text("\(state.allocatedMemoryGB) GB")
                                .bold()
                                .foregroundColor(.shibaOrange)
                        }
                        Slider(value: Binding(
                            get: { Double(state.allocatedMemoryGB) },
                            set: { state.allocatedMemoryGB = Int($0) }
                        ), in: 1...16, step: 1)
                        .tint(.shibaOrange)
                        .onChange(of: state.allocatedMemoryGB) { state.persistVMConfig() }
                        
                        Divider()
                        
                        Toggle(isOn: $state.enableRosetta) {
                            HStack {
                                Label("Rosetta 2 Emulation", systemImage: "sparkles")
                                Spacer()
                                Text(state.enableRosetta ? "Enabled" : "Disabled")
                                    .bold()
                                    .foregroundColor(.shibaOrange)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(.shibaOrange)
                        .onChange(of: state.enableRosetta) { state.persistVMConfig() }
                    }

                    HStack {
                        Text("Reboot required to apply modifications to guest kernels.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Apply & Restart") {
                            state.restartVM()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(state.vmState != "running")
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Clean/Reset Environment card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Troubleshooting & Maintenance")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Diagnostics Collector")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Gathers active environment configuration, OCI runtime details, and network routing logs into a beautiful markdown report on your Desktop.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button(action: { state.generateDiagnosticsReport() }) {
                            Label("Collect Diagnostics", systemImage: "doc.text.magnifyingglass")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Divider()
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reset Local Environment")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Deletes all configurations, local volumes, caches, and resets ShibaStack to a clean, original state.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button(role: .destructive, action: { showingResetAlert = true }) {
                            Text("Reset State")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.gridColor), lineWidth: 1)
                )
            }
            .padding()
        }
        .frame(minWidth: 500, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Reset ShibaStack?", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                state.resetEnvironment()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete ~/.apc/, all custom container definitions, local storage files, and reinitialize a fresh environment. This action is irreversible.")
        }
    }
}

// MARK: - Menu Bar Extra View
struct MenuBarView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var copiedDocker = false
    @State private var copiedSSH = false

    var body: some View {
        VStack(spacing: 12) {
            // 1. Title & Engine status
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(state.vmState == "running" ? Color.green : (state.vmState == "stopped" ? Color.red : Color.orange))
                            .frame(width: 8, height: 8)
                        
                        Text("ShibaStack Engine")
                            .font(.headline)
                    }
                    Text(state.vmState == "running" ? "Hypervisor Active" : (state.vmState == "stopped" ? "Stopped" : "Modifying state..."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                HStack(spacing: 8) {
                    Button(action: {
                        state.restartVM()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(state.vmState == "running" ? .shibaGold : .secondary)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.vmState != "running")
                    .help("Restart Virtual Machine")
                    
                    Button(action: state.toggleVM) {
                        Image(systemName: "power")
                            .foregroundColor(state.vmState == "running" ? .red : .green)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .buttonStyle(.plain)
                    .help(state.vmState == "running" ? "Stop Engine" : "Start Engine")
                }
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // Inline Alert/Error Notice
            if state.showingAlert, let message = state.alertMessage {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Error", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        Spacer()
                        Button(action: {
                            state.showingAlert = false
                            state.alertMessage = nil
                        }) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    Text(message)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
                
                Divider()
            }
            
            // 2. Resource Stats (OrbStack-style thin bars)
            if state.vmState == "running" {
                VStack(spacing: 8) {
                    // CPU Bar
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("CPU Usage")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(String(format: "%.1f", state.hardwareStats.cpuUsage))%")
                                .font(.caption2)
                                .bold()
                        }
                        ProgressView(value: state.hardwareStats.cpuUsage, total: 100.0)
                            .progressViewStyle(.linear)
                            .tint(.shibaOrange)
                            .scaleEffect(x: 1, y: 0.75, anchor: .center)
                    }
                    
                    // RAM Bar
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Memory Allocation")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(String(format: "%.0f", state.hardwareStats.memoryUsage)) MB / \(state.allocatedMemoryGB) GB")
                                .font(.caption2)
                                .bold()
                        }
                        ProgressView(value: state.hardwareStats.memoryUsage, total: Double(state.allocatedMemoryGB * 1024))
                            .progressViewStyle(.linear)
                            .tint(.shibaGold)
                            .scaleEffect(x: 1, y: 0.75, anchor: .center)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                
                Divider()
            }
            
            // 3. VM Details / Allocation Badge
            HStack {
                Label {
                    Text("\(state.allocatedCPUs) CPUs  •  \(state.allocatedMemoryGB) GB  •  \(state.enableRosetta ? "Rosetta" : "Native")")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "cpu")
                        .foregroundColor(.shibaOrange)
                }
                Spacer()
            }
            .padding(.vertical, 2)
            
            Divider()
            
            // 4. Containers Section (OrbStack core value!)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Containers (\(state.containers.count))")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                
                if state.containers.isEmpty {
                    Text("No containers available.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 6) {
                        ForEach(state.containers.prefix(5)) { cont in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(cont.state == "running" ? Color.green : Color.gray)
                                    .frame(width: 6, height: 6)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(cont.name)
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(cont.image)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                
                                // Quick Port Open / Safari shortcut
                                if cont.state == "running", let hostPort = cont.hostPort {
                                    Button(action: {
                                        if let url = URL(string: "http://localhost:\(hostPort)") {
                                            NSWorkspace.shared.open(url)
                                        }
                                    }) {
                                        Image(systemName: "safari")
                                            .foregroundColor(.shibaOrange)
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Open in Browser (port \(hostPort))")
                                }
                                
                                // Quick Toggle Start/Stop
                                Button(action: {
                                    if cont.state == "running" {
                                        state.stopContainer(cont.id)
                                    } else {
                                        state.startContainer(cont.id)
                                    }
                                }) {
                                    Image(systemName: cont.state == "running" ? "stop.fill" : "play.fill")
                                        .foregroundColor(cont.state == "running" ? .red : .green)
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.plain)
                                .help(cont.state == "running" ? "Stop Container" : "Start Container")
                            }
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                            .cornerRadius(4)
                        }
                    }
                }
            }
            
            Divider()
            
            // 5. Maintenance / Utilities Quick Actions
            VStack(spacing: 4) {
                // Copy Docker Env Command — points at the real compatibility socket
                // (~/.apc/docker.sock), so existing `docker` tooling talks to the
                // Apple-container engine through ShibaStack's translation bridge.
                Button(action: {
                    let socketPath = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".apc/docker.sock").path
                    let cmd = "export DOCKER_HOST=\"unix://\(socketPath)\""
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cmd, forType: .string)
                    copiedDocker = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedDocker = false
                    }
                }) {
                    HStack {
                        Image(systemName: copiedDocker ? "checkmark.circle.fill" : "terminal.fill")
                            .foregroundColor(copiedDocker ? .green : .shibaOrange)
                        Text(copiedDocker ? "Copied Docker Env!" : "Copy Docker Environment Command")
                            .font(.caption)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
                
                // Copy a real container shell command (there is no guest SSH server;
                // a shell comes from `container exec`, which actually works).
                Button(action: {
                    let name = state.containers.first(where: { $0.state == "running" })?.name ?? "<container>"
                    let cmd = "container exec -it \(name) sh"
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cmd, forType: .string)
                    copiedSSH = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedSSH = false
                    }
                }) {
                    HStack {
                        Image(systemName: copiedSSH ? "checkmark.circle.fill" : "key.fill")
                            .foregroundColor(copiedSSH ? .green : .shibaGold)
                        Text(copiedSSH ? "Copied Shell Command!" : "Copy Container Shell Command")
                            .font(.caption)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
                
                // One-click Disk Prune
                Button(action: {
                    state.pruneStorage()
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("Clean Unused Data (Prune)")
                            .font(.caption)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
            
            Divider()
            
            // 6. Action Footer Buttons
            VStack(alignment: .leading, spacing: 6) {
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "dashboard" }) {
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        if let url = URL(string: "shibastack://open-dashboard") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }) {
                    Label("Open Dashboard Panel", systemImage: "macwindow")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                
                Button(role: .destructive, action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Label("Quit ShibaStack Suite", systemImage: "power")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(width: 310)
    }
}

// MARK: - Get Started View (Dependencies Installer & Status Board)
struct GetStartedView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var showingResetAlert = false
    @State private var forceShowChecklist = false
    
    var isReady: Bool {
        state.swiftInstalled && state.goInstalled && state.envInitialized
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if isReady && !forceShowChecklist {
                    // --- PREMIUM LIVE RESOURCES DASHBOARD ---
                    VStack(alignment: .leading, spacing: 24) {
                        // Title area
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ShibaStack Hypervisor Board")
                                    .font(.system(size: 28, weight: .bold))
                                Text("Dynamic host-virtualization cluster metrics on Apple Silicon")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Button(action: { forceShowChecklist = true }) {
                                Label("Setup Guide", systemImage: "checklist")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.bottom, 8)
                        
                        // Live Ring Gauges
                        HStack(spacing: 20) {
                            // CPU Ring Gauge
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                                        .frame(width: 100, height: 100)
                                    
                                    Circle()
                                        .trim(from: 0.0, to: CGFloat(min(state.hardwareStats.cpuUsage, 100.0) / 100.0))
                                        .stroke(Color.shibaOrange, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                        .frame(width: 100, height: 100)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut, value: state.hardwareStats.cpuUsage)
                                    
                                    VStack {
                                        Text("\(String(format: "%.1f", state.hardwareStats.cpuUsage))%")
                                            .font(.system(.headline, design: .monospaced))
                                        Text("CPU")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Text("CPU Consumption")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                            
                            // RAM Ring Gauge
                            VStack(spacing: 12) {
                                let totalMemoryMB = Double(state.allocatedMemoryGB) * 1024.0
                                let memoryPercentage = min(state.hardwareStats.memoryUsage / totalMemoryMB, 1.0)
                                ZStack {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.15), lineWidth: 10)
                                        .frame(width: 100, height: 100)
                                    
                                    Circle()
                                        .trim(from: 0.0, to: CGFloat(memoryPercentage))
                                        .stroke(Color.shibaGold, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                        .frame(width: 100, height: 100)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut, value: state.hardwareStats.memoryUsage)
                                    
                                    VStack {
                                        Text("\(Int(state.hardwareStats.memoryUsage)) MB")
                                            .font(.system(.subheadline, design: .monospaced))
                                            .fontWeight(.bold)
                                        Text("of \(state.allocatedMemoryGB) GB")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Text("Memory Allocations")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                        
                        // Action/Status Grid Cards
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            // Containers Card
                            HStack(spacing: 16) {
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.shibaOrange)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Alpine Containers")
                                        .font(.headline)
                                    let activeCount = state.containers.filter { $0.state == "running" }.count
                                    Text("\(activeCount) Running / \(state.containers.count) Total")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                            
                            // Storage Volumes Card
                            HStack(spacing: 16) {
                                Image(systemName: "internaldrive.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.shibaOrange)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Persistent Volumes")
                                        .font(.headline)
                                    Text("\(state.volumes.count) Volumes Registered")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                            
                            // Networking Ports Mapped Card
                            HStack(spacing: 16) {
                                Image(systemName: "network")
                                    .font(.largeTitle)
                                    .foregroundColor(.shibaOrange)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("User-Space Networking")
                                        .font(.headline)
                                    let runningContsWithPorts = state.containers.filter { $0.state == "running" && !$0.ports.isEmpty }.count
                                    Text("\(runningContsWithPorts) Containers Mapped")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                            
                            // Virtual USB Accessories Card
                            HStack(spacing: 16) {
                                Image(systemName: "usb")
                                    .font(.largeTitle)
                                    .foregroundColor(.shibaOrange)
                                    .frame(width: 40)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("USB Passthrough")
                                        .font(.headline)
                                    let attachedCount = state.usbDevices.filter { $0.isAttached }.count
                                    Text("\(attachedCount) Attached / \(state.usbDevices.count) Scanned")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(12)
                        }
                        
                        // Dynamic Toggle Control
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Native Virtualization VM Status")
                                    .font(.headline)
                                Text("Virtualization state: \(state.vmState.uppercased())")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Button(action: state.toggleVM) {
                                Text(state.vmState == "running" ? "Shutdown Engine" : "Boot Engine")
                                    .bold()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(state.vmState == "running" ? .red : .shibaOrange)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(state.vmState == "running" ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                } else {
                    // Header Panel
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Welcome to ShibaStack")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Spacer()
                            if forceShowChecklist {
                                Button(action: { forceShowChecklist = false }) {
                                    Label("Show Dashboard", systemImage: "sparkles")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        Text("ShibaStack manages OCI-compliant Alpine containers natively on Apple Silicon. Let's make sure your host system is fully configured.")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                    
                    // Dependency Status Cards
                    VStack(spacing: 16) {
                        // Xcode Command Line Tools Card
                        DependencyCardView(
                            title: "Xcode Command Line Tools (Swift)",
                            description: "Provides the native Apple compilers and tooling libraries needed to build virtualization and USB accessories.",
                            isInstalled: state.swiftInstalled,
                            isInstalling: state.installingTools,
                            actionLabel: "Install Tools",
                            action: state.installCommandLineTools
                        )
                        
                        // Go Compiler Card
                        DependencyCardView(
                            title: "Go Language Compiler",
                            description: "Required to compile and run the high-performance user-space local DNS server and HTTP routing proxy.",
                            isInstalled: state.goInstalled,
                            isInstalling: state.installingGo,
                            actionLabel: "Install Go Compiler",
                            action: state.installGo
                        )
                        
                        // Local DNS Resolver Card
                        DependencyCardView(
                            title: "Local DNS Resolver Rule",
                            description: "Directs macOS to delegate all *.apc.local host requests to ShibaStack's user-space DNS server (requires one-time admin permission).",
                            isInstalled: state.resolverConfigured,
                            isInstalling: state.configuringResolver,
                            actionLabel: "Configure DNS Rule",
                            action: state.configureResolverRule
                        )
                        
                        // Apple Native Containerization Tool Card
                        DependencyCardView(
                            title: "Apple Native Container Tool",
                            description: "Verifies the presence of Apple's open-source 'apple/container' core command line helper on the host machine.",
                            isInstalled: state.appleContainerInstalled,
                            isInstalling: state.installingAppleContainer,
                            actionLabel: "Download Apple Container",
                            action: state.installAppleContainer
                        )
                        
                        // Configuration Environment Card
                        DependencyCardView(
                            title: "State Database Environment",
                            description: "Prepares local synchronized folders and persistent JSON state configurations under ~/.apc/",
                            isInstalled: state.envInitialized,
                            isInstalling: false,
                            actionLabel: "Initialize Directory",
                            action: state.initializeEnvironment
                        )
                        
                        // Guest Alpine Boot Images Card (Converts mock state to 100% real virtualization!)
                        DependencyCardView(
                            title: "Alpine Linux Guest Kernels",
                            description: "Downloads lightweight, official Alpine Linux aarch64 netboot kernels (vmlinuz-virt & initramfs-virt) needed to boot the native virtual machine.",
                            isInstalled: state.kernelsInstalled,
                            isInstalling: state.downloadingKernels,
                            actionLabel: "Download Kernels (24 MB)",
                            action: state.downloadBootImages
                        )
                    }
                }
                
                // Clean/Reset Environment card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Troubleshooting & Maintenance")
                        .font(.headline)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reset Local Environment")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Deletes all configurations, local volumes, caches, and resets ShibaStack to a clean, original state.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        Button(role: .destructive, action: { showingResetAlert = true }) {
                            Text("Reset State")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(NSColor.gridColor), lineWidth: 1)
                )
                
                Spacer()
            }
            .padding(40)
        }
        .alert("Reset ShibaStack?", isPresented: $showingResetAlert) {
            Button("Reset", role: .destructive) {
                state.resetEnvironment()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete ~/.apc/, all custom container definitions, local storage files, and reinitialize a fresh environment. This action is irreversible.")
        }
    }
}

struct DependencyCardView: View {
    let title: String
    let description: String
    let isInstalled: Bool
    let isInstalling: Bool
    let actionLabel: String
    let action: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Status Icon
            if isInstalling {
                ProgressView()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: isInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.title)
                    .foregroundColor(isInstalled ? .green : .red)
                    .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if !isInstalled {
                    Button(action: action) {
                        if isInstalling {
                            Text("Installing...")
                        } else {
                            Text(actionLabel)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isInstalling)
                    .padding(.top, 4)
                } else {
                    Text("System Verified")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(4)
                        .padding(.top, 4)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.gridColor), lineWidth: 1)
        )
    }
}
