//
//  SonosManager+AudioClip.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    public func loadAudioClip(playerId: String, clip: AudioClipBody) async throws -> AudioClip {
        try await audioClipService.loadAudioClip(playerId: playerId, clip: clip)
    }

    public func cancelAudioClip(playerId: String, clipId: String) async throws {
        try await audioClipService.cancelAudioClip(playerId: playerId, clipId: clipId)
    }

    public func subscribeToAudioClip(playerId: String) async throws {
        try await audioClipService.subscribe(playerId: playerId)
    }

    public func unsubscribeFromAudioClip(playerId: String) async throws {
        try await audioClipService.unsubscribe(playerId: playerId)
    }
}
