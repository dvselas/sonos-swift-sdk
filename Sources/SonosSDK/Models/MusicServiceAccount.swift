//
//  MusicServiceAccount.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation

/// A music service account set up in a household, as `match` returns it.
public struct MusicServiceAccount: Codable, Sendable, Equatable {

    /// The account's number in the household, e.g. `sn_10`: what
    /// `SonosContent.accountId` plays with.
    public let accountId: String
    public let serviceId: String
    public let nickname: String?
    public let userIdHashCode: String?
    public let isGuest: Bool?

    public init(accountId: String, serviceId: String, nickname: String? = nil, userIdHashCode: String? = nil,
                isGuest: Bool? = nil) {
        self.accountId = accountId
        self.serviceId = serviceId
        self.nickname = nickname
        self.userIdHashCode = userIdHashCode
        self.isGuest = isGuest
    }

    private enum CodingKeys: String, CodingKey {
        case id, accountId, service, serviceId, nickname, userIdHashCode, isGuest
    }

    private struct Service: Codable {
        let id: String
    }

    /// The players answer with `id` and `service.id`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .accountId)
        serviceId = try container.decodeIfPresent(Service.self, forKey: .service)?.id
            ?? container.decode(String.self, forKey: .serviceId)
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        userIdHashCode = try container.decodeIfPresent(String.self, forKey: .userIdHashCode)
        isGuest = try container.decodeIfPresent(Bool.self, forKey: .isGuest)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(accountId, forKey: .id)
        try container.encode(Service(id: serviceId), forKey: .service)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(userIdHashCode, forKey: .userIdHashCode)
        try container.encodeIfPresent(isGuest, forKey: .isGuest)
    }
}
