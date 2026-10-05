//
//  SonosCloudLiveClientTests.swift
//  SonosSDKTests
//
//  Live updates through the cloud: the state is read over the Control API,
//  events arrive from the app's event server. Household: Kitchen (A)
//  coordinates a group with Dining (B); Office (C) plays alone.
//

import Foundation
import XCTest
@testable import SonosSDK

/// Answers cloud reads with a fixed household and records every call.
final class FakeCloud: HTTPClientProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _endpoints: [String] = []

    var endpoints: [String] {
        lock.lock(); defer { lock.unlock() }
        return _endpoints
    }

    /// Calls whose description starts with `prefix`.
    func calls(_ prefix: String) -> [String] {
        endpoints.filter { $0.hasPrefix(prefix) }
    }

    private func record(_ endpoint: SonosAPIEndpoint) {
        lock.lock(); _endpoints.append(String(describing: endpoint)); lock.unlock()
    }

    private func body(for endpoint: SonosAPIEndpoint) -> String {
        switch endpoint {
        case .getGroups:
            return #"""
            {"groups":[{"id":"RINCON_A:1","name":"Kitchen + 1","coordinatorId":"RINCON_A","playerIds":["RINCON_A","RINCON_B"]},
                       {"id":"RINCON_C:5","name":"Office","coordinatorId":"RINCON_C","playerIds":["RINCON_C"]}],
             "players":[{"id":"RINCON_A","name":"Kitchen"},{"id":"RINCON_B","name":"Dining"},{"id":"RINCON_C","name":"Office"}]}
            """#
        case .getPlaybackStatus:
            return #"{"playbackState":"PLAYBACK_STATE_PLAYING","positionMillis":1000}"#
        case .getMetadataStatus:
            return #"{"container":{"name":"Radio"}}"#
        case .getGroupVolume, .getPlayerVolume:
            return #"{"volume":20,"muted":false,"fixed":false}"#
        default:
            return "{}"
        }
    }

    func request<T: Decodable>(_ endpoint: SonosAPIEndpoint) async throws -> T {
        record(endpoint)
        return try JSONDecoder().decode(T.self, from: Data(body(for: endpoint).utf8))
    }

    func request(_ endpoint: SonosAPIEndpoint) async throws {
        record(endpoint)
    }

    func requestData(_ endpoint: SonosAPIEndpoint) async throws -> Data {
        record(endpoint)
        return Data(body(for: endpoint).utf8)
    }
}

/// An event server the test drives: each `connect` opens a new connection.
final class FakeRelay: SonosEventRelaying, @unchecked Sendable {
    private let lock = NSLock()
    private var connections: [AsyncThrowingStream<SonosEventRelayMessage, Error>.Continuation] = []
    private var _tokens: [String] = []

    var tokens: [String] {
        lock.lock(); defer { lock.unlock() }
        return _tokens
    }

    var connectionCount: Int {
        lock.lock(); defer { lock.unlock() }
        return connections.count
    }

    func connect(token: String) -> AsyncThrowingStream<SonosEventRelayMessage, Error> {
        let (stream, continuation) = AsyncThrowingStream.makeStream(of: SonosEventRelayMessage.self)
        lock.lock()
        connections.append(continuation)
        _tokens.append(token)
        lock.unlock()
        return stream
    }

    private var latest: AsyncThrowingStream<SonosEventRelayMessage, Error>.Continuation? {
        lock.lock(); defer { lock.unlock() }
        return connections.last
    }

    func open() { latest?.yield(.opened) }

    func send(type: String, target: String, seq: Int = 0, household: String = "Sonos_HH", body: String) {
        let message = """
        {"householdId":"\(household)","namespace":"x","type":"\(type)","targetType":"groupId",
         "targetValue":"\(target)","seq":\(seq),"body":\(body)}
        """
        latest?.yield(.event(Data(message.utf8)))
    }

    func drop() { latest?.finish(throwing: URLError(.networkConnectionLost)) }
}

final class SonosCloudLiveClientTests: XCTestCase {

    private func makeClient(focus: Set<String>?) -> (SonosCloudLiveClient, FakeCloud, FakeRelay, EventRecorder) {
        let cloud = FakeCloud()
        let relay = FakeRelay()
        var configuration = fastConfiguration()
        configuration.focusPlayerIds = focus
        let client = SonosCloudLiveClient(householdId: "Sonos_HH", cloud: cloud, relay: relay,
                                          token: { "token-1" }, configuration: configuration)
        return (client, cloud, relay, EventRecorder(client.events))
    }

    private func connected(_ recorder: EventRecorder) -> Set<String> {
        var states: [String: Bool] = [:]
        for case .connection(let playerId, let state) in recorder.events {
            states[playerId] = state.isConnected
        }
        return Set(states.filter(\.value).keys)
    }

    func testOnlyTheFocusIsSubscribedAndRead() async {
        let (client, cloud, relay, recorder) = makeClient(focus: ["RINCON_B"])
        await client.start(groups: [], players: [])
        await eventually { relay.connectionCount == 1 }
        XCTAssertEqual(relay.tokens, ["token-1"], "the app's Sonos token opens the connection")

        relay.open()
        await eventually { cloud.calls("subscribeToPlayerVolume").count == 1 }

        XCTAssertEqual(cloud.calls("subscribeToGroups").count, 1)
        XCTAssertEqual(cloud.calls("subscribeToPlayback("), [#"subscribeToPlayback(groupId: "RINCON_A:1")"#],
                       "Dining's group, not Office")
        XCTAssertEqual(cloud.calls("subscribeToPlayerVolume"), [#"subscribeToPlayerVolume(playerId: "RINCON_B")"#])
        XCTAssertEqual(cloud.calls("getPlaybackStatus"), [#"getPlaybackStatus(groupId: "RINCON_A:1")"#])
        await eventually { self.connected(recorder) == ["RINCON_A", "RINCON_B"] }
        XCTAssertTrue(recorder.events.contains {
            if case .playbackStatus(let groupId, _) = $0 { return groupId == "RINCON_A:1" }
            return false
        })
        await client.stop()
    }

    func testRelayedEventsReachTheApp() async {
        let (client, _, relay, recorder) = makeClient(focus: nil)
        await client.start(groups: [], players: [])
        await eventually { relay.connectionCount == 1 }
        relay.open()

        relay.send(type: "groupVolume", target: "RINCON_C:5", seq: 7, body: #"{"volume":33,"muted":false,"fixed":false}"#)
        relay.send(type: "groupVolume", target: "RINCON_C:5", seq: 6, body: #"{"volume":11,"muted":false,"fixed":false}"#)
        relay.send(type: "groupVolume", target: "RINCON_C:5", household: "Sonos_OTHER",
                   body: #"{"volume":99,"muted":false,"fixed":false}"#)
        relay.send(type: "playbackError", target: "RINCON_C:5", body: #"{"errorCode":"ERROR_PLAYBACK_FAILED"}"#)

        await eventually {
            recorder.events.contains { if case .playbackError = $0 { return true }; return false }
        }
        let volumes = recorder.events.compactMap { event -> Int? in
            if case .groupVolume("RINCON_C:5", let volume) = event { return volume.volume }
            return nil
        }
        XCTAssertTrue(volumes.contains(33))
        XCTAssertFalse(volumes.contains(11), "a late event is dropped")
        XCTAssertFalse(volumes.contains(99), "another household's event is ignored")
        await client.stop()
    }

    func testAGroupsEventFollowsTheNewGroup() async {
        let (client, cloud, relay, _) = makeClient(focus: ["RINCON_B"])
        await client.start(groups: [], players: [])
        await eventually { relay.connectionCount == 1 }
        relay.open()
        await eventually { cloud.calls("subscribeToPlayback(").count == 1 }

        // Dining leaves the group and plays on its own.
        relay.send(type: "groups", target: "Sonos_HH", body: #"""
        {"groups":[{"id":"RINCON_A:1","name":"Kitchen","coordinatorId":"RINCON_A","playerIds":["RINCON_A"]},
                   {"id":"RINCON_B:9","name":"Dining","coordinatorId":"RINCON_B","playerIds":["RINCON_B"]}],
         "players":[{"id":"RINCON_A","name":"Kitchen"},{"id":"RINCON_B","name":"Dining"}]}
        """#)

        await eventually { cloud.calls(#"subscribeToPlayback(groupId: "RINCON_B:9")"#).count == 1 }
        XCTAssertEqual(cloud.calls(#"getPlaybackStatus(groupId: "RINCON_B:9")"#).count, 1)
        await client.stop()
    }

    func testReconnectingSubscribesAndReadsAgain() async {
        let (client, cloud, relay, recorder) = makeClient(focus: ["RINCON_C"])
        await client.start(groups: [], players: [])
        await eventually { relay.connectionCount == 1 }
        relay.open()
        await eventually { cloud.calls("subscribeToPlayback(").count == 1 }

        relay.drop()
        await eventually { self.connected(recorder).isEmpty }
        await eventually { relay.connectionCount == 2 }
        relay.open()

        await eventually { cloud.calls("subscribeToPlayback(").count == 2 }
        await eventually { self.connected(recorder) == ["RINCON_C"] }
        await client.stop()
    }

    func testSuspendClosesAndResumeReconnects() async {
        let (client, _, relay, recorder) = makeClient(focus: ["RINCON_C"])
        await client.start(groups: [], players: [])
        await eventually { relay.connectionCount == 1 }
        relay.open()
        await eventually { self.connected(recorder) == ["RINCON_C"] }

        await client.suspend()
        await eventually {
            recorder.events.contains {
                if case .connection("RINCON_C", .suspended) = $0 { return true }
                return false
            }
        }
        await client.resume()
        await eventually { relay.connectionCount == 2 }
        await client.stop()
    }
}
