import AppKit
import CodeEditorPlugin
import SwiftUI

struct CodeEditorView: View {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String

    var body: some View {
        UnifiedCodeEditorView(
            configuration: configuration,
            text: $text,
            language: language,
            onTextViewReady: nil
        )
        .background(Color(configuration.theme.backgroundColor))
    }
}
