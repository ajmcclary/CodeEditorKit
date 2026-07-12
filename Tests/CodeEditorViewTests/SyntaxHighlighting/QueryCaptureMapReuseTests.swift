import CodeEditorLanguages
@testable import CodeEditorSyntaxHighlighting
import Testing

@Suite("Query capture-map reuse")
struct QueryCaptureMapReuseTests {
    @Test("TypeScript includes JavaScript mappings plus explicit overrides")
    func typescriptDerivation() {
        #expect(QueryCaptureMap.typescript.tokenType(for: "function") == .function)
        #expect(QueryCaptureMap.typescript.tokenType(for: "interface") == .type)
        #expect(QueryCaptureMap.typescript.tokenType(for: "type.alias") == .type)
    }

    @Test("merging replaces existing values without mutating the source")
    func explicitOverride() {
        let merged = QueryCaptureMap.javascript.merging(["function": .keyword])
        #expect(merged.tokenType(for: "function") == .keyword)
        #expect(QueryCaptureMap.javascript.tokenType(for: "function") == .function)
    }
}
