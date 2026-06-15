import Foundation

/// Streams a container's logs live by running `container logs -f` as a long-lived
/// process and emitting complete lines as they arrive. The GUI owns one of these
/// per visible Logs tab and calls `stop()` when the container or tab changes.
public final class LogStreamer: @unchecked Sendable {
    private let executablePath: String
    private let lock = NSLock()
    private var process: Process?
    private var buffer = ""

    public init(executablePath: String = "/usr/local/bin/container") {
        self.executablePath = executablePath
    }

    /// Start following `containerId`'s logs, seeding with the last `tail` lines.
    /// `onLine` is invoked (off the main thread) for each complete log line.
    public func start(containerId: String, tail: Int = 200, onLine: @escaping @Sendable (String) -> Void) {
        stop()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["logs", "-f", "-n", "\(tail)", containerId]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard let self, !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            self.lock.lock()
            self.buffer += text
            var lines = self.buffer.components(separatedBy: "\n")
            self.buffer = lines.removeLast() // keep the trailing partial line
            self.lock.unlock()
            for line in lines where !line.isEmpty { onLine(line) }
        }

        do {
            try process.run()
            lock.lock(); self.process = process; lock.unlock()
        } catch {
            onLine("[log stream error] \(error.localizedDescription)")
        }
    }

    public func stop() {
        lock.lock()
        let running = process
        process = nil
        buffer = ""
        lock.unlock()

        guard let running else { return }
        (running.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        if running.isRunning { running.terminate() }
    }

    deinit { stop() }
}
