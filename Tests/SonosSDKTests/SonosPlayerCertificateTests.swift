//
//  SonosPlayerCertificateTests.swift
//  SonosSDKTests
//
//  Players present one certificate, issued by the "Sonos Device
//  Authentication Root CA", with their MAC address as common name. The
//  certificates here are made up: one from a stand-in CA of that name for
//  the player RINCON_AABBCCDDEEFF01400, one with the same common name from
//  another issuer.
//

#if canImport(Security)
import Security
import XCTest
@testable import SonosSDK

final class SonosPlayerCertificateTests: XCTestCase {

    private let player = "RINCON_AABBCCDDEEFF01400"

    /// CN=AABBCCDDEEFF, issued by CN=Sonos Device Authentication Root CA.
    private let playerCertificate = "MIIBwDCCAWYCCQDhDIMk0TAO2jAJBgcqhkjOPQQBMGgxCzAJBgNVBAYTAlVTMRMwEQYDVQQKDApTb25vcywgSW5jMRYwFAYDVQQLDA1Tb25vcyBEZXZpY2VzMSwwKgYDVQQDDCNTb25vcyBEZXZpY2UgQXV0aGVudGljYXRpb24gUm9vdCBDQTAgFw0yNjEwMDUwODM1NDRaGA8yMTI2MDkxMTA4MzU0NFowZzELMAkGA1UEBhMCVVMxEzARBgNVBAoMClNvbm9zLCBJbmMxFjAUBgNVBAsMDVNvbm9zIERldmljZXMxFDASBgoJkiaJk/IsZAEZFgRwcm9kMRUwEwYDVQQDDAxBQUJCQ0NEREVFRkYwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAATnWmIIMhjJwK/X9rm62Wslwx++9ixJDmwTMZP3Kp5vjaLe62lENDTu9wtx39yHIexqzldFjekS98aikGPbsUwMMAkGByqGSM49BAEDSQAwRgIhAKLRGgZRYevahMAphSOaAzj/ir+nZsF7fjnwlMqKT2WSAiEAsJ4rffD9g09pXVJksX0EfjikIptDK7eLpX9v7bgt8S0="

    /// CN=AABBCCDDEEFF, self-signed by somebody else.
    private let impostorCertificate = "MIIBYDCCAQYCCQCqtPoFslOdzjAKBggqhkjOPQQDAjA3MQswCQYDVQQGEwJVUzERMA8GA1UECgwIU29tZWJvZHkxFTATBgNVBAMMDEFBQkJDQ0RERUVGRjAgFw0yNjEwMDUwODM1NDRaGA8yMTI2MDkxMTA4MzU0NFowNzELMAkGA1UEBhMCVVMxETAPBgNVBAoMCFNvbWVib2R5MRUwEwYDVQQDDAxBQUJCQ0NEREVFRkYwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARW+Qx23goNAruXA7lNpWSl9N9VY7mmZrocru+rTIeuwgHoBY1kCOqGU2sGkD9cgrLtPAWxg80o5lq/J2JYKD8FMAoGCCqGSM49BAMCA0gAMEUCIHqngksvMevnWe9fr55q7es37UGXo0k91+OoNfD48HE7AiEAiKcF06Kbdn6Oia0Fd8lQUfGiCknHVq5ItE30QjGKr+4="

    private func certificate(_ base64: String) throws -> SecCertificate {
        let der = try XCTUnwrap(Data(base64Encoded: base64))
        return try XCTUnwrap(SecCertificateCreateWithData(nil, der as CFData))
    }

    private func trust(_ base64: String) throws -> SecTrust {
        var trust: SecTrust?
        let status = SecTrustCreateWithCertificates(try certificate(base64), SecPolicyCreateSSL(true, "192.168.1.20" as CFString), &trust)
        XCTAssertEqual(status, errSecSuccess)
        return try XCTUnwrap(trust)
    }

    func testThePlayersOwnCertificateIsAccepted() throws {
        XCTAssertTrue(SonosPlayerCertificate.matches(try trust(playerCertificate), playerId: player))
    }

    func testAnotherPlayersCertificateIsRejected() throws {
        XCTAssertFalse(SonosPlayerCertificate.matches(try trust(playerCertificate), playerId: "RINCON_11223344556601400"))
    }

    func testACertificateFromAnotherIssuerIsRejected() throws {
        XCTAssertFalse(SonosPlayerCertificate.matches(try trust(impostorCertificate), playerId: player))
    }

    func testAPlayerIdWithoutMACOnlyChecksTheIssuer() throws {
        XCTAssertTrue(SonosPlayerCertificate.matches(try certificate(playerCertificate), playerId: "RINCON_B"))
        XCTAssertFalse(SonosPlayerCertificate.matches(try certificate(impostorCertificate), playerId: "RINCON_B"))
    }

    func testTheMACComesFromThePlayerId() {
        XCTAssertEqual(SonosPlayerCertificate.macAddress(fromPlayerId: "RINCON_38420b30d39201400"), "38420B30D392")
        XCTAssertNil(SonosPlayerCertificate.macAddress(fromPlayerId: "RINCON_A"))
        XCTAssertNil(SonosPlayerCertificate.macAddress(fromPlayerId: "38420B30D39201400"))
    }

    func testOnlyTheHouseholdsPlayersOnTheLocalPortAreKnown() {
        let delegate = SonosLocalSessionDelegate()
        delegate.setTrustedPlayers(["Sonos-AABBCCDDEEFF.local": player])

        XCTAssertEqual(delegate.playerId(host: "sonos-aabbccddeeff.local", port: SonosLocalAPI.port), player)
        XCTAssertNil(delegate.playerId(host: "sonos-aabbccddeeff.local", port: 443))
        XCTAssertNil(delegate.playerId(host: "192.168.1.99", port: SonosLocalAPI.port))
    }
}
#endif
