//
//  GroupVolumeService.swift
//  SonosSDK
//

import Foundation

struct GroupVolumeService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func getVolume(groupId: String) async throws -> GroupVolume {
        try await client.request(.getGroupVolume(groupId: groupId))
    }

    func setVolume(groupId: String, volume: Int) async throws {
        try await client.request(.setGroupVolume(groupId: groupId, volume: volume))
    }

    func setMuted(groupId: String, muted: Bool) async throws {
        try await client.request(.setGroupMute(groupId: groupId, muted: muted))
    }

    func setRelativeVolume(groupId: String, volumeDelta: Int) async throws {
        try await client.request(.setGroupRelativeVolume(groupId: groupId, volumeDelta: volumeDelta))
    }

    func subscribe(groupId: String) async throws {
        try await client.request(.subscribeToGroupVolume(groupId: groupId))
    }

    func unsubscribe(groupId: String) async throws {
        try await client.request(.unsubscribeFromGroupVolume(groupId: groupId))
    }
}
