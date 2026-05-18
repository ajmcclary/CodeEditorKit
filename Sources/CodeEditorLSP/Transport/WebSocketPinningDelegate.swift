import CodeEditorCommon
import CryptoKit
import Foundation
import Security

/// `URLSessionDelegate` that applies the security-correctness settings the
/// outer `RemoteLSPConfiguration` carries (certificate pinning,
/// `validateSSLCertificates` toggle). Installed by `WebSocketTransport` when
/// the active configuration requires non-default trust handling. Default
/// system trust evaluation is preserved when neither pinning nor
/// "validate=false" is set — `WebSocketTransport.connect()` will pass
/// `delegate: nil` in that case so this code only runs when the caller has
/// asked for tighter behavior than `URLSession` does on its own.
///
/// Callbacks fire on `URLSession`'s delegate queue (not the actor), so this
/// class is intentionally a `final` `NSObject` whose only stored state is
/// immutable. Marked `@unchecked Sendable` because `NSObject` is not
/// `Sendable` even when its subclass carries only immutable, `Sendable`
/// state.
@available(macOS 10.15, iOS 13.0, *)
final class WebSocketPinningDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let pinning: CertificatePinning?
    private let validateSSLCertificates: Bool
    private let logger = CrossPlatformLogger.logger(
        subsystem: "com.codeeditor.lsp", category: "WebSocketPinning"
    )

    init(pinning: CertificatePinning?, validateSSLCertificates: Bool) {
        self.pinning = pinning
        self.validateSSLCertificates = validateSSLCertificates
    }

    func urlSession(
        _: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // Caller has explicitly opted out of certificate validation. Useful
        // for self-signed dev servers; *not* recommended outside that case.
        if !validateSSLCertificates {
            logger.warning(
                "Bypassing TLS certificate validation for \(challenge.protectionSpace.host) (validateSSLCertificates=false)"
            )
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }

        // Run system trust evaluation first; if the trust is invalid by the
        // platform's own rules, reject regardless of pinning state.
        var trustError: CFError?
        let isSystemTrustValid = SecTrustEvaluateWithError(serverTrust, &trustError)
        guard isSystemTrustValid else {
            if let trustError {
                logger.error("Server trust failed system evaluation: \(trustError)")
            }
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        guard let pinning else {
            // No pinning configured — system trust suffices.
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }

        if Self.serverTrust(serverTrust, matchesPinning: pinning) {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            logger.error(
                "Server trust rejected by pinning policy (\(pinning.method.rawValue)) for \(challenge.protectionSpace.host)"
            )
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    /// Returns `true` iff at least one certificate in `serverTrust`'s chain
    /// matches one of the pinned values under the configured `method`.
    /// Exposed `static` for unit testing without spinning a real session.
    static func serverTrust(
        _ serverTrust: SecTrust,
        matchesPinning pinning: CertificatePinning
    ) -> Bool {
        let allPins = pinning.pinnedData + pinning.backupPins
        guard !allPins.isEmpty else { return false }

        let chain = (SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate]) ?? []
        guard !chain.isEmpty else { return false }

        switch pinning.method {
        case .certificate:
            guard let leaf = chain.first else { return false }
            let leafData = SecCertificateCopyData(leaf) as Data
            return allPins.contains(leafData)

        case .publicKey:
            guard let leaf = chain.first,
                  let publicKey = SecCertificateCopyKey(leaf),
                  let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?
            else { return false }
            let hash = Data(SHA256.hash(data: publicKeyData))
            return allPins.contains(hash)

        case .intermediateCertificate:
            // Match any non-leaf certificate in the chain.
            return chain.dropFirst().contains { cert in
                let certData = SecCertificateCopyData(cert) as Data
                return allPins.contains(certData)
            }
        }
    }
}
