//
//  MusicServiceAccountsService.swift
//  SonosSDK
//

import Foundation

struct MusicServiceAccountsService {

    private let client: HTTPClientProtocol

    init(client: HTTPClientProtocol) {
        self.client = client
    }

    func matchAccount(householdId: String, account: MusicServiceAccountBody) async throws -> MusicServiceAccount {
        try await client.request(.matchMusicServiceAccount(householdId: householdId, account: account))
    }
}
