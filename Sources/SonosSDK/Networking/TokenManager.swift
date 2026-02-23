//
//  TokenManager.swift
//  SonosSDK
//
//  Created on 2026-02-23.
//

import Foundation

/// Thread-safe actor managing Sonos OAuth tokens with automatic refresh
public actor TokenManager {

    // MARK: - Types

    /// Internal representation stored in UserDefaults
    struct StoredToken: Codable {
        let accessToken: String
        let refreshToken: String
        let tokenType: String
        let scope: String
        let expiresAt: Date

        var isExpired: Bool {
            // Treat as expired 60 seconds before actual expiry for safety margin
            expiresAt.addingTimeInterval(-60) < Date()
        }

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
            case scope
            case expiresAt = "expire_date"
        }
    }

    /// Token response from the Sonos API
    public struct TokenResponse: Codable, Sendable {
        public let accessToken: String
        public let refreshToken: String
        public let tokenType: String
        public let expiresIn: Int
        public let scope: String

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case scope
        }
    }

    // MARK: - Properties

    private let clientKey: String
    private let clientSecret: String
    private let redirectURI: String
    private let userDefaultsKey = "com.sonossdk.token"

    private var currentToken: StoredToken?
    private var refreshTask: Task<String, Error>?
    private var session: URLSession

    /// Called when authentication state changes
    public var onAuthenticationChanged: (@Sendable (Bool) -> Void)?

    // MARK: - Initialization

    public init(clientKey: String, clientSecret: String, redirectURI: String, session: URLSession = .shared) {
        self.clientKey = clientKey
        self.clientSecret = clientSecret
        self.redirectURI = redirectURI
        self.session = session
        self.currentToken = loadFromUserDefaults()
    }

    // MARK: - Public Methods

    /// Get a valid access token, refreshing if needed
    public func validToken() async throws -> String {
        // If we have an in-flight refresh, await it
        if let refreshTask {
            return try await refreshTask.value
        }

        guard let token = currentToken else {
            throw SonosError.notAuthenticated
        }

        if !token.isExpired {
            return token.accessToken
        }

        // Token expired — refresh
        return try await refreshAndReturn(token.refreshToken)
    }

    /// Get the Base64-encoded client key for Basic auth
    public func encodedClientKey() throws -> String {
        let combined = "\(clientKey):\(clientSecret)"
        guard let data = combined.data(using: .utf8) else {
            throw SonosError.notAuthenticated
        }
        return data.base64EncodedString()
    }

    /// Whether a token exists (may be expired)
    public var hasToken: Bool {
        currentToken != nil
    }

    /// Whether the current token is valid (not expired)
    public var isAuthenticated: Bool {
        guard let token = currentToken else { return false }
        return !token.isExpired
    }

    /// Exchange an authorization code for tokens
    public func exchangeCode(_ authCode: String) async throws -> TokenResponse {
        let encodedKey = try encodedClientKey()
        let body = "grant_type=authorization_code&code=\(authCode)&redirect_uri=\(redirectURI)"

        let tokenResponse: TokenResponse = try await performTokenRequest(body: body, encodedKey: encodedKey)
        storeToken(from: tokenResponse)
        return tokenResponse
    }

    /// Force a token refresh
    public func forceRefresh() async throws {
        guard let token = currentToken else {
            throw SonosError.notAuthenticated
        }
        _ = try await refreshAndReturn(token.refreshToken)
    }

    /// Clear all stored tokens (logout)
    public func clearTokens() {
        currentToken = nil
        refreshTask = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        onAuthenticationChanged?(false)
    }

    /// Store a token received from external auth flow
    public func storeToken(from response: TokenResponse) {
        let stored = StoredToken(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            scope: response.scope,
            expiresAt: Date(timeIntervalSinceNow: TimeInterval(response.expiresIn))
        )
        currentToken = stored
        saveToUserDefaults(stored)
        onAuthenticationChanged?(true)
    }

    /// Get the authorization URL for OAuth flow
    public func authorizationURL(state: String = "sonos_auth") -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = SonosHost.authorization
        components.path = "/login/v3/oauth"
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientKey),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: "playback-control-all"),
            URLQueryItem(name: "redirect_uri", value: redirectURI)
        ]
        return components.url
    }

    // MARK: - Private Methods

    private func refreshAndReturn(_ refreshToken: String) async throws -> String {
        // Coalesce concurrent refresh requests
        if let refreshTask {
            return try await refreshTask.value
        }

        let task = Task<String, Error> {
            defer { self.refreshTask = nil }

            let encodedKey = try encodedClientKey()
            let body = "grant_type=refresh_token&refresh_token=\(refreshToken)"

            do {
                let response: TokenResponse = try await performTokenRequest(body: body, encodedKey: encodedKey)
                storeToken(from: response)
                return response.accessToken
            } catch {
                // Refresh failed — clear tokens
                clearTokens()
                throw SonosError.notAuthenticated
            }
        }

        self.refreshTask = task
        return try await task.value
    }

    private func performTokenRequest<T: Decodable>(body: String, encodedKey: String) async throws -> T {
        var components = URLComponents()
        components.scheme = "https"
        components.host = SonosHost.authorization
        components.path = "/login/v3/oauth/access"

        guard let url = components.url else {
            throw SonosError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Basic \(encodedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.data(using: .utf8)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw SonosError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SonosError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = try? JSONDecoder().decode(SonosErrorBody.self, from: data)
            throw SonosError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as DecodingError {
            throw SonosError.decodingError(error)
        }
    }

    // MARK: - Persistence

    private func loadFromUserDefaults() -> StoredToken? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(StoredToken.self, from: data)
    }

    private func saveToUserDefaults(_ token: StoredToken) {
        if let data = try? JSONEncoder().encode(token) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}
