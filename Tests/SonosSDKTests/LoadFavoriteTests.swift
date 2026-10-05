//
//  LoadFavoriteTests.swift
//  SonosSDKTests
//
//  `loadFavorite` replaces the queue and, when asked, plays it in order:
//  Sonos otherwise keeps the group's shuffle and repeat.
//

import XCTest
@testable import SonosSDK

final class LoadFavoriteTests: XCTestCase {

    private func json(_ endpoint: SonosAPIEndpoint) throws -> [String: Any] {
        let body = try XCTUnwrap(endpoint.body)
        let data = try JSONEncoder().encode(Wrapped(value: body))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testInOrderTurnsShuffleAndRepeatOff() throws {
        let body = try json(.loadFavorite(groupId: "G:1", favoriteId: "7", playOnCompletion: false, action: "REPLACE",
                                          playModes: .inOrder))

        XCTAssertEqual(body["favoriteId"] as? String, "7")
        XCTAssertEqual(body["playOnCompletion"] as? Bool, false)
        XCTAssertEqual(body["action"] as? String, "REPLACE")
        let modes = try XCTUnwrap(body["playModes"] as? [String: Bool])
        XCTAssertEqual(modes, ["shuffle": false, "repeat": false, "repeatOne": false])
    }

    func testWithoutPlayModesTheGroupKeepsItsOwn() throws {
        let body = try json(.loadFavorite(groupId: "G:1", favoriteId: "7", playOnCompletion: true, action: "REPLACE"))
        XCTAssertNil(body["playModes"])
    }
}

private struct Wrapped: Encodable {
    let value: Encodable
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
