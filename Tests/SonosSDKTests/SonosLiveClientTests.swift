//
//  SonosLiveClientTests.swift
//  SonosSDKTests
//

import XCTest
@testable import SonosSDK

final class SonosLocalConnectionTests: XCTestCase {

    private let url = URL(string: "wss://10.0.0.1:1443/websocket/api")!

    func testSendBeforeConnectingThrowsNotConnected() async {
        let connection = SonosLocalConnection(playerId: "P", url: url, apiKey: "k",
                                              factory: FakeTransportFactory(), configuration: fastConfiguration())
        do {
            _ = try await connection.send(SonosLocalCommand(namespace: "playback", command: "play", target: .group("P:1")))
            XCTFail("expected notConnected")
        } catch {
            XCTAssertEqual(error as? SonosLocalError, .notConnected)
        }
    }

    func testRepliesAreMatchedByCommandId() async throws {
        let connection = SonosLocalConnection(playerId: "P", url: url, apiKey: "k",
                                              factory: FakeTransportFactory(), configuration: fastConfiguration())
        await connection.start()
        await eventually { await connection.state.isConnected }

        let frame = try await connection.send(SonosLocalCommand(namespace: "groupVolume", command: "getVolume", target: .group("P:1")))
        XCTAssertEqual(try SonosLocalFrameCodec.decodeBody(GroupVolume.self, from: frame).volume, 25)
        await connection.stop(finish: true)
    }

    func testUnansweredCommandTimesOut() async {
        let factory = FakeTransportFactory(responder: { _, _ in [] })
        let connection = SonosLocalConnection(playerId: "P", url: url, apiKey: "k", factory: factory, configuration: fastConfiguration())
        await connection.start()
        await eventually { await connection.state.isConnected }
        do {
            _ = try await connection.send(SonosLocalCommand(namespace: "playback", command: "play", target: .group("P:1")))
            XCTFail("expected timeout")
        } catch {
            XCTAssertEqual(error as? SonosLocalError, .timeout)
        }
        await connection.stop(finish: true)
    }

    func testReconnectsAfterSocketDrops() async {
        let factory = FakeTransportFactory()
        let connection = SonosLocalConnection(playerId: "P", url: url, apiKey: "k", factory: factory, configuration: fastConfiguration())
        await connection.start()
        await eventually { await connection.state.isConnected }

        factory.transports.first?.close()
        await eventually { factory.transports.count >= 2 }
        await eventually { await connection.state.isConnected }
        await connection.stop(finish: true)
    }

    func testReconnectDelayGrowsAndIsCapped() async {
        let connection = SonosLocalConnection(playerId: "P", url: url, apiKey: "k", factory: FakeTransportFactory(),
                                              configuration: SonosLiveConfiguration(initialReconnectDelay: 1, maxReconnectDelay: 60))
        let first = await connection.reconnectDelay(forAttempt: 1)
        let fourth = await connection.reconnectDelay(forAttempt: 4)
        let late = await connection.reconnectDelay(forAttempt: 20)
        XCTAssert((0.8...1.2).contains(first))
        XCTAssert((6.4...9.6).contains(fourth))
        XCTAssert((48...72).contains(late))
    }
}

final class SonosLiveClientTests: XCTestCase {

    private func makeClient(factory: FakeTransportFactory = FakeTransportFactory()) -> (SonosLiveClient, FakeTransportFactory) {
        let client = SonosLiveClient(householdId: FakePlayer.householdId, apiKey: "key",
                                     configuration: fastConfiguration(), factory: factory)
        return (client, factory)
    }

    func testSubscriptionsArePlacedOnTheOwningSockets() async {
        let (client, factory) = makeClient()
        await client.start(groups: FakePlayer.groups, players: FakePlayer.players)

        let hosts = ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
        func subscriptions(_ host: String) -> Set<String> {
            Set(factory.latest(host: host)?.subscriptions ?? []).subtracting(["groups:1@Sonos_HH"])
        }
        await eventually { subscriptions("10.0.0.1").count == 4 && subscriptions("10.0.0.3").count == 4 }
        await eventually { hosts.filter { factory.latest(host: $0)?.subscriptions.contains("groups:1@Sonos_HH") ?? false }.count == 1 }

        XCTAssertEqual(subscriptions("10.0.0.1"), ["playback:1@RINCON_A:1", "playbackMetadata:1@RINCON_A:1",
                                                   "groupVolume:1@RINCON_A:1", "playerVolume:1@RINCON_A"])
        XCTAssertEqual(subscriptions("10.0.0.2"), ["playerVolume:1@RINCON_B"])
        XCTAssertEqual(subscriptions("10.0.0.3"), ["playback:1@RINCON_C:5", "playbackMetadata:1@RINCON_C:5",
                                                   "groupVolume:1@RINCON_C:5", "playerVolume:1@RINCON_C"])
        XCTAssertEqual(factory.trustedHosts, ["10.0.0.1", "10.0.0.2", "10.0.0.3"])
        await client.stop()
    }

    func testSnapshotsAndPushedEventsAreEmitted() async {
        let (client, factory) = makeClient()
        let recorder = EventRecorder(client.events)
        await client.start(groups: FakePlayer.groups, players: FakePlayer.players)

        await eventually {
            recorder.events.contains { if case .playbackStatus("RINCON_C:5", let s) = $0 { return s.positionMillis == 42000 }; return false }
        }
        await eventually {
            recorder.events.contains { if case .metadataStatus("RINCON_A:1", let m) = $0 { return m.currentItem?.track?.durationMillis == 180000 }; return false }
        }

        factory.latest(host: "10.0.0.3")?.push(#"[{"namespace":"playback:1","type":"playbackStatus","groupId":"RINCON_C:5","householdId":"Sonos_HH"},{"playbackState":"PLAYBACK_STATE_PAUSED","positionMillis":50000}]"#)
        factory.latest(host: "10.0.0.2")?.push(#"[{"namespace":"playerVolume:1","type":"playerVolume","playerId":"RINCON_B","householdId":"Sonos_HH"},{"volume":61,"muted":false,"fixed":false}]"#)

        await eventually {
            recorder.events.contains { if case .playbackStatus("RINCON_C:5", let s) = $0 { return s.playbackState == "PLAYBACK_STATE_PAUSED" }; return false }
        }
        await eventually {
            recorder.events.contains { if case .playerVolume("RINCON_B", let v) = $0 { return v.volume == 61 }; return false }
        }
        await client.stop()
    }

    func testCommandsAreRoutedToTheCoordinator() async throws {
        let (client, factory) = makeClient()
        await client.start(groups: FakePlayer.groups, players: FakePlayer.players)
        await eventually { await client.isLive(groupId: "RINCON_C:5") }
        await eventually { await client.isLive(playerId: "RINCON_B") }

        _ = try await client.perform(.togglePlayPause(groupId: "RINCON_C:5"))
        _ = try await client.perform(.setPlayerVolume(playerId: "RINCON_B", volume: 30))

        XCTAssertTrue(factory.latest(host: "10.0.0.3")?.sentHeaders.contains { $0["command"] as? String == "togglePlayPause" } ?? false)
        XCTAssertTrue(factory.latest(host: "10.0.0.2")?.sentHeaders.contains { $0["command"] as? String == "setVolume" } ?? false)
        XCTAssertFalse(factory.latest(host: "10.0.0.1")?.sentHeaders.contains { $0["command"] as? String == "togglePlayPause" } ?? true)
        await client.stop()
    }

    func testUnreachableCoordinatorIsNotLiveAndNotRoutable() async {
        let (client, _) = makeClient(factory: FakeTransportFactory(failingHosts: ["10.0.0.3"]))
        await client.start(groups: FakePlayer.groups, players: FakePlayer.players)
        await eventually { await client.isLive(groupId: "RINCON_A:1") }

        let isLive = await client.isLive(groupId: "RINCON_C:5")
        XCTAssertFalse(isLive)
        do {
            _ = try await client.perform(.play(groupId: "RINCON_C:5"))
            XCTFail("expected notConnected")
        } catch {
            XCTAssertEqual(error as? SonosLocalError, .notConnected)
        }
        await client.stop()
    }

    func testRegroupMovesSubscriptionsToTheNewCoordinator() async {
        let (client, factory) = makeClient()
        await client.start(groups: FakePlayer.groups, players: FakePlayer.players)
        await eventually { factory.latest(host: "10.0.0.1")?.subscriptions.contains("groupVolume:1@RINCON_A:1") ?? false }

        // Dining (B) leaves the kitchen group and becomes its own group.
        let groupsEvent = #"[{"namespace":"groups:1","type":"groups","householdId":"Sonos_HH"},{"groups":[{"id":"RINCON_A:2","name":"Kitchen","coordinatorId":"RINCON_A","playerIds":["RINCON_A"]},{"id":"RINCON_B:1","name":"Dining","coordinatorId":"RINCON_B","playerIds":["RINCON_B"]},{"id":"RINCON_C:5","name":"Office","coordinatorId":"RINCON_C","playerIds":["RINCON_C"]}],"players":[\#(FakePlayer.playerJSON("RINCON_A","Kitchen","10.0.0.1")),\#(FakePlayer.playerJSON("RINCON_B","Dining","10.0.0.2")),\#(FakePlayer.playerJSON("RINCON_C","Office","10.0.0.3"))]}]"#
        factory.latest(host: "10.0.0.1")?.push(groupsEvent)

        await eventually { factory.latest(host: "10.0.0.2")?.subscriptions.contains("playback:1@RINCON_B:1") ?? false }
        await eventually { factory.latest(host: "10.0.0.1")?.subscriptions.contains("playback:1@RINCON_A:2") ?? false }
        await eventually {
            factory.latest(host: "10.0.0.1")?.sentHeaders.contains {
                $0["command"] as? String == "unsubscribe" && $0["groupId"] as? String == "RINCON_A:1"
            } ?? false
        }
        let desiredB = await client.desiredSubscriptions(for: "RINCON_B")
        XCTAssertTrue(desiredB.contains(.groupVolume("RINCON_B:1")))
        await client.stop()
    }

    func testResubscribesAfterReconnect() async {
        let (client, factory) = makeClient()
        await client.start(groups: FakePlayer.groups, players: FakePlayer.players)
        await eventually { factory.latest(host: "10.0.0.3")?.subscriptions.contains("groupVolume:1@RINCON_C:5") ?? false }

        let first = factory.latest(host: "10.0.0.3")
        first?.close()
        await eventually { factory.latest(host: "10.0.0.3") !== first }
        await eventually { factory.latest(host: "10.0.0.3")?.subscriptions.contains("groupVolume:1@RINCON_C:5") ?? false }
        await eventually { factory.latest(host: "10.0.0.3")?.subscriptions.contains("playback:1@RINCON_C:5") ?? false }
        await client.stop()
    }

    func testSuspendClosesSocketsAndResumeReconnects() async {
        let (client, factory) = makeClient()
        await client.start(groups: FakePlayer.groups, players: FakePlayer.players)
        await eventually { await client.isLive(playerId: "RINCON_A") }

        await client.suspend()
        XCTAssertTrue(factory.transports.allSatisfy { $0.isClosed })
        await eventually { await client.connectionStates()["RINCON_A"] == .suspended }
        let isLiveWhileSuspended = await client.isLive(playerId: "RINCON_A")
        XCTAssertFalse(isLiveWhileSuspended)

        await client.resume()
        await eventually { await client.isLive(playerId: "RINCON_A") }
        await client.stop()
    }
}

final class SonosRoutingHTTPClientTests: XCTestCase {

    final class CloudSpy: HTTPClientProtocol, @unchecked Sendable {
        private let lock = NSLock()
        private var _calls: [String] = []
        var calls: [String] { lock.lock(); defer { lock.unlock() }; return _calls }

        private func record(_ endpoint: SonosAPIEndpoint) {
            lock.lock(); _calls.append("\(endpoint)"); lock.unlock()
        }

        func request<T: Decodable>(_ endpoint: SonosAPIEndpoint) async throws -> T {
            record(endpoint)
            return try JSONDecoder().decode(T.self, from: Data(#"{"volume":1,"muted":false,"fixed":false}"#.utf8))
        }

        func request(_ endpoint: SonosAPIEndpoint) async throws { record(endpoint) }

        func requestData(_ endpoint: SonosAPIEndpoint) async throws -> Data {
            record(endpoint)
            return Data()
        }
    }

    func testFallsBackToCloudWithoutLiveClient() async throws {
        let cloud = CloudSpy()
        let routing = SonosRoutingHTTPClient(cloud: cloud, router: SonosLiveRouter())
        try await routing.request(.play(groupId: "RINCON_A:1"))
        XCTAssertEqual(cloud.calls.count, 1)
    }

    func testUsesLocalSocketWhenLive() async throws {
        let cloud = CloudSpy()
        let router = SonosLiveRouter()
        let factory = FakeTransportFactory()
        let client = SonosLiveClient(householdId: FakePlayer.householdId, apiKey: "k", configuration: fastConfiguration(), factory: factory)
        _ = router.replace(with: client)
        await client.start(groups: FakePlayer.groups, players: FakePlayer.players)
        await eventually { await client.isLive(groupId: "RINCON_A:1") }

        let routing = SonosRoutingHTTPClient(cloud: cloud, router: router)
        let volume: GroupVolume = try await routing.request(.getGroupVolume(groupId: "RINCON_A:1"))
        try await routing.request(.getFavorites(householdId: FakePlayer.householdId))

        XCTAssertEqual(volume.volume, 25, "answered by the player")
        XCTAssertEqual(cloud.calls.count, 1, "only the cloud-only endpoint reached the cloud")
        XCTAssertTrue(cloud.calls.first?.contains("getFavorites") ?? false)
        await client.stop()
    }

    func testPlayerErrorsAreNotRetriedOverTheCloud() async throws {
        let cloud = CloudSpy()
        let router = SonosLiveRouter()
        let factory = FakeTransportFactory(responder: { header, text in
            if header["command"] as? String == "setVolume", let cmdId = header["cmdId"] as? String {
                return [#"[{"cmdId":"\#(cmdId)","success":false},{"errorCode":"ERROR_DISALLOWED_BY_POLICY","reason":"fixed volume"}]"#]
            }
            return FakePlayer.respond(header: header, text: text)
        })
        let client = SonosLiveClient(householdId: FakePlayer.householdId, apiKey: "k", configuration: fastConfiguration(), factory: factory)
        _ = router.replace(with: client)
        await client.start(groups: FakePlayer.groups, players: FakePlayer.players)
        await eventually { await client.isLive(playerId: "RINCON_B") }

        let routing = SonosRoutingHTTPClient(cloud: cloud, router: router)
        do {
            try await routing.request(.setPlayerVolume(playerId: "RINCON_B", volume: 40))
            XCTFail("expected the player's error")
        } catch SonosError.apiError(let code, _) {
            XCTAssertEqual(code, "ERROR_DISALLOWED_BY_POLICY")
        }
        XCTAssertTrue(cloud.calls.isEmpty)
        await client.stop()
    }
}
