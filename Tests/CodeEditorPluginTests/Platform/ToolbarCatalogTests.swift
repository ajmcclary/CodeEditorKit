@testable import CodeEditorView
import Testing

@Suite("Toolbar catalog")
struct ToolbarCatalogTests {
    @Test(arguments: [
        (ToolbarPlatformKind.macOS, ["find", "replace", "symbol", "format", "minimap", "navigator"]),
        (ToolbarPlatformKind.iPad, ["find", "replace", "symbol", "format"]),
        (ToolbarPlatformKind.iPhone, ["find", "share"])
    ])
    func platformSelection(
        _ platform: ToolbarPlatformKind,
        expectedIdentifiers: [String]
    ) {
        let identifiers = ToolbarCatalog.items(for: platform).map(\.id)
        #expect(identifiers == expectedIdentifiers)
        #expect(Set(identifiers).count == identifiers.count)
    }
}
