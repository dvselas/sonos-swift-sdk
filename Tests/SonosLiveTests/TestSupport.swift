//
//  TestSupport.swift
//  SonosLiveTests
//

import Foundation
import XCTest
@testable import SonosSDK

extension XCTestCase {

    /// A fresh, empty `UserDefaults`, deleted at teardown. The suite is named
    /// by a path in its own temporary directory so cfprefsd can't leave an
    /// empty plist behind in `~/Library/Preferences`.
    func makeTemporaryDefaults() -> UserDefaults {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SonosLiveTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suite = directory.appendingPathComponent("Defaults").path
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        return defaults
    }
}

@MainActor
func waitUntil(timeout: TimeInterval = 2, file: StaticString = #filePath, line: UInt = #line,
               _ condition: @MainActor () -> Bool) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("condition not met within \(timeout)s", file: file, line: line)
}

/// Records every endpoint and answers reads with canned JSON.
final class FakeSonosHTTPClient: HTTPClientProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _endpoints: [String] = []
    private var _failCommands = false
    private var _failReads = false

    var endpoints: [String] {
        lock.lock(); defer { lock.unlock() }
        return _endpoints
    }

    var failCommands: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _failCommands }
        set { lock.lock(); _failCommands = newValue; lock.unlock() }
    }

    var failReads: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _failReads }
        set { lock.lock(); _failReads = newValue; lock.unlock() }
    }

    private func record(_ endpoint: SonosAPIEndpoint) {
        lock.lock(); _endpoints.append(String(describing: endpoint)); lock.unlock()
    }

    private func body(for endpoint: SonosAPIEndpoint) -> String {
        switch endpoint {
        case .getHouseholds:
            return #"{"households":[{"id":"HH","name":"Home"}]}"#
        case .getGroups:
            return #"{"groups":[{"id":"RINCON_C:5","name":"Office","coordinatorId":"RINCON_C","playerIds":["RINCON_C"]}],"players":[{"id":"RINCON_C","name":"Office"}]}"#
        case .getPlaybackStatus:
            return #"{"playbackState":"PLAYBACK_STATE_PLAYING","positionMillis":1000}"#
        case .getGroupVolume, .getPlayerVolume:
            return #"{"volume":20,"muted":false,"fixed":false}"#
        case .getFavorites:
            return #"{"items":[{"id":"F1","name":"FM4","description":"TuneIn Station"},{"id":"F2","name":"Bayern 3"}]}"#
        case .modifyGroupMembers(let groupId, _, _):
            return #"{"group":{"id":"\#(groupId)","name":"Kitchen","coordinatorId":"RINCON_A","playerIds":["RINCON_A"]}}"#
        default:
            return "{}"
        }
    }

    func request<T: Decodable>(_ endpoint: SonosAPIEndpoint) async throws -> T {
        record(endpoint)
        if failReads {
            throw SonosError.networkError(URLError(.notConnectedToInternet))
        }
        return try JSONDecoder().decode(T.self, from: Data(body(for: endpoint).utf8))
    }

    func request(_ endpoint: SonosAPIEndpoint) async throws {
        record(endpoint)
        if failCommands {
            throw SonosError.apiError(errorCode: "ERROR_TEST", reason: "rejected")
        }
    }

    func requestData(_ endpoint: SonosAPIEndpoint) async throws -> Data {
        record(endpoint)
        return Data(body(for: endpoint).utf8)
    }
}
