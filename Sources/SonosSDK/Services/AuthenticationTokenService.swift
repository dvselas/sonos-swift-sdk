//
//  AuthService.swift
//  SonosSDK
//
//  Unified authentication service replacing the old callback-based services.
//

import Foundation

/// Handles OAuth token exchange and refresh via the TokenManager
struct AuthService {

    private let tokenManager: TokenManager

    init(tokenManager: TokenManager) {
        self.tokenManager = tokenManager
    }

    /// Exchange an authorization code for tokens
    func exchangeCode(_ authCode: String) async throws -> TokenManager.TokenResponse {
        try await tokenManager.exchangeCode(authCode)
    }

    /// Force refresh the current token
    func refreshToken() async throws {
        try await tokenManager.forceRefresh()
    }

    /// Clear all stored tokens
    func logout() async {
        await tokenManager.clearTokens()
    }
}
