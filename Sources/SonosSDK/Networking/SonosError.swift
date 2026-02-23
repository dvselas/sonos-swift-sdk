//
//  SonosError.swift
//  SonosSDK
//
//  Created on 2026-02-23.
//

import Foundation

/// Typed error for all Sonos SDK operations
public enum SonosError: LocalizedError, Sendable {

    /// No valid authentication token available
    case notAuthenticated

    /// Server returned an unexpected or empty response
    case invalidResponse

    /// HTTP error with status code and optional Sonos error body
    case httpError(statusCode: Int, body: SonosErrorBody?)

    /// Failed to decode the response JSON
    case decodingError(DecodingError)

    /// Underlying network/transport error
    case networkError(URLError)

    /// WebSocket-specific error
    case webSocketError(WebSocketFailure)

    /// Rate limited by the Sonos API
    case rateLimited(retryAfter: TimeInterval?)

    /// Sonos API returned a structured error
    case apiError(errorCode: String, reason: String?)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please log in to your Sonos account."
        case .invalidResponse:
            return "Received an invalid or empty response from the Sonos API."
        case .httpError(let statusCode, let body):
            if let body {
                return "HTTP \(statusCode): \(body.errorCode) - \(body.reason ?? "Unknown error")"
            }
            return "HTTP error \(statusCode)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .webSocketError(let failure):
            return "WebSocket error: \(failure.errorDescription ?? "Unknown")"
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "Rate limited. Retry after \(Int(retryAfter)) seconds."
            }
            return "Rate limited by the Sonos API."
        case .apiError(let errorCode, let reason):
            return "Sonos API error [\(errorCode)]: \(reason ?? "No reason provided")"
        }
    }
}

/// Structured error body returned by the Sonos Control API
public struct SonosErrorBody: Codable, Sendable {
    public let errorCode: String
    public let reason: String?
}

/// WebSocket-specific failure cases
public enum WebSocketFailure: LocalizedError, Sendable {
    case invalidURL
    case invalidMessageFormat
    case missingRequiredFields
    case connectionFailed(String)
    case connectionClosed(closeCode: Int, reason: String?)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid WebSocket URL"
        case .invalidMessageFormat:
            return "Invalid WebSocket message format"
        case .missingRequiredFields:
            return "WebSocket message missing required fields"
        case .connectionFailed(let message):
            return "WebSocket connection failed: \(message)"
        case .connectionClosed(let closeCode, let reason):
            return "WebSocket closed with code \(closeCode): \(reason ?? "No reason")"
        }
    }
}
