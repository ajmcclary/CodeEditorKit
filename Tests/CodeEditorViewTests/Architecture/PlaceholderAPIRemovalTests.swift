import Foundation
import Testing

@Suite("Placeholder API removal")
struct PlaceholderAPIRemovalTests {
    @Test("production sources contain no identity text processor")
    func noIdentityTextProcessor() {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = root.appending(
            path: "Sources/CodeEditorView/Actors/TextProcessingActor.swift"
        )

        #expect(FileManager.default.fileExists(atPath: source.path) == false)
    }
}
