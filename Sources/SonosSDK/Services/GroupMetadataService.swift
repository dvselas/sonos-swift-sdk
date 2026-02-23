//
//  GroupMetadataService.swift
//  SonosSDK
//

import Foundation

struct GroupMetadataService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func getMetadataStatus(groupId: String) async throws -> PlaybackMetadata {
        try await client.request(.getMetadataStatus(groupId: groupId))
    }

    func subscribe(groupId: String) async throws {
        try await client.request(.subscribeToPlaybackMetadata(groupId: groupId))
    }

    func unsubscribe(groupId: String) async throws {
        try await client.request(.unsubscribeFromPlaybackMetadata(groupId: groupId))
    }
}
