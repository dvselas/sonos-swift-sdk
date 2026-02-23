//
//  SonosManager+PlayerSettings.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    public func getPlayerSettings(playerId: String) async throws -> PlayerSettings {
        try await playerSettingsService.getSettings(playerId: playerId)
    }

    public func setPlayerSettings(playerId: String, settings: PlayerSettingsBody) async throws {
        try await playerSettingsService.setSettings(playerId: playerId, settings: settings)
    }
}
