import DesignKitTokens
import CodeEditorPlugin
import CodeEditorSwiftUI
import SwiftUI

/// Modal sheet for jumping the caret to a specific line. Triggered from
/// the command palette ("Go to Line…"). Backed by
/// `EditorController.gotoLine(_:)`.
struct GotoLineSheet: View {
    @Environment(\.designTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    let controller: EditorController
    @State private var lineText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Go to Line")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(tokens: theme.style.text.base))
            TextField("Line number", text: $lineText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .onSubmit { submit() }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Go") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(parsedLine == nil)
            }
        }
        .padding(20)
        .frame(width: 280)
    }

    private var parsedLine: Int? {
        let trimmed = lineText.trimmingCharacters(in: .whitespaces)
        guard let value = Int(trimmed), value >= 1 else { return nil }
        return value
    }

    private func submit() {
        guard let line = parsedLine else { return }
        controller.gotoLine(line)
        dismiss()
    }
}
