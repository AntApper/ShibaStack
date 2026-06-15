import Foundation

/// The seam between `ContainerManager`'s mapping logic and the host container runtime.
///
/// `ContainerManager` owns *how* CLI output becomes a `Container` (image-name
/// stripping, port parsing, state normalisation). It does not own *how* the
/// runtime is reached — that lives behind this interface. Production talks to the
/// native `container` binary; tests supply a fake that returns canned output, so
/// the mapping is exercisable without `/usr/local/bin/container` installed.
public protocol ContainerEngine: Sendable {
    /// Run a container subcommand, returning combined stdout, or `nil` on failure.
    func run(_ arguments: [String]) -> String?
}

/// Production adapter: shells out to the native `container` CLI on the host Mac.
public struct ProcessContainerEngine: ContainerEngine {
    private let executableURL: URL

    public init(executablePath: String = "/usr/local/bin/container") {
        self.executableURL = URL(fileURLWithPath: executablePath)
    }

    public func run(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // Swallow stderr to keep logs pristine

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            print("[ProcessContainerEngine] Error executing container CLI: \(error.localizedDescription)")
            return nil
        }
    }
}
