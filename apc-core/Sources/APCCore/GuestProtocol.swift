import Foundation

/// The wire contract between the host and the guest daemon (`guest-vminitd`).
///
/// This is the Swift owner of the exec message shape. Its Go counterpart is
/// `Command`/`Response` in `guest-vminitd/main.go` — the two must agree on field
/// names and the newline-delimited-JSON framing. Keeping the shape in one typed
/// place per side (instead of an inline `[String: Any]` dictionary) means a field
/// change is a compile-time event, not a silent string-key mismatch.
public struct GuestCommand: Codable, Equatable, Sendable {
    public var action: String   // "run", "exec", "ps"
    public var name: String
    public var image: String
    public var cmd: [String]

    public init(action: String, name: String = "", image: String = "", cmd: [String] = []) {
        self.action = action
        self.name = name
        self.image = image
        self.cmd = cmd
    }
}

/// The guest's structured reply. The guest omits empty `output`/`error` fields,
/// so both decode as "" when absent.
public struct GuestResponse: Codable, Equatable, Sendable {
    public var success: Bool
    public var output: String
    public var error: String

    public init(success: Bool, output: String = "", error: String = "") {
        self.success = success
        self.output = output
        self.error = error
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        output = try container.decodeIfPresent(String.self, forKey: .output) ?? ""
        error = try container.decodeIfPresent(String.self, forKey: .error) ?? ""
    }
}

/// Newline-delimited-JSON codec for the guest channel — the single place that
/// knows the framing. The guest reads one command per `\n`-terminated line and
/// writes one response the same way.
public enum GuestProtocol {
    public static func encodeLine(_ command: GuestCommand) throws -> Data {
        var data = try JSONEncoder().encode(command)
        data.append(0x0A) // '\n' frame terminator
        return data
    }

    public static func decode(_ data: Data) throws -> GuestResponse {
        try JSONDecoder().decode(GuestResponse.self, from: data)
    }
}
