import CodeEditorLSP
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import Foundation
import Testing

/// Regression coverage for the removal of deprecated TLS 1.0/1.1 cases
/// from `SecurityOptions.TLSVersion`. The previous enum exposed
/// `.tls10` and `.tls11` mapped to `tls_protocol_version_t.TLSv10` /
/// `.TLSv11`, both deprecated in macOS 12.0 / iOS 15.0 — every clean
/// build emitted two deprecation warnings, and hosts could downgrade
/// remote LSP connections below TLS 1.2. These tests pin the trimmed
/// public surface and confirm any stored config that still requested
/// "1.0" / "1.1" now fails decoding (the correct behavior — silent
/// downgrade would defeat the security goal).
@Suite("SecurityOptions.TLSVersion post-removal surface")
struct SecurityOptionsTLSVersionTests {
    @Test("Only TLS 1.2 and 1.3 cases are exposed")
    func surfaceLimitedToModernVersions() {
        let raws = Set([SecurityOptions.TLSVersion.tls12.rawValue, SecurityOptions.TLSVersion.tls13.rawValue])
        #expect(raws == ["1.2", "1.3"])
    }

    @Test("Non-deprecated tls_protocol_version_t constants are returned")
    func mappingsHitTLSv12AndTLSv13() {
        #expect(SecurityOptions.TLSVersion.tls12.tlsProtocolVersion == .TLSv12)
        #expect(SecurityOptions.TLSVersion.tls13.tlsProtocolVersion == .TLSv13)
    }

    @Test("SecurityOptions defaults to TLS 1.2 minimum")
    func defaultMinimumIsTLS12() {
        #expect(SecurityOptions().minimumTLSVersion == .tls12)
    }

    @Test("Decoding a config that stored TLS 1.0 throws")
    func decodingTLS10RawValueFails() {
        let payload = Data("\"1.0\"".utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(SecurityOptions.TLSVersion.self, from: payload)
        }
    }

    @Test("Decoding a config that stored TLS 1.1 throws")
    func decodingTLS11RawValueFails() {
        let payload = Data("\"1.1\"".utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(SecurityOptions.TLSVersion.self, from: payload)
        }
    }

    @Test("Decoding TLS 1.2 still round-trips")
    func decodingTLS12RawValueSucceeds() throws {
        let payload = Data("\"1.2\"".utf8)
        let version = try JSONDecoder().decode(SecurityOptions.TLSVersion.self, from: payload)
        #expect(version == .tls12)
    }
}
