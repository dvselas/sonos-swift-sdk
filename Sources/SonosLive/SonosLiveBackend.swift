//
//  SonosLiveBackend.swift
//  SonosLive
//
//  What `SonosLiveStore` needs from Sonos. `SonosManager` is the real
//  backend; `SonosDemo` provides a simulated household for demo mode,
//  UI tests and previews.
//

import Combine
import Foundation
import SonosSDK

/// A running stream of household events: a `SonosLiveClient` (local sockets)
/// or a `SonosCloudLiveClient` (cloud plus event server) in production.
public protocol SonosLiveSession: AnyObject, Sendable {
    /// Single-consumer stream of state changes.
    var events: AsyncStream<SonosLiveEvent> { get }
    /// Closes the connections but keeps their state (system sleep, app in the background).
    func suspend() async
    /// Reconnects after `suspend()` and replays the current state.
    func resume() async
}

extension SonosLiveClient: SonosLiveSession {}
extension SonosCloudLiveClient: SonosLiveSession {}

public protocol SonosLiveBackend: AnyObject {

    var isAuthenticated: Bool { get }
    /// The sign-in state now and on every change.
    var authenticationPublisher: AnyPublisher<Bool, Never> { get }

    // MARK: Reads

    func getHouseholds() async throws -> [Household]
    func getGroups(householdId: String, useCache: Bool) async throws -> ([Group], [Player])
    func getGroupPlaybackStatus(groupId: String, useCache: Bool) async throws -> PlaybackStatus
    func getGroupPlaybackMetadata(groupId: String, useCache: Bool) async throws -> PlaybackMetadata
    func getGroupVolume(groupId: String, useCache: Bool) async throws -> GroupVolume
    func getPlayerVolume(playerId: String, useCache: Bool) async throws -> PlayerVolume
    func getFavorites(householdId: String) async throws -> [Favorite]
    /// The household's Sonos playlists.
    func getPlaylists(householdId: String) async throws -> [Playlist]

    // MARK: Playback

    func play(groupId: String) async throws
    func pause(groupId: String) async throws
    func skipToNextTrack(groupId: String) async throws
    func skipToPreviousTrack(groupId: String) async throws
    func seek(groupId: String, positionMillis: UInt) async throws
    func setPlayModes(groupId: String, playModes: PlayModesBody) async throws
    /// Replaces the queue with a favorite, in order (no shuffle, no repeat); starts it when `play` is true.
    func loadFavorite(groupId: String, favoriteId: String, play: Bool) async throws
    /// Replaces the queue with a Sonos playlist, in order, and starts it.
    func loadPlaylist(groupId: String, playlistId: String) async throws
    /// Replaces the queue with `content`; starts it when `play` is true.
    func loadContent(groupId: String, content: SonosContent, play: Bool) async throws

    // MARK: Volume

    func setGroupVolume(groupId: String, volume: Int) async throws
    func setGroupMuted(groupId: String, muted: Bool) async throws
    func setPlayerVolume(playerId: String, volume: Int) async throws
    func setPlayerMuted(playerId: String, muted: Bool) async throws

    // MARK: Grouping

    func createGroup(householdId: String, playerIds: [String], musicContextGroupId: String?) async throws -> Group
    func modifyGroupMembers(groupId: String, playerIdsToAdd: [String], playerIdsToRemove: [String]) async throws -> Group

    // MARK: Live updates

    func startLiveSession(
        householdId: String,
        groups: [Group],
        players: [Player],
        configuration: SonosLiveConfiguration
    ) async -> any SonosLiveSession

    func stopLiveSession(_ session: any SonosLiveSession) async
}

extension SonosManager: SonosLiveBackend {

    public var authenticationPublisher: AnyPublisher<Bool, Never> {
        $isAuthenticated.eraseToAnyPublisher()
    }

    public func loadFavorite(groupId: String, favoriteId: String, play: Bool) async throws {
        try await loadFavorite(groupId: groupId, favoriteId: favoriteId, playOnCompletion: play, action: "REPLACE",
                               playModes: .inOrder)
    }

    public func loadPlaylist(groupId: String, playlistId: String) async throws {
        try await loadPlaylist(groupId: groupId, playlistId: playlistId, playOnCompletion: true, playModes: .inOrder,
                               action: "REPLACE")
    }

    public func startLiveSession(
        householdId: String,
        groups: [Group],
        players: [Player],
        configuration: SonosLiveConfiguration
    ) async -> any SonosLiveSession {
        if let relay = configuration.eventRelay {
            return await startCloudLiveUpdates(householdId: householdId, groups: groups, players: players,
                                               relay: relay, configuration: configuration)
        }
        return await startLiveUpdates(householdId: householdId, groups: groups, players: players, configuration: configuration)
    }

    public func stopLiveSession(_ session: any SonosLiveSession) async {
        if let client = session as? SonosLiveClient {
            await stopLiveUpdates(client)
        } else if let client = session as? SonosCloudLiveClient {
            await client.stop()
        }
    }
}
