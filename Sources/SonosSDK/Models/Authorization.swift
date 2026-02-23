//
//  Authorization.swift
//  SonosSDK
//
//  Created by James Hickman on 2/7/21.
//

import Foundation

struct Authorization: Codable, Sendable {

    let state: String
    let code: String

    init?(fromURL url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let state = components.queryItems?.first(where: { $0.name == "state" })?.value,
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            return nil
        }
        self.state = state
        self.code = code
    }
}
