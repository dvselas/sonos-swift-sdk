//
//  SonosManager+MusicServiceAccounts.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    /// The household's account for a music service user, e.g. the Spotify
    /// account behind `userIdHashCode` from the service's sign-in, to play
    /// with exactly that account (`SonosContent.accountId`). Fails when the
    /// household doesn't have it. Answered by the players over their local
    /// socket while live updates run.
    public func matchMusicServiceAccount(householdId: String, account: MusicServiceAccountBody) async throws
        -> MusicServiceAccount {
        try await musicServiceAccountsService.matchAccount(householdId: householdId, account: account)
    }
}
