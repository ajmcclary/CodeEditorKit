#if canImport(AppKit)
import Foundation

/// Test stand-in for the `xcrun --find sourcekit-lsp` lookup that
/// `LSPSampleCoordinator` performs at startup. Inject via the coordinator's
/// `serverResolver` init parameter so coordinator-state tests can run
/// without depending on whether Xcode is installed.
enum StubProcessResolver {
    static let succeeds: @Sendable () async -> URL? = {
        URL(fileURLWithPath: "/fake/path/to/sourcekit-lsp")
    }

    static let fails: @Sendable () async -> URL? = {
        nil
    }
}
#endif
