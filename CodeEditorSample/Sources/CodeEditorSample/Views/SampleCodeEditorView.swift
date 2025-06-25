#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import CodeEditorPlugin
import SwiftUI

struct SampleCodeEditorView: View {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String

    var body: some View {
        CodeEditorViewWrapper(
            configuration: configuration,
            text: $text,
            language: language,
            onTextViewReady: nil
        )
        .background(Color(configuration.theme.backgroundColor))
    }
}
