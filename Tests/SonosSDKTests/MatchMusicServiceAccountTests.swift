//
//  MatchMusicServiceAccountTests.swift
//  SonosSDKTests
//
//  Finding the household's account for a music service user, as a player
//  answered it over its local socket (RoomTone: the Spotify account behind a
//  sign-in through Sonos' Spotify service).
//

import XCTest
@testable import SonosSDK

final class MatchMusicServiceAccountTests: XCTestCase {

    private let account = MusicServiceAccountBody(serviceId: SonosServiceId.spotify,
                                                  userIdHashCode: "cd916fcd04e0eacc7900cb490d93026e", nickname: "Thore")

    func testGoesToAnySocketOfTheHousehold() throws {
        let route = try XCTUnwrap(SonosAPIEndpoint.matchMusicServiceAccount(householdId: "Sonos_abc.def", account: account)
            .localRoute)
        XCTAssertEqual(route.namespace, "musicServiceAccounts")
        XCTAssertEqual(route.command, "match")
        XCTAssertEqual(route.target, .household("Sonos_abc.def"))
    }

    func testBodyLeavesOutTheLinkCode() throws {
        let data = try JSONEncoder().encode(account)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(body, ["serviceId": "9", "userIdHashCode": "cd916fcd04e0eacc7900cb490d93026e", "nickname": "Thore"])
    }

    func testReadsThePlayersAnswer() throws {
        let frame = Data(#"""
        [{"namespace":"musicServiceAccounts:1","householdId":"Sonos_abc.def","locationId":"lc_1","response":"match","success":true,"type":"musicServiceAccount","cmdId":"1"},{"_objectType":"musicServiceAccount","userIdHashCode":"cd916fcd04e0eacc7900cb490d93026e","nickname":"Thore","id":"sn_10","isGuest":false,"service":{"_objectType":"service","name":"Spotify","id":"9","images":[]}}]
        """#.utf8)

        let found = try SonosLocalFrameCodec.decodeBody(MusicServiceAccount.self, from: frame)

        XCTAssertEqual(found, MusicServiceAccount(accountId: "sn_10", serviceId: "9", nickname: "Thore",
                                                  userIdHashCode: "cd916fcd04e0eacc7900cb490d93026e", isGuest: false))
    }

    func testKeepsReadingTheEarlierShape() throws {
        let data = Data(#"{"accountId":"sn_5","serviceId":"9","nickname":"dvselas"}"#.utf8)
        let found = try JSONDecoder().decode(MusicServiceAccount.self, from: data)
        XCTAssertEqual(found.accountId, "sn_5")
        XCTAssertEqual(found.serviceId, "9")
        XCTAssertEqual(try JSONDecoder().decode(MusicServiceAccount.self, from: JSONEncoder().encode(found)), found)
    }
}
