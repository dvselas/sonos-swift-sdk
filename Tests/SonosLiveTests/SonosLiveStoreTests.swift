//
//  SonosLiveStoreTests.swift
//  SonosLiveTests
//
//  Reducers, optimistic intents and commands of the live Sonos store.
//

import XCTest
@testable import SonosLive
@testable import SonosSDK

// MARK: - Playback

final class SonosPlaybackControlStateTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    private func status(_ state: SonosPlaybackState, _ position: UInt = 0) -> PlaybackStatus {
        PlaybackStatus(playbackState: state.rawValue, positionMillis: position)
    }

    func testPauseIntentIgnoresStalePlayingEventUntilConfirmed() {
        var sut = SonosPlaybackControlState()
        sut.apply(status(.playing, 10_000), at: t0)

        sut.beginPlayIntent(.paused, at: t0.addingTimeInterval(1))
        XCTAssertEqual(sut.playState, .paused)

        // The player still reports the pre-command state.
        sut.apply(status(.playing, 11_000), at: t0.addingTimeInterval(1.2))
        XCTAssertEqual(sut.playState, .paused, "a stale event must not flip the button back")

        sut.apply(status(.paused, 11_300), at: t0.addingTimeInterval(1.5))
        XCTAssertEqual(sut.playState, .paused)
        XCTAssertNil(sut.pendingPlayState)
        XCTAssertEqual(sut.position(at: t0.addingTimeInterval(10)), 11_300)
    }

    func testIntentExpiresAndTruthWins() {
        var sut = SonosPlaybackControlState()
        sut.apply(status(.playing, 0), at: t0)
        sut.beginPlayIntent(.paused, at: t0)

        sut.apply(status(.playing, 6_000), at: t0.addingTimeInterval(SonosIntentTiming.playState + 1))
        XCTAssertEqual(sut.playState, .playing)
        XCTAssertNil(sut.pendingPlayState)
    }

    func testBufferingKeepsAPlayIntentAlive() {
        var sut = SonosPlaybackControlState()
        sut.apply(status(.paused, 5_000), at: t0)
        sut.beginPlayIntent(.playing, at: t0)

        sut.apply(status(.buffering, 5_000), at: t0.addingTimeInterval(0.3))
        XCTAssertEqual(sut.playState, .playing)
        XCTAssertNotNil(sut.pendingPlayState)

        sut.apply(status(.playing, 5_000), at: t0.addingTimeInterval(0.8))
        XCTAssertNil(sut.pendingPlayState)
        XCTAssertEqual(sut.position(at: t0.addingTimeInterval(2.8)), 7_000, accuracy: 1)
    }

    func testPositionAdvancesOnlyWhilePlaying() {
        var sut = SonosPlaybackControlState()
        sut.apply(status(.playing, 10_000), at: t0)
        XCTAssertEqual(sut.position(at: t0.addingTimeInterval(2)), 12_000, accuracy: 1)

        sut.apply(status(.paused, 12_500), at: t0.addingTimeInterval(2.5))
        XCTAssertEqual(sut.position(at: t0.addingTimeInterval(60)), 12_500)
    }

    func testSeekIntentHoldsTargetUntilConfirmed() {
        var sut = SonosPlaybackControlState()
        sut.apply(status(.playing, 10_000), at: t0)
        sut.beginSeekIntent(to: 60_000, at: t0)

        sut.apply(status(.playing, 10_300), at: t0.addingTimeInterval(0.3))
        XCTAssertEqual(sut.position(at: t0.addingTimeInterval(0.3)), 60_300, accuracy: 1, "stale position is ignored")

        sut.apply(status(.playing, 60_400), at: t0.addingTimeInterval(0.5))
        XCTAssertNil(sut.pendingSeek)
        XCTAssertEqual(sut.position(at: t0.addingTimeInterval(1.5)), 61_400, accuracy: 1)
    }

    func testExpireIntentsDropsTheOverride() {
        var sut = SonosPlaybackControlState()
        sut.apply(status(.paused, 1_000), at: t0)
        sut.beginPlayIntent(.playing, at: t0)
        sut.expireIntents(at: t0.addingTimeInterval(SonosIntentTiming.playState + 0.1))
        XCTAssertEqual(sut.playState, .paused)
        XCTAssertFalse(sut.isAdvancing)
    }
}

// MARK: - Volume

final class SonosVolumeControlStateTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    func testDragOwnsTheValueUntilReleased() {
        var sut = SonosVolumeControlState()
        sut.apply(volume: 20, muted: false, fixed: false)

        sut.beginVolumeIntent(45, dragging: true, at: t0)
        sut.apply(volume: 30, muted: false, fixed: false)
        XCTAssertEqual(sut.displayedVolume, 45, "events must not move the knob mid-drag")

        sut.beginVolumeIntent(50, dragging: false, at: t0.addingTimeInterval(1))
        sut.apply(volume: 50, muted: false, fixed: false)
        XCTAssertNil(sut.pendingVolume)
        XCTAssertEqual(sut.displayedVolume, 50)
    }

    func testUnconfirmedVolumeFallsBackAfterSettling() {
        var sut = SonosVolumeControlState()
        sut.apply(volume: 20, muted: false, fixed: false)
        sut.beginVolumeIntent(80, dragging: false, at: t0)
        sut.expireIntents(at: t0.addingTimeInterval(SonosIntentTiming.volumeSettle + 0.1))
        XCTAssertEqual(sut.displayedVolume, 20)
    }

    func testMuteIntentAndClamp() {
        var sut = SonosVolumeControlState()
        sut.apply(volume: 20, muted: false, fixed: true)
        sut.beginMuteIntent(true, at: t0)
        XCTAssertTrue(sut.displayedMuted)
        sut.apply(volume: 20, muted: true, fixed: true)
        XCTAssertNil(sut.pendingMuted)
        XCTAssertTrue(sut.fixed)

        sut.beginVolumeIntent(140, dragging: true, at: t0)
        XCTAssertEqual(sut.displayedVolume, 100)
    }
}

// MARK: - Household state

@MainActor
final class SonosLiveStateTests: XCTestCase {

    private let t0 = Date(timeIntervalSinceReferenceDate: 1_000)

    private var kitchenAndDining: [SonosSDK.Group] {
        [
            SonosSDK.Group(id: "RINCON_A:1", name: "Kitchen + 1", coordinatorId: "RINCON_A", playerIds: ["RINCON_A", "RINCON_B"]),
            SonosSDK.Group(id: "RINCON_C:5", name: "Office", coordinatorId: "RINCON_C", playerIds: ["RINCON_C"])
        ]
    }

    private var players: [Player] {
        [Player(id: "RINCON_A", name: "Kitchen"), Player(id: "RINCON_B", name: "Dining"), Player(id: "RINCON_C", name: "Office")]
    }

    func testEventsReachTheCoordinatorsModel() throws {
        let sut = SonosLiveState()
        sut.apply(.topology(groups: kitchenAndDining, players: players), at: t0)
        sut.apply(.playbackStatus(groupId: "RINCON_A:1", status: PlaybackStatus(playbackState: "PLAYBACK_STATE_PLAYING")), at: t0)
        sut.apply(.groupVolume(groupId: "RINCON_A:1", volume: GroupVolume(volume: 33)), at: t0)
        sut.apply(.playerVolume(playerId: "RINCON_B", volume: PlayerVolume(volume: 12)), at: t0)

        let kitchen = try XCTUnwrap(sut.group(coordinatorId: "RINCON_A"))
        XCTAssertTrue(kitchen.isPlaying)
        XCTAssertEqual(kitchen.volume.displayedVolume, 33)
        XCTAssertEqual(sut.player("RINCON_B")?.volume.displayedVolume, 12)
        XCTAssertEqual(sut.groups.map(\.name), ["Kitchen + 1", "Office"])
    }

    func testRegroupKeepsTheCardAndItsState() throws {
        let sut = SonosLiveState()
        sut.apply(.topology(groups: kitchenAndDining, players: players), at: t0)
        sut.apply(.playbackStatus(groupId: "RINCON_A:1", status: PlaybackStatus(playbackState: "PLAYBACK_STATE_PLAYING")), at: t0)
        let kitchen = try XCTUnwrap(sut.group(coordinatorId: "RINCON_A"))

        // Dining leaves; the kitchen group gets a new id.
        let regrouped = [
            SonosSDK.Group(id: "RINCON_A:2", name: "Kitchen", coordinatorId: "RINCON_A", playerIds: ["RINCON_A"]),
            SonosSDK.Group(id: "RINCON_B:1", name: "Dining", coordinatorId: "RINCON_B", playerIds: ["RINCON_B"]),
            SonosSDK.Group(id: "RINCON_C:5", name: "Office", coordinatorId: "RINCON_C", playerIds: ["RINCON_C"])
        ]
        sut.apply(.topology(groups: regrouped, players: players), at: t0)

        XCTAssertTrue(sut.group(coordinatorId: "RINCON_A") === kitchen, "same card object")
        XCTAssertEqual(kitchen.groupId, "RINCON_A:2")
        XCTAssertTrue(kitchen.isPlaying, "playback state survives the regroup")
        XCTAssertFalse(kitchen.isGrouped)
        XCTAssertEqual(sut.groups.count, 3)

        sut.apply(.groupVolume(groupId: "RINCON_A:2", volume: GroupVolume(volume: 70)), at: t0)
        XCTAssertEqual(kitchen.volume.displayedVolume, 70)
    }

    func testConnectionStateMarksGroupsLive() throws {
        let sut = SonosLiveState()
        sut.apply(.topology(groups: kitchenAndDining, players: players), at: t0)
        sut.apply(.connection(playerId: "RINCON_A", state: .connected), at: t0)

        XCTAssertTrue(try XCTUnwrap(sut.group(coordinatorId: "RINCON_A")).isLive)
        XCTAssertFalse(try XCTUnwrap(sut.group(coordinatorId: "RINCON_C")).isLive)
        XCTAssertEqual(sut.liveCount.live, 1)
        XCTAssertEqual(sut.liveCount.total, 3)

        sut.apply(.connection(playerId: "RINCON_A", state: .disconnected(retryIn: 2)), at: t0)
        XCTAssertFalse(try XCTUnwrap(sut.group(coordinatorId: "RINCON_A")).isLive)
    }

    func testDurationArrivingAfterPlaybackStillAdvances() throws {
        let sut = SonosLiveState()
        sut.apply(.topology(groups: kitchenAndDining, players: players), at: t0)
        sut.apply(.playbackStatus(groupId: "RINCON_C:5", status: PlaybackStatus(playbackState: "PLAYBACK_STATE_PLAYING", positionMillis: 1_000)), at: t0)

        let metadata = try JSONDecoder().decode(PlaybackMetadata.self, from: Data(#"{"currentItem":{"track":{"name":"Song","durationMillis":200000}}}"#.utf8))
        sut.apply(.metadataStatus(groupId: "RINCON_C:5", metadata: metadata), at: t0.addingTimeInterval(1))

        let office = try XCTUnwrap(sut.group(coordinatorId: "RINCON_C"))
        XCTAssertEqual(office.durationMillis, 200_000)
        XCTAssertEqual(office.positionMillis(at: t0.addingTimeInterval(4)), 5_000, accuracy: 1)
        XCTAssertEqual(office.positionMillis(at: t0.addingTimeInterval(1_000)), 200_000, "clamped to the track length")
    }

    func testEventsForUnknownGroupsAreIgnored() {
        let sut = SonosLiveState()
        sut.apply(.topology(groups: kitchenAndDining, players: players), at: t0)
        sut.apply(.playbackStatus(groupId: "RINCON_Z:9", status: PlaybackStatus(playbackState: "PLAYBACK_STATE_PLAYING")), at: t0)
        XCTAssertFalse(sut.groups.contains { $0.isPlaying })
    }
}

// MARK: - Store commands

@MainActor
final class SonosLiveStoreTests: XCTestCase {

    private func makeStore(http: FakeSonosHTTPClient, defaults: UserDefaults? = nil) -> SonosLiveStore {
        let manager = SonosManager(
            client: Client(keyName: "test", key: "key", secret: "secret", redirectURI: "test://r", callbackURL: "test://c"),
            httpClient: http,
            tokenManager: TokenManager(clientKey: "key", clientSecret: "secret", redirectURI: "test://r",
                                       tokenStore: InMemoryTokenStore())
        )
        let store = SonosLiveStore(backend: manager, defaults: defaults ?? makeTemporaryDefaults(), log: { _ in })
        store.state.apply(.topology(groups: [
            SonosSDK.Group(id: "RINCON_A:1", name: "Kitchen + 1", coordinatorId: "RINCON_A", playerIds: ["RINCON_A", "RINCON_B"])
        ], players: [Player(id: "RINCON_A", name: "Kitchen"), Player(id: "RINCON_B", name: "Dining")]))
        return store
    }

    func testPlayPauseSendsAnExplicitPauseAndShowsItAtOnce() async throws {
        let http = FakeSonosHTTPClient()
        let store = makeStore(http: http)
        let kitchen = try XCTUnwrap(store.state.group(coordinatorId: "RINCON_A"))
        store.state.apply(.playbackStatus(groupId: "RINCON_A:1", status: PlaybackStatus(playbackState: "PLAYBACK_STATE_PLAYING")))

        store.togglePlayPause(kitchen)

        XCTAssertEqual(kitchen.playState, .paused)
        await waitUntil { http.endpoints.contains(#"pause(groupId: "RINCON_A:1")"#) }
        XCTAssertFalse(http.endpoints.contains { $0.hasPrefix("togglePlayPause") })
    }

    func testFailedCommandRollsBackAndReportsTheError() async throws {
        let http = FakeSonosHTTPClient()
        http.failCommands = true
        let store = makeStore(http: http)
        let kitchen = try XCTUnwrap(store.state.group(coordinatorId: "RINCON_A"))
        store.state.apply(.playbackStatus(groupId: "RINCON_A:1", status: PlaybackStatus(playbackState: "PLAYBACK_STATE_PAUSED")))

        store.togglePlayPause(kitchen)
        XCTAssertEqual(kitchen.playState, .playing)

        await waitUntil { store.alertMessage != nil }
        XCTAssertEqual(kitchen.playState, .paused)
    }

    func testGroupSliderControlsGroupVolume() async throws {
        let http = FakeSonosHTTPClient()
        let store = makeStore(http: http)
        let kitchen = try XCTUnwrap(store.state.group(coordinatorId: "RINCON_A"))

        store.setGroupVolume(kitchen, to: 10, isFinal: false)
        store.setGroupVolume(kitchen, to: 20, isFinal: false)
        store.setGroupVolume(kitchen, to: 30, isFinal: true)

        XCTAssertEqual(kitchen.volume.displayedVolume, 30)
        await waitUntil { http.endpoints.contains(#"setGroupVolume(groupId: "RINCON_A:1", volume: 30)"#) }
        XCTAssertFalse(http.endpoints.contains { $0.hasPrefix("setPlayerVolume") }, "grouped rooms use group volume")
    }

    func testRoomSliderControlsPlayerVolume() async throws {
        let http = FakeSonosHTTPClient()
        let store = makeStore(http: http)
        let dining = try XCTUnwrap(store.state.player("RINCON_B"))

        store.setPlayerVolume(dining, to: 42, isFinal: true)
        await waitUntil { http.endpoints.contains(#"setPlayerVolume(playerId: "RINCON_B", volume: 42)"#) }
    }

    func testShuffleTogglesFromTheCurrentMode() async throws {
        let http = FakeSonosHTTPClient()
        let store = makeStore(http: http)
        let kitchen = try XCTUnwrap(store.state.group(coordinatorId: "RINCON_A"))
        store.state.apply(.playbackStatus(groupId: "RINCON_A:1", status: PlaybackStatus(
            playbackState: "PLAYBACK_STATE_PLAYING", playModes: PlayModes(shuffle: true)
        )))

        store.toggleShuffle(kitchen)
        await waitUntil { http.endpoints.contains { $0.hasPrefix("setPlayModes") && $0.contains("shuffle: Optional(false)") } }
    }

    func testUngroupRemovesEveryRoomButTheCoordinator() async throws {
        let http = FakeSonosHTTPClient()
        let store = makeStore(http: http)
        let kitchen = try XCTUnwrap(store.state.group(coordinatorId: "RINCON_A"))

        try await store.ungroup(kitchen)

        XCTAssertTrue(http.endpoints.contains(#"modifyGroupMembers(groupId: "RINCON_A:1", playerIdsToAdd: [], playerIdsToRemove: ["RINCON_B"])"#))
    }

    func testFavoritesLoadOnceAndStayDuringARefresh() async throws {
        let http = FakeSonosHTTPClient()
        let defaults = makeTemporaryDefaults()
        defaults.set(false, forKey: SonosLiveStore.enabledKey)
        let connected = makeStore(http: http, defaults: defaults)
        connected.state.reset()
        connected.connect()
        await waitUntil { connected.phase == .ready }

        await connected.loadFavorites()
        XCTAssertEqual(connected.favorites.map(\.name), ["FM4", "Bayern 3"])
        XCTAssertEqual(connected.favoritesPhase, .loaded)

        http.failReads = true
        await connected.loadFavorites()
        XCTAssertEqual(connected.favorites.count, 2, "a failed refresh keeps the last list")
        XCTAssertEqual(connected.favoritesPhase, .loaded)
    }

    func testFavoritesWithoutHouseholdDoNothing() async {
        let http = FakeSonosHTTPClient()
        let store = makeStore(http: http)

        await store.loadFavorites()

        XCTAssertEqual(store.favoritesPhase, .idle)
        XCTAssertFalse(http.endpoints.contains { $0.hasPrefix("getFavorites") })
    }

    func testPlayingAFavoriteRetriesOnceThenExplains() async throws {
        let http = FakeSonosHTTPClient()
        http.failCommands = true
        let store = makeStore(http: http)
        store.favoriteRetryDelay = .zero
        let kitchen = try XCTUnwrap(store.state.group(coordinatorId: "RINCON_A"))

        do {
            try await store.playFavorite("F1", on: kitchen)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error is SonosFavoriteError)
        }
        XCTAssertEqual(http.endpoints.filter { $0.hasPrefix("loadFavorite") }.count, 2)
    }

    func testPlaylistsLoadOnceAndStayDuringARefresh() async throws {
        let http = FakeSonosHTTPClient()
        let defaults = makeTemporaryDefaults()
        defaults.set(false, forKey: SonosLiveStore.enabledKey)
        let store = makeStore(http: http, defaults: defaults)
        store.state.reset()
        store.connect()
        await waitUntil { store.phase == .ready }

        await store.loadPlaylists()
        XCTAssertEqual(store.playlists.map(\.name), ["Road Trip"])
        XCTAssertEqual(store.playlistsPhase, .loaded)

        http.failReads = true
        await store.loadPlaylists()
        XCTAssertEqual(store.playlists.count, 1, "a failed refresh keeps the last list")
    }

    func testAPlaylistReplacesTheQueue() async throws {
        let http = FakeSonosHTTPClient()
        let store = makeStore(http: http)
        let kitchen = try XCTUnwrap(store.state.group(coordinatorId: "RINCON_A"))

        try await store.playPlaylist("0", on: kitchen)

        let load = try XCTUnwrap(http.endpoints.first { $0.hasPrefix("loadPlaylist") })
        XCTAssertTrue(load.contains("RINCON_A:1") && load.contains("\"REPLACE\""), load)
    }

    func testPlayingAPlaylistRetriesOnceThenExplains() async throws {
        let http = FakeSonosHTTPClient()
        http.failCommands = true
        let store = makeStore(http: http)
        store.favoriteRetryDelay = .zero
        let kitchen = try XCTUnwrap(store.state.group(coordinatorId: "RINCON_A"))

        do {
            try await store.playPlaylist("0", on: kitchen)
            XCTFail("expected an error")
        } catch {
            XCTAssertTrue(error is SonosFavoriteError)
        }
        XCTAssertEqual(http.endpoints.filter { $0.hasPrefix("loadPlaylist") }.count, 2)
    }

    func testFavoriteErrorReplacesTheEnqueueFailure() {
        let enqueue = SonosFavoriteError(underlying: SonosError.apiError(errorCode: "ERROR_FAILURE_TO_ENQUEUE", reason: "Internal error setting URI"),
                                         enqueueFailedMessage: "Try again")
        XCTAssertEqual(enqueue.errorDescription, "Try again")

        let other = SonosFavoriteError(underlying: URLError(.timedOut))
        XCTAssertEqual(other.errorDescription, URLError(.timedOut).localizedDescription)
    }

    func testTopologyCacheRoundTrip() throws {
        let defaults = makeTemporaryDefaults()
        let cache = SonosTopologyCache(
            householdId: "HH",
            groups: [SonosSDK.Group(id: "A:1", name: "Kitchen", coordinatorId: "A", playerIds: ["A"])],
            players: [Player(id: "A", name: "Kitchen", websocketUrl: "wss://10.0.0.1:1443/websocket/api")]
        )
        cache.save(to: defaults)
        let loaded = try XCTUnwrap(SonosTopologyCache.load(from: defaults))
        XCTAssertEqual(loaded.signature, cache.signature)
        XCTAssertEqual(loaded.players.first?.websocketUrl, "wss://10.0.0.1:1443/websocket/api")
    }

    func testWithAnEventServerTheStoreGoesThroughTheCloud() async throws {
        let http = FakeSonosHTTPClient()
        let relay = OpenRelay()
        let store = makeStore(http: http)
        store.eventRelay = relay
        store.focusPlayerIds = ["RINCON_C"]
        store.state.reset()
        // The relay connection needs a signed-in user.
        let manager = try XCTUnwrap(store.backend as? SonosManager)
        await manager.tokenManager.storeToken(from: TokenManager.TokenResponse(
            accessToken: "A", refreshToken: "R", tokenType: "Bearer", expiresIn: 3600, scope: "playback-control-all"))

        store.connect()

        await waitUntil { store.state.player("RINCON_C")?.isLive == true }
        XCTAssertEqual(relay.connections, 1)
        XCTAssertTrue(http.endpoints.contains(#"subscribeToPlayback(groupId: "RINCON_C:5")"#))
        XCTAssertTrue(http.endpoints.contains(#"getPlaybackStatus(groupId: "RINCON_C:5")"#))
        await store.disconnect()
    }

    func testConnectLoadsTheHouseholdAndCachesIt() async {
        let defaults = makeTemporaryDefaults()
        defaults.set(false, forKey: SonosLiveStore.enabledKey)
        let store = makeStore(http: FakeSonosHTTPClient(), defaults: defaults)
        store.state.reset()

        store.connect()
        await waitUntil { store.phase == .ready }

        XCTAssertEqual(store.householdId, "HH")
        XCTAssertEqual(store.state.groups.map(\.name), ["Office"])
        XCTAssertNil((store.backend as? SonosManager)?.liveClient, "live updates are off: no local sockets")
        XCTAssertEqual(SonosTopologyCache.load(from: defaults)?.householdId, "HH")
    }

    func testCloudOnlyGroupsArePolledWhileVisible() async throws {
        let defaults = makeTemporaryDefaults()
        defaults.set(false, forKey: SonosLiveStore.enabledKey)
        let http = FakeSonosHTTPClient()
        let store = makeStore(http: http, defaults: defaults)
        store.state.reset()
        store.connect()
        await waitUntil { store.phase == .ready }

        await store.pollUnreachable()

        XCTAssertTrue(http.endpoints.contains(#"getPlaybackStatus(groupId: "RINCON_C:5")"#))
        XCTAssertTrue(http.endpoints.contains(#"getGroupVolume(groupId: "RINCON_C:5")"#))
        let office = try XCTUnwrap(store.state.group(coordinatorId: "RINCON_C"))
        XCTAssertTrue(office.isPlaying)
        XCTAssertEqual(office.volume.displayedVolume, 20)
    }

    func testFailedCloudLoadGoesOfflineWithoutCache() async {
        let http = FakeSonosHTTPClient()
        http.failReads = true
        let store = makeStore(http: http)
        store.state.reset()
        store.retryInterval = .seconds(3_600)

        store.connect()
        await waitUntil { if case .offline = store.phase { return true } else { return false } }
        XCTAssertNil(store.householdId)
    }
}
