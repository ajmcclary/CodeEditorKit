import Testing
@testable import CodeEditorDesignTokens

@Test("schema version is exposed")
func schemaVersionIsExposed() {
    #expect(Tokens.schemaVersion == "1.0.0")
}
