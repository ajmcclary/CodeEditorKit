import CodeEditorDesignTokens
@testable import CodeEditorPlugin
import Foundation
import Testing

@Suite("Foundation primitives")
struct FoundationPrimitivesTests {
    @Test("DynamicCodingKey roundtrips its stringValue")
    func dynamicCodingKey() {
        let key = DynamicCodingKey(stringValue: "editor.gutter.background")
        #expect(key.stringValue == "editor.gutter.background")
        #expect(key.intValue == nil)
        #expect(DynamicCodingKey(intValue: 5) == nil)
    }

    @Test("WarningCollector accumulates warnings in order")
    func warningCollectorAccumulates() {
        let collector = WarningCollector()
        collector.record(.init(kind: .missingKey, keyPath: "a", detail: nil))
        collector.record(.init(kind: .malformedColor, keyPath: "b", detail: "not-a-color"))
        #expect(collector.warnings.count == 2)
        #expect(collector.warnings[0].kind == .missingKey)
        #expect(collector.warnings[1].detail == "not-a-color")
    }

    @Test("WarningCollector.missing returns fallback and records warning")
    func warningCollectorMissingFallsBack() {
        let collector = WarningCollector()
        let fallback = Tokens.Color(hex: 0xABCDEF)
        let value = collector.missing(path: "text", key: "text.muted", fallback: fallback)
        #expect(value == fallback)
        #expect(collector.warnings.count == 1)
        #expect(collector.warnings[0].kind == .missingKey)
        #expect(collector.warnings[0].keyPath == "text.muted")
    }

    @Test("ZedColorBridge.parse accepts 6- and 8-digit hex")
    func zedColorBridgeParseAccepts() {
        let collector = WarningCollector()
        let opaque = ZedColorBridge.parse("#0A84FF", path: "x", warnings: collector)
        #expect(opaque == Tokens.Color(hex: 0x0A84FF))
        let translucent = ZedColorBridge.parse("#0A84FF80", path: "x", warnings: collector)
        #expect(translucent?.alpha != nil && abs((translucent?.alpha ?? 0) - 0.5) < 0.01)
        #expect(collector.warnings.isEmpty)
    }

    @Test("ZedColorBridge.parse warns on malformed and returns nil")
    func zedColorBridgeParseRejects() {
        let collector = WarningCollector()
        let result = ZedColorBridge.parse("not-a-color", path: "x", warnings: collector)
        #expect(result == nil)
        #expect(collector.warnings.count == 1)
        #expect(collector.warnings[0].kind == .malformedColor)
        #expect(collector.warnings[0].detail == "not-a-color")
    }

    @Test("ZedColorBridge.encode formats 6-digit when opaque, 8-digit when translucent")
    func zedColorBridgeEncode() {
        #expect(ZedColorBridge.encode(Tokens.Color(hex: 0x0A84FF)) == "#0A84FF")
        let translucent = Tokens.Color(hex: 0x0A84FF, alpha: 0.5)
        let encoded = ZedColorBridge.encode(translucent)
        #expect(encoded.hasPrefix("#0A84FF"))
        #expect(encoded.count == 9)
    }
}
