//
//  SonosLocalProtocol.swift
//  SonosSDK
//
//  Wire format of the Sonos Control API over a player's local WebSocket
//  (`wss://<player-ip>:1443/websocket/api`).
//
//  Every message is a two-element JSON array: `[header, body]`.
//  - Commands:  header = {namespace: "playback:1", command, cmdId, groupId|playerId|householdId}
//  - Replies:   header = {namespace, response, cmdId, success, type, householdId, …}
//               failures carry `errorCode` (and `reason`) in the body
//  - Events:    header = {namespace, type, groupId|playerId|householdId, …}, no cmdId
//  Bodies are the same objects the cloud Control API returns.
//

import Foundation

/// Constants of the local Control API.
public enum SonosLocalAPI {
    /// WebSocket sub-protocol the players require.
    public static let subprotocol = "v1.api.smartspeaker.audio"
    /// Handshake header carrying the integration's API key.
    public static let apiKeyHeader = "X-Sonos-Api-Key"
    /// Port of the local API on every player.
    public static let port = 1443
    /// Namespace version suffix appended to every command (`playback:1`).
    static let namespaceVersion = 1
}

/// The id a namespace command is addressed to.
public enum SonosLocalTarget: Hashable, Sendable {
    case household(String)
    case group(String)
    case player(String)

    var headerKey: String {
        switch self {
        case .household: return "householdId"
        case .group: return "groupId"
        case .player: return "playerId"
        }
    }

    var id: String {
        switch self {
        case .household(let id), .group(let id), .player(let id):
            return id
        }
    }
}

/// Errors of the local transport. `notConnected` and `noRoute` mean the
/// command was never sent, so callers may safely retry it over the cloud.
public enum SonosLocalError: LocalizedError, Sendable, Equatable {
    case notConnected
    case noRoute(String)
    case timeout
    case commandFailed(errorCode: String, reason: String?)
    case invalidFrame
    case closed

    /// True when the command never reached a player.
    public var isRoutable: Bool {
        switch self {
        case .notConnected, .noRoute: return true
        default: return false
        }
    }

    public var errorDescription: String? {
        switch self {
        case .notConnected: return "Not connected to the Sonos player on the local network."
        case .noRoute(let target): return "No local connection can reach \(target)."
        case .timeout: return "The Sonos player did not answer in time."
        case .commandFailed(let code, let reason): return "Sonos player rejected the command [\(code)]: \(reason ?? "no reason given")"
        case .invalidFrame: return "Received an unreadable message from the Sonos player."
        case .closed: return "The local Sonos connection was closed."
        }
    }
}

/// A command ready to be framed.
struct SonosLocalCommand: Sendable {
    let namespace: String
    let command: String
    let target: SonosLocalTarget
    let householdId: String?
    let body: (any Encodable & Sendable)?

    init(namespace: String, command: String, target: SonosLocalTarget, householdId: String? = nil, body: (any Encodable & Sendable)? = nil) {
        self.namespace = namespace
        self.command = command
        self.target = target
        self.householdId = householdId
        self.body = body
    }

    var description: String { "\(namespace).\(command)(\(target.id))" }
}

/// Header of an inbound message. All fields are optional on the wire.
struct SonosLocalHeader: Decodable, Sendable, Equatable {
    let namespace: String?
    let type: String?
    let response: String?
    let cmdId: String?
    let success: Bool?
    let householdId: String?
    let groupId: String?
    let playerId: String?
    let sessionId: String?

    init(namespace: String? = nil, type: String? = nil, response: String? = nil, cmdId: String? = nil,
         success: Bool? = nil, householdId: String? = nil, groupId: String? = nil,
         playerId: String? = nil, sessionId: String? = nil) {
        self.namespace = namespace
        self.type = type
        self.response = response
        self.cmdId = cmdId
        self.success = success
        self.householdId = householdId
        self.groupId = groupId
        self.playerId = playerId
        self.sessionId = sessionId
    }

    enum CodingKeys: String, CodingKey {
        case namespace, type, response, cmdId, success, householdId, groupId, playerId, sessionId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func string(_ key: CodingKeys) -> String? { try? c.decodeIfPresent(String.self, forKey: key) }
        // Players report `playback:1`; the version suffix carries no information for us.
        namespace = string(.namespace).map(SonosLocalFrameCodec.stripVersion)
        type = string(.type)
        response = string(.response)
        cmdId = string(.cmdId)
        success = try? c.decodeIfPresent(Bool.self, forKey: .success)
        householdId = string(.householdId)
        groupId = string(.groupId)
        playerId = string(.playerId)
        sessionId = string(.sessionId)
    }
}

/// A classified inbound message. `frame` is the raw message; decode its body
/// with `SonosLocalFrameCodec.decodeBody(_:from:)`.
enum SonosLocalInbound: Sendable {
    case reply(cmdId: String, result: Result<Data, SonosLocalError>)
    case event(SonosLocalHeader, frame: Data)
    case ignored
}

enum SonosLocalFrameCodec {

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    // MARK: Encoding

    static func encode(_ command: SonosLocalCommand, cmdId: String) throws -> String {
        var header: [String: String] = [
            "namespace": "\(command.namespace):\(SonosLocalAPI.namespaceVersion)",
            "command": command.command,
            "cmdId": cmdId,
            command.target.headerKey: command.target.id
        ]
        if let householdId = command.householdId, header["householdId"] == nil {
            header["householdId"] = householdId
        }
        let frame = OutboundFrame(header: header, body: command.body)
        let data = try encoder.encode(frame)
        return String(decoding: data, as: UTF8.self)
    }

    private struct OutboundFrame: Encodable {
        let header: [String: String]
        let body: (any Encodable)?

        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(header)
            if let body {
                try container.encode(AnyEncodable(body))
            } else {
                try container.encode([String: String]())
            }
        }
    }

    // MARK: Decoding

    static func stripVersion(_ namespace: String) -> String {
        guard let colon = namespace.firstIndex(of: ":") else { return namespace }
        return String(namespace[..<colon])
    }

    /// Classifies a raw message as a command reply, an event, or noise.
    static func classify(_ text: String) throws -> SonosLocalInbound {
        let frame = Data(text.utf8)
        let header: SonosLocalHeader
        do {
            header = try JSONDecoder().decode(HeaderFrame.self, from: frame).header
        } catch {
            throw SonosLocalError.invalidFrame
        }

        if let cmdId = header.cmdId {
            if let failure = errorBody(in: frame), header.success != true {
                return .reply(cmdId: cmdId, result: .failure(.commandFailed(errorCode: failure.errorCode, reason: failure.reason)))
            }
            if header.success == false {
                return .reply(cmdId: cmdId, result: .failure(.commandFailed(errorCode: header.type ?? "ERROR_COMMAND_FAILED", reason: nil)))
            }
            return .reply(cmdId: cmdId, result: .success(frame))
        }

        if header.type != nil {
            return .event(header, frame: frame)
        }
        return .ignored
    }

    /// Decodes the body (second element) of a raw message.
    static func decodeBody<T: Decodable>(_ type: T.Type, from frame: Data) throws -> T {
        try JSONDecoder().decode(BodyFrame<T>.self, from: frame).body
    }

    /// The body of a raw message re-serialised on its own.
    static func bodyData(from frame: Data) throws -> Data {
        guard let array = try JSONSerialization.jsonObject(with: frame) as? [Any] else {
            throw SonosLocalError.invalidFrame
        }
        let body = array.count > 1 ? array[1] : [String: Any]()
        return try JSONSerialization.data(withJSONObject: body)
    }

    struct ErrorBody: Decodable, Sendable {
        let errorCode: String
        let reason: String?
    }

    static func errorBody(in frame: Data) -> ErrorBody? {
        try? decodeBody(ErrorBody.self, from: frame)
    }

    private struct HeaderFrame: Decodable {
        let header: SonosLocalHeader

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            header = try container.decode(SonosLocalHeader.self)
        }
    }

    private struct BodyFrame<T: Decodable>: Decodable {
        let body: T

        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            _ = try container.decode(Skip.self)
            body = try container.decode(T.self)
        }
    }

    /// Consumes any JSON value without keeping it.
    private struct Skip: Decodable {
        init(from decoder: Decoder) throws {}
    }
}
