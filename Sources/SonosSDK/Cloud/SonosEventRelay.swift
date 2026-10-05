//
//  SonosEventRelay.swift
//  SonosSDK
//
//  Sonos delivers an integration's events to one HTTPS callback URL. Apps
//  that may not use the players' local API (published apps; see the Sonos
//  terms) run an event server there that passes each event on to the apps of
//  that household. This is the app's end: a WebSocket to that server.
//
//  Each message is one event:
//  {"householdId", "namespace", "type", "targetType", "targetValue", "seq", "body"}
//  where the strings come from the X-Sonos-* headers and `body` is the
//  Control API event object.
//

import Foundation

public enum SonosEventRelayMessage: Sendable {
    /// The connection is open; events arrive from now on.
    case opened
    /// One relayed event.
    case event(Data)
}

public protocol SonosEventRelaying: Sendable {
    /// Connects with the user's Sonos access token, which tells the server
    /// whose events to send, and yields messages until the connection ends.
    func connect(token: String) -> AsyncThrowingStream<SonosEventRelayMessage, Error>
}

/// The relay over `URLSessionWebSocketTask`. The token goes in the
/// `Authorization` header of the handshake.
public final class SonosWebSocketEventRelay: SonosEventRelaying, @unchecked Sendable {

    private let url: URL
    private let keepAliveInterval: TimeInterval
    private let session: URLSession

    /// - Parameter keepAliveInterval: Seconds between keep-alive messages; API Gateway
    ///   closes WebSockets that stay idle for 10 minutes.
    public init(url: URL, keepAliveInterval: TimeInterval = 300, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.url = url
        self.keepAliveInterval = keepAliveInterval
        self.session = session
    }

    public func connect(token: String) -> AsyncThrowingStream<SonosEventRelayMessage, Error> {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let task = session.webSocketTask(with: request)
        let keepAliveInterval = self.keepAliveInterval

        return AsyncThrowingStream { continuation in
            let worker = Task {
                task.resume()
                do {
                    // The first pong confirms the handshake (a refused token fails it).
                    try await withCheckedThrowingContinuation { (pong: CheckedContinuation<Void, Error>) in
                        task.sendPing { error in
                            if let error { pong.resume(throwing: error) } else { pong.resume() }
                        }
                    }
                    continuation.yield(.opened)
                    let keepAlive = Task {
                        while !Task.isCancelled {
                            try? await Task.sleep(nanoseconds: UInt64(keepAliveInterval * 1_000_000_000))
                            guard !Task.isCancelled else { return }
                            try? await task.send(.string(#"{"action":"ping"}"#))
                        }
                    }
                    defer { keepAlive.cancel() }
                    while !Task.isCancelled {
                        switch try await task.receive() {
                        case .string(let text): continuation.yield(.event(Data(text.utf8)))
                        case .data(let data): continuation.yield(.event(data))
                        @unknown default: break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                worker.cancel()
                task.cancel(with: .goingAway, reason: nil)
            }
        }
    }
}

/// One relayed event; `body` stays raw until its type is known.
struct SonosRelayedEvent {
    let householdId: String
    let namespace: String
    let type: String
    let targetType: String
    let targetValue: String
    let seq: Int
    let body: Data

    init?(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let householdId = object["householdId"] as? String,
              let type = object["type"] as? String,
              let targetValue = object["targetValue"] as? String else { return nil }
        self.householdId = householdId
        self.namespace = object["namespace"] as? String ?? ""
        self.type = type
        self.targetType = object["targetType"] as? String ?? ""
        self.targetValue = targetValue
        self.seq = (object["seq"] as? NSNumber)?.intValue ?? 0
        let body = object["body"] ?? NSNull()
        self.body = (try? JSONSerialization.data(withJSONObject: body, options: [.fragmentsAllowed])) ?? Data("null".utf8)
    }

    func decodeBody<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(T.self, from: body)
    }
}
