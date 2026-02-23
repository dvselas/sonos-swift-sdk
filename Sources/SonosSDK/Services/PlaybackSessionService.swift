//
//  PlaybackSessionService.swift
//  SonosSDK
//

import Foundation

struct PlaybackSessionService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func createSession(groupId: String, appId: String, appContext: String? = nil, customData: String? = nil) async throws -> PlaybackSession {
        try await client.request(.createSession(groupId: groupId, appId: appId, appContext: appContext, customData: customData))
    }

    func joinSession(sessionId: String, appId: String, appContext: String? = nil) async throws -> PlaybackSession {
        try await client.request(.joinSession(sessionId: sessionId, appId: appId, appContext: appContext))
    }

    func joinOrCreateSession(groupId: String, appId: String, appContext: String? = nil, customData: String? = nil) async throws -> PlaybackSession {
        try await client.request(.joinOrCreateSession(groupId: groupId, appId: appId, appContext: appContext, customData: customData))
    }

    func suspendSession(sessionId: String) async throws {
        try await client.request(.suspendSession(sessionId: sessionId))
    }

    func loadCloudQueue(sessionId: String, cloudQueue: CloudQueueBody) async throws {
        try await client.request(.loadCloudQueue(sessionId: sessionId, cloudQueue: cloudQueue))
    }

    func refreshCloudQueue(sessionId: String) async throws {
        try await client.request(.refreshCloudQueue(sessionId: sessionId))
    }

    func loadStreamUrl(sessionId: String, streamUrl: String, item: StreamItemBody? = nil, playOnCompletion: Bool? = nil) async throws {
        try await client.request(.loadStreamUrl(sessionId: sessionId, streamUrl: streamUrl, item: item, playOnCompletion: playOnCompletion))
    }

    func seek(sessionId: String, positionMillis: UInt, itemId: String? = nil) async throws {
        try await client.request(.sessionSeek(sessionId: sessionId, positionMillis: positionMillis, itemId: itemId))
    }

    func seekRelative(sessionId: String, deltaMillis: Int, itemId: String? = nil) async throws {
        try await client.request(.sessionSeekRelative(sessionId: sessionId, deltaMillis: deltaMillis, itemId: itemId))
    }

    func skipToItem(sessionId: String, itemId: String, queueVersion: String? = nil) async throws {
        try await client.request(.sessionSkipToItem(sessionId: sessionId, itemId: itemId, queueVersion: queueVersion))
    }

    func subscribe(sessionId: String) async throws {
        try await client.request(.subscribeToPlaybackSession(sessionId: sessionId))
    }

    func unsubscribe(sessionId: String) async throws {
        try await client.request(.unsubscribeFromPlaybackSession(sessionId: sessionId))
    }
}
