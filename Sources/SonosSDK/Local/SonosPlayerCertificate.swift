//
//  SonosPlayerCertificate.swift
//  SonosSDK
//
//  Checks that the certificate a player presents on its local socket is
//  that player's. Players send a single certificate issued by the "Sonos
//  Device Authentication Root CA", which the system doesn't trust, with the
//  player's MAC address as common name: `RINCON_<MAC>01400` → `CN=<MAC>`.
//  Sonos renews the certificates (and their keys) about once a year, so
//  the keys aren't pinned.
//

#if canImport(Security)
import Foundation
import Security

enum SonosPlayerCertificate {

    static let issuerName = "Sonos Device Authentication Root CA"

    static func matches(_ trust: SecTrust, playerId: String) -> Bool {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate], let leaf = chain.first else {
            return false
        }
        return matches(leaf, playerId: playerId)
    }

    /// Issued by Sonos, and its common name is the player's MAC address.
    /// A player id without a MAC address only gets the issuer check.
    static func matches(_ certificate: SecCertificate, playerId: String) -> Bool {
        guard isIssuedBySonos(certificate) else { return false }
        guard let mac = macAddress(fromPlayerId: playerId) else { return true }
        var commonName: CFString?
        guard SecCertificateCopyCommonName(certificate, &commonName) == errSecSuccess,
              let name = commonName as String? else { return false }
        return name.filter(\.isHexDigit).uppercased() == mac
    }

    /// `RINCON_38420B30D39201400` → `38420B30D392`.
    static func macAddress(fromPlayerId playerId: String) -> String? {
        let prefix = "RINCON_"
        guard playerId.hasPrefix(prefix) else { return nil }
        let hex = playerId.dropFirst(prefix.count).prefix(12)
        guard hex.count == 12, hex.allSatisfy(\.isHexDigit) else { return nil }
        return hex.uppercased()
    }

    /// The normalized issuer sequence holds the issuer's names as text.
    private static func isIssuedBySonos(_ certificate: SecCertificate) -> Bool {
        guard let issuer = SecCertificateCopyNormalizedIssuerSequence(certificate) as Data?,
              let text = String(data: issuer, encoding: .isoLatin1) else { return false }
        return text.uppercased().contains(issuerName.uppercased())
    }
}
#endif
