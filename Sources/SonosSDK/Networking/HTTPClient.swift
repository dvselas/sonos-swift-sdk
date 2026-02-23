//
//  HTTPClient.swift
//  SonosSDK
//
//  Created on 2026-02-23.
//

import Foundation

// MARK: - Protocol

public protocol HTTPClientProtocol: Sendable {
    /// Execute a request and decode the response
    func request<T: Decodable>(_ endpoint: SonosAPIEndpoint) async throws -> T

    /// Execute a request with no response body
    func request(_ endpoint: SonosAPIEndpoint) async throws

    /// Execute a request and return raw data
    func requestData(_ endpoint: SonosAPIEndpoint) async throws -> Data
}

// MARK: - URLSession Implementation

public final class SonosHTTPClient: HTTPClientProtocol, @unchecked Sendable {

    private let session: URLSession
    private let tokenManager: TokenManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(session: URLSession = .shared, tokenManager: TokenManager) {
        self.session = session
        self.tokenManager = tokenManager

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .useDefaultKeys

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .useDefaultKeys
    }

    // MARK: - Public Methods

    public func request<T: Decodable>(_ endpoint: SonosAPIEndpoint) async throws -> T {
        let data = try await executeWithRetry(endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw SonosError.decodingError(error)
        }
    }

    public func request(_ endpoint: SonosAPIEndpoint) async throws {
        _ = try await executeWithRetry(endpoint)
    }

    public func requestData(_ endpoint: SonosAPIEndpoint) async throws -> Data {
        return try await executeWithRetry(endpoint)
    }

    // MARK: - Private Methods

    private func executeWithRetry(_ endpoint: SonosAPIEndpoint, retried: Bool = false) async throws -> Data {
        let request = try await buildRequest(for: endpoint)
        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SonosError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data

        case 401 where !retried && !endpoint.usesBasicAuth:
            // Token expired — refresh and retry once
            try await tokenManager.forceRefresh()
            return try await executeWithRetry(endpoint, retried: true)

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw SonosError.rateLimited(retryAfter: retryAfter)

        default:
            let errorBody = try? decoder.decode(SonosErrorBody.self, from: data)
            throw SonosError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }
    }

    private func buildRequest(for endpoint: SonosAPIEndpoint) async throws -> URLRequest {
        let url = try endpoint.url()
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Auth header
        if endpoint.usesBasicAuth {
            let encodedKey = try await tokenManager.encodedClientKey()
            request.setValue("Basic \(encodedKey)", forHTTPHeaderField: "Authorization")
        } else {
            let token = try await tokenManager.validToken()
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Body
        if let body = endpoint.body {
            if endpoint.usesBasicAuth {
                // Token endpoints use form-encoded
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.httpBody = formEncode(body)
            } else {
                request.httpBody = try encoder.encode(AnyEncodable(body))
            }
        }

        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            throw SonosError.networkError(error)
        }
    }

    /// Encode an Encodable value as application/x-www-form-urlencoded
    private func formEncode(_ value: Encodable) -> Data? {
        guard let data = try? encoder.encode(AnyEncodable(value)),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let formString = dict
            .sorted { $0.key < $1.key }
            .compactMap { key, value -> String? in
                guard let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                      let encodedValue = "\(value)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
                    return nil
                }
                return "\(encodedKey)=\(encodedValue)"
            }
            .joined(separator: "&")

        return formString.data(using: .utf8)
    }
}

// MARK: - Type Erasure for Encodable

struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init(_ value: Encodable) {
        _encode = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}
