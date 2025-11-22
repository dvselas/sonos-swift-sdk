//
//  ServiceExtensions+Async.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation

// MARK: - GroupPlaybackService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension GroupPlaybackService {

    func getGroupPlaybackStatus(authenticationToken: AuthenticationToken, groupId: String) async throws -> PlaybackStatus {
        try await withCheckedThrowingContinuation { continuation in
            getGroupPlaybackStatus(authenticationToken: authenticationToken, groupId: groupId) { status in
                continuation.resume(returning: status)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupPlaybackPlay(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupPlaybackPlay(authenticationToken: authenticationToken, groupId: groupId) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupPlaybackPause(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupPlaybackPause(authenticationToken: authenticationToken, groupId: groupId) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupPlaybackModes(authenticationToken: AuthenticationToken, groupId: String, playModes: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupPlaybackModes(authenticationToken: authenticationToken, groupId: groupId, playModes: playModes) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupSkipToNext(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupSkipToNext(authenticationToken: authenticationToken, groupId: groupId) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupSkipToPrevious(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupSkipToPrevious(authenticationToken: authenticationToken, groupId: groupId) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupSkipToSeek(authenticationToken: AuthenticationToken, groupId: String, positionMillis: UInt) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupSkipToSeek(authenticationToken: authenticationToken, groupId: groupId, positionMillis: positionMillis) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func togglePlayPause(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            togglePlayPause(authenticationToken: authenticationToken, groupId: groupId) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func seekRelative(authenticationToken: AuthenticationToken, groupId: String, itemId: String? = nil, deltaMillis: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            seekRelative(authenticationToken: authenticationToken, groupId: groupId, itemId: itemId, deltaMillis: deltaMillis) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func loadLineIn(authenticationToken: AuthenticationToken, groupId: String, deviceId: String? = nil, playOnCompletion: Bool? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loadLineIn(authenticationToken: authenticationToken, groupId: groupId, deviceId: deviceId, playOnCompletion: playOnCompletion) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - GroupVolumeService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension GroupVolumeService {

    func getVolume(authenticationToken: AuthenticationToken, groupId: String) async throws -> GroupVolume {
        try await withCheckedThrowingContinuation { continuation in
            getVolume(authenticationToken: authenticationToken, groupId: groupId) { volume in
                continuation.resume(returning: volume)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setVolume(authenticationToken: AuthenticationToken, groupId: String, volume: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setVolume(authenticationToken: authenticationToken, groupId: groupId, volume: volume) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setMuted(authenticationToken: AuthenticationToken, groupId: String, muted: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setMuted(authenticationToken: authenticationToken, groupId: groupId, muted: muted) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setRelativeVolume(authenticationToken: AuthenticationToken, groupId: String, relativeVolume: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setRelativeVolume(authenticationToken: authenticationToken, groupId: groupId, relativeVolume: relativeVolume) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func subscribe(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            subscribe(authenticationToken: authenticationToken, groupId: groupId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func unsubscribe(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unsubscribe(authenticationToken: authenticationToken, groupId: groupId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - PlayerVolumeService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension PlayerVolumeService {

    func getVolume(authenticationToken: AuthenticationToken, playerId: String) async throws -> PlayerVolume {
        try await withCheckedThrowingContinuation { continuation in
            getVolume(authenticationToken: authenticationToken, playerID: playerId) { volume in
                continuation.resume(returning: volume)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setVolume(authenticationToken: AuthenticationToken, playerId: String, volume: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setVolume(authenticationToken: authenticationToken, playerID: playerId, volume: volume) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setMuted(authenticationToken: AuthenticationToken, playerId: String, muted: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setMuted(authenticationToken: authenticationToken, playerID: playerId, muted: muted) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setRelativeVolume(authenticationToken: AuthenticationToken, playerId: String, relativeVolume: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setRelativeVolume(authenticationToken: authenticationToken, playerID: playerId, relativeVolume: relativeVolume) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func subscribe(authenticationToken: AuthenticationToken, playerId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            subscribe(authenticationToken: authenticationToken, playerID: playerId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func unsubscribe(authenticationToken: AuthenticationToken, playerId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unsubscribe(authenticationToken: authenticationToken, playerID: playerId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - GroupService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension GroupService {

    func getGroups(authenticationToken: AuthenticationToken, householdId: String) async throws -> ([Group], [Player]) {
        try await withCheckedThrowingContinuation { continuation in
            getGroups(authenticationToken: authenticationToken, householdId: householdId) { groups, players in
                continuation.resume(returning: (groups, players))
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func createGroup(authenticationToken: AuthenticationToken, householdId: String, playerIds: [String], musicContextGroupId: String? = nil) async throws -> Group {
        try await withCheckedThrowingContinuation { continuation in
            createGroup(authenticationToken: authenticationToken, householdId: householdId, playerIds: playerIds, musicContextGroupId: musicContextGroupId) { group in
                continuation.resume(returning: group)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupMembers(authenticationToken: AuthenticationToken, householdId: String, playerIds: [String]) async throws -> Group {
        try await withCheckedThrowingContinuation { continuation in
            setGroupMembers(authenticationToken: authenticationToken, householdId: householdId, playerIds: playerIds) { group in
                continuation.resume(returning: group)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func subscribe(authenticationToken: AuthenticationToken, householdId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            subscribe(authenticationToken: authenticationToken, householdId: householdId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func unsubscribe(authenticationToken: AuthenticationToken, householdId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unsubscribe(authenticationToken: authenticationToken, householdId: householdId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - PlayerService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension PlayerService {

    func getPlayers(authenticationToken: AuthenticationToken, householdId: String) async throws -> [Player] {
        try await withCheckedThrowingContinuation { continuation in
            getPlayers(authenticationToken: authenticationToken, householdId: householdId) { players in
                continuation.resume(returning: players)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - PlaybackSessionService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension PlaybackSessionService {

    func createSession(authenticationToken: AuthenticationToken, groupId: String, appId: String, appContext: String, accountId: String? = nil, customData: String? = nil) async throws -> PlaybackSession {
        try await withCheckedThrowingContinuation { continuation in
            createSession(authenticationToken: authenticationToken, groupId: groupId, appId: appId, appContext: appContext, accountId: accountId, customData: customData) { session in
                continuation.resume(returning: session)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func joinSession(authenticationToken: AuthenticationToken, groupId: String, appId: String, appContext: String) async throws -> PlaybackSession {
        try await withCheckedThrowingContinuation { continuation in
            joinSession(authenticationToken: authenticationToken, groupId: groupId, appId: appId, appContext: appContext) { session in
                continuation.resume(returning: session)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func suspendSession(authenticationToken: AuthenticationToken, sessionId: String, queueVersion: String? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            suspendSession(authenticationToken: authenticationToken, sessionId: sessionId, queueVersion: queueVersion) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func loadCloudQueue(authenticationToken: AuthenticationToken, sessionId: String, queueBaseUrl: String, httpAuthorization: String? = nil, itemId: String? = nil, playOnCompletion: Bool? = nil, positionMillis: UInt? = nil, queueVersion: String? = nil, trackMetadata: [String: Any]? = nil, useHttpAuthorizationForMedia: Bool? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loadCloudQueue(authenticationToken: authenticationToken, sessionId: sessionId, queueBaseUrl: queueBaseUrl, httpAuthorization: httpAuthorization, itemId: itemId, playOnCompletion: playOnCompletion, positionMillis: positionMillis, queueVersion: queueVersion, trackMetadata: trackMetadata, useHttpAuthorizationForMedia: useHttpAuthorizationForMedia) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func refreshCloudQueue(authenticationToken: AuthenticationToken, sessionId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            refreshCloudQueue(authenticationToken: authenticationToken, sessionId: sessionId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func loadStreamUrl(authenticationToken: AuthenticationToken, sessionId: String, streamUrl: String, playOnCompletion: Bool? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loadStreamUrl(authenticationToken: authenticationToken, sessionId: sessionId, streamUrl: streamUrl, playOnCompletion: playOnCompletion) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func sessionSeek(authenticationToken: AuthenticationToken, sessionId: String, positionMillis: UInt, itemId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionSeek(authenticationToken: authenticationToken, sessionId: sessionId, positionMillis: positionMillis, itemId: itemId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func sessionSeekRelative(authenticationToken: AuthenticationToken, sessionId: String, deltaMillis: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionSeekRelative(authenticationToken: authenticationToken, sessionId: sessionId, deltaMillis: deltaMillis) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func sessionSkipToItem(authenticationToken: AuthenticationToken, sessionId: String, itemId: String, playOnCompletion: Bool? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionSkipToItem(authenticationToken: authenticationToken, sessionId: sessionId, itemId: itemId, playOnCompletion: playOnCompletion) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func subscribe(authenticationToken: AuthenticationToken, sessionId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            subscribe(authenticationToken: authenticationToken, sessionId: sessionId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func unsubscribe(authenticationToken: AuthenticationToken, sessionId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unsubscribe(authenticationToken: authenticationToken, sessionId: sessionId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - PlaylistService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension PlaylistService {

    func getPlaylists(authenticationToken: AuthenticationToken, householdId: String) async throws -> [Playlist] {
        try await withCheckedThrowingContinuation { continuation in
            getPlaylists(authenticationToken: authenticationToken, householdId: householdId) { playlists in
                continuation.resume(returning: playlists)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func getPlaylist(authenticationToken: AuthenticationToken, householdId: String, playlistId: String) async throws -> Playlist {
        try await withCheckedThrowingContinuation { continuation in
            getPlaylist(authenticationToken: authenticationToken, householdId: householdId, playlistId: playlistId) { playlist in
                continuation.resume(returning: playlist)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func loadPlaylist(authenticationToken: AuthenticationToken, groupId: String, action: String? = nil, playlistId: String, playOnCompletion: Bool? = nil, playModes: [String]? = nil) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loadPlaylist(authenticationToken: authenticationToken, groupId: groupId, action: action, playlistId: playlistId, playOnCompletion: playOnCompletion, playModes: playModes) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func subscribe(authenticationToken: AuthenticationToken, householdId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            subscribe(authenticationToken: authenticationToken, householdId: householdId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func unsubscribe(authenticationToken: AuthenticationToken, householdId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unsubscribe(authenticationToken: authenticationToken, householdId: householdId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - MusicServiceAccountsService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension MusicServiceAccountsService {

    func matchAccount(authenticationToken: AuthenticationToken, householdId: String, serviceId: String, userIdHashCode: String, nickname: String, linkCode: String? = nil, linkDeviceId: String? = nil) async throws -> MusicServiceAccount {
        try await withCheckedThrowingContinuation { continuation in
            matchAccount(authenticationToken: authenticationToken, householdId: householdId, serviceId: serviceId, userIdHashCode: userIdHashCode, nickname: nickname, linkCode: linkCode, linkDeviceId: linkDeviceId) { account in
                continuation.resume(returning: account)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - GroupMetadataService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension GroupMetadataService {

    func getGroupPlaybackMetadata(authenticationToken: AuthenticationToken, groupId: String) async throws -> PlaybackMetadata {
        try await withCheckedThrowingContinuation { continuation in
            getGroupPlaybackMetadata(authenticationToken: authenticationToken, groupId: groupId) { metadata in
                continuation.resume(returning: metadata)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}
