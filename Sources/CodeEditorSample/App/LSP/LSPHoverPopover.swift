#if canImport(AppKit)
import CodeEditorSwiftUI
import SwiftUI

/// SwiftUI content for the hover popover. Renders an LSP `Hover` result's
/// markdown via `LocalizedStringKey` so basic markdown formatting (bold,
/// italics, monospace) lights up automatically.
struct LSPHoverPopover: View {
    let markdown: String

    var body: some View {
        ScrollView {
            Text(LocalizedStringKey(markdown))
                .textSelection(.enabled)
                .padding(8)
        }
        .frame(
            minWidth: 280,
            idealWidth: 360,
            maxWidth: 480,
            minHeight: 40,
            idealHeight: 120,
            maxHeight: 300
        )
    }
}
#endif
