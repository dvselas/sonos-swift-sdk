//
//  LocalTestSupport.swift
//  SonosSDKTests
//
//  In-memory WebSocket doubles for the local Control API.
//

import Foundation
import XCTest
@testable import SonosSDK

/// A fake player socket. Commands it receives are answered by `responder`;
/// tests can push events with `push(_:)`.
final class FakeTransport: SonosLocalTransport, @unchecked Sendable {

    typealias Responder = @Sendable (_ header: [String: Any], _ text: String) -> [String]

    let url: URL
    private let lock = NSLock()
    private var inbox: [String] = []
    private var waiter: CheckedContinuation<String, Error>?
    private var closed = false
    private var _sent: [String] = []
    private let responder: Responder
    private let failOpen: Bool

    init(url: URL, failOpen: Bool = false, responder: @escaping Responder) {
        self.url = url
        self.failOpen = failOpen
        self.responder = responder
    }

    var sent: [String] {
        lock.lock(); defer { lock.unlock() }
        return _sent
    }

    /// Headers of every command sent, in order.
    var sentHeaders: [[String: Any]] {
        sent.compactMap { text in
            (try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [Any])?.first as? [String: Any]
        }
    }

    var isClosed: Bool {
        lock.lock(); defer { lock.unlock() }
        return closed
    }

    func open() async throws {
        if failOpen { throw SonosLocalError.closed }
        if isClosed { throw SonosLocalError.closed }
    }

    func send(_ text: String) async throws {
        lock.lock()
        if closed { lock.unlock(); throw SonosLocalError.closed }
        _sent.append(text)
        lock.unlock()
        let header = (try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [Any])?.first as? [String: Any] ?? [:]
        for reply in responder(header, text) {
            push(reply)
        }
    }

    func receive() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if !inbox.isEmpty {
                let next = inbox.removeFirst()
                lock.unlock()
                continuation.resume(returning: next)
            } else if closed {
                lock.unlock()
                continuation.resume(throwing: SonosLocalError.closed)
            } else {
                waiter = continuation
                lock.unlock()
            }
        }
    }

    func ping() async throws {
        if isClosed { throw SonosLocalError.closed }
    }

    func push(_ text: String) {
        lock.lock()
        if let waiter {
            self.waiter = nil
            lock.unlock()
            waiter.resume(returning: text)
        } else {
            inbox.append(text)
            lock.unlock()
        }
    }

    func close() {
        lock.lock()
        closed = true
        let waiter = self.waiter
        self.waiter = nil
        lock.unlock()
        waiter?.resume(throwing: SonosLocalError.closed)
    }
}

final class FakeTransportFactory: SonosLocalTransportFactory, @unchecked Sendable {

    private let lock = NSLock()
    private var _transports: [FakeTransport] = []
    private var _trustedPlayers: [String: String] = [:]
    private let responder: FakeTransport.Responder
    private let failingHosts: Set<String>

    init(failingHosts: Set<String> = [], responder: @escaping FakeTransport.Responder = FakePlayer.respond) {
        self.responder = responder
        self.failingHosts = failingHosts
    }

    func makeTransport(url: URL, apiKey: String) -> any SonosLocalTransport {
        let transport = FakeTransport(url: url, failOpen: failingHosts.contains(url.host ?? ""), responder: responder)
        lock.lock()
        _transports.append(transport)
        lock.unlock()
        return transport
    }

    func setTrustedPlayers(_ playerIdsByHost: [String: String]) {
        lock.lock()
        _trustedPlayers = playerIdsByHost
        lock.unlock()
    }

    var transports: [FakeTransport] {
        lock.lock(); defer { lock.unlock() }
        return _transports
    }

    var trustedPlayers: [String: String] {
        lock.lock(); defer { lock.unlock() }
        return _trustedPlayers
    }

    /// The newest transport opened to `host`.
    func latest(host: String) -> FakeTransport? {
        transports.last { $0.url.host == host }
    }
}

/// Canned player behaviour: answers every command successfully.
enum FakePlayer {

    static let householdId = "Sonos_HH"

    static func respond(header: [String: Any], text: String) -> [String] {
        guard let cmdId = header["cmdId"] as? String,
              let namespace = header["namespace"] as? String,
              let command = header["command"] as? String else { return [] }
        let body: String
        switch command {
        case "getPlaybackStatus":
            body = #"{"_objectType":"playbackStatus","playbackState":"PLAYBACK_STATE_PLAYING","positionMillis":42000,"previousPositionMillis":0,"isDucking":false,"playModes":{"repeat":false,"repeatOne":false,"shuffle":false,"crossfade":false},"availablePlaybackActions":{"canSkip":true,"canSeek":true}}"#
        case "getMetadataStatus":
            body = #"{"_objectType":"metadataStatus","currentItem":{"track":{"name":"Song","durationMillis":180000}}}"#
        case "getVolume":
            body = #"{"volume":25,"muted":false,"fixed":false}"#
        case "getGroups":
            body = groupsJSON
        default:
            body = "{}"
        }
        let target = ["groupId", "playerId", "householdId"]
            .compactMap { key in (header[key] as? String).map { #""\#(key)":"\#($0)""# } }
            .joined(separator: ",")
        return [#"[{"namespace":"\#(namespace)","response":"\#(command)","cmdId":"\#(cmdId)","success":true,\#(target)},\#(body)]"#]
    }

    static var groupsJSON: String {
        #"{"groups":[{"id":"RINCON_A:1","name":"Kitchen + 1","coordinatorId":"RINCON_A","playerIds":["RINCON_A","RINCON_B"]},{"id":"RINCON_C:5","name":"Office","coordinatorId":"RINCON_C","playerIds":["RINCON_C"]}],"players":[\#(playerJSON("RINCON_A","Kitchen","10.0.0.1")),\#(playerJSON("RINCON_B","Dining","10.0.0.2")),\#(playerJSON("RINCON_C","Office","10.0.0.3"))]}"#
    }

    static func playerJSON(_ id: String, _ name: String, _ ip: String) -> String {
        #"{"id":"\#(id)","name":"\#(name)","websocketUrl":"wss://\#(ip):1443/websocket/api","softwareVersion":"80.1","apiVersion":"1.40.0","minApiVersion":"1.1.0","isUnregistered":false,"capabilities":["PLAYBACK"],"deviceIds":["\#(id)"]}"#
    }

    static var groups: [Group] {
        [
            Group(id: "RINCON_A:1", name: "Kitchen + 1", coordinatorId: "RINCON_A", playerIds: ["RINCON_A", "RINCON_B"]),
            Group(id: "RINCON_C:5", name: "Office", coordinatorId: "RINCON_C", playerIds: ["RINCON_C"])
        ]
    }

    static var players: [Player] {
        [
            Player(id: "RINCON_A", name: "Kitchen", websocketUrl: "wss://10.0.0.1:1443/websocket/api"),
            Player(id: "RINCON_B", name: "Dining", websocketUrl: "wss://10.0.0.2:1443/websocket/api"),
            Player(id: "RINCON_C", name: "Office", websocketUrl: "wss://10.0.0.3:1443/websocket/api")
        ]
    }
}

/// Collects events from a live client in the background.
final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var _events: [SonosLiveEvent] = []
    private var task: Task<Void, Never>?

    init(_ stream: AsyncStream<SonosLiveEvent>) {
        task = Task { [weak self] in
            for await event in stream {
                self?.append(event)
            }
        }
    }

    private func append(_ event: SonosLiveEvent) {
        lock.lock(); _events.append(event); lock.unlock()
    }

    var events: [SonosLiveEvent] {
        lock.lock(); defer { lock.unlock() }
        return _events
    }

    deinit { task?.cancel() }
}

func fastConfiguration() -> SonosLiveConfiguration {
    SonosLiveConfiguration(commandTimeout: 0.5, connectTimeout: 0.5, pingInterval: 30,
                           initialReconnectDelay: 0.02, maxReconnectDelay: 0.1, subscriptionRetryDelay: 0.1)
}

/// Polls `condition` until it holds or `timeout` passes.
func eventually(timeout: TimeInterval = 2, file: StaticString = #filePath, line: UInt = #line,
                _ condition: @escaping () async -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("condition not met within \(timeout)s", file: file, line: line)
}

extension FakeTransport {
    /// `namespace` values of the subscribe commands sent on this socket, with their target.
    var subscriptions: [String] {
        sentHeaders.compactMap { header in
            guard header["command"] as? String == "subscribe",
                  let namespace = header["namespace"] as? String else { return nil }
            let target = (header["groupId"] ?? header["playerId"] ?? header["householdId"]) as? String ?? "?"
            return "\(namespace)@\(target)"
        }
    }
}
