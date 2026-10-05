//
//  SonosLiveContentTests.swift
//  SonosLiveTests
//
//  Taking a room out of its group, playing content there, finding the
//  household's accounts, and the store's lifecycle, against the demo
//  household (which follows the players' rules seen on real systems).
//

import XCTest
import SonosDemo
@testable import SonosLive
@testable import SonosSDK

@MainActor
final class SonosLiveContentTests: XCTestCase {

    private let kitchen = "RINCON_DEMO_KITCHEN"
    private let dining = "RINCON_DEMO_DINING"
    private let bath = "RINCON_DEMO_BATH"
    private let kids = "RINCON_DEMO_KIDS"

    private func makeConnectedStore() async -> (SonosLiveStore, DemoSonosBackend) {
        let backend = DemoSonosBackend()
        let store = SonosLiveStore(backend: backend, defaults: makeTemporaryDefaults())
        store.connect()
        await waitUntil { store.phase == .ready && store.state.liveCount.live == 5 }
        return (store, backend)
    }

    func testDemoHouseholdStreamsItsState() async throws {
        let (store, _) = await makeConnectedStore()

        XCTAssertEqual(store.state.groups.count, 4)
        let kitchenGroup = try XCTUnwrap(store.state.group(coordinatorId: kitchen))
        XCTAssertEqual(kitchenGroup.playerIds, [kitchen, dining])
        XCTAssertTrue(kitchenGroup.isPlaying)
        XCTAssertEqual(kitchenGroup.contentName, "Coffeehouse Radio")
        XCTAssertTrue(kitchenGroup.isLive)
    }

    func testDemoPlaylistsPlayInARoom() async throws {
        let (store, _) = await makeConnectedStore()
        await store.loadPlaylists()
        XCTAssertEqual(store.playlists.map(\.name), ["Road Trip Sing-Along", "Bedtime Stories"])
        XCTAssertNil(store.playlists.first?.imageUrl, "Sonos playlists have no image of their own")

        let bathGroup = try XCTUnwrap(store.state.group(coordinatorId: bath))
        try await store.playPlaylist(try XCTUnwrap(store.playlists.last).id, on: bathGroup)

        await waitUntil { store.state.group(coordinatorId: self.bath)?.contentName == "Bedtime Stories" }
        XCTAssertTrue(try XCTUnwrap(store.state.group(coordinatorId: bath)).isPlaying)
    }

    func testDemoCoversAreDrawnWithoutTheNetwork() async throws {
        let (store, _) = await makeConnectedStore()
        await store.loadFavorites()

        for favorite in store.favorites {
            let url = try XCTUnwrap(favorite.imageUrl)
            XCTAssertTrue(url.hasPrefix("data:image/png;base64,"), "\(favorite.name) has a drawn cover")
            let png = try XCTUnwrap(Data(base64Encoded: String(url.dropFirst("data:image/png;base64,".count))))
            XCTAssertEqual(Array(png.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
        }
        let playing = try XCTUnwrap(store.state.group(coordinatorId: kitchen))
        XCTAssertTrue(playing.metadata?.currentItem?.track?.imageUrl?.hasPrefix("data:image/png") == true)
    }

    func testIsolatingTheCoordinatorHandsTheMusicToTheOtherRooms() async throws {
        let (store, _) = await makeConnectedStore()
        let before = try XCTUnwrap(store.state.group(coordinatorId: kitchen))
        let originalId = before.groupId

        let groupId = try await store.isolate(kitchen)

        XCTAssertEqual(groupId, originalId, "the coordinator keeps its group id")
        await waitUntil { store.state.group(containing: self.dining)?.isPlaying == true }
        let diningGroup = try XCTUnwrap(store.state.group(containing: dining))
        XCTAssertEqual(diningGroup.playerIds, [dining])
        XCTAssertEqual(diningGroup.contentName, "Coffeehouse Radio", "the other room keeps the music")
        XCTAssertEqual(store.state.group(containing: kitchen)?.playerIds, [kitchen])
    }

    func testIsolatingAMemberLeavesTheMusicWithTheGroup() async throws {
        let (store, _) = await makeConnectedStore()

        let groupId = try await store.isolate(dining)

        XCTAssertNotEqual(groupId, store.state.group(coordinatorId: kitchen)?.groupId)
        await waitUntil { store.state.group(containing: self.dining)?.playerIds == [self.dining] }
        XCTAssertFalse(try XCTUnwrap(store.state.group(containing: dining)).isPlaying)
        XCTAssertTrue(try XCTUnwrap(store.state.group(coordinatorId: kitchen)).isPlaying)
    }

    func testIsolatingAMemberWaitsUntilThePlayersReportIt() async throws {
        let (store, backend) = await makeConnectedStore()
        // Real players confirm the change before `getGroups` shows it.
        backend.topologyDelay = .milliseconds(300)
        store.topologyPollInterval = .milliseconds(20)

        let groupId = try await store.isolate(dining)

        let diningGroup = try XCTUnwrap(store.state.group(containing: dining))
        XCTAssertEqual(diningGroup.playerIds, [dining])
        XCTAssertEqual(diningGroup.groupId, groupId)
        XCTAssertEqual(store.state.group(coordinatorId: kitchen)?.playerIds, [kitchen])
    }

    func testIsolatingTheCoordinatorWaitsUntilThePlayersReportIt() async throws {
        let (store, backend) = await makeConnectedStore()
        backend.topologyDelay = .milliseconds(300)
        store.topologyPollInterval = .milliseconds(20)
        let originalId = try XCTUnwrap(store.state.group(coordinatorId: kitchen)).groupId

        let groupId = try await store.isolate(kitchen)

        XCTAssertEqual(groupId, originalId)
        XCTAssertEqual(store.state.group(containing: kitchen)?.playerIds, [kitchen])
        await waitUntil { store.state.group(containing: self.dining)?.isPlaying == true }
    }

    func testTheCoordinatorOfAnIdleGroupLeavesToo() async throws {
        let (store, backend) = await makeConnectedStore()
        let bathGroupId = try XCTUnwrap(store.state.group(coordinatorId: bath)).groupId
        _ = try await backend.modifyGroupMembers(groupId: bathGroupId, playerIdsToAdd: [kids], playerIdsToRemove: [])
        await waitUntil { store.state.group(containing: self.kids)?.playerIds == [self.bath, self.kids] }

        // Sonos refuses to hand over the music of an idle group.
        let groupId = try await store.isolate(bath)

        XCTAssertEqual(groupId, bathGroupId)
        XCTAssertEqual(store.state.group(containing: bath)?.playerIds, [bath])
        await waitUntil { store.state.group(containing: self.kids)?.playerIds == [self.kids] }
    }

    func testIsolatingARoomOnItsOwnChangesNothing() async throws {
        let (store, _) = await makeConnectedStore()
        let bathGroup = try XCTUnwrap(store.state.group(coordinatorId: bath))

        let groupId = try await store.isolate(bath)

        XCTAssertEqual(groupId, bathGroup.groupId)
    }

    func testPlayingContentTakesTheRoomOutOfItsGroupFirst() async throws {
        let (store, _) = await makeConnectedStore()
        let episode = SonosContent(kind: .album, serviceId: SonosServiceId.appleMusic,
                                   objectId: "album:demo-moonbeam-2", accountId: "sn_2")

        try await store.play(episode, onPlayer: dining)

        await waitUntil { store.state.group(containing: self.dining)?.contentName == "Moonbeam Adventures, Episode 2" }
        let diningGroup = try XCTUnwrap(store.state.group(containing: dining))
        XCTAssertEqual(diningGroup.playerIds, [dining])
        await waitUntil { diningGroup.isPlaying }
        XCTAssertEqual(store.state.group(coordinatorId: kitchen)?.contentName, "Coffeehouse Radio")
    }

    func testAccountsAreFoundWithoutPlaying() async throws {
        let (store, _) = await makeConnectedStore()
        let probe = SonosContent(kind: .track, serviceId: SonosServiceId.spotify,
                                 objectId: "spotify:track:probe", accountId: "sn_1")

        let accounts = try await store.discoverAccounts(probe: probe, onPlayer: bath, candidates: ["sn_1", "sn_5", "sn_6", "sn_7"])

        XCTAssertEqual(accounts, ["sn_5", "sn_6"])
        await waitUntil { store.state.group(coordinatorId: self.bath)?.hasContent == true }
        XCTAssertFalse(try XCTUnwrap(store.state.group(coordinatorId: bath)).isPlaying, "nothing plays while probing")
    }

    func testActivateConnectsOnceSignedIn() async {
        let store = SonosLiveStore(backend: DemoSonosBackend(), defaults: makeTemporaryDefaults())

        store.activate()

        await waitUntil { store.phase == .ready }
        XCTAssertEqual(store.householdId, DemoSonosBackend.householdId)
    }

    func testResumeReplaysTheHousehold() async throws {
        let (store, backend) = await makeConnectedStore()
        await store.suspend()
        // A change while suspended reaches the store after resuming.
        try await backend.setPlayerVolume(playerId: bath, volume: 61)
        await store.resume()

        await waitUntil { store.state.player(self.bath)?.volume.displayedVolume == 61 }
    }

    func testContentCommandsGoToTheGroup() async throws {
        let http = FakeSonosHTTPClient()
        let manager = SonosManager(
            client: Client(keyName: "test", key: "key", secret: "secret", redirectURI: "test://r", callbackURL: "test://c"),
            httpClient: http,
            tokenManager: TokenManager(clientKey: "key", clientSecret: "secret", redirectURI: "test://r",
                                       tokenStore: InMemoryTokenStore())
        )
        let defaults = makeTemporaryDefaults()
        defaults.set(false, forKey: SonosLiveStore.enabledKey)
        let store = SonosLiveStore(backend: manager, defaults: defaults)
        store.connect()
        await waitUntil { store.phase == .ready }
        let track = SonosContent(kind: .track, serviceId: "9", objectId: "spotify:track:abc", accountId: "sn_6")

        try await store.play(track, onPlayer: "RINCON_C")

        XCTAssertTrue(http.endpoints.contains { $0.hasPrefix("loadContent(groupId: \"RINCON_C:5\"") && $0.contains("sn_6") && $0.contains("play: true") })
    }
}
