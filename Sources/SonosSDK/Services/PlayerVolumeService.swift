//
//  PlayerVolumeService.swift
//  SonosSDK
//

import Foundation

struct PlayerVolumeService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func getVolume(playerId: String) async throws -> PlayerVolume {
        try await client.request(.getPlayerVolume(playerId: playerId))
    }

    func setVolume(playerId: String, volume: Int) async throws {
        try await client.request(.setPlayerVolume(playerId: playerId, volume: volume))
    }

    func setMuted(playerId: String, muted: Bool) async throws {
        try await client.request(.setPlayerMute(playerId: playerId, muted: muted))
    }

    func setRelativeVolume(playerId: String, volumeDelta: Int) async throws {
        try await client.request(.setPlayerRelativeVolume(playerId: playerId, volumeDelta: volumeDelta))
    }

    /// Temporarily reduce volume (for notifications/alerts)
    func duck(playerId: String) async throws {
        try await client.request(.duckPlayerVolume(playerId: playerId))
    }

    /// Restore volume after ducking
    func unduck(playerId: String) async throws {
        try await client.request(.unduckPlayerVolume(playerId: playerId))
    }

    func subscribe(playerId: String) async throws {
        try await client.request(.subscribeToPlayerVolume(playerId: playerId))
    }

    func unsubscribe(playerId: String) async throws {
        try await client.request(.unsubscribeFromPlayerVolume(playerId: playerId))
    }
}
