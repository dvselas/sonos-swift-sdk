//
//  Playlist.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation

public struct Playlist: Codable, Identifiable, Hashable, Sendable {

    public let id: String
    public let name: String
    public let type: String
    public let trackCount: Int?
    public let imageUrl: String?
}

/// Response wrapper for getPlaylists
struct PlaylistsResponse: Codable {
    let playlists: [Playlist]
    let version: String?
}
