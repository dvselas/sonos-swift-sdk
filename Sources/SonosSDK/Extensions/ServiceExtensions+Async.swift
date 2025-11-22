//
//  ServiceExtensions+Async.swift
//  SonosSDK
//
//  Created on 2025-01-22.
//

import Foundation

// MARK: - GroupPlaybackService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension GroupPlaybackService {

    func getGroupPlaybackStatus(authenticationToken: AuthenticationToken, groupId: String) async throws -> PlaybackStatus {
        try await withCheckedThrowingContinuation { continuation in
            getGroupPlaybackStatus(authenticationToken: authenticationToken, groupId: groupId) { status in
                continuation.resume(returning: status)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupPlaybackPlay(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupPlaybackPlay(authenticationToken: authenticationToken, groupId: groupId) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupPlaybackPause(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupPlaybackPause(authenticationToken: authenticationToken, groupId: groupId) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupPlaybackModes(authenticationToken: AuthenticationToken, groupId: String, playModes: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupPlaybackModes(authenticationToken: authenticationToken, groupId: groupId, playModes: playModes) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupSkipToNext(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupSkipToNext(authenticationToken: authenticationToken, groupId: groupId) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupSkipToPrevious(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupSkipToPrevious(authenticationToken: authenticationToken, groupId: groupId) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setGroupSkipToSeek(authenticationToken: AuthenticationToken, groupId: String, positionMillis: UInt) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setGroupSkipToSeek(authenticationToken: authenticationToken, groupId: groupId, positionMillis: positionMillis) { _ in
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - GroupVolumeService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension GroupVolumeService {

    func getVolume(authenticationToken: AuthenticationToken, groupId: String) async throws -> GroupVolume {
        try await withCheckedThrowingContinuation { continuation in
            getVolume(authenticationToken: authenticationToken, groupId: groupId) { volume in
                continuation.resume(returning: volume)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setVolume(authenticationToken: AuthenticationToken, groupId: String, volume: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setVolume(authenticationToken: authenticationToken, groupId: groupId, volume: volume) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setMuted(authenticationToken: AuthenticationToken, groupId: String, muted: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setMuted(authenticationToken: authenticationToken, groupId: groupId, muted: muted) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setRelativeVolume(authenticationToken: AuthenticationToken, groupId: String, relativeVolume: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setRelativeVolume(authenticationToken: authenticationToken, groupId: groupId, relativeVolume: relativeVolume) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func subscribe(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            subscribe(authenticationToken: authenticationToken, groupId: groupId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func unsubscribe(authenticationToken: AuthenticationToken, groupId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unsubscribe(authenticationToken: authenticationToken, groupId: groupId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - PlayerVolumeService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension PlayerVolumeService {

    func getVolume(authenticationToken: AuthenticationToken, playerId: String) async throws -> PlayerVolume {
        try await withCheckedThrowingContinuation { continuation in
            getVolume(authenticationToken: authenticationToken, playerID: playerId) { volume in
                continuation.resume(returning: volume)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setVolume(authenticationToken: AuthenticationToken, playerId: String, volume: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setVolume(authenticationToken: authenticationToken, playerID: playerId, volume: volume) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setMuted(authenticationToken: AuthenticationToken, playerId: String, muted: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setMuted(authenticationToken: authenticationToken, playerID: playerId, muted: muted) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func setRelativeVolume(authenticationToken: AuthenticationToken, playerId: String, relativeVolume: Int) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            setRelativeVolume(authenticationToken: authenticationToken, playerID: playerId, relativeVolume: relativeVolume) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func subscribe(authenticationToken: AuthenticationToken, playerId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            subscribe(authenticationToken: authenticationToken, playerID: playerId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func unsubscribe(authenticationToken: AuthenticationToken, playerId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unsubscribe(authenticationToken: authenticationToken, playerID: playerId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - GroupService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension GroupService {

    func getGroups(authenticationToken: AuthenticationToken, householdId: String) async throws -> ([Group], [Player]) {
        try await withCheckedThrowingContinuation { continuation in
            getGroups(authenticationToken: authenticationToken, householdId: householdId) { groups, players in
                continuation.resume(returning: (groups, players))
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func subscribe(authenticationToken: AuthenticationToken, householdId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            subscribe(authenticationToken: authenticationToken, householdId: householdId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }

    func unsubscribe(authenticationToken: AuthenticationToken, householdId: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            unsubscribe(authenticationToken: authenticationToken, householdId: householdId) {
                continuation.resume()
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}

// MARK: - PlayerService Async Extensions

@available(iOS 14.0, macOS 10.15, *)
extension PlayerService {

    func getPlayers(authenticationToken: AuthenticationToken, householdId: String) async throws -> [Player] {
        try await withCheckedThrowingContinuation { continuation in
            getPlayers(authenticationToken: authenticationToken, householdId: householdId) { players in
                continuation.resume(returning: players)
            } failure: { error in
                continuation.resume(throwing: error ?? NSError.errorWithMessage(message: "Unknown error"))
            }
        }
    }
}
