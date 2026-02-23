//
//  GroupPlaybackService.swift
//  SonosSDK
//
//  Created by James Hickman on 2/17/21.
//

import Foundation

struct GroupPlaybackService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func getPlaybackStatus(groupId: String) async throws -> PlaybackStatus {
        try await client.request(.getPlaybackStatus(groupId: groupId))
    }

    func play(groupId: String) async throws {
        try await client.request(.play(groupId: groupId))
    }

    func pause(groupId: String) async throws {
        try await client.request(.pause(groupId: groupId))
    }

    func togglePlayPause(groupId: String) async throws {
        try await client.request(.togglePlayPause(groupId: groupId))
    }

    func skipToNextTrack(groupId: String) async throws {
        try await client.request(.skipToNextTrack(groupId: groupId))
    }

    func skipToPreviousTrack(groupId: String) async throws {
        try await client.request(.skipToPreviousTrack(groupId: groupId))
    }

    func seek(groupId: String, positionMillis: UInt) async throws {
        try await client.request(.seek(groupId: groupId, positionMillis: positionMillis))
    }

    func seekRelative(groupId: String, deltaMillis: Int, itemId: String? = nil) async throws {
        try await client.request(.seekRelative(groupId: groupId, deltaMillis: deltaMillis, itemId: itemId))
    }

    func setPlayModes(groupId: String, playModes: PlayModesBody) async throws {
        try await client.request(.setPlayModes(groupId: groupId, playModes: playModes))
    }

    func loadLineIn(groupId: String, deviceId: String? = nil, playOnCompletion: Bool? = nil) async throws {
        try await client.request(.loadLineIn(groupId: groupId, deviceId: deviceId, playOnCompletion: playOnCompletion))
    }

    func subscribe(groupId: String) async throws {
        try await client.request(.subscribeToPlayback(groupId: groupId))
    }

    func unsubscribe(groupId: String) async throws {
        try await client.request(.unsubscribeFromPlayback(groupId: groupId))
    }
}
