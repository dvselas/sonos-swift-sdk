//
//  LoadContentTests.swift
//  SonosSDKTests
//
//  The `loadContent` command as the players expect it (see the spike log
//  of RoomTone: Spotify and Apple Music by id on a chosen account).
//

import XCTest
@testable import SonosSDK

final class LoadContentTests: XCTestCase {

    private let album = SonosContent(kind: .album, serviceId: SonosServiceId.appleMusic,
                                     objectId: "album:6772208931", accountId: "sn_2")

    private func json(_ body: Encodable?) throws -> [String: Any] {
        let data = try JSONEncoder().encode(XCTUnwrap(body).asAnyEncodable)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testBodyCarriesTheUniversalMusicObjectId() throws {
        let body = try json(SonosAPIEndpoint.loadContent(groupId: "G:1", content: album, play: true).body)

        XCTAssertEqual(body["type"] as? String, "ALBUM")
        XCTAssertEqual(body["playbackAction"] as? String, "PLAY")
        let id = try XCTUnwrap(body["id"] as? [String: String])
        XCTAssertEqual(id, [
            "_objectType": "universalMusicObjectId",
            "serviceId": "204",
            "objectId": "album:6772208931",
            "accountId": "sn_2",
        ])
    }

    func testLoadingWithoutPlayOmitsThePlaybackAction() throws {
        let body = try json(SonosAPIEndpoint.loadContent(groupId: "G:1", content: album, play: false).body)
        XCTAssertNil(body["playbackAction"])
    }

    func testRoutesToTheGroupCoordinatorsSocket() throws {
        let route = try XCTUnwrap(SonosAPIEndpoint.loadContent(groupId: "RINCON_A:7", content: album, play: true).localRoute)
        XCTAssertEqual(route.namespace, "playback")
        XCTAssertEqual(route.command, "loadContent")
        XCTAssertEqual(route.target, .group("RINCON_A:7"))
    }
}

private struct AnyEncodable: Encodable {
    let value: Encodable
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

private extension Encodable {
    var asAnyEncodable: AnyEncodable { AnyEncodable(value: self) }
}
