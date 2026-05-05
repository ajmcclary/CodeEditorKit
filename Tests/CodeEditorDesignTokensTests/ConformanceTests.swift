import Testing
import Foundation
@testable import CodeEditorDesignTokens

/// Compile-time conformance asserts. If any value type loses Sendable,
/// Hashable, or Codable, this file stops compiling.
@Suite("Tokens conformance audit")
struct ConformanceTests {

    @Test("Tokens.Color conforms to Sendable, Hashable, Codable")
    func colorConformance() {
        Self.requireConformance(Tokens.Color.self)
    }

    @Test("Tokens.Easing conforms to Sendable, Hashable, Codable")
    func easingConformance() {
        Self.requireConformance(Tokens.Easing.self)
    }

    private static func requireConformance<T>(_ type: T.Type)
    where T: Sendable & Hashable & Codable {
        _ = String(describing: type)
    }
}
