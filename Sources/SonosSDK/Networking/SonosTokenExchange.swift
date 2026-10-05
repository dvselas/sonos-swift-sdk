//
//  SonosTokenExchange.swift
//  SonosSDK
//
//  Where authorization codes and refresh tokens are traded for tokens.
//  Private tools can talk to Sonos directly with the integration's secret;
//  published apps keep the secret on a server and exchange through it.
//

import Foundation

public protocol SonosTokenExchanging: Sendable {
    /// Trades the code from the sign-in redirect for tokens.
    func exchange(code: String, redirectURI: String) async throws -> TokenManager.TokenResponse
    /// Trades a refresh token for new tokens.
    func refresh(refreshToken: String) async throws -> TokenManager.TokenResponse
}

/// Exchanges with the Sonos authorization server, signing with the
/// integration's key and secret (which then live in the app).
public struct SonosDirectTokenExchange: SonosTokenExchanging {
    private let clientKey: String
    private let clientSecret: String
    private let session: URLSession

    public init(clientKey: String, clientSecret: String, session: URLSession = .shared) {
        self.clientKey = clientKey
        self.clientSecret = clientSecret
        self.session = session
    }

    public func exchange(code: String, redirectURI: String) async throws -> TokenManager.TokenResponse {
        try await request([
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
        ])
    }

    public func refresh(refreshToken: String) async throws -> TokenManager.TokenResponse {
        try await request([
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
        ])
    }

    private func request(_ form: [URLQueryItem]) async throws -> TokenManager.TokenResponse {
        var components = URLComponents()
        components.scheme = "https"
        components.host = SonosHost.authorization
        components.path = "/login/v3/oauth/access"
        guard let url = components.url else { throw SonosError.invalidResponse }

        var body = URLComponents()
        body.queryItems = form
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let basic = Data("\(clientKey):\(clientSecret)".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.percentEncodedQuery.map { Data($0.utf8) }
        return try await SonosTokenExchangeResponse.decode(session: session, request: request)
    }
}

/// Exchanges through a server that holds the integration's secret: `POST
/// <base>/sonos/token` with `{"code"}` and `POST <base>/sonos/refresh` with
/// `{"refreshToken"}`, both answering with the Sonos token JSON. The server
/// fixes the redirect URI itself.
public struct SonosBackendTokenExchange: SonosTokenExchanging {
    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func exchange(code: String, redirectURI: String) async throws -> TokenManager.TokenResponse {
        try await post("sonos/token", ["code": code])
    }

    public func refresh(refreshToken: String) async throws -> TokenManager.TokenResponse {
        try await post("sonos/refresh", ["refreshToken": refreshToken])
    }

    private func post(_ path: String, _ body: [String: String]) async throws -> TokenManager.TokenResponse {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await SonosTokenExchangeResponse.decode(session: session, request: request)
    }
}

enum SonosTokenExchangeResponse {
    static func decode(session: URLSession, request: URLRequest) async throws -> TokenManager.TokenResponse {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw SonosError.networkError(error)
        }
        guard let http = response as? HTTPURLResponse else { throw SonosError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            throw SonosError.httpError(statusCode: http.statusCode, body: try? JSONDecoder().decode(SonosErrorBody.self, from: data))
        }
        do {
            return try JSONDecoder().decode(TokenManager.TokenResponse.self, from: data)
        } catch let error as DecodingError {
            throw SonosError.decodingError(error)
        }
    }
}
