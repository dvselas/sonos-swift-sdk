//
//  File.swift
//  
//
//  Created by von Selasinsky, Deno on 13.11.23.
//

import Foundation
import SwiftyJSON

public struct PlaybackMetadata {
    
    public var _objectType: String?
    public var container: ContainerMetadata
    public var currentItem: Item
    public var nextItem: Item
    let jsonObject: [String: Any] = [
        "_objectType": "none"
    ]
    
    init?(_ data: Any) {
        let json = JSON(data)
        
        guard let _objectType = json["_objectType"].string,
              let container = json["container"].dictionary,
              let currentItem = json["currentItem"].dictionary,
              let nextItem = json["nextItem"].dictionary else { return nil }

        self._objectType = _objectType
        self.container = ContainerMetadata(container)
        self.currentItem = Item(currentItem)
        self.nextItem = Item(nextItem)
    }

    
}

public struct ContainerMetadata {
    public var _objectType: String?
    public var name: String?
    public var type: String?
    public var id: IdMetadata?
    public var service: ServiceMetadata?
    public var imageUrl: String?
    public var images: Images?
    let jsonObject: [String: Any] = [
        "_objectType": "none"
    ]
    
    init(_ data: [String: Any]) {
        let json = JSON(data)
        
        self._objectType = json["_objectType"].string ?? ""
        self.name = json["name"].string ?? ""
        self.type = json["type"].string ?? ""
        self.id = IdMetadata(json["id"].dictionary ?? jsonObject)
        self.service = ServiceMetadata(json["service"].dictionary ?? jsonObject)
        self.imageUrl = json["imageUrl"].string ?? ""
        self.images = Images(json["images"].arrayValue)
    }
}

public struct Item {
    public var _objectType: String
    public var track: Track?
    public var policies:Policies?
    
    init(_ data: [String: Any]) {
        let json = JSON(data)
        self._objectType = json["_objectType"].string ?? ""
        self.track = Track(json["track"].dictionary!)
        self.policies = Policies(json["policies"].dictionary!)
    }
}

public struct IdMetadata {
    public var _objectType: String
    public var serviceId: String
    public var objectId: String
    public var accountId: String
    init(_ data: [String: Any]) {
        let json = JSON(data)
        self._objectType = json["_objectType"].string ?? ""
        self.serviceId = json["serviceId"].string ?? ""
        self.objectId = json["objectId"].string ?? ""
        self.accountId = json["accountId"].string ?? ""
    }
}

public struct ServiceMetadata {
    public var _objectType: String
    public var name: String
    public var id: String
    public var accountId: String?
    public var images: Images?
    init(_ data: [String: Any]) {
        let json = JSON(data)
        self._objectType = json["_objectType"].string ?? ""
        self.name = json["name"].string ?? ""
        self.id = json["id"].string ?? ""
        self.accountId = json["accountId"].string ?? ""
        self.images = Images(json["images"].arrayValue)
    }
}

public struct Images {
    public var _objectType: String
    public var url: String
    init(_ data: [JSON]) {
        let json = JSON(data)
        self._objectType = json["_objectType"].string ?? ""
        self.url = json["imageUrl"].string ?? ""
    }
}

public struct Track {
    public var _objectType: String
    public var name: String
    public var type: String
    public var imageUrl: String?
    public var images: Images?
    public var album: Album?
    public var artist: Artist?
    public var id: IdMetadata?
    public var service: ServiceMetadata?
    public var durationMillis: Int64
    public var quality: Quality?
    
    init(_ data: [String: Any]) {
        let json = JSON(data)
        self._objectType = json["_objectType"].string ?? ""
        self.name = json["name"].string ?? ""
        self.type = json["type"].string ?? ""
        self.imageUrl = json["imageUrl"].string ?? ""
        self.images = Images(json["images"].arrayValue)
        self.album = Album(json["album"].dictionary!)
        self.artist = Artist(json["artist"].dictionary!)
        self.id = IdMetadata(json["id"].dictionary!)
        self.service = ServiceMetadata(json["service"].dictionary!)
        self.durationMillis = json["durationMillis"].int64Value
    }
}

public struct Album {
    public var _objectType: String
    public var name: String
    init(_ data: [String: Any]) {
        let json = JSON(data)
        self._objectType = json["_objectType"].string ?? ""
        self.name = json["name"].string ?? ""
    }
}

public struct Artist {
    public var _objectType: String
    public var name: String
    init(_ data: [String: Any]) {
        let json = JSON(data)
        self._objectType = json["_objectType"].string ?? ""
        self.name = json["name"].string ?? ""
    }
}

public struct Quality {
    public var _objectType: String
    init(_ data: [String: Any]) {
        let json = JSON(data)
        self._objectType = json["_objectType"].string ?? ""
    }
}


public struct Policies {
    public var _objectType: String
    init(_ data: [String: Any]) {
        let json = JSON(data)
        self._objectType = json["_objectType"].string ?? ""
    }
}
