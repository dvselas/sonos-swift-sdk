//
//  PlayerSettingsService.swift
//  SonosSDK
//

import Foundation

struct PlayerSettingsService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func getSettings(playerId: String) async throws -> PlayerSettings {
        try await client.request(.getPlayerSettings(playerId: playerId))
    }

    func setSettings(playerId: String, settings: PlayerSettingsBody) async throws {
        try await client.request(.setPlayerSettings(playerId: playerId, settings: settings))
    }
}
