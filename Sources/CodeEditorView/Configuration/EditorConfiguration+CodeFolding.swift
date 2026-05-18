import CodeEditorConfiguration
import Foundation

extension EditorConfiguration {
    /// Maps the code folding settings from this EditorConfiguration to a
    /// CodeFoldingConfiguration that can be used by the CodeFoldingEngine.
    func createCodeFoldingConfiguration() -> CodeFoldingConfiguration {
        var config = CodeFoldingConfiguration()
        config.enabled = display.isCodeFoldingEnabled
        config.showGutterControls = display.areFoldingControlsVisible
        config.minimumLineCount = display.minimumFoldableLines
        config.animatesFolding = performance.animateCodeFolding
        return config
    }
}
