//
//  AudioClipService.swift
//  SonosSDK
//

import Foundation

struct AudioClipService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func loadAudioClip(playerId: String, clip: AudioClipBody) async throws -> AudioClip {
        try await client.request(.loadAudioClip(playerId: playerId, clip: clip))
    }

    func cancelAudioClip(playerId: String, clipId: String) async throws {
        try await client.request(.cancelAudioClip(playerId: playerId, clipId: clipId))
    }

    func subscribe(playerId: String) async throws {
        try await client.request(.subscribeToAudioClip(playerId: playerId))
    }

    func unsubscribe(playerId: String) async throws {
        try await client.request(.unsubscribeFromAudioClip(playerId: playerId))
    }
}
