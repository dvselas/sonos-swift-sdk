//
//  SonosLocalHTTPClientTests.swift
//  SonosSDKTests
//
//  Local-only mode: players found over Bonjour answer the Control API on
//  their local REST API, each call on the right player.
//

import Foundation
import XCTest
@testable import SonosSDK

final class FakeDiscovery: SonosPlayerDiscovering, @unchecked Sendable {
    var found: [SonosDiscoveredPlayer]

    init(_ found: [SonosDiscoveredPlayer]) {
        self.found = found
    }

    func players(waitingUpTo timeout: Duration) async -> [SonosDiscoveredPlayer] {
        found
    }
}

final class SonosLocalHTTPClientTests: XCTestCase {

    private let household = "Sonos_abc.def"
    private let kids = SonosDiscoveredPlayer(id: "RINCON_000000000001", name: "Kids", host: "10.0.0.1", householdTag: "Sonos_abc")
    private let dining = SonosDiscoveredPlayer(id: "RINCON_000000000002", name: "Dining", host: "10.0.0.2", householdTag: "Sonos_abc")
    private let neighbor = SonosDiscoveredPlayer(id: "RINCON_000000000009", name: "Other", host: "10.0.0.9", householdTag: "Sonos_xyz")

    private func client(_ players: [SonosDiscoveredPlayer]) -> SonosLocalHTTPClient {
        SonosLocalHTTPClient(apiKey: "key-1", discovery: FakeDiscovery(players), protocolClasses: [StubURLProtocol.self])
    }

    // MARK: Discovery

    func testBonjourAnnouncementNamesThePlayerAndItsAddress() throws {
        let player = try XCTUnwrap(SonosDiscoveredPlayer(
            instanceName: "RINCON_000000000001@Kids Room",
            txt: ["uuid": "RINCON_000000000001", "hhid": "Sonos_abc",
                  "location": "http://10.0.0.1:1400/xml/device_description.xml"]))

        XCTAssertEqual(player, SonosDiscoveredPlayer(id: "RINCON_000000000001", name: "Kids Room", host: "10.0.0.1",
                                                     householdTag: "Sonos_abc"))
        XCTAssertTrue(player.belongs(to: "Sonos_abc.def"))
        XCTAssertFalse(player.belongs(to: "Sonos_abcd.ef"))
        XCTAssertNil(SonosDiscoveredPlayer(instanceName: "Printer@Office", txt: [:]))
    }

    // MARK: Routing

    func testHouseholdsAreAskedOfOnePlayerPerHousehold() async throws {
        StubURLProtocol.reset([.init(body: #"{"householdId":"Sonos_abc.def","playerId":"RINCON_000000000001"}"#),
                               .init(body: #"{"householdId":"Sonos_xyz.uvw","playerId":"RINCON_000000000009"}"#)])

        let response: HouseholdsResponse = try await client([kids, dining, neighbor]).request(.getHouseholds)

        XCTAssertEqual(response.households.map(\.id), ["Sonos_abc.def", "Sonos_xyz.uvw"])
        XCTAssertEqual(StubURLProtocol.requests.map { $0.request.url?.absoluteString },
                       ["https://10.0.0.1:1443/api/v1/players/local/info", "https://10.0.0.9:1443/api/v1/players/local/info"])
        XCTAssertEqual(StubURLProtocol.requests.first?.request.value(forHTTPHeaderField: "X-Sonos-Api-Key"), "key-1")
    }

    func testHouseholdCallsGoToAPlayerOfThatHousehold() async throws {
        StubURLProtocol.reset([.init(body: #"{"items":[],"version":"1"}"#)])

        try await client([neighbor, kids]).request(.getFavorites(householdId: household))

        XCTAssertEqual(StubURLProtocol.requests.map { $0.request.url?.absoluteString },
                       ["https://10.0.0.1:1443/api/v1/households/Sonos_abc.def/favorites"])
    }

    func testAnotherPlayerAnswersWhenTheFirstIsGone() async throws {
        StubURLProtocol.reset([.init(error: URLError(.cannotConnectToHost)), .init(body: #"{"playlists":[]}"#)])

        try await client([kids, dining]).request(.getPlaylists(householdId: household))

        XCTAssertEqual(StubURLProtocol.requests.compactMap { $0.request.url?.host }, ["10.0.0.1", "10.0.0.2"])
    }

    func testGroupCallsGoToTheCoordinator() async throws {
        StubURLProtocol.reset([.init(body: #"{"volume":20,"muted":false,"fixed":false}"#)])

        try await client([kids, dining]).request(.setGroupVolume(groupId: "RINCON_000000000002:17", volume: 20))

        let sent = try XCTUnwrap(StubURLProtocol.requests.first)
        XCTAssertEqual(sent.request.httpMethod, "POST")
        XCTAssertEqual(sent.request.url?.absoluteString, "https://10.0.0.2:1443/api/v1/groups/RINCON_000000000002:17/groupVolume")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(sent.body)) as? [String: Any])
        XCTAssertEqual(body["volume"] as? Int, 20)
    }

    func testLoadingGoesOverTheSocketsNotTheRESTAPI() {
        let load = SonosAPIEndpoint.loadFavorite(groupId: "RINCON_000000000002:17", favoriteId: "7", playOnCompletion: false,
                                                 action: "REPLACE", playModes: .inOrder)
        XCTAssertNil(load.localTarget, "players answer 404 on their REST API")
        XCTAssertNil(load.localRoute, "with the cloud, loading stays in the cloud")
        let route = load.contentRoute
        XCTAssertEqual(route?.namespace, "favorites")
        XCTAssertEqual(route?.command, "loadFavorite")
        XCTAssertEqual(route?.target, .group("RINCON_000000000002:17"))
        XCTAssertEqual(route?.waitsLong, true)
        XCTAssertEqual(SonosAPIEndpoint.loadPlaylist(groupId: "G:1", playlistId: "3", playOnCompletion: true, playModes: nil)
            .contentRoute?.command, "loadPlaylist")
    }

    func testPlayerCallsGoToThePlayer() async throws {
        StubURLProtocol.reset([.init(body: "")])

        try await client([kids, dining]).request(.setPlayerVolume(playerId: "RINCON_000000000001", volume: 20))

        XCTAssertEqual(StubURLProtocol.requests.first?.request.url?.host, "10.0.0.1")
    }

    func testWithoutPlayersNothingIsSent() async throws {
        StubURLProtocol.reset([])

        do {
            try await client([]).request(.play(groupId: "RINCON_000000000001:1"))
            XCTFail("expected no route")
        } catch let error as SonosLocalError {
            XCTAssertTrue(error.isRoutable)
        }
        XCTAssertTrue(StubURLProtocol.requests.isEmpty)
    }

    func testCloudOnlyCallsHaveNoLocalRoute() {
        XCTAssertNil(SonosAPIEndpoint.subscribeToFavorites(householdId: household).localTarget)
        XCTAssertNil(SonosAPIEndpoint.refreshToken(refreshToken: "R").localTarget)
    }

    // MARK: Errors

    func testPlayerErrorsKeepTheirCode() async throws {
        StubURLProtocol.reset([.init(status: 499, body: #"{"errorCode":"ERROR_FAILURE_TO_ENQUEUE","reason":"no"}"#)])

        do {
            try await client([kids]).request(.play(groupId: "RINCON_000000000001:1"))
            XCTFail("expected an error")
        } catch SonosError.httpError(let status, let body) {
            XCTAssertEqual(status, 499)
            XCTAssertEqual(body?.errorCode, "ERROR_FAILURE_TO_ENQUEUE")
        }
    }

    func testATimeoutReadsLikeTheClouds504() async throws {
        StubURLProtocol.reset([.init(error: URLError(.timedOut))])

        do {
            try await client([kids]).request(.getFavorites(householdId: household))
            XCTFail("expected a timeout")
        } catch SonosError.httpError(let status, _) {
            XCTAssertEqual(status, 504)
        }
    }
}
