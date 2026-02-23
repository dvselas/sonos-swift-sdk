//
//  Service.swift
//  SonosSDK
//
//  Created by James Hickman on 2/24/21.
//

import Foundation

public struct Service: Codable, Identifiable, Sendable {

    public let id: String?
    public let name: String?
    public let imageUrl: String?
}
