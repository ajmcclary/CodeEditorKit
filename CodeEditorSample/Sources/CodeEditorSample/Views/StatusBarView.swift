import CodeEditorPlugin
import SwiftUI

struct StatusBarView: View {
    let textView: STTextView?
    @State private var cursorPosition: (line: Int, column: Int) = (1, 1)
    @State private var selectionLength: Int = 0
    @State private var totalLines: Int = 0
    @State private var language: String = "Plain Text"

    var body: some View {
        HStack {
            // Language indicator
            Label(language, systemImage: "doc.text")
                .font(.caption)

            Spacer()

            // Selection info
            if selectionLength > 0 {
                Text("\(selectionLength) selected")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()
                    .frame(height: 12)
            }

            // Line and column
            Text("Ln \(cursorPosition.line), Col \(cursorPosition.column)")
                .font(.caption)
                .monospacedDigit()

            Divider()
                .frame(height: 12)

            // Total lines
            Text("\(totalLines) lines")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            setupObservers()
            updateStatus()
        }
    }

    private func setupObservers() {
        // Listen for text changes
        NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { _ in
            Task { @MainActor in
                updateStatus()
            }
        }

        // Listen for selection changes
        NotificationCenter.default.addObserver(
            forName: NSTextView.didChangeSelectionNotification,
            object: textView,
            queue: .main
        ) { _ in
            Task { @MainActor in
                updateStatus()
            }
        }
    }

    private func updateStatus() {
        guard let textView else {
            return
        }

        // Get cursor position
        let selectedRange = textView.selectedRange()
        let text = textView.string as NSString

        // Calculate line and column
        var line = 1
        var column = 1

        if selectedRange.location <= text.length {
            // Count lines up to cursor
            let substring = text.substring(to: selectedRange.location)
            line = substring.components(separatedBy: .newlines).count

            // Calculate column (position within current line)
            let lineRange = text.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            column = selectedRange.location - lineRange.location + 1
        }

        cursorPosition = (line, column)
        selectionLength = selectedRange.length

        // Count total lines
        totalLines = textView.string.components(separatedBy: .newlines).count
    }
}
