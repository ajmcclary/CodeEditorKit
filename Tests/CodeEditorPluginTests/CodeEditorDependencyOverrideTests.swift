import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
import CodeEditorTextModel
@testable import CodeEditorView
import Dependencies
import Testing

@Suite("CodeEditor dependency overrides")
struct CodeEditorDependencyOverrideTests {
    @MainActor
    @Test("Memory monitor factory uses dependency overrides")
    func memoryMonitorFactoryUsesDependencyOverride() {
        let monitor = MemoryMonitor()

        withDependencies {
            $0.codeEditorMemoryMonitor = { monitor }
        } operation: {
            #expect(CodeEditorDependencies.makeMemoryMonitor() === monitor)
        }
    }

    @Test("Paragraph style cache factory uses dependency overrides")
    func paragraphStyleCacheFactoryUsesDependencyOverride() {
        let cache = ParagraphStyleCache()

        withDependencies {
            $0.codeEditorParagraphStyleCache = { cache }
        } operation: {
            #expect(CodeEditorDependencies.makeParagraphStyleCache() === cache)
        }
    }
}
