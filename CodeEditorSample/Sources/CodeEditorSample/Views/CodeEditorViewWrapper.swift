import CodeEditorPlugin
import SwiftUI

// MARK: - CodeEditorViewWrapper Protocol

/// Protocol defining the common interface for platform-specific code editor wrappers
protocol CodeEditorViewWrapperProtocol: View {
    init(
        configuration: EditorConfiguration,
        text: Binding<String>,
        language: String,
        onTextViewReady: ((CodeEditorView) -> Void)?
    )
}

// MARK: - Shared Language Detection

extension CodeEditorViewWrapperProtocol {
    /// Detects language from file extension using the syntax highlighting coordinator
    func detectLanguage(from fileExtension: String) -> Language {
        let coordinator = SyntaxHighlightingCoordinator()
        return coordinator.detectLanguage(from: fileExtension)
    }
}

// MARK: - Platform-Specific Wrapper Type

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
/// On macOS, use the complex NSViewRepresentable implementation
typealias CodeEditorViewWrapper = MacOSCodeEditorViewWrapper
#else
/// On iOS/Catalyst, use the simple SwiftUI component wrapper
typealias CodeEditorViewWrapper = IOSCodeEditorViewWrapper
#endif
