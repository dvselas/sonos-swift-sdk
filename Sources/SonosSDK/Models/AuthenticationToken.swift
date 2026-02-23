//
//  AuthenticationToken.swift
//  SonosSDK
//
//  Created by James Hickman on 2/7/21.
//

import Foundation

public struct AuthenticationToken: Codable, Sendable {

    public let accessToken: String
    public let tokenType: String
    public let refreshToken: String
    public let expiresIn: Int
    public let scope: String
    public let expireDate: Date

    public var isExpired: Bool {
        expireDate < Date()
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
        case expireDate
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.accessToken = try container.decode(String.self, forKey: .accessToken)
        self.tokenType = try container.decode(String.self, forKey: .tokenType)
        self.refreshToken = try container.decode(String.self, forKey: .refreshToken)
        self.expiresIn = try container.decode(Int.self, forKey: .expiresIn)
        self.scope = try container.decode(String.self, forKey: .scope)
        // If expireDate is stored, use it; otherwise compute from expiresIn
        self.expireDate = (try? container.decode(Date.self, forKey: .expireDate))
            ?? Date(timeIntervalSinceNow: TimeInterval(self.expiresIn))
    }
}
