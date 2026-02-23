//
//  Client.swift
//  SonosSDK
//
//  Created by James Hickman on 2/8/21.
//

import Foundation

public struct Client: Codable, Equatable, Sendable {

    public let keyName: String
    public let key: String
    public let secret: String
    public let redirectURI: String
    public let callbackURL: String

    public init(keyName: String, key: String, secret: String, redirectURI: String, callbackURL: String) {
        self.keyName = keyName
        self.key = key
        self.secret = secret
        self.redirectURI = redirectURI
        self.callbackURL = callbackURL
    }
}
