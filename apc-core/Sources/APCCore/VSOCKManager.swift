import Foundation
import Virtualization
import Network

#if os(macOS)
public final class VSOCKListenerDelegate: NSObject, VZVirtioSocketListenerDelegate {
    private let onConnection: (VZVirtioSocketConnection) -> Void
    
    public init(onConnection: @escaping (VZVirtioSocketConnection) -> Void) {
        self.onConnection = onConnection
    }
    
    public func listener(_ listener: VZVirtioSocketListener, shouldAcceptNewConnection connection: VZVirtioSocketConnection, from socketDevice: VZVirtioSocketDevice) -> Bool {
        onConnection(connection)
        return true
    }
}
#endif

public final class VSOCKManager {
    public static nonisolated(unsafe) let shared = VSOCKManager()
    
    private let lock = NSLock()
    #if os(macOS)
    private var listenerDelegates: [UInt32: VSOCKListenerDelegate] = [:]
    private var mockListener: NWListener?
    #endif
    
    private init() {}
    
    public func registerListener(onPort port: UInt32, vm: VZVirtualMachine?, onConnectionReceived: @escaping (Int32) -> Void) {
        #if os(macOS)
        guard let vm = vm else {
            print("[VSOCKManager] Real VM instance not available. Operating in mock communication mode.")
            if port == 1024 {
                print("[VSOCKManager] Starting mock TCP server on localhost port 10124 to bind with guest agent (guest-vminitd)...")
                startMockTCPServer(onPort: 10124) { connection in
                    // Connection received in mock mode
                }
            }
            return
        }
        
        let delegate = VSOCKListenerDelegate { connection in
            print("[VSOCKManager] Accepted new incoming connection on VSOCK port \(port) from guest (source port: \(connection.sourcePort))")
            onConnectionReceived(connection.fileDescriptor)
        }
        
        lock.lock()
        listenerDelegates[port] = delegate
        lock.unlock()
        
        if let socketDevice = vm.socketDevices.first as? VZVirtioSocketDevice {
            let listener = VZVirtioSocketListener()
            listener.delegate = delegate
            socketDevice.setSocketListener(listener, forPort: port)
            print("[VSOCKManager] Successfully bound native VSOCK listener on port \(port)")
        } else {
            print("[VSOCKManager] Error: No socket devices found in VM configuration.")
        }
        #else
        print("[VSOCKManager] VSOCK is not supported on this platform. Mocking port \(port)")
        #endif
    }
    
    public func connectToGuest(port: UInt32, vm: VZVirtualMachine?, completion: @escaping (Int32?, Error?) -> Void) {
        #if os(macOS)
        guard let vm = vm else {
            completion(nil, NSError(domain: "VSOCKManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "VM is in mock mode"]))
            return
        }
        
        guard let socketDevice = vm.socketDevices.first as? VZVirtioSocketDevice else {
            completion(nil, NSError(domain: "VSOCKManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No VSOCK device available"]))
            return
        }
        
        socketDevice.connect(toPort: port) { result in
            switch result {
            case .success(let connection):
                print("[VSOCKManager] Connected to guest VSOCK port \(port) (file descriptor: \(connection.fileDescriptor))")
                completion(connection.fileDescriptor, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
        #else
        completion(nil, NSError(domain: "VSOCKManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "VSOCK not supported"]))
        #endif
    }
    
    public func sendMockMessage(port: UInt32, message: String) {
        print("[VSOCKManager] [Mock Mode] Sending mock command to guest port \(port): \(message)")
    }
    
    public func sendGuestCommand(action: String, name: String = "", image: String = "", cmd: [String] = [], completion: @escaping @Sendable (String?, (any Error)?) -> Void) {
        #if os(macOS)
        let connection = NWConnection(host: "127.0.0.1", port: 10124, using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                let command = GuestCommand(action: action, name: name, image: image, cmd: cmd)
                guard let payload = try? GuestProtocol.encodeLine(command) else {
                    connection.cancel()
                    completion(nil, NSError(domain: "VSOCKManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to serialize JSON"]))
                    return
                }

                connection.send(content: payload, completion: .contentProcessed { error in
                    if let error = error {
                        connection.cancel()
                        completion(nil, error)
                        return
                    }

                    connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, _, err in
                        connection.cancel()
                        if let err = err {
                            completion(nil, err)
                            return
                        }
                        guard let data = data, let response = try? GuestProtocol.decode(data) else {
                            completion(nil, NSError(domain: "VSOCKManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode response"]))
                            return
                        }

                        if response.success {
                            completion(response.output, nil)
                        } else {
                            let errorMsg = response.error.isEmpty ? "Unknown guest error" : response.error
                            completion(nil, NSError(domain: "VSOCKManager", code: 3, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
                        }
                    }
                })
            case .failed(let error):
                connection.cancel()
                completion(nil, error)
            default:
                break
            }
        }
        connection.start(queue: .global())
        #else
        completion(nil, NSError(domain: "VSOCKManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Not supported on this platform"]))
        #endif
    }
    
    #if os(macOS)
    private func startMockTCPServer(onPort port: UInt16, onConnectionReceived: @escaping @Sendable (NWConnection) -> Void) {
        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("[VSOCKManager] [Mock Mode] Host TCP loop listener active on port \(port)")
                case .failed(let error):
                    print("[VSOCKManager] [Mock Mode] Host TCP listener failed: \(error.localizedDescription)")
                default:
                    break
                }
            }
            listener.newConnectionHandler = { connection in
                print("[VSOCKManager] [Mock Mode] Connection accepted from Guest Agent vminitd!")
                connection.start(queue: .global())
                onConnectionReceived(connection)
            }
            listener.start(queue: .global())
            lock.lock()
            self.mockListener = listener
            lock.unlock()
        } catch {
            print("[VSOCKManager] [Mock Mode] Error starting TCP server: \(error.localizedDescription)")
        }
    }
    #endif
}
