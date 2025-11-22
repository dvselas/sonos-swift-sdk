//
//  PlaybackSession.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation
import SwiftyJSON

public struct PlaybackSession {

    public var sessionId: String
    public var appId: String
    public var appContext: String
    public var customData: String?

    init?(_ data: Any) {
        let json = JSON(data)

        guard let sessionId = json["sessionId"].string,
              let appId = json["appId"].string,
              let appContext = json["appContext"].string else {
            return nil
        }

        self.sessionId = sessionId
        self.appId = appId
        self.appContext = appContext
        self.customData = json["customData"].string
    }
}
