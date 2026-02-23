import XCTest
@testable import SonosSDK

final class SonosSDKBasicTests: XCTestCase {

    struct TestConfiguration {
        static let keyName = "test-key-name"
        static let key = "test-developer-key"
        static let secret = "test-developer-secret"
        static let redirectURI = "sonos-swift-sdk://authorize"
        static let callbackURL = "https://example.com/callback"
    }

    func testClientCreation() {
        let client = Client(
            keyName: TestConfiguration.keyName,
            key: TestConfiguration.key,
            secret: TestConfiguration.secret,
            redirectURI: TestConfiguration.redirectURI,
            callbackURL: TestConfiguration.callbackURL
        )

        XCTAssertEqual(client.key, TestConfiguration.key)
        XCTAssertEqual(client.secret, TestConfiguration.secret)
        XCTAssertEqual(client.redirectURI, TestConfiguration.redirectURI)
    }

    func testSonosManagerInit() {
        let manager = SonosManager(
            keyName: TestConfiguration.keyName,
            key: TestConfiguration.key,
            secret: TestConfiguration.secret,
            redirectURI: TestConfiguration.redirectURI,
            callbackURL: TestConfiguration.callbackURL
        )

        XCTAssertNotNil(manager)
        XCTAssertFalse(manager.isAuthenticated)
    }

    func testGroupVolumeModel() throws {
        let json = """
        {"volume": 42, "muted": false, "fixed": false}
        """.data(using: .utf8)!

        let volume = try JSONDecoder().decode(GroupVolume.self, from: json)
        XCTAssertEqual(volume.volume, 42)
        XCTAssertFalse(volume.muted)
        XCTAssertFalse(volume.fixed)
    }

    func testPlayerVolumeModel() throws {
        let json = """
        {"volume": 75, "muted": true, "fixed": false}
        """.data(using: .utf8)!

        let volume = try JSONDecoder().decode(PlayerVolume.self, from: json)
        XCTAssertEqual(volume.volume, 75)
        XCTAssertTrue(volume.muted)
    }

    func testHouseholdModel() throws {
        let json = """
        {"id": "HH_123", "name": "My Home"}
        """.data(using: .utf8)!

        let household = try JSONDecoder().decode(Household.self, from: json)
        XCTAssertEqual(household.id, "HH_123")
        XCTAssertEqual(household.name, "My Home")
    }

    func testPlaybackSessionModel() throws {
        let json = """
        {"sessionId": "sess_abc", "sessionState": "SESSION_STATE_CONNECTED", "sessionCreated": true}
        """.data(using: .utf8)!

        let session = try JSONDecoder().decode(PlaybackSession.self, from: json)
        XCTAssertEqual(session.sessionId, "sess_abc")
        XCTAssertEqual(session.sessionCreated, true)
    }

    func testSonosErrorDescriptions() {
        let error = SonosError.notAuthenticated
        XCTAssertNotNil(error.errorDescription)

        let httpError = SonosError.httpError(statusCode: 429, body: SonosErrorBody(errorCode: "RATE_LIMIT", reason: "Too many requests"))
        XCTAssertTrue(httpError.errorDescription?.contains("429") ?? false)
    }

    func testEndpointURLConstruction() throws {
        let endpoint = SonosAPIEndpoint.getGroupVolume(groupId: "GRP_123")
        let url = try endpoint.url()
        XCTAssertEqual(url.host, "api.ws.sonos.com")
        XCTAssertTrue(url.path.contains("GRP_123"))
        XCTAssertTrue(url.path.contains("groupVolume"))
    }

    func testEndpointHTTPMethods() {
        XCTAssertEqual(SonosAPIEndpoint.getHouseholds.method, .get)
        XCTAssertEqual(SonosAPIEndpoint.play(groupId: "g1").method, .post)
        XCTAssertEqual(SonosAPIEndpoint.unsubscribeFromPlayback(groupId: "g1").method, .delete)
        XCTAssertEqual(SonosAPIEndpoint.duckPlayerVolume(playerId: "p1").method, .post)
    }

    static var allTests = [
        ("testClientCreation", testClientCreation),
        ("testSonosManagerInit", testSonosManagerInit),
        ("testGroupVolumeModel", testGroupVolumeModel),
        ("testPlayerVolumeModel", testPlayerVolumeModel),
        ("testHouseholdModel", testHouseholdModel),
        ("testPlaybackSessionModel", testPlaybackSessionModel),
        ("testSonosErrorDescriptions", testSonosErrorDescriptions),
        ("testEndpointURLConstruction", testEndpointURLConstruction),
        ("testEndpointHTTPMethods", testEndpointHTTPMethods),
    ]
}
