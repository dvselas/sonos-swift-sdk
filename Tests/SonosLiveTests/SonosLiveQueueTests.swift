//
//  SonosLiveQueueTests.swift
//  SonosLiveTests
//
//  Adding music to the end of a room's queue, against the demo household:
//  "Moonbeam Adventures, Episode 1" (favorite 3, four chapters) and episode 2
//  from the demo catalog (three chapters).
//

import XCTest
import SonosDemo
@testable import SonosLive
@testable import SonosSDK

@MainActor
final class SonosLiveQueueTests: XCTestCase {

    private let bath = "RINCON_DEMO_BATH"
    private let episode2 = SonosContent(kind: .album, serviceId: SonosServiceId.appleMusic,
                                        objectId: "album:demo-moonbeam-2", accountId: "sn_2")

    private func makeStore() async throws -> (SonosLiveStore, DemoSonosBackend, SonosGroupModel) {
        let backend = DemoSonosBackend()
        let store = SonosLiveStore(backend: backend, defaults: makeTemporaryDefaults())
        store.connect()
        await waitUntil { store.phase == .ready && store.state.liveCount.live == 5 }
        await store.loadFavorites()
        let group = try XCTUnwrap(store.state.group(coordinatorId: bath))
        try await store.playFavorite("3", on: group)
        await waitUntil { group.albumName == "Episode 1: The Hidden Lighthouse" && group.isPlaying }
        return (store, backend, group)
    }

    func testAppendingKeepsThePlayingTrackAndAddsAfterTheLast() async throws {
        let (store, backend, group) = try await makeStore()

        try await store.append(episode2, to: group)

        XCTAssertTrue(group.isPlaying)
        XCTAssertEqual(group.metadata?.currentItem?.track?.name, "Chapter 1")
        XCTAssertEqual(group.contentName, "Moonbeam Adventures, Episode 1")
        for _ in 1...4 { try await backend.skipToNextTrack(groupId: group.groupId) }
        await waitUntil { group.albumName == "Episode 2: The Secret Garden" }
        XCTAssertEqual(group.metadata?.currentItem?.track?.name, "Chapter 1")
    }

    func testAPausedRoomStaysPaused() async throws {
        let (store, backend, group) = try await makeStore()
        try await backend.pause(groupId: group.groupId)
        await waitUntil { !group.isPlaying }

        try await store.appendFavorite("3", to: group)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(group.isPlaying)
        XCTAssertEqual(group.metadata?.currentItem?.track?.name, "Chapter 1")
    }

    func testStationFavoritesAreStreams() async throws {
        let (store, _, _) = try await makeStore()
        XCTAssertEqual(store.favorites.filter(\.isStream).map(\.name), ["Coffeehouse Radio"])
    }

    func testAppendingWithoutPlayPausesLikeThePlayers() async throws {
        let (store, backend, group) = try await makeStore()
        defer { withExtendedLifetime(store) {} }

        try await backend.loadContent(groupId: group.groupId, content: episode2, play: false, queueAction: .append)

        await waitUntil { !group.isPlaying }
    }
}
