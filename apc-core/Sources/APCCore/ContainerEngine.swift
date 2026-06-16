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
        // Read commands (list/logs/exec/inspect/prune) are bounded so a wedged
        // `container` call (VM mid-start, stuck container) can't hang the worker
        // thread forever. Long-running mutations (build/pull/push) don't use this path.
        let result = ProcessRunner.run(executableURL: executableURL, arguments: arguments, timeout: 20)
        if let error = result.launchError {
            print("[ProcessContainerEngine] Error executing container CLI: \(error.localizedDescription)")
            return nil
        }
        if result.timedOut {
            print("[ProcessContainerEngine] container \(arguments.first ?? "") timed out")
            return nil
        }
        return result.output
    }
}

/// Outcome of a bounded process run.
struct ProcessRunResult {
    let output: String       // combined stdout+stderr (empty if it timed out before draining)
    let exitCode: Int32      // -1 if it timed out or never launched
    let timedOut: Bool
    let launchError: Error?
}

/// Runs a subprocess to completion with an optional deadline.
///
/// Output is drained on a background queue *before* reaping the exit status, so a
/// process that fills the pipe buffer can't deadlock the wait (the classic
/// `waitUntilExit()`-before-read hazard). `timeout == nil` waits indefinitely —
/// used for legitimately long operations like `build` and `pull`.
enum ProcessRunner {
    static func run(executableURL: URL, arguments: [String], timeout: TimeInterval?) -> ProcessRunResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return ProcessRunResult(output: "", exitCode: -1, timedOut: false, launchError: error)
        }

        let drained = DispatchSemaphore(value: 0)
        let box = DataBox()
        DispatchQueue.global(qos: .userInitiated).async {
            box.data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            drained.signal()
        }

        let waitResult: DispatchTimeoutResult
        if let timeout {
            waitResult = drained.wait(timeout: .now() + timeout)
        } else {
            drained.wait()
            waitResult = .success
        }

        if waitResult == .timedOut {
            process.terminate() // SIGTERM; closes the write end, unblocking the read
            var finished = drained.wait(timeout: .now() + 1.0) == .success
            if !finished {
                // SIGTERM ignored — force kill so the drain thread/process can't leak.
                kill(process.processIdentifier, SIGKILL)
                finished = drained.wait(timeout: .now() + 1.0) == .success
            }
            // Only read the shared buffer once the drain has provably finished (happens-before
            // via the semaphore); otherwise leave it empty rather than race the background write.
            let out = finished ? (String(data: box.data, encoding: .utf8) ?? "") : ""
            return ProcessRunResult(output: out, exitCode: -1, timedOut: true, launchError: nil)
        }

        return ProcessRunResult(output: String(data: box.data, encoding: .utf8) ?? "",
                                exitCode: process.terminationStatus, timedOut: false, launchError: nil)
    }
}

/// Tiny reference box so the draining queue and the waiting thread share the buffer;
/// the semaphore provides the happens-before that makes the cross-thread read safe.
private final class DataBox: @unchecked Sendable {
    var data = Data()
}
