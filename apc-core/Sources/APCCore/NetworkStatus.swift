import Foundation
import Network

/// Real liveness probes for ShibaStack's user-space network services, so the UI
/// can report actual status instead of a hardcoded "ACTIVE" badge.
public enum NetworkStatus {

    /// True if a TCP listener accepts a connection on 127.0.0.1:port within `timeout`.
    public static func isTCPListening(port: UInt16, timeout: TimeInterval = 0.4) -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: .tcp)
        let result = Locked(false)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                result.value = true
                semaphore.signal()
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        connection.start(queue: .global())
        _ = semaphore.wait(timeout: .now() + timeout)
        connection.cancel()
        return result.value
    }

    /// True if the user-space DNS server answers a `*.apc.local` query on the given UDP port.
    public static func isDNSResponding(port: UInt16 = 15353, timeout: TimeInterval = 0.4) -> Bool {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        let semaphore = DispatchSemaphore(value: 0)
        let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: .udp)
        let result = Locked(false)

        // Minimal DNS A-query for "health.apc.local".
        let query = Data([
            0x12, 0x34, 0x01, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            6, 0x68, 0x65, 0x61, 0x6c, 0x74, 0x68,        // "health"
            3, 0x61, 0x70, 0x63,                          // "apc"
            5, 0x6c, 0x6f, 0x63, 0x61, 0x6c,              // "local"
            0x00, 0x00, 0x01, 0x00, 0x01,                 // QTYPE=A, QCLASS=IN
        ])

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.send(content: query, completion: .contentProcessed { _ in
                    connection.receiveMessage { data, _, _, _ in
                        if let data, !data.isEmpty { result.value = true }
                        semaphore.signal()
                    }
                })
            case .failed, .cancelled:
                semaphore.signal()
            default:
                break
            }
        }
        connection.start(queue: .global())
        _ = semaphore.wait(timeout: .now() + timeout)
        connection.cancel()
        return result.value
    }
}

/// Tiny lock-guarded box so the probe closures and the waiting thread share a result safely.
private final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Value
    init(_ value: Value) { stored = value }
    var value: Value {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }
}
