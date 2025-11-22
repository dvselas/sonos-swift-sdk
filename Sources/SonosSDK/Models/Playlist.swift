//
//  Playlist.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation
import SwiftyJSON

public struct Playlist: Identifiable, Hashable {

    public var id: String
    public var name: String
    public var type: String
    public var trackCount: Int?
    public var imageUrl: String?

    init?(_ data: Any) {
        let json = JSON(data)

        guard let id = json["id"].string,
              let name = json["name"].string,
              let type = json["type"].string else {
            return nil
        }

        self.id = id
        self.name = name
        self.type = type
        self.trackCount = json["trackCount"].int
        self.imageUrl = json["imageUrl"].string
    }
}
