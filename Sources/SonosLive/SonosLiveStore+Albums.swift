//
//  SonosLiveStore+Albums.swift
//  SonosLive
//
//  Moving between whole albums of a queue, for playlists that hold one
//  album after another, like a label's playlist with every episode of an
//  audio drama series. The Control API can't jump to a track by its
//  position, so the group skips track by track, paused and therefore
//  silent, until the album changes, and then plays.
//
//  "Random album" lets shuffle pick a track, turns shuffle off again (the
//  queue returns to its order around that track) and goes back to the
//  start of the track's album.
//

import Foundation
import SonosSDK

public enum SonosAlbumNavigationError: LocalizedError, Equatable {
    /// The playing track doesn't say which album it belongs to.
    case noAlbum

    public var errorDescription: String? {
        switch self {
        case .noAlbum: return "The playing track has no album."
        }
    }
}

extension SonosLiveStore {

    /// At most this many tracks are skipped in one move.
    static let maximumAlbumSteps = 80

    /// Plays the next album of the queue from its first track.
    public func playNextAlbum(_ group: SonosGroupModel) async throws {
        try await movingAlbums(group) { [self] in
            let album = try albumName(of: group)
            for _ in 0..<Self.maximumAlbumSteps {
                guard try await step(group, forward: true) else { return }
                if try albumName(of: group) != album { return }
            }
        }
    }

    /// Plays the previous album of the queue from its first track.
    public func playPreviousAlbum(_ group: SonosGroupModel) async throws {
        try await movingAlbums(group) { [self] in
            try await rewindToAlbumStart(group)
            if try await step(group, forward: false) {
                try await rewindToAlbumStart(group)
            }
        }
    }

    /// Plays the current album again from its first track.
    public func restartAlbum(_ group: SonosGroupModel) async throws {
        try await movingAlbums(group) { [self] in
            try await rewindToAlbumStart(group)
        }
    }

    /// Plays a random album of the queue from its first track, in order.
    public func playRandomAlbum(_ group: SonosGroupModel) async throws {
        try await movingAlbums(group) { [self] in
            let groupId = group.groupId
            try await backend.setPlayModes(groupId: groupId, playModes: PlayModesBody(shuffle: true, repeat: false, repeatOne: false))
            _ = try await step(group, forward: true)
            try await backend.setPlayModes(groupId: groupId, playModes: PlayModesBody(shuffle: false))
            try await rewindToAlbumStart(group)
        }
    }

    // MARK: - Moving

    /// Pauses `group`, runs `moves` and plays. One move per group at a time.
    private func movingAlbums(_ group: SonosGroupModel, _ moves: () async throws -> Void) async throws {
        let groupId = group.groupId
        guard !movingGroupIds.contains(groupId) else { return }
        _ = try albumName(of: group)
        movingGroupIds.insert(groupId)
        defer { movingGroupIds.remove(groupId) }
        if group.isPlaying {
            try await backend.pause(groupId: groupId)
        }
        try await moves()
        try await backend.play(groupId: groupId)
    }

    /// Goes back to the first track of the current album.
    private func rewindToAlbumStart(_ group: SonosGroupModel) async throws {
        let album = try albumName(of: group)
        // A step back within the first seconds of a track goes to the previous one; later it restarts the track.
        try await backend.seek(groupId: group.groupId, positionMillis: 0)
        for _ in 0..<Self.maximumAlbumSteps {
            guard try await step(group, forward: false) else { break }
            if try albumName(of: group) != album {
                _ = try await step(group, forward: true)
                break
            }
        }
        try await backend.seek(groupId: group.groupId, positionMillis: 0)
    }

    /// Skips one track; false at either end of the queue, where the track stays.
    private func step(_ group: SonosGroupModel, forward: Bool) async throws -> Bool {
        let before = Self.trackKey(group.metadata)
        do {
            if forward {
                try await backend.skipToNextTrack(groupId: group.groupId)
            } else {
                try await backend.skipToPreviousTrack(groupId: group.groupId)
            }
        } catch SonosError.apiError(let code, let reason) {
            // Past the end of the queue the players refuse to skip.
            log("[Sonos] Skip \(forward ? "forward" : "back") refused: \(reason ?? code)")
            return false
        } catch SonosError.httpError(let status, _) where status == 504 {
            // The cloud stopped waiting for busy players; the skip may still happen.
            log("[Sonos] Skip \(forward ? "forward" : "back") timed out in the cloud")
        }
        return try await awaitTrackChange(of: group, from: before)
    }

    /// Waits for the new track: live events usually report it within a few
    /// hundred milliseconds; without them, or when none comes, the players are asked.
    private func awaitTrackChange(of group: SonosGroupModel, from before: String) async throws -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: trackChangeTimeout)
        var lastRead = clock.now
        while clock.now < deadline {
            if Self.trackKey(group.metadata) != before { return true }
            if !group.isLive, clock.now - lastRead >= .milliseconds(300) {
                group.applyMetadata(try await backend.getGroupPlaybackMetadata(groupId: group.groupId, useCache: false))
                lastRead = clock.now
                continue
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        let metadata = try await backend.getGroupPlaybackMetadata(groupId: group.groupId, useCache: false)
        group.applyMetadata(metadata)
        return Self.trackKey(metadata) != before
    }

    private func albumName(of group: SonosGroupModel) throws -> String {
        guard let name = group.metadata?.currentItem?.track?.album?.name, !name.isEmpty else {
            throw SonosAlbumNavigationError.noAlbum
        }
        return name
    }

    /// Tells tracks of a queue apart, even the same song at two places.
    static func trackKey(_ metadata: PlaybackMetadata?) -> String {
        let item = metadata?.currentItem
        return [item?.id, item?.track?.id?.objectId, item?.track?.name, item?.track?.album?.name]
            .map { $0 ?? "" }
            .joined(separator: "|")
    }
}

extension SonosGroupModel {

    /// The queue plays whole albums one after another, like a playlist with
    /// every episode of an audio drama series: it isn't an album itself, and
    /// the next track belongs to the same album as the playing one.
    public var playsAlbumsInSequence: Bool {
        guard let album = metadata?.currentItem?.track?.album?.name, !album.isEmpty,
              let container = metadata?.container, container.name != album,
              container.type?.localizedCaseInsensitiveContains("album") != true else { return false }
        return metadata?.nextItem?.track?.album?.name == album
    }

    /// The album of the playing track.
    public var albumName: String? {
        metadata?.currentItem?.track?.album?.name
    }
}
