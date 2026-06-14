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
        
        // 2. Menu Bar Extra Status Item (using server icon for maximum rendering accuracy)
        MenuBarExtra("ShibaStack", systemImage: "server.rack") {
            MenuBarView()
                .environmentObject(stateManager)
                .tint(.shibaOrange)
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
    
    // Hardware configuration allocations
    @Published var allocatedCPUs: Int = 2
    @Published var allocatedMemoryGB: Int = 4
    
    // Dependency Status State
    @Published var swiftInstalled: Bool = false
    @Published var goInstalled: Bool = false
    @Published var envInitialized: Bool = false
    @Published var resolverConfigured: Bool = false
    
    // Installation progress triggers
    @Published var installingGo: Bool = false
    @Published var installingTools: Bool = false
    @Published var configuringResolver: Bool = false
    
    @Published var selectedSidebarItem: SidebarItem? = .getStarted
    @Published var selectedContainer: Container?
    
    private var timer: Timer?
    
    init() {
        let savedConfig = VMManager.shared.loadVMConfig()
        self.allocatedCPUs = savedConfig.allocatedCPUs
        self.allocatedMemoryGB = savedConfig.allocatedMemoryGB
        
        refreshAll()
        checkDependencies() // Check dependencies once on startup
        startPeriodicRefresh()
    }
    
    func refreshAll() {
        self.vmState = VMManager.shared.getVMState()
        self.containers = ContainerManager.shared.getContainers()
        self.images = ContainerManager.shared.getImages()
        self.volumes = ContainerManager.shared.getVolumes()
        self.usbDevices = USBManager.shared.scanDevices()
        self.hardwareStats = ContainerManager.shared.getStats()
        
        // Auto-select first container if none selected
        if selectedContainer == nil, let first = containers.first {
            selectedContainer = first
        } else if let selected = selectedContainer {
            // Keep selection updated
            selectedContainer = containers.first(where: { $0.id == selected.id })
        }
    }
    
    private func startPeriodicRefresh() {
        // Keep stats and containers dynamically updated every 1.5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.refreshAll()
            }
        }
    }
    
    // Actions
    func toggleVM() {
        if vmState == "running" {
            try? VMManager.shared.stopVM()
        } else {
            let currentConfig = VMConfig(allocatedCPUs: allocatedCPUs, allocatedMemoryGB: allocatedMemoryGB)
            VMManager.shared.saveVMConfig(currentConfig)
            try? VMManager.shared.startVM()
        }
        refreshAll()
    }
    
    func restartVM() {
        try? VMManager.shared.stopVM()
        let currentConfig = VMConfig(allocatedCPUs: allocatedCPUs, allocatedMemoryGB: allocatedMemoryGB)
        VMManager.shared.saveVMConfig(currentConfig)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            try? VMManager.shared.startVM()
            self?.refreshAll()
        }
    }
    
    func startContainer(_ id: String) {
        ContainerManager.shared.startContainer(id: id)
        refreshAll()
    }
    
    func stopContainer(_ id: String) {
        ContainerManager.shared.stopContainer(id: id)
        refreshAll()
    }
    
    func createContainer(name: String, image: String, ports: String) {
        _ = ContainerManager.shared.runNewContainer(name: name, image: image, portMap: ports)
        refreshAll()
    }
    
    func pullNewImage(repo: String, tag: String) {
        ContainerManager.shared.addImage(repository: repo, tag: tag)
        refreshAll()
    }
    
    func addPortForward(hostPort: Int, containerPort: Int, containerName: String) {
        ContainerManager.shared.addPortForward(containerName: containerName, portMap: "\(hostPort):\(containerPort)")
        refreshAll()
    }
    
    func removeImage(_ id: String) {
        ContainerManager.shared.removeImage(id: id)
        refreshAll()
    }
    
    func pruneStorage() {
        ContainerManager.shared.pruneVolumes()
        refreshAll()
    }
    
    func toggleUSBDevice(_ device: USBDevice) {
        do {
            if device.isAttached {
                try USBManager.shared.detachDevice(device, from: VMManager.shared.getUnderlyingVM())
            } else {
                try USBManager.shared.attachDevice(device, to: VMManager.shared.getUnderlyingVM())
            }
        } catch {
            print("USB Action failed: \(error.localizedDescription)")
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
            
            DispatchQueue.main.async {
                self.swiftInstalled = swiftPath
                self.goInstalled = goPath
                self.envInitialized = envExists
                self.resolverConfigured = resolverExists
            }
        }
    }
    
    private func checkCommandExists(_ command: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [command]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
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
            // Attempt brew installation first
            let brewCheck = Process()
            brewCheck.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            brewCheck.arguments = ["brew"]
            try? brewCheck.run()
            brewCheck.waitUntilExit()
            
            if brewCheck.terminationStatus == 0 {
                let brewInstall = Process()
                var brewPath = "/opt/homebrew/bin/brew"
                if !FileManager.default.fileExists(atPath: brewPath) {
                    brewPath = "/usr/local/bin/brew"
                }
                brewInstall.executableURL = URL(fileURLWithPath: brewPath)
                brewInstall.arguments = ["install", "go"]
                try? brewInstall.run()
                brewInstall.waitUntilExit()
            } else {
                // Fallback: Download official Arm64 .pkg and run macOS installer with elevations
                let downloadTask = Process()
                downloadTask.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
                downloadTask.arguments = ["-L", "https://dl.google.com/go/go1.22.4.darwin-arm64.pkg", "-o", "/tmp/go-installer.pkg"]
                try? downloadTask.run()
                downloadTask.waitUntilExit()
                
                let script = "do shell script \"installer -pkg /tmp/go-installer.pkg -target /\" with administrator privileges"
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
    
    func resetEnvironment() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let apcDir = home.appendingPathComponent(".apc")
        try? FileManager.default.removeItem(at: apcDir)
        initializeEnvironment()
    }
    
    deinit {
        timer?.invalidate()
    }
}

// MARK: - Navigation Definitions
enum SidebarItem: String, CaseIterable, Identifiable {
    case getStarted = "Get Started"
    case containers = "Containers"
    case images = "Images"
    case volumes = "Volumes"
    case network = "Network"
    case hardware = "Hardware & USB"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .getStarted: return "sparkles"
        case .containers: return "square.stack.3d.up.fill"
        case .images: return "photo.fill"
        case .volumes: return "internaldrive.fill"
        case .network: return "network"
        case .hardware: return "cpu"
        }
    }
}

// MARK: - Main Dashboard View
struct MainDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var showingPruneConfirmation = false
    
    var body: some View {
        NavigationSplitView {
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
                case .getStarted:
                    GetStartedView()
                case .containers:
                    ContainersDashboardView()
                case .images:
                    ImagesDashboardView()
                case .volumes:
                    VolumesDashboardView()
                case .network:
                    NetworkDashboardView()
                case .hardware:
                    HardwareDashboardView()
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
    @State private var activeDetailTab: ContainerTab = .logs
    
    // Interactive Terminal Simulation states
    @State private var terminalInput = ""
    @State private var terminalLogs: [String] = ["Welcome to Alpine Linux 3.18.2 guest terminal.", "shiba-guest:~$ "]
    
    // Filesystem explorer simulation states
    @State private var currentPath = "/"
    @State private var filesList: [FileItem] = [
        FileItem(name: "bin", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 10:00"),
        FileItem(name: "etc", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 10:01"),
        FileItem(name: "home", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 09:30"),
        FileItem(name: "var", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 08:24"),
        FileItem(name: "root", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 10:05"),
        FileItem(name: "usr", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 10:00"),
        FileItem(name: "index.html", isDirectory: false, size: "1.2 KB", modDate: "Jun 12 14:23")
    ]
    
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
                
                List(state.containers, selection: $state.selectedContainer) { cont in
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
                        
                        // Inline Resource Indicators (Matches OrbStack layout)
                        if cont.state == "running" {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(String(format: "%.1f", cont.cpuUsage))% CPU")
                                    .font(.system(size: 10, design: .monospaced))
                                Text("\(String(format: "%.1f", cont.memoryUsage)) MB")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .tag(cont)
                    .padding(.vertical, 4)
                }
            }
            .frame(minWidth: 350, maxWidth: 450)
            
            // Container Details (Tabs: Logs, Terminal, Files, Inspect)
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
                        
                        // State Action buttons (OrbStack style top action headers)
                        HStack(spacing: 8) {
                            if selected.state == "running" {
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
                            } else {
                                Button(action: { state.startContainer(selected.id) }) {
                                    Label("Start", systemImage: "play.fill")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    .padding()
                    
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
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(selected.logs, id: \.self) { log in
                                    Text(log)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.shibaCream)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding()
                        }
                        .background(Color.shibaCharcoal)
                        
                    case .terminal:
                        // Real alpine interactive shell terminal simulation
                        VStack(alignment: .leading, spacing: 0) {
                            ScrollView {
                                ScrollViewReader { scrollProxy in
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(terminalLogs, id: \.self) { line in
                                            logLineColored(line)
                                                .font(.system(.caption, design: .monospaced))
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .id(line)
                                        }
                                    }
                                    .padding()
                                    .onChange(of: terminalLogs) { oldValue, newValue in
                                        if let last = newValue.last {
                                            scrollProxy.scrollTo(last, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            // Input field
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
                        }
                        .background(Color.shibaCharcoal)
                        
                    case .files:
                        // Interactive container filesystem directory tree browser
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Button(action: {
                                    if currentPath != "/" {
                                        currentPath = "/"
                                        resetFilesList()
                                    }
                                }) {
                                    Label("Root (/) ", systemImage: "folder.fill")
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
                                        .frame(width: 80, alignment: .trailing)
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if file.isDirectory {
                                        currentPath = currentPath == "/" ? "/\(file.name)" : "\(currentPath)/\(file.name)"
                                        enterFileDirectory(file.name)
                                    }
                                }
                            }
                        }
                        
                    case .inspect:
                        // Syntax highlighted dynamic JSON inspector
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(getContainerInspectJSON(selected))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.teal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding()
                        }
                        .background(Color.shibaCharcoal)
                    }
                }
                .frame(minWidth: 450)
            } else {
                ContentUnavailableView("No Container Selected", systemImage: "square.stack.3d.up", description: Text("Select a container from the list or launch a new one."))
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateContainerSheet(isPresented: $showingCreateSheet)
        }
    }
    
    // Command prompt executor simulation
    private func executeTerminalCommand() {
        let input = terminalInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        // Remove trailing prompt indicator from terminalLogs
        if let last = terminalLogs.last, last == "shiba-guest:~$ " {
            terminalLogs.removeLast()
        }
        
        terminalLogs.append("shiba-guest:~$ " + input)
        
        switch input.lowercased() {
        case "ls":
            terminalLogs.append("bin      dev      etc      home     proc     root     sys      usr      var")
        case "uname -a":
            terminalLogs.append("Linux shiba-guest 6.6.15-shibastack-arm64 #1 SMP Alpine Linux v3.18")
        case "whoami":
            terminalLogs.append("root")
        case "pwd":
            terminalLogs.append("/root")
        case "cat index.html":
            terminalLogs.append("<!DOCTYPE html>")
            terminalLogs.append("<html>")
            terminalLogs.append("<head><title>Welcome to ShibaStack!</title></head>")
            terminalLogs.append("<body>")
            terminalLogs.append("<h1>🐕 ShibaStack: Container Up & Running!</h1>")
            terminalLogs.append("<p>You are natively running Alpine + Nginx on Apple Silicon with near-zero overhead.</p>")
            terminalLogs.append("</body>")
            terminalLogs.append("</html>")
        case "cat /etc/resolv.conf":
            terminalLogs.append("# User-space DNS config mapped via ShibaStack Resolver")
            terminalLogs.append("nameserver 127.0.0.1")
            terminalLogs.append("port 15353")
        case "cat /etc/hosts":
            terminalLogs.append("127.0.0.1   localhost shiba-guest")
            terminalLogs.append("127.0.0.1   web-app.apc.local postgres-db.apc.local")
        case "nginx -v":
            terminalLogs.append("nginx version: nginx/1.25.1 (Alpine Linux)")
        case "ps", "ps aux":
            terminalLogs.append("PID   USER     TIME  COMMAND")
            terminalLogs.append("    1 root      0:01 /sbin/init")
            terminalLogs.append("    8 root      0:02 /usr/sbin/syslogd -t")
            terminalLogs.append("   22 root      0:05 /usr/bin/vminitd --vsock 1024")
            terminalLogs.append("  104 root      0:12 nginx: master process nginx -g daemon off;")
            terminalLogs.append("  105 nginx     0:08 nginx: worker process")
        case "df -h":
            terminalLogs.append("Filesystem      Size  Used Avail Use% Mounted on")
            terminalLogs.append("/dev/root        4.0G  1.2G  2.6G  32% /")
            terminalLogs.append("users           476G  182G  294G  39% /Users")
        case "apk add curl":
            terminalLogs.append("(1/3) Upgrading alpine-keys (3.18-r0 -> 3.18-r1)")
            terminalLogs.append("(2/3) Installing libcurl (8.5.0-r0)")
            terminalLogs.append("(3/3) Installing curl (8.5.0-r0)")
            terminalLogs.append("Executing busybox-1.36.1-r2.trigger")
            terminalLogs.append("OK: 12 MiB in 18 packages")
        case "curl http://web-app.apc.local", "curl http://localhost":
            terminalLogs.append("HTTP/1.1 200 OK")
            terminalLogs.append("Server: nginx/1.25.1")
            terminalLogs.append("Content-Type: text/html")
            terminalLogs.append("")
            terminalLogs.append("🐕 ShibaStack Landing: Container is online!")
        case "ping -c 3 apc.local":
            terminalLogs.append("PING apc.local (127.0.0.1): 56 data bytes")
            terminalLogs.append("64 bytes from 127.0.0.1: seq=0 ttl=64 time=0.124 ms")
            terminalLogs.append("64 bytes from 127.0.0.1: seq=1 ttl=64 time=0.098 ms")
            terminalLogs.append("64 bytes from 127.0.0.1: seq=2 ttl=64 time=0.105 ms")
            terminalLogs.append("--- apc.local ping statistics ---")
            terminalLogs.append("3 packets transmitted, 3 packets received, 0% packet loss")
        case "clear":
            terminalLogs = []
        case "help":
            terminalLogs.append("Available commands: ls, uname -a, whoami, pwd, cat index.html, cat /etc/resolv.conf, cat /etc/hosts, nginx -v, ps, df -h, apk add curl, curl http://localhost, ping -c 3 apc.local, clear, help")
        default:
            terminalLogs.append("sh: command not found: \(input). Type 'help' for instructions.")
        }
        
        terminalLogs.append("shiba-guest:~$ ")
        terminalInput = ""
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
    
    private func resetFilesList() {
        filesList = [
            FileItem(name: "bin", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 10:00"),
            FileItem(name: "etc", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 10:01"),
            FileItem(name: "home", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 09:30"),
            FileItem(name: "var", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 08:24"),
            FileItem(name: "root", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 10:05"),
            FileItem(name: "usr", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 10:00"),
            FileItem(name: "index.html", isDirectory: false, size: "1.2 KB", modDate: "Jun 12 14:23")
        ]
    }
    
    private func enterFileDirectory(_ dir: String) {
        if dir == "etc" {
            filesList = [
                FileItem(name: "hosts", isDirectory: false, size: "128 B", modDate: "Jun 14 10:00"),
                FileItem(name: "resolv.conf", isDirectory: false, size: "48 B", modDate: "Jun 14 10:00"),
                FileItem(name: "nginx", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 10:01")
            ]
        } else if dir == "nginx" {
            filesList = [
                FileItem(name: "nginx.conf", isDirectory: false, size: "2.1 KB", modDate: "Jun 14 10:01"),
                FileItem(name: "conf.d", isDirectory: true, size: "4.0 KB", modDate: "Jun 14 10:01")
            ]
        } else {
            filesList = [
                FileItem(name: "dummy_file.txt", isDirectory: false, size: "0 B", modDate: "Jun 14 10:05")
            ]
        }
    }
    
    private func getContainerInspectJSON(_ cont: Container) -> String {
        return """
{
  "Id": "\(cont.id)",
  "Created": "2026-06-14T15:00:00.124892Z",
  "Path": "/bin/sh",
  "Args": [],
  "State": {
    "Status": "\(cont.state)",
    "Running": \(cont.state == "running" ? "true" : "false"),
    "Pid": \(cont.state == "running" ? "1248" : "0"),
    "ExitCode": 0,
    "Error": ""
  },
  "Image": "sha256:\(UUID().uuidString.prefix(12).lowercased())",
  "ResolvConfPath": "/etc/resolv.conf",
  "HostnamePath": "/etc/hostname",
  "HostsPath": "/etc/hosts",
  "LogPath": "/var/log/containers/\(cont.id).log",
  "Name": "/\(cont.name)",
  "Config": {
    "Hostname": "alpine-guest",
    "Domainname": "apc.local",
    "User": "root",
    "ExposedPorts": {
      "\(cont.ports.first ?? "8080")/tcp": {}
    },
    "Env": [
      "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
      "ALPINE_VERSION=3.18.2"
    ],
    "Cmd": [
      "/bin/sh"
    ]
  }
}
"""
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
    @EnvironmentObject var state: GUIStateManager
    @State private var name = ""
    @State private var image = "alpine"
    @State private var ports = "80:8080"
    
    // Validation messages
    @State private var nameError: String? = nil
    @State private var portError: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Launch New Container")
                .font(.title2)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 14) {
                // Name input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Container Name:")
                        .font(.headline)
                    TextField("e.g. web-server, postgres-db", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: name) { _, newValue in
                            validateName(newValue)
                        }
                    
                    if let err = nameError {
                        Text(err)
                            .font(.caption2)
                            .foregroundColor(.red)
                    } else {
                        Text("Only alphanumeric characters, dashes, and underscores allowed.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Image input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Image Tag:")
                        .font(.headline)
                    TextField("e.g. alpine:latest, nginx:3.18", text: $image)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Port mapping input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Port Forwarding (host_port:container_port):")
                        .font(.headline)
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
                        Text("Exposes guest services to local localhost ports.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Run") {
                    guard !name.isEmpty && !image.isEmpty && nameError == nil && portError == nil else { return }
                    state.createContainer(name: name, image: image, ports: ports)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || image.isEmpty || nameError != nil || portError != nil)
            }
        }
        .padding()
        .frame(width: 420, height: 380)
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
    @State private var isPulling = false
    @State private var pullProgress: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Container Images")
                .font(.title)
                .fontWeight(.bold)
                .padding([.top, .leading])
            
            // Visual Pull Image Box (Matches OrbStack capabilities)
            VStack(alignment: .leading, spacing: 12) {
                Text("Pull New Image")
                    .font(.headline)
                
                HStack {
                    TextField("Repository Name (e.g. alpine, redis)", text: $pullRepo)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isPulling)
                    
                    TextField("Tag", text: $pullTag)
                        .frame(width: 80)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isPulling)
                    
                    Button(action: startPullImage) {
                        Text(isPulling ? "Pulling" : "Pull")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPulling || pullRepo.isEmpty)
                }
                
                if isPulling {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: pullProgress, total: 100.0)
                            .progressViewStyle(.linear)
                            .tint(.shibaOrange)
                        Text("Downloading layers... \(Int(pullProgress))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal)
            
            List(state.images) { img in
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
                    
                    Button(action: { state.removeImage(img.id) }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Image")
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func startPullImage() {
        isPulling = true
        pullProgress = 0.0
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            pullProgress += 5.0
            if pullProgress >= 100.0 {
                timer.invalidate()
                state.pullNewImage(repo: pullRepo, tag: pullTag)
                isPulling = false
                pullRepo = ""
            }
        }
    }
}

// MARK: - Volumes View (With capacity storage ring indicators)
struct VolumesDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Persistent Volumes")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button(action: state.pruneStorage) {
                    Label("One-Click Disk Prune", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .tint(.shibaGold)
            }
            .padding([.top, .horizontal])
            
            // Storage Capacity Utilization Board
            HStack(spacing: 24) {
                // Circular ring gauge
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.15), lineWidth: 12)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0.0, to: 0.42)
                        .stroke(Color.shibaOrange, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("42%")
                            .font(.headline)
                        Text("Used")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Disk Allocation Statistics")
                        .font(.headline)
                    Text("Total Volume Capacity: 10.0 GB")
                        .font(.subheadline)
                    Text("Active Mounts Storage: 155.8 MB | Reclaimable Space: 1.6 MB")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal)
            
            List(state.volumes) { vol in
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
                    
                    Text(vol.size)
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Network View (With active port forward custom adding)
struct NetworkDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var showingAddRule = false
    @State private var fwdHostPort = "8080"
    @State private var fwdContainerPort = "80"
    @State private var fwdContainerName = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ShibaStack Network & Local DNS")
                .font(.title)
                .fontWeight(.bold)
                .padding([.top, .horizontal])
            
            Text("Automatic local DNS resolving is active. Any running container responds dynamically at its registered domain suffix '*.apc.local' without root modifications.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Host Network Services Status Panel
            HStack(spacing: 16) {
                // DNS Resolver status
                HStack(spacing: 12) {
                    Image(systemName: "globe.americas.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DNS Server")
                            .font(.headline)
                        Text("Port 15353 (UDP)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                
                // Proxy status
                HStack(spacing: 12) {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reverse Proxy")
                            .font(.headline)
                        Text("Port 80/8080 (TCP)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
            }
            .padding(.horizontal)
            
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
            .padding(.horizontal)
            
            // Add custom port forwarding rule (Matches OrbStack networking tab)
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Custom Port Mappings")
                        .font(.headline)
                    Spacer()
                    Button(action: { showingAddRule.toggle() }) {
                        Label(showingAddRule ? "Hide Form" : "Add Port Map", systemImage: "plus")
                    }
                }
                
                if showingAddRule {
                    HStack {
                        TextField("Host Port", text: $fwdHostPort)
                            .textFieldStyle(.roundedBorder)
                        Text(":")
                        TextField("Container Port", text: $fwdContainerPort)
                            .textFieldStyle(.roundedBorder)
                        
                        Picker("", selection: $fwdContainerName) {
                            Text("Select container").tag("")
                            ForEach(state.containers) { cont in
                                Text(cont.name).tag(cont.name)
                            }
                        }
                        .frame(width: 150)
                        
                        Button("Apply Forward") {
                            guard let hPort = Int(fwdHostPort), let cPort = Int(fwdContainerPort), !fwdContainerName.isEmpty else { return }
                            state.addPortForward(hostPort: hPort, containerPort: cPort, containerName: fwdContainerName)
                            showingAddRule = false
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(fwdContainerName.isEmpty)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal)
            
            List {
                Section(header: Text("Active Port Forwardings & Subdomains").font(.headline)) {
                    ForEach(state.containers.filter { $0.state == "running" }) { cont in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(cont.name).apc.local")
                                    .font(.headline)
                                    .foregroundColor(.shibaOrange)
                                Text("Container Port Mapping: \(cont.ports.joined(separator: ", "))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            
                            Link(destination: URL(string: "http://\(cont.name).apc.local:8080")!) {
                                Label("Open Domain", systemImage: "safari")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .onAppear {
            if let first = state.containers.first {
                fwdContainerName = first.name
            }
        }
    }
}

// MARK: - Hardware & USB View (With CPU/RAM allocation sliders)
struct HardwareDashboardView: View {
    @EnvironmentObject var state: GUIStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Hardware Forwarding & Virtual Machine Config")
                .font(.title)
                .fontWeight(.bold)
                .padding([.top, .horizontal])
            
            // Dynamic VM Resource sliders (Matches OrbStack virtual machine configurations)
            VStack(alignment: .leading, spacing: 14) {
                Text("Configure ShibaStack Virtual Machine Allocations")
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
                }
                
                HStack {
                    Text("Reboot required to apply modifications to guest kernels.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Apply Resource Limits") {
                        state.restartVM()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(state.vmState != "running")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .padding(.horizontal)
            
            Text("Scan and dynamically connect physical USB hardware accessories on your Mac host directly to the Alpine guest virtual machine using Apple's virtualization bus.")
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            List(state.usbDevices) { dev in
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
                }
                .padding(.vertical, 6)
            }
        }
    }
}

// MARK: - Menu Bar Extra View
struct MenuBarView: View {
    @EnvironmentObject var state: GUIStateManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ShibaStack")
                        .font(.headline)
                    Text("Native macOS Container Engine")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Button(action: state.toggleVM) {
                    Image(systemName: "power")
                        .foregroundColor(state.vmState == "running" ? .shibaOrange : .secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // Stats Section
            VStack(spacing: 8) {
                // CPU Bar
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("CPU Usage")
                            .font(.caption)
                        Spacer()
                        Text("\(String(format: "%.1f", state.hardwareStats.cpuUsage))%")
                            .font(.caption)
                            .bold()
                    }
                    ProgressView(value: state.hardwareStats.cpuUsage, total: 100.0)
                        .progressViewStyle(.linear)
                        .tint(.shibaOrange)
                }
                
                // RAM Bar
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Memory Allocation")
                            .font(.caption)
                        Spacer()
                        Text("\(String(format: "%.0f", state.hardwareStats.memoryUsage)) MB / 4 GB")
                            .font(.caption)
                            .bold()
                    }
                    ProgressView(value: state.hardwareStats.memoryUsage, total: 4096.0)
                        .progressViewStyle(.linear)
                        .tint(.shibaGold)
                }
            }
            
            Divider()
            
            // Actions
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "dashboard" }) {
                        window.makeKeyAndOrderFront(nil)
                    } else {
                        // Open window if not found
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
        .padding(14)
        .frame(width: 280)
    }
}

// MARK: - Get Started View (Dependencies Installer & Status Board)
struct GetStartedView: View {
    @EnvironmentObject var state: GUIStateManager
    @State private var showingResetAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header Panel
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to ShibaStack")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
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
                    
                    // Configuration Environment Card
                    DependencyCardView(
                        title: "State Database Environment",
                        description: "Prepares local synchronized folders and persistent JSON state configurations under ~/.apc/",
                        isInstalled: state.envInitialized,
                        isInstalling: false,
                        actionLabel: "Initialize Directory",
                        action: state.initializeEnvironment
                    )
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
