import CodeEditorConfiguration
@testable import CodeEditorPlugin
import Foundation
import Testing

/// Regression coverage for the deterministic encoding of
/// `EditorConfiguration.Behavior.completionTriggerCharacters`.
///
/// The previous encoder wrote `String(completionTriggerCharacters)`
/// directly over a `Set<Character>`; set iteration order is unstable
/// across runs, so two equivalent configurations could produce
/// different JSON strings, causing noisy snapshot diffs and breaking
/// content-hash-based caching. The fix sorts the characters before
/// encoding.
@Suite("EditorConfiguration.Behavior JSON encoding stability")
struct EditorConfigurationBehaviorEncodingTests {
    @Test("Encoding the same Behavior twice yields byte-identical JSON")
    func encodeIsIdempotent() throws {
        var behavior = EditorConfiguration.Behavior()
        behavior.completionTriggerCharacters = [".", ":", "<", "/", "\"", "'", " "]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let first = try encoder.encode(behavior)
        let second = try encoder.encode(behavior)
        #expect(first == second, "Equivalent configurations must serialize identically")
    }

    @Test("Two Behaviors with the same trigger characters encode identically")
    func equivalentConfigsEncodeIdentically() throws {
        var lhs = EditorConfiguration.Behavior()
        var rhs = EditorConfiguration.Behavior()
        // Insert the same characters in different orders to make any
        // accidental insertion-order dependence visible.
        lhs.completionTriggerCharacters = Set(["a", "b", "c"])
        rhs.completionTriggerCharacters = Set(["c", "b", "a"])

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let lhsJSON = try encoder.encode(lhs)
        let rhsJSON = try encoder.encode(rhs)
        #expect(lhsJSON == rhsJSON, "Two Sets containing the same characters must serialize identically")
    }

    @Test("Encoded trigger-characters string is in sorted order")
    func encodedStringIsSorted() throws {
        var behavior = EditorConfiguration.Behavior()
        behavior.completionTriggerCharacters = ["z", "a", "m", "."]

        let encoder = JSONEncoder()
        let data = try encoder.encode(behavior)
        let json = try #require(String(data: data, encoding: .utf8))

        // The encoded value should contain ".amz" — sorted ascending.
        #expect(
            json.contains("\"completionTriggerCharacters\":\".amz\""),
            "Trigger characters must encode in sorted order. Got: \(json)"
        )
    }

    @Test("Encode → decode round-trip preserves the trigger-character set")
    func roundTripPreservesSet() throws {
        var original = EditorConfiguration.Behavior()
        original.completionTriggerCharacters = [".", ":", "/", "<", "\""]

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(EditorConfiguration.Behavior.self, from: data)

        #expect(decoded.completionTriggerCharacters == original.completionTriggerCharacters)
    }
}
