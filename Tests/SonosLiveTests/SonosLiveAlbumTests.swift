//
//  SonosLiveAlbumTests.swift
//  SonosLiveTests
//
//  Favorites load in order, and a queue of whole albums (an audio drama
//  series' playlist) moves album by album, always from an album's first
//  track. Against the demo household's "All Episodes" playlist: episode 3
//  (theme + 3 chapters), episode 2 (theme + 3), episode 1 (theme + 4).
//

import XCTest
import SonosDemo
@testable import SonosLive
@testable import SonosSDK

@MainActor
final class SonosLiveAlbumTests: XCTestCase {

    private let bath = "RINCON_DEMO_BATH"
    private let allEpisodes = "5"

    private func makeStore() async throws -> (SonosLiveStore, DemoSonosBackend, SonosGroupModel) {
        let backend = DemoSonosBackend()
        let store = SonosLiveStore(backend: backend, defaults: makeTemporaryDefaults())
        store.trackChangeTimeout = .milliseconds(200)
        store.connect()
        await waitUntil { store.phase == .ready && store.state.liveCount.live == 5 }
        await store.loadFavorites()
        let group = try XCTUnwrap(store.state.group(coordinatorId: bath))
        return (store, backend, group)
    }

    private func playAllEpisodes(_ store: SonosLiveStore, _ group: SonosGroupModel) async throws {
        try await store.playFavorite(allEpisodes, on: group)
        await waitUntil { group.albumName == "Episode 3: The Snowy Mountain" }
    }

    func testAFavoriteStartsAtItsFirstTrackWithoutShuffle() async throws {
        let (store, backend, group) = try await makeStore()
        try await backend.setPlayModes(groupId: group.groupId, playModes: PlayModesBody(shuffle: true, repeat: true))

        try await playAllEpisodes(store, group)

        await waitUntil { !group.playModes.shuffle }
        XCTAssertEqual(group.metadata?.currentItem?.track?.name, "Moonbeam Theme")
        XCTAssertFalse(group.playModes.repeat)
        XCTAssertTrue(group.isPlaying)
    }

    func testAPlaylistOfWholeAlbumsIsRecognized() async throws {
        let (store, _, group) = try await makeStore()
        try await playAllEpisodes(store, group)
        XCTAssertTrue(group.playsAlbumsInSequence)

        try await store.playFavorite("1", on: group)  // Morning Mix: one song per album
        await waitUntil { group.contentName == "Morning Mix" }
        XCTAssertFalse(group.playsAlbumsInSequence)

        try await store.playFavorite("3", on: group)  // a single album
        await waitUntil { group.contentName == "Moonbeam Adventures, Episode 1" }
        XCTAssertFalse(group.playsAlbumsInSequence)
    }

    func testNextAlbumStartsAtItsTheme() async throws {
        let (store, _, group) = try await makeStore()
        try await playAllEpisodes(store, group)
        store.skip(group, forward: true)
        await waitUntil { group.metadata?.currentItem?.track?.name == "Chapter 1: The Snowy Mountain" }

        try await store.playNextAlbum(group)

        XCTAssertEqual(group.albumName, "Episode 2: The Secret Garden")
        XCTAssertEqual(group.metadata?.currentItem?.track?.name, "Moonbeam Theme")
        await waitUntil { group.isPlaying }
        XCTAssertTrue(store.movingGroupIds.isEmpty)
    }

    func testNextAlbumStopsAtTheLastOne() async throws {
        let (store, _, group) = try await makeStore()
        try await playAllEpisodes(store, group)
        try await store.playNextAlbum(group)
        try await store.playNextAlbum(group)
        XCTAssertEqual(group.albumName, "Episode 1: The Hidden Lighthouse")

        try await store.playNextAlbum(group)

        XCTAssertEqual(group.albumName, "Episode 1: The Hidden Lighthouse", "there is no album after the last one")
    }

    func testRandomAlbumStartsAtItsThemeInOrder() async throws {
        let (store, backend, group) = try await makeStore()
        try await playAllEpisodes(store, group)
        backend.randomIndex = { _ in 10 }  // lands on "Chapter 3: The Hidden Lighthouse"

        try await store.playRandomAlbum(group)

        XCTAssertEqual(group.albumName, "Episode 1: The Hidden Lighthouse")
        XCTAssertEqual(group.metadata?.currentItem?.track?.name, "Moonbeam Theme")
        await waitUntil { group.isPlaying }
        XCTAssertFalse(group.playModes.shuffle, "the album plays in order")
    }

    func testPreviousAlbumAndRestart() async throws {
        let (store, _, group) = try await makeStore()
        try await playAllEpisodes(store, group)
        try await store.playNextAlbum(group)
        store.skip(group, forward: true)
        await waitUntil { group.metadata?.currentItem?.track?.name == "Chapter 1: The Secret Garden" }

        try await store.restartAlbum(group)
        XCTAssertEqual(group.albumName, "Episode 2: The Secret Garden")
        XCTAssertEqual(group.metadata?.currentItem?.track?.name, "Moonbeam Theme")

        try await store.playPreviousAlbum(group)
        XCTAssertEqual(group.albumName, "Episode 3: The Snowy Mountain")
        XCTAssertEqual(group.metadata?.currentItem?.track?.name, "Moonbeam Theme")
    }

    func testATrackWithoutAnAlbumCannotMove() async throws {
        let (store, _, group) = try await makeStore()
        try await store.playFavorite("2", on: group)  // radio
        await waitUntil { group.contentName == "Coffeehouse Radio" }

        do {
            try await store.playNextAlbum(group)
            XCTFail("radio has no albums")
        } catch {
            XCTAssertEqual(error as? SonosAlbumNavigationError, .noAlbum)
        }
        XCTAssertTrue(store.movingGroupIds.isEmpty)
    }

    func testALongPlaylistIsNotLoadedTwiceWhenTheCloudTimesOut() async throws {
        let (store, backend, group) = try await makeStore()
        backend.cloudTimeoutTrackCount = 5

        try await playAllEpisodes(store, group)

        XCTAssertEqual(group.metadata?.currentItem?.track?.name, "Moonbeam Theme")
        await waitUntil { group.isPlaying }
    }
}
