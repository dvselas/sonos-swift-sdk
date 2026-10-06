//
//  SonosLiveStore+Queue.swift
//  SonosLive
//
//  Adding favorites, Sonos playlists and music service items to the end of a
//  group's queue, e.g. a child picking the next audio book.
//
//  The players pause a playing group that gets music added without being
//  asked to play, so the play flag follows the group: a playing group carries
//  on with its track, a paused one stays paused. The queue keeps its name
//  (`container`) after the first item, so it doesn't tell what was added.
//

import Foundation
import SonosSDK

extension SonosLiveStore {

    /// Adds a favorite after the last track of `group`'s queue.
    public func appendFavorite(_ favoriteId: String, to group: SonosGroupModel) async throws {
        try await appending("loadFavorite") { [backend] in
            try await backend.loadFavorite(groupId: group.groupId, favoriteId: favoriteId, play: group.isPlaying,
                                           queueAction: .append)
        }
    }

    /// Adds a Sonos playlist after the last track of `group`'s queue.
    public func appendPlaylist(_ playlistId: String, to group: SonosGroupModel) async throws {
        try await appending("loadPlaylist") { [backend] in
            try await backend.loadPlaylist(groupId: group.groupId, playlistId: playlistId, play: group.isPlaying,
                                           queueAction: .append)
        }
    }

    /// Adds a music service item after the last track of `group`'s queue.
    public func append(_ content: SonosContent, to group: SonosGroupModel) async throws {
        try await appending("loadContent") { [backend] in
            try await backend.loadContent(groupId: group.groupId, content: content, play: group.isPlaying,
                                          queueAction: .append)
        }
    }

    /// Runs an append once: unlike replacing, trying again after an unclear
    /// failure could add the music twice. A long playlist answers the cloud's
    /// `504` while the players still finish adding it.
    private func appending(_ name: String, _ load: () async throws -> Void) async throws {
        do {
            try await load()
        } catch SonosError.httpError(let status, let body) where status == 504 {
            log("[Sonos] \(name) still appending after the cloud's timeout: \(body?.errorCode ?? "504")")
        }
    }
}
