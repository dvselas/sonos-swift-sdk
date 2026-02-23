//
//  SonosManager+PlaybackSession.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    public func createPlaybackSession(groupId: String, appId: String, appContext: String? = nil, customData: String? = nil) async throws -> PlaybackSession {
        try await playbackSessionService.createSession(groupId: groupId, appId: appId, appContext: appContext, customData: customData)
    }

    public func joinPlaybackSession(sessionId: String, appId: String, appContext: String? = nil) async throws -> PlaybackSession {
        try await playbackSessionService.joinSession(sessionId: sessionId, appId: appId, appContext: appContext)
    }

    public func joinOrCreatePlaybackSession(groupId: String, appId: String, appContext: String? = nil, customData: String? = nil) async throws -> PlaybackSession {
        try await playbackSessionService.joinOrCreateSession(groupId: groupId, appId: appId, appContext: appContext, customData: customData)
    }

    public func suspendPlaybackSession(sessionId: String) async throws {
        try await playbackSessionService.suspendSession(sessionId: sessionId)
    }

    public func loadCloudQueue(sessionId: String, cloudQueue: CloudQueueBody) async throws {
        try await playbackSessionService.loadCloudQueue(sessionId: sessionId, cloudQueue: cloudQueue)
    }

    public func refreshCloudQueue(sessionId: String) async throws {
        try await playbackSessionService.refreshCloudQueue(sessionId: sessionId)
    }

    public func loadStreamUrl(sessionId: String, streamUrl: String, item: StreamItemBody? = nil, playOnCompletion: Bool? = nil) async throws {
        try await playbackSessionService.loadStreamUrl(sessionId: sessionId, streamUrl: streamUrl, item: item, playOnCompletion: playOnCompletion)
    }

    public func sessionSeek(sessionId: String, positionMillis: UInt, itemId: String? = nil) async throws {
        try await playbackSessionService.seek(sessionId: sessionId, positionMillis: positionMillis, itemId: itemId)
    }

    public func sessionSeekRelative(sessionId: String, deltaMillis: Int, itemId: String? = nil) async throws {
        try await playbackSessionService.seekRelative(sessionId: sessionId, deltaMillis: deltaMillis, itemId: itemId)
    }

    public func sessionSkipToItem(sessionId: String, itemId: String, queueVersion: String? = nil) async throws {
        try await playbackSessionService.skipToItem(sessionId: sessionId, itemId: itemId, queueVersion: queueVersion)
    }

    public func subscribeToPlaybackSession(sessionId: String) async throws {
        try await playbackSessionService.subscribe(sessionId: sessionId)
    }

    public func unsubscribeFromPlaybackSession(sessionId: String) async throws {
        try await playbackSessionService.unsubscribe(sessionId: sessionId)
    }
}
