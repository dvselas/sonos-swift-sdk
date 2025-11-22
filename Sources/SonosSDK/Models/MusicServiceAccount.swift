//
//  MusicServiceAccount.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation
import SwiftyJSON

public struct MusicServiceAccount {

    public var accountId: String
    public var serviceId: String
    public var nickname: String?
    public var isGuest: Bool

    init?(_ data: Any) {
        let json = JSON(data)

        guard let accountId = json["accountId"].string,
              let serviceId = json["serviceId"].string else {
            return nil
        }

        self.accountId = accountId
        self.serviceId = serviceId
        self.nickname = json["nickname"].string
        self.isGuest = json["isGuest"].bool ?? false
    }
}
