//
//  HomeTheaterOptions.swift
//  SonosSDK
//
//  Created by James Hickman on 2/22/21.
//

import Foundation

public struct HomeTheaterOptions: Codable, Sendable {

    public let nightMode: Bool
    public let enhanceDialog: Bool

    public init(nightMode: Bool = false, enhanceDialog: Bool = false) {
        self.nightMode = nightMode
        self.enhanceDialog = enhanceDialog
    }
}
