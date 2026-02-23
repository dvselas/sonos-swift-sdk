//
//  SonosAPIEndpoint.swift
//  SonosSDK
//
//  Created on 2026-02-23.
//

import Foundation

// MARK: - HTTP Method

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

// MARK: - API Host

enum SonosHost {
    static let authorization = "api.sonos.com"
    static let control = "api.ws.sonos.com"
}

// MARK: - Subscription Namespace

public enum SonosNamespace: String, CaseIterable, Sendable {
    case playback
    case playbackMetadata
    case groupVolume
    case playerVolume
    case groups
    case favorites
    case playlists
    case audioClip
    case playbackSession
}

// MARK: - API Endpoint

public enum SonosAPIEndpoint: Sendable {

    // MARK: - Authorization
    case createToken(authCode: String, redirectURI: String)
    case refreshToken(refreshToken: String)

    // MARK: - Households
    case getHouseholds
    case getHousehold(householdId: String)

    // MARK: - Groups
    case getGroups(householdId: String)
    case createGroup(householdId: String, playerIds: [String], musicContextGroupId: String?)
    case modifyGroupMembers(groupId: String, playerIdsToAdd: [String], playerIdsToRemove: [String])
    case setGroupMembers(householdId: String, playerIds: [String])
    case subscribeToGroups(householdId: String)
    case unsubscribeFromGroups(householdId: String)

    // MARK: - Playback
    case getPlaybackStatus(groupId: String)
    case play(groupId: String)
    case pause(groupId: String)
    case togglePlayPause(groupId: String)
    case skipToNextTrack(groupId: String)
    case skipToPreviousTrack(groupId: String)
    case seek(groupId: String, positionMillis: UInt)
    case seekRelative(groupId: String, deltaMillis: Int, itemId: String?)
    case setPlayModes(groupId: String, playModes: PlayModesBody)
    case loadLineIn(groupId: String, deviceId: String?, playOnCompletion: Bool?)
    case subscribeToPlayback(groupId: String)
    case unsubscribeFromPlayback(groupId: String)

    // MARK: - Playback Metadata
    case getMetadataStatus(groupId: String)
    case subscribeToPlaybackMetadata(groupId: String)
    case unsubscribeFromPlaybackMetadata(groupId: String)

    // MARK: - Playback Session
    case createSession(groupId: String, appId: String, appContext: String?, customData: String?)
    case joinSession(sessionId: String, appId: String, appContext: String?)
    case joinOrCreateSession(groupId: String, appId: String, appContext: String?, customData: String?)
    case suspendSession(sessionId: String)
    case loadCloudQueue(sessionId: String, cloudQueue: CloudQueueBody)
    case refreshCloudQueue(sessionId: String)
    case loadStreamUrl(sessionId: String, streamUrl: String, item: StreamItemBody?, playOnCompletion: Bool?)
    case sessionSeek(sessionId: String, positionMillis: UInt, itemId: String?)
    case sessionSeekRelative(sessionId: String, deltaMillis: Int, itemId: String?)
    case sessionSkipToItem(sessionId: String, itemId: String, queueVersion: String?)
    case subscribeToPlaybackSession(sessionId: String)
    case unsubscribeFromPlaybackSession(sessionId: String)

    // MARK: - Group Volume
    case getGroupVolume(groupId: String)
    case setGroupVolume(groupId: String, volume: Int)
    case setGroupMute(groupId: String, muted: Bool)
    case setGroupRelativeVolume(groupId: String, volumeDelta: Int)
    case subscribeToGroupVolume(groupId: String)
    case unsubscribeFromGroupVolume(groupId: String)

    // MARK: - Player Volume
    case getPlayerVolume(playerId: String)
    case setPlayerVolume(playerId: String, volume: Int)
    case setPlayerMute(playerId: String, muted: Bool)
    case setPlayerRelativeVolume(playerId: String, volumeDelta: Int)
    case duckPlayerVolume(playerId: String)
    case unduckPlayerVolume(playerId: String)
    case subscribeToPlayerVolume(playerId: String)
    case unsubscribeFromPlayerVolume(playerId: String)

    // MARK: - Audio Clip
    case loadAudioClip(playerId: String, clip: AudioClipBody)
    case cancelAudioClip(playerId: String, clipId: String)
    case subscribeToAudioClip(playerId: String)
    case unsubscribeFromAudioClip(playerId: String)

    // MARK: - Favorites
    case getFavorites(householdId: String)
    case loadFavorite(groupId: String, favoriteId: String, playOnCompletion: Bool?, action: String?)
    case subscribeToFavorites(householdId: String)
    case unsubscribeFromFavorites(householdId: String)

    // MARK: - Playlists
    case getPlaylists(householdId: String)
    case getPlaylist(householdId: String, playlistId: String)
    case loadPlaylist(groupId: String, playlistId: String, playOnCompletion: Bool?, playModes: PlayModesBody?)
    case subscribeToPlaylists(householdId: String)
    case unsubscribeFromPlaylists(householdId: String)

    // MARK: - Home Theater
    case getHomeTheaterOptions(playerId: String)
    case setHomeTheaterOptions(playerId: String, nightMode: Bool?, enhanceDialog: Bool?)
    case loadHomeTheaterPlayback(playerId: String)
    case setTvPowerState(playerId: String, powerState: String)

    // MARK: - Player Settings
    case getPlayerSettings(playerId: String)
    case setPlayerSettings(playerId: String, settings: PlayerSettingsBody)

    // MARK: - Music Service Accounts
    case matchMusicServiceAccount(householdId: String, account: MusicServiceAccountBody)
}

// MARK: - Endpoint Properties

extension SonosAPIEndpoint {

    var method: HTTPMethod {
        switch self {
        // GET endpoints
        case .getHouseholds, .getHousehold,
             .getGroups,
             .getPlaybackStatus, .getMetadataStatus,
             .getGroupVolume, .getPlayerVolume,
             .getFavorites, .getPlaylists, .getPlaylist,
             .getHomeTheaterOptions, .getPlayerSettings:
            return .get

        // DELETE endpoints
        case .unsubscribeFromGroups, .unsubscribeFromPlayback,
             .unsubscribeFromPlaybackMetadata, .unsubscribeFromPlaybackSession,
             .unsubscribeFromGroupVolume, .unsubscribeFromPlayerVolume,
             .unsubscribeFromAudioClip, .unsubscribeFromFavorites,
             .unsubscribeFromPlaylists,
             .cancelAudioClip:
            return .delete

        // Everything else is POST
        default:
            return .post
        }
    }

    var host: String {
        switch self {
        case .createToken, .refreshToken:
            return SonosHost.authorization
        default:
            return SonosHost.control
        }
    }

    var path: String {
        switch self {
        // Authorization
        case .createToken, .refreshToken:
            return "/login/v3/oauth/access"

        // Households
        case .getHouseholds:
            return "/control/api/v1/households"
        case .getHousehold(let householdId):
            return "/control/api/v1/households/\(householdId)"

        // Groups
        case .getGroups(let householdId):
            return "/control/api/v1/households/\(householdId)/groups"
        case .createGroup(let householdId, _, _):
            return "/control/api/v1/households/\(householdId)/groups/createGroup"
        case .setGroupMembers(let householdId, _):
            return "/control/api/v1/households/\(householdId)/groups/setGroupMembers"
        case .modifyGroupMembers(let groupId, _, _):
            return "/control/api/v1/groups/\(groupId)/groups/modifyGroupMembers"
        case .subscribeToGroups(let householdId):
            return "/control/api/v1/households/\(householdId)/groups/subscription"
        case .unsubscribeFromGroups(let householdId):
            return "/control/api/v1/households/\(householdId)/groups/subscription"

        // Playback
        case .getPlaybackStatus(let groupId):
            return "/control/api/v1/groups/\(groupId)/playback"
        case .play(let groupId):
            return "/control/api/v1/groups/\(groupId)/playback/play"
        case .pause(let groupId):
            return "/control/api/v1/groups/\(groupId)/playback/pause"
        case .togglePlayPause(let groupId):
            return "/control/api/v1/groups/\(groupId)/playback/togglePlayPause"
        case .skipToNextTrack(let groupId):
            return "/control/api/v1/groups/\(groupId)/playback/skipToNextTrack"
        case .skipToPreviousTrack(let groupId):
            return "/control/api/v1/groups/\(groupId)/playback/skipToPreviousTrack"
        case .seek(let groupId, _):
            return "/control/api/v1/groups/\(groupId)/playback/seek"
        case .seekRelative(let groupId, _, _):
            return "/control/api/v1/groups/\(groupId)/playback/seekRelative"
        case .setPlayModes(let groupId, _):
            return "/control/api/v1/groups/\(groupId)/playback/playMode"
        case .loadLineIn(let groupId, _, _):
            return "/control/api/v1/groups/\(groupId)/playback/lineIn"
        case .subscribeToPlayback(let groupId):
            return "/control/api/v1/groups/\(groupId)/playback/subscription"
        case .unsubscribeFromPlayback(let groupId):
            return "/control/api/v1/groups/\(groupId)/playback/subscription"

        // Playback Metadata
        case .getMetadataStatus(let groupId):
            return "/control/api/v1/groups/\(groupId)/playbackMetadata"
        case .subscribeToPlaybackMetadata(let groupId):
            return "/control/api/v1/groups/\(groupId)/playbackMetadata/subscription"
        case .unsubscribeFromPlaybackMetadata(let groupId):
            return "/control/api/v1/groups/\(groupId)/playbackMetadata/subscription"

        // Playback Session
        case .createSession(let groupId, _, _, _):
            return "/control/api/v1/groups/\(groupId)/playbackSession"
        case .joinSession(let sessionId, _, _):
            return "/control/api/v1/playbackSessions/\(sessionId)/playbackSession/join"
        case .joinOrCreateSession(let groupId, _, _, _):
            return "/control/api/v1/groups/\(groupId)/playbackSession/joinOrCreate"
        case .suspendSession(let sessionId):
            return "/control/api/v1/playbackSessions/\(sessionId)/playbackSession/suspend"
        case .loadCloudQueue(let sessionId, _):
            return "/control/api/v1/playbackSessions/\(sessionId)/playbackSession/loadCloudQueue"
        case .refreshCloudQueue(let sessionId):
            return "/control/api/v1/playbackSessions/\(sessionId)/playbackSession/refreshCloudQueue"
        case .loadStreamUrl(let sessionId, _, _, _):
            return "/control/api/v1/playbackSessions/\(sessionId)/playbackSession/loadStreamUrl"
        case .sessionSeek(let sessionId, _, _):
            return "/control/api/v1/playbackSessions/\(sessionId)/playbackSession/seek"
        case .sessionSeekRelative(let sessionId, _, _):
            return "/control/api/v1/playbackSessions/\(sessionId)/playbackSession/seekRelative"
        case .sessionSkipToItem(let sessionId, _, _):
            return "/control/api/v1/playbackSessions/\(sessionId)/playbackSession/skipToItem"
        case .subscribeToPlaybackSession(let sessionId):
            return "/control/api/v1/playbackSessions/\(sessionId)/playbackSession/subscription"
        case .unsubscribeFromPlaybackSession(let sessionId):
            return "/control/api/v1/playbackSessions/\(sessionId)/playbackSession/subscription"

        // Group Volume
        case .getGroupVolume(let groupId):
            return "/control/api/v1/groups/\(groupId)/groupVolume"
        case .setGroupVolume(let groupId, _):
            return "/control/api/v1/groups/\(groupId)/groupVolume"
        case .setGroupMute(let groupId, _):
            return "/control/api/v1/groups/\(groupId)/groupVolume/mute"
        case .setGroupRelativeVolume(let groupId, _):
            return "/control/api/v1/groups/\(groupId)/groupVolume/relative"
        case .subscribeToGroupVolume(let groupId):
            return "/control/api/v1/groups/\(groupId)/groupVolume/subscription"
        case .unsubscribeFromGroupVolume(let groupId):
            return "/control/api/v1/groups/\(groupId)/groupVolume/subscription"

        // Player Volume
        case .getPlayerVolume(let playerId):
            return "/control/api/v1/players/\(playerId)/playerVolume"
        case .setPlayerVolume(let playerId, _):
            return "/control/api/v1/players/\(playerId)/playerVolume"
        case .setPlayerMute(let playerId, _):
            return "/control/api/v1/players/\(playerId)/playerVolume/mute"
        case .setPlayerRelativeVolume(let playerId, _):
            return "/control/api/v1/players/\(playerId)/playerVolume/relative"
        case .duckPlayerVolume(let playerId):
            return "/control/api/v1/players/\(playerId)/playerVolume/duck"
        case .unduckPlayerVolume(let playerId):
            return "/control/api/v1/players/\(playerId)/playerVolume/unduck"
        case .subscribeToPlayerVolume(let playerId):
            return "/control/api/v1/players/\(playerId)/playerVolume/subscription"
        case .unsubscribeFromPlayerVolume(let playerId):
            return "/control/api/v1/players/\(playerId)/playerVolume/subscription"

        // Audio Clip
        case .loadAudioClip(let playerId, _):
            return "/control/api/v1/players/\(playerId)/audioClip"
        case .cancelAudioClip(let playerId, let clipId):
            return "/control/api/v1/players/\(playerId)/audioClip/\(clipId)"
        case .subscribeToAudioClip(let playerId):
            return "/control/api/v1/players/\(playerId)/audioClip/subscription"
        case .unsubscribeFromAudioClip(let playerId):
            return "/control/api/v1/players/\(playerId)/audioClip/subscription"

        // Favorites
        case .getFavorites(let householdId):
            return "/control/api/v1/households/\(householdId)/favorites"
        case .loadFavorite(let groupId, _, _, _):
            return "/control/api/v1/groups/\(groupId)/favorites"
        case .subscribeToFavorites(let householdId):
            return "/control/api/v1/households/\(householdId)/favorites/subscription"
        case .unsubscribeFromFavorites(let householdId):
            return "/control/api/v1/households/\(householdId)/favorites/subscription"

        // Playlists
        case .getPlaylists(let householdId):
            return "/control/api/v1/households/\(householdId)/playlists"
        case .getPlaylist(let householdId, let playlistId):
            return "/control/api/v1/households/\(householdId)/playlists/\(playlistId)"
        case .loadPlaylist(let groupId, _, _, _):
            return "/control/api/v1/groups/\(groupId)/playlists"
        case .subscribeToPlaylists(let householdId):
            return "/control/api/v1/households/\(householdId)/playlists/subscription"
        case .unsubscribeFromPlaylists(let householdId):
            return "/control/api/v1/households/\(householdId)/playlists/subscription"

        // Home Theater
        case .getHomeTheaterOptions(let playerId):
            return "/control/api/v1/players/\(playerId)/homeTheater/options"
        case .setHomeTheaterOptions(let playerId, _, _):
            return "/control/api/v1/players/\(playerId)/homeTheater/options"
        case .loadHomeTheaterPlayback(let playerId):
            return "/control/api/v1/players/\(playerId)/homeTheater"
        case .setTvPowerState(let playerId, _):
            return "/control/api/v1/players/\(playerId)/homeTheater/tvPowerState"

        // Player Settings
        case .getPlayerSettings(let playerId):
            return "/control/api/v1/players/\(playerId)/settings/player"
        case .setPlayerSettings(let playerId, _):
            return "/control/api/v1/players/\(playerId)/settings/player"

        // Music Service Accounts
        case .matchMusicServiceAccount(let householdId, _):
            return "/control/api/v1/households/\(householdId)/musicServiceAccounts/match"
        }
    }

    var body: Encodable? {
        switch self {
        // Authorization
        case .createToken(let authCode, let redirectURI):
            return TokenRequestBody(grantType: "authorization_code", code: authCode, redirectUri: redirectURI)
        case .refreshToken(let refreshToken):
            return RefreshTokenRequestBody(grantType: "refresh_token", refreshToken: refreshToken)

        // Groups
        case .createGroup(_, let playerIds, let musicContextGroupId):
            return CreateGroupBody(playerIds: playerIds, musicContextGroupId: musicContextGroupId)
        case .modifyGroupMembers(_, let add, let remove):
            return ModifyGroupMembersBody(playerIdsToAdd: add, playerIdsToRemove: remove)
        case .setGroupMembers(_, let playerIds):
            return SetGroupMembersBody(playerIds: playerIds)

        // Playback
        case .seek(_, let positionMillis):
            return SeekBody(positionMillis: positionMillis)
        case .seekRelative(_, let deltaMillis, let itemId):
            return SeekRelativeBody(deltaMillis: deltaMillis, itemId: itemId)
        case .setPlayModes(_, let playModes):
            return playModes
        case .loadLineIn(_, let deviceId, let playOnCompletion):
            return LoadLineInBody(deviceId: deviceId, playOnCompletion: playOnCompletion)

        // Playback Session
        case .createSession(_, let appId, let appContext, let customData):
            return CreateSessionBody(appId: appId, appContext: appContext, customData: customData)
        case .joinSession(_, let appId, let appContext):
            return JoinSessionBody(appId: appId, appContext: appContext)
        case .joinOrCreateSession(_, let appId, let appContext, let customData):
            return JoinOrCreateSessionBody(appId: appId, appContext: appContext, customData: customData)
        case .loadCloudQueue(_, let cloudQueue):
            return cloudQueue
        case .loadStreamUrl(_, let streamUrl, let item, let playOnCompletion):
            return LoadStreamUrlBody(streamUrl: streamUrl, item: item, playOnCompletion: playOnCompletion)
        case .sessionSeek(_, let positionMillis, let itemId):
            return SessionSeekBody(positionMillis: positionMillis, itemId: itemId)
        case .sessionSeekRelative(_, let deltaMillis, let itemId):
            return SeekRelativeBody(deltaMillis: deltaMillis, itemId: itemId)
        case .sessionSkipToItem(_, let itemId, let queueVersion):
            return SkipToItemBody(itemId: itemId, queueVersion: queueVersion)

        // Volume
        case .setGroupVolume(_, let volume):
            return VolumeBody(volume: volume)
        case .setGroupMute(_, let muted):
            return MuteBody(muted: muted)
        case .setGroupRelativeVolume(_, let volumeDelta):
            return RelativeVolumeBody(volumeDelta: volumeDelta)
        case .setPlayerVolume(_, let volume):
            return VolumeBody(volume: volume)
        case .setPlayerMute(_, let muted):
            return MuteBody(muted: muted)
        case .setPlayerRelativeVolume(_, let volumeDelta):
            return RelativeVolumeBody(volumeDelta: volumeDelta)

        // Audio Clip
        case .loadAudioClip(_, let clip):
            return clip

        // Favorites
        case .loadFavorite(_, let favoriteId, let playOnCompletion, let action):
            return LoadFavoriteBody(favoriteId: favoriteId, playOnCompletion: playOnCompletion ?? true, action: action ?? "REPLACE")

        // Playlists
        case .loadPlaylist(_, let playlistId, let playOnCompletion, let playModes):
            return LoadPlaylistBody(playlistId: playlistId, playOnCompletion: playOnCompletion ?? true, playModes: playModes)

        // Home Theater
        case .setHomeTheaterOptions(_, let nightMode, let enhanceDialog):
            return HomeTheaterOptionsBody(nightMode: nightMode, enhanceDialog: enhanceDialog)
        case .setTvPowerState(_, let powerState):
            return TvPowerStateBody(tvPowerState: powerState)

        // Player Settings
        case .setPlayerSettings(_, let settings):
            return settings

        // Music Service Accounts
        case .matchMusicServiceAccount(_, let account):
            return account

        // All other endpoints have no body
        default:
            return nil
        }
    }

    /// Whether this endpoint uses Basic auth (token endpoints) vs Bearer auth
    var usesBasicAuth: Bool {
        switch self {
        case .createToken, .refreshToken:
            return true
        default:
            return false
        }
    }

    /// Build the full URL for this endpoint
    func url() throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = path

        guard let url = components.url else {
            throw SonosError.invalidResponse
        }
        return url
    }
}

// MARK: - Request Body Types

public struct TokenRequestBody: Encodable, Sendable {
    let grantType: String
    let code: String
    let redirectUri: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case code
        case redirectUri = "redirect_uri"
    }
}

public struct RefreshTokenRequestBody: Encodable, Sendable {
    let grantType: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case grantType = "grant_type"
        case refreshToken = "refresh_token"
    }
}

struct CreateGroupBody: Encodable, Sendable {
    let playerIds: [String]
    let musicContextGroupId: String?
}

struct ModifyGroupMembersBody: Encodable, Sendable {
    let playerIdsToAdd: [String]
    let playerIdsToRemove: [String]
}

struct SetGroupMembersBody: Encodable, Sendable {
    let playerIds: [String]
}

struct SeekBody: Encodable, Sendable {
    let positionMillis: UInt
}

struct SeekRelativeBody: Encodable, Sendable {
    let deltaMillis: Int
    let itemId: String?
}

public struct PlayModesBody: Encodable, Sendable {
    public let shuffle: Bool?
    public let `repeat`: Bool?
    public let repeatOne: Bool?
    public let crossfade: Bool?

    public init(shuffle: Bool? = nil, repeat repeatValue: Bool? = nil, repeatOne: Bool? = nil, crossfade: Bool? = nil) {
        self.shuffle = shuffle
        self.`repeat` = repeatValue
        self.repeatOne = repeatOne
        self.crossfade = crossfade
    }
}

struct LoadLineInBody: Encodable, Sendable {
    let deviceId: String?
    let playOnCompletion: Bool?
}

struct CreateSessionBody: Encodable, Sendable {
    let appId: String
    let appContext: String?
    let customData: String?
}

struct JoinSessionBody: Encodable, Sendable {
    let appId: String
    let appContext: String?
}

struct JoinOrCreateSessionBody: Encodable, Sendable {
    let appId: String
    let appContext: String?
    let customData: String?
}

public struct CloudQueueBody: Encodable, Sendable {
    public let queueBaseUrl: String
    public let httpAuthorization: String?
    public let itemId: String?
    public let queueVersion: String?
    public let useHttpAuthorizationForMedia: Bool?
    public let playOnCompletion: Bool?

    public init(queueBaseUrl: String, httpAuthorization: String? = nil, itemId: String? = nil, queueVersion: String? = nil, useHttpAuthorizationForMedia: Bool? = nil, playOnCompletion: Bool? = nil) {
        self.queueBaseUrl = queueBaseUrl
        self.httpAuthorization = httpAuthorization
        self.itemId = itemId
        self.queueVersion = queueVersion
        self.useHttpAuthorizationForMedia = useHttpAuthorizationForMedia
        self.playOnCompletion = playOnCompletion
    }
}

public struct StreamItemBody: Encodable, Sendable {
    public let id: String
    public let track: StreamTrackBody?

    public init(id: String, track: StreamTrackBody? = nil) {
        self.id = id
        self.track = track
    }
}

public struct StreamTrackBody: Encodable, Sendable {
    public let name: String?
    public let durationMillis: Int?

    public init(name: String? = nil, durationMillis: Int? = nil) {
        self.name = name
        self.durationMillis = durationMillis
    }
}

struct LoadStreamUrlBody: Encodable, Sendable {
    let streamUrl: String
    let item: StreamItemBody?
    let playOnCompletion: Bool?
}

struct SessionSeekBody: Encodable, Sendable {
    let positionMillis: UInt
    let itemId: String?
}

struct SkipToItemBody: Encodable, Sendable {
    let itemId: String
    let queueVersion: String?
}

struct VolumeBody: Encodable, Sendable {
    let volume: Int
}

struct MuteBody: Encodable, Sendable {
    let muted: Bool
}

struct RelativeVolumeBody: Encodable, Sendable {
    let volumeDelta: Int
}

public struct AudioClipBody: Encodable, Sendable {
    public let appId: String
    public let clipType: String?
    public let httpAuthorization: String?
    public let name: String?
    public let priority: String?
    public let streamUrl: String?
    public let volume: Int?

    public init(appId: String, clipType: String? = nil, httpAuthorization: String? = nil, name: String? = nil, priority: String? = nil, streamUrl: String? = nil, volume: Int? = nil) {
        self.appId = appId
        self.clipType = clipType
        self.httpAuthorization = httpAuthorization
        self.name = name
        self.priority = priority
        self.streamUrl = streamUrl
        self.volume = volume
    }
}

struct LoadFavoriteBody: Encodable, Sendable {
    let favoriteId: String
    let playOnCompletion: Bool
    let action: String
}

struct LoadPlaylistBody: Encodable, Sendable {
    let playlistId: String
    let playOnCompletion: Bool
    let playModes: PlayModesBody?
}

struct HomeTheaterOptionsBody: Encodable, Sendable {
    let nightMode: Bool?
    let enhanceDialog: Bool?
}

struct TvPowerStateBody: Encodable, Sendable {
    let tvPowerState: String
}

public struct PlayerSettingsBody: Encodable, Sendable {
    public let volumeMode: String?
    public let volumeScalingFactor: Double?
    public let monoMode: Bool?
    public let wifiDisable: Bool?

    public init(volumeMode: String? = nil, volumeScalingFactor: Double? = nil, monoMode: Bool? = nil, wifiDisable: Bool? = nil) {
        self.volumeMode = volumeMode
        self.volumeScalingFactor = volumeScalingFactor
        self.monoMode = monoMode
        self.wifiDisable = wifiDisable
    }
}

public struct MusicServiceAccountBody: Encodable, Sendable {
    public let serviceId: String
    public let userIdHashCode: String
    public let nickname: String
    public let linkCode: String?
    public let linkDeviceId: String?

    public init(serviceId: String, userIdHashCode: String, nickname: String, linkCode: String? = nil, linkDeviceId: String? = nil) {
        self.serviceId = serviceId
        self.userIdHashCode = userIdHashCode
        self.nickname = nickname
        self.linkCode = linkCode
        self.linkDeviceId = linkDeviceId
    }
}
