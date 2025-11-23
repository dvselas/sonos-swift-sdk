//
//  SonosManager+PlaybackSession.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation

extension SonosManager {

    // MARK: - Playback Session (Callback-based)

    public func createPlaybackSession(groupId: String, appId: String, appContext: String, accountId: String? = nil, customData: String? = nil, success: @escaping (PlaybackSession) -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.createSession(authenticationToken: authenticationToken, groupId: groupId, appId: appId, appContext: appContext, accountId: accountId, customData: customData, success: success, failure: failure)
    }

    public func joinPlaybackSession(groupId: String, appId: String, appContext: String, success: @escaping (PlaybackSession) -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.joinSession(authenticationToken: authenticationToken, groupId: groupId, appId: appId, appContext: appContext, success: success, failure: failure)
    }

    public func suspendPlaybackSession(sessionId: String, queueVersion: String? = nil, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.suspendSession(authenticationToken: authenticationToken, sessionId: sessionId, queueVersion: queueVersion, success: success, failure: failure)
    }

    // MARK: - Cloud Queue (Callback-based)

    public func loadCloudQueue(sessionId: String, queueBaseUrl: String, httpAuthorization: String? = nil, itemId: String? = nil, playOnCompletion: Bool? = nil, positionMillis: UInt? = nil, queueVersion: String? = nil, trackMetadata: [String: Any]? = nil, useHttpAuthorizationForMedia: Bool? = nil, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.loadCloudQueue(authenticationToken: authenticationToken, sessionId: sessionId, queueBaseUrl: queueBaseUrl, httpAuthorization: httpAuthorization, itemId: itemId, playOnCompletion: playOnCompletion, positionMillis: positionMillis, queueVersion: queueVersion, trackMetadata: trackMetadata, useHttpAuthorizationForMedia: useHttpAuthorizationForMedia, success: success, failure: failure)
    }

    public func refreshCloudQueue(sessionId: String, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.refreshCloudQueue(authenticationToken: authenticationToken, sessionId: sessionId, success: success, failure: failure)
    }

    // MARK: - Stream URL (Callback-based)

    public func loadStreamUrl(sessionId: String, streamUrl: String, itemId: String? = nil, playOnCompletion: Bool? = nil, stationMetadata: [String: Any]? = nil, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.loadStreamUrl(authenticationToken: authenticationToken, sessionId: sessionId, streamUrl: streamUrl, itemId: itemId, playOnCompletion: playOnCompletion, stationMetadata: stationMetadata, success: success, failure: failure)
    }

    // MARK: - Session Playback Control (Callback-based)

    public func sessionSeek(sessionId: String, positionMillis: UInt, itemId: String, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.sessionSeek(authenticationToken: authenticationToken, sessionId: sessionId, positionMillis: positionMillis, itemId: itemId, success: success, failure: failure)
    }

    public func sessionSeekRelative(sessionId: String, deltaMillis: Int, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.sessionSeekRelative(authenticationToken: authenticationToken, sessionId: sessionId, deltaMillis: deltaMillis, success: success, failure: failure)
    }

    public func sessionSkipToItem(sessionId: String, itemId: String, playOnCompletion: Bool? = nil, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.sessionSkipToItem(authenticationToken: authenticationToken, sessionId: sessionId, itemId: itemId, playOnCompletion: playOnCompletion, success: success, failure: failure)
    }

    // MARK: - Session Subscriptions (Callback-based)

    public func subscribeToPlaybackSession(sessionId: String, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.subscribe(authenticationToken: authenticationToken, sessionId: sessionId, success: success, failure: failure)
    }

    public func unsubscribeFromPlaybackSession(sessionId: String, success: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        guard let authenticationToken = authenticationToken else {
            let error = NSError.errorWithMessage(message: "Could not load authentication token.")
            failure(error)
            return
        }

        playbackSessionService.unsubscribe(authenticationToken: authenticationToken, sessionId: sessionId, success: success, failure: failure)
    }
}

// MARK: - Async/Await Extensions

@available(iOS 14.0, macOS 10.15, *)
extension SonosManager {

    // MARK: - Playback Session (Async)

    public func createPlaybackSession(groupId: String, appId: String, appContext: String, accountId: String? = nil, customData: String? = nil) async throws -> PlaybackSession {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        return try await playbackSessionService.createSession(authenticationToken: authenticationToken, groupId: groupId, appId: appId, appContext: appContext, accountId: accountId, customData: customData)
    }

    public func joinPlaybackSession(groupId: String, appId: String, appContext: String) async throws -> PlaybackSession {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        return try await playbackSessionService.joinSession(authenticationToken: authenticationToken, groupId: groupId, appId: appId, appContext: appContext)
    }

    public func suspendPlaybackSession(sessionId: String, queueVersion: String? = nil) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playbackSessionService.suspendSession(authenticationToken: authenticationToken, sessionId: sessionId, queueVersion: queueVersion)
    }

    // MARK: - Cloud Queue (Async)

    public func loadCloudQueue(groupId: String, sessionId: String, queueBaseUrl: String, httpAuthorization: String? = nil, itemId: String? = nil, playOnCompletion: Bool? = nil, positionMillis: UInt? = nil, queueVersion: String? = nil, trackMetadata: [String: Any]? = nil, useHttpAuthorizationForMedia: Bool? = nil) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playbackSessionService.loadCloudQueue(authenticationToken: authenticationToken, sessionId: sessionId, queueBaseUrl: queueBaseUrl, httpAuthorization: httpAuthorization, itemId: itemId, playOnCompletion: playOnCompletion, positionMillis: positionMillis, queueVersion: queueVersion, trackMetadata: trackMetadata, useHttpAuthorizationForMedia: useHttpAuthorizationForMedia)

        // Invalidate cache after loading new content
        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    public func refreshCloudQueue(groupId: String, sessionId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playbackSessionService.refreshCloudQueue(authenticationToken: authenticationToken, sessionId: sessionId)

        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    // MARK: - Stream URL (Async)

    public func loadStreamUrl(groupId: String, sessionId: String, streamUrl: String, itemId: String? = nil, playOnCompletion: Bool? = nil, stationMetadata: [String: Any]? = nil) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playbackSessionService.loadStreamUrl(authenticationToken: authenticationToken, sessionId: sessionId, streamUrl: streamUrl, itemId: itemId, playOnCompletion: playOnCompletion, stationMetadata: stationMetadata)

        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    // MARK: - Session Playback Control (Async)

    public func sessionSeek(groupId: String, sessionId: String, positionMillis: UInt, itemId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playbackSessionService.sessionSeek(authenticationToken: authenticationToken, sessionId: sessionId, positionMillis: positionMillis, itemId: itemId)

        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func sessionSeekRelative(groupId: String, sessionId: String, deltaMillis: Int) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playbackSessionService.sessionSeekRelative(authenticationToken: authenticationToken, sessionId: sessionId, deltaMillis: deltaMillis)

        stateCache.invalidatePlaybackStatus(for: groupId)
    }

    public func sessionSkipToItem(groupId: String, sessionId: String, itemId: String, playOnCompletion: Bool? = nil) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playbackSessionService.sessionSkipToItem(authenticationToken: authenticationToken, sessionId: sessionId, itemId: itemId, playOnCompletion: playOnCompletion)

        stateCache.invalidatePlaybackStatus(for: groupId)
        stateCache.invalidatePlaybackMetadata(for: groupId)
    }

    // MARK: - Session Subscriptions (Async)

    public func subscribeToPlaybackSession(sessionId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playbackSessionService.subscribe(authenticationToken: authenticationToken, sessionId: sessionId)
    }

    public func unsubscribeFromPlaybackSession(sessionId: String) async throws {
        guard let authenticationToken = authenticationToken else {
            throw NSError.errorWithMessage(message: "Could not load authentication token.")
        }

        try await playbackSessionService.unsubscribe(authenticationToken: authenticationToken, sessionId: sessionId)
    }
}
