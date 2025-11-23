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
    public var appId: String?               // Not in response, only in request
    public var appContext: String?          // Not in response, only in request
    public var sessionState: String?        // "SESSION_STATE_CONNECTED"
    public var sessionCreated: Bool?        // true if newly created, false if joined existing
    public var customData: String?

    init?(_ data: Any) {
        let json = JSON(data)

        guard let sessionId = json["sessionId"].string else {
            return nil
        }

        self.sessionId = sessionId
        self.appId = json["appId"].string
        self.appContext = json["appContext"].string
        self.sessionState = json["sessionState"].string
        self.sessionCreated = json["sessionCreated"].bool
        self.customData = json["customData"].string
    }
}
