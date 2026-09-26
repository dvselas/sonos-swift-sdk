//
//  SonosLocalProtocolTests.swift
//  SonosSDKTests
//

import XCTest
@testable import SonosSDK

final class SonosLocalProtocolTests: XCTestCase {

    private func json(_ text: String) throws -> [Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [Any])
    }

    func testEncodeCommandFramesHeaderAndEmptyBody() throws {
        let command = SonosLocalCommand(namespace: "playback", command: "togglePlayPause",
                                        target: .group("RINCON_A:1"), householdId: "HH")
        let frame = try json(SonosLocalFrameCodec.encode(command, cmdId: "7"))

        XCTAssertEqual(frame.count, 2)
        let header = try XCTUnwrap(frame[0] as? [String: String])
        XCTAssertEqual(header["namespace"], "playback:1")
        XCTAssertEqual(header["command"], "togglePlayPause")
        XCTAssertEqual(header["cmdId"], "7")
        XCTAssertEqual(header["groupId"], "RINCON_A:1")
        XCTAssertEqual(header["householdId"], "HH")
        XCTAssertEqual((frame[1] as? [String: Any])?.isEmpty, true)
    }

    func testEncodeHouseholdTargetDoesNotDuplicateHouseholdId() throws {
        let command = SonosLocalCommand(namespace: "groups", command: "subscribe",
                                        target: .household("HH"), householdId: "HH")
        let header = try XCTUnwrap(json(SonosLocalFrameCodec.encode(command, cmdId: "1"))[0] as? [String: String])
        XCTAssertEqual(header["householdId"], "HH")
        XCTAssertNil(header["groupId"])
    }

    func testSetPlayModesBodyIsWrapped() throws {
        let route = try XCTUnwrap(SonosAPIEndpoint.setPlayModes(groupId: "G:1", playModes: PlayModesBody(shuffle: true)).localRoute)
        let command = SonosLocalCommand(namespace: route.namespace, command: route.command, target: route.target, body: route.body)
        let body = try XCTUnwrap(json(SonosLocalFrameCodec.encode(command, cmdId: "1"))[1] as? [String: Any])
        let modes = try XCTUnwrap(body["playModes"] as? [String: Any])
        XCTAssertEqual(modes["shuffle"] as? Bool, true)
        XCTAssertNil(modes["repeat"], "unset modes must be omitted")
    }

    func testClassifySuccessfulReplyAndDecodeBody() throws {
        let text = #"[{"namespace":"playback:1","response":"getPlaybackStatus","type":"playbackStatus","cmdId":"3","success":true,"householdId":"HH","groupId":"G:1"},{"playbackState":"PLAYBACK_STATE_PAUSED","positionMillis":1234}]"#
        guard case .reply(let cmdId, .success(let frame)) = try SonosLocalFrameCodec.classify(text) else {
            return XCTFail("expected a successful reply")
        }
        XCTAssertEqual(cmdId, "3")
        let status = try SonosLocalFrameCodec.decodeBody(PlaybackStatus.self, from: frame)
        XCTAssertEqual(status.playbackState, "PLAYBACK_STATE_PAUSED")
        XCTAssertEqual(status.positionMillis, 1234)
    }

    func testClassifyErrorReply() throws {
        let text = #"[{"namespace":"groupVolume:1","response":"subscribe","cmdId":"9","success":false,"householdId":"HH"},{"_objectType":"globalError","errorCode":"groupCoordinatorChanged","reason":"moved"}]"#
        guard case .reply(let cmdId, .failure(let error)) = try SonosLocalFrameCodec.classify(text) else {
            return XCTFail("expected a failed reply")
        }
        XCTAssertEqual(cmdId, "9")
        XCTAssertEqual(error, .commandFailed(errorCode: "groupCoordinatorChanged", reason: "moved"))
    }

    func testClassifyEventStripsNamespaceVersion() throws {
        let text = #"[{"namespace":"groupVolume:1","type":"groupVolume","groupId":"RINCON_A:1","householdId":"HH"},{"volume":30,"muted":true,"fixed":false}]"#
        guard case .event(let header, let frame) = try SonosLocalFrameCodec.classify(text) else {
            return XCTFail("expected an event")
        }
        XCTAssertEqual(header.namespace, "groupVolume")
        XCTAssertEqual(header.type, "groupVolume")
        XCTAssertEqual(header.groupId, "RINCON_A:1")
        XCTAssertEqual(try SonosLocalFrameCodec.decodeBody(GroupVolume.self, from: frame), GroupVolume(volume: 30, muted: true))
    }

    func testClassifyRejectsGarbage() {
        XCTAssertThrowsError(try SonosLocalFrameCodec.classify("not json"))
        XCTAssertThrowsError(try SonosLocalFrameCodec.classify(#"{"namespace":"x"}"#))
    }

    func testBodyDataReturnsSecondElement() throws {
        let frame = Data(#"[{"cmdId":"1","success":true},{"volume":5,"muted":false}]"#.utf8)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: SonosLocalFrameCodec.bodyData(from: frame)) as? [String: Any])
        XCTAssertEqual(body["volume"] as? Int, 5)
    }

    func testCoordinatorIdFromGroupId() {
        XCTAssertEqual(SonosLiveClient.coordinatorId(fromGroupId: "RINCON_48A6B8A1B2C301400:3452"), "RINCON_48A6B8A1B2C301400")
        XCTAssertNil(SonosLiveClient.coordinatorId(fromGroupId: "no-colon"))
        XCTAssertNil(SonosLiveClient.coordinatorId(fromGroupId: ":1"))
    }

    func testLocalRoutesCoverCommandsTheAppUses() {
        XCTAssertEqual(SonosAPIEndpoint.togglePlayPause(groupId: "G:1").localRoute?.command, "togglePlayPause")
        XCTAssertEqual(SonosAPIEndpoint.setGroupVolume(groupId: "G:1", volume: 3).localRoute?.namespace, "groupVolume")
        XCTAssertEqual(SonosAPIEndpoint.setPlayerMute(playerId: "P", muted: true).localRoute?.target, .player("P"))
        XCTAssertEqual(SonosAPIEndpoint.getGroups(householdId: "HH").localRoute?.target, .household("HH"))
        XCTAssertNil(SonosAPIEndpoint.getFavorites(householdId: "HH").localRoute, "favorites stay on the cloud")
        XCTAssertNil(SonosAPIEndpoint.loadFavorite(groupId: "G:1", favoriteId: "1", playOnCompletion: true, action: nil).localRoute)
    }
}

final class SonosModelDecodingTests: XCTestCase {

    func testPlaybackStatusToleratesMissingFields() throws {
        let status = try JSONDecoder().decode(PlaybackStatus.self, from: Data(#"{"playbackState":"PLAYBACK_STATE_IDLE"}"#.utf8))
        XCTAssertEqual(status.playbackState, "PLAYBACK_STATE_IDLE")
        XCTAssertEqual(status.positionMillis, 0)
        XCTAssertEqual(status.playModes, PlayModes())
        XCTAssertFalse(status.availablePlaybackActions.canSkip)
    }

    func testPlayerToleratesMissingFields() throws {
        let player = try JSONDecoder().decode(Player.self, from: Data(#"{"id":"RINCON_X","name":"Bad"}"#.utf8))
        XCTAssertEqual(player.id, "RINCON_X")
        XCTAssertEqual(player.websocketUrl, "")
        XCTAssertEqual(player.capabilities, [])
    }

    func testGroupsResponseWithoutPlayers() throws {
        let response = try JSONDecoder().decode(GroupsResponse.self, from: Data(#"{"groups":[{"id":"A:1","coordinatorId":"A"}]}"#.utf8))
        XCTAssertEqual(response.groups.first?.playerIds, ["A"])
        XCTAssertEqual(response.players, [])
    }

    func testVolumeDefaults() throws {
        let volume = try JSONDecoder().decode(PlayerVolume.self, from: Data(#"{"volume":12}"#.utf8))
        XCTAssertEqual(volume, PlayerVolume(volume: 12, muted: false, fixed: false))
    }
}
