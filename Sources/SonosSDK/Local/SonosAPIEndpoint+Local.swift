//
//  SonosAPIEndpoint+Local.swift
//  SonosSDK
//
//  Which cloud endpoints the players also answer over their local socket.
//  These are sent over the LAN when a live client is connected and fall back
//  to the cloud otherwise. Favorites, playlists, sessions and settings stay
//  cloud-only, except in local-only mode, where the players' local REST API
//  answers them (`localTarget`, `SonosLocalHTTPClient`).
//

import Foundation

struct SonosLocalRoute: Sendable {
    let namespace: String
    let command: String
    let target: SonosLocalTarget
    let body: (any Encodable & Sendable)?

    init(_ namespace: String, _ command: String, _ target: SonosLocalTarget, body: (any Encodable & Sendable)? = nil) {
        self.namespace = namespace
        self.command = command
        self.target = target
        self.body = body
    }
}

extension SonosAPIEndpoint {

    var localRoute: SonosLocalRoute? {
        switch self {
        // Groups
        case .getGroups(let householdId):
            return SonosLocalRoute("groups", "getGroups", .household(householdId))
        case .createGroup(let householdId, let playerIds, let musicContextGroupId):
            return SonosLocalRoute("groups", "createGroup", .household(householdId),
                                   body: CreateGroupBody(playerIds: playerIds, musicContextGroupId: musicContextGroupId))
        case .modifyGroupMembers(let groupId, let add, let remove):
            return SonosLocalRoute("groups", "modifyGroupMembers", .group(groupId),
                                   body: ModifyGroupMembersBody(playerIdsToAdd: add, playerIdsToRemove: remove))

        // Playback
        case .getPlaybackStatus(let groupId):
            return SonosLocalRoute("playback", "getPlaybackStatus", .group(groupId))
        case .play(let groupId):
            return SonosLocalRoute("playback", "play", .group(groupId))
        case .pause(let groupId):
            return SonosLocalRoute("playback", "pause", .group(groupId))
        case .togglePlayPause(let groupId):
            return SonosLocalRoute("playback", "togglePlayPause", .group(groupId))
        case .skipToNextTrack(let groupId):
            return SonosLocalRoute("playback", "skipToNextTrack", .group(groupId))
        case .skipToPreviousTrack(let groupId):
            return SonosLocalRoute("playback", "skipToPreviousTrack", .group(groupId))
        case .seek(let groupId, let positionMillis):
            return SonosLocalRoute("playback", "seek", .group(groupId), body: SeekBody(positionMillis: positionMillis))
        case .seekRelative(let groupId, let deltaMillis, let itemId):
            return SonosLocalRoute("playback", "seekRelative", .group(groupId),
                                   body: SeekRelativeBody(deltaMillis: deltaMillis, itemId: itemId))
        case .setPlayModes(let groupId, let playModes):
            return SonosLocalRoute("playback", "setPlayModes", .group(groupId), body: SetPlayModesBody(playModes: playModes))
        case .loadLineIn(let groupId, let deviceId, let playOnCompletion):
            return SonosLocalRoute("playback", "loadLineIn", .group(groupId),
                                   body: LoadLineInBody(deviceId: deviceId, playOnCompletion: playOnCompletion))
        case .loadContent(let groupId, let content, let play):
            return SonosLocalRoute("playback", "loadContent", .group(groupId),
                                   body: LoadContentBody(content: content, play: play))

        // Metadata
        case .getMetadataStatus(let groupId):
            return SonosLocalRoute("playbackMetadata", "getMetadataStatus", .group(groupId))

        // Group volume
        case .getGroupVolume(let groupId):
            return SonosLocalRoute("groupVolume", "getVolume", .group(groupId))
        case .setGroupVolume(let groupId, let volume):
            return SonosLocalRoute("groupVolume", "setVolume", .group(groupId), body: VolumeBody(volume: volume))
        case .setGroupMute(let groupId, let muted):
            return SonosLocalRoute("groupVolume", "setMute", .group(groupId), body: MuteBody(muted: muted))
        case .setGroupRelativeVolume(let groupId, let volumeDelta):
            return SonosLocalRoute("groupVolume", "setRelativeVolume", .group(groupId),
                                   body: RelativeVolumeBody(volumeDelta: volumeDelta))

        // Player volume
        case .getPlayerVolume(let playerId):
            return SonosLocalRoute("playerVolume", "getVolume", .player(playerId))
        case .setPlayerVolume(let playerId, let volume):
            return SonosLocalRoute("playerVolume", "setVolume", .player(playerId), body: VolumeBody(volume: volume))
        case .setPlayerMute(let playerId, let muted):
            return SonosLocalRoute("playerVolume", "setMute", .player(playerId), body: MuteBody(muted: muted))
        case .setPlayerRelativeVolume(let playerId, let volumeDelta):
            return SonosLocalRoute("playerVolume", "setRelativeVolume", .player(playerId),
                                   body: RelativeVolumeBody(volumeDelta: volumeDelta))

        default:
            return nil
        }
    }
}

extension SonosAPIEndpoint {

    /// Which player's local REST API takes this call (`SonosLocalHTTPClient`):
    /// the group's coordinator, the player itself, or any player of the
    /// household. Nil for calls only the cloud answers (sign-in, cloud
    /// subscriptions, playback sessions).
    var localTarget: SonosLocalTarget? {
        if let route = localRoute { return route.target }
        switch self {
        case .getHousehold(let householdId),
             .setGroupMembers(let householdId, _),
             .getFavorites(let householdId),
             .getPlaylists(let householdId),
             .getPlaylist(let householdId, _),
             .matchMusicServiceAccount(let householdId, _):
            return .household(householdId)
        case .loadFavorite(let groupId, _, _, _, _),
             .loadPlaylist(let groupId, _, _, _, _):
            return .group(groupId)
        case .duckPlayerVolume(let playerId),
             .unduckPlayerVolume(let playerId),
             .loadAudioClip(let playerId, _),
             .cancelAudioClip(let playerId, _),
             .getHomeTheaterOptions(let playerId),
             .setHomeTheaterOptions(let playerId, _, _),
             .loadHomeTheaterPlayback(let playerId),
             .setTvPowerState(let playerId, _),
             .getPlayerSettings(let playerId),
             .setPlayerSettings(let playerId, _):
            return .player(playerId)
        default:
            return nil
        }
    }

    /// The path on a player: the cloud's path without `/control`.
    var localPath: String {
        let cloudPrefix = "/control"
        return path.hasPrefix(cloudPrefix + "/") ? String(path.dropFirst(cloudPrefix.count)) : path
    }
}
