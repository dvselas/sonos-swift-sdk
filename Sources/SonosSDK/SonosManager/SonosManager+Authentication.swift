//
//  SonosManager+Authentication.swift
//  SonosSDK
//

import Foundation

extension SonosManager {

    /// Authenticate using a cached token (auto-refreshes if expired)
    public func authenticate() async throws {
        if await tokenManager.hasToken {
            _ = try await tokenManager.validToken()
        } else {
            throw SonosError.notAuthenticated
        }
    }

    /// Exchange an OAuth authorization code for tokens
    public func exchangeAuthCode(_ code: String) async throws {
        _ = try await tokenManager.exchangeCode(code)
    }

    /// Handle the OAuth redirect URL and extract the authorization code
    public func handleAuthRedirect(url: URL) async throws {
        guard let authorization = Authorization(fromURL: url) else {
            throw SonosError.invalidResponse
        }
        _ = try await tokenManager.exchangeCode(authorization.code)
    }

    /// Logout and clear all tokens
    public func logout() async {
        await tokenManager.clearTokens()
        stateCache.invalidateAll()
        subscriptionCoordinator.stopAllWebSockets()
    }
}
