import CodeEditorUI
import Foundation
import Testing

@Suite("CodeEditorUI target compiles")
struct TargetCompilesTests {
    @Test("module loads")
    func moduleLoads() {
        #expect(CodeEditorUI.identifier == "CodeEditorUI")
    }
}
