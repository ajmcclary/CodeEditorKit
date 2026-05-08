#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Right sidebar: live `EditorConfiguration` rendered as Swift source,
/// with a Copy button. macOS / Catalyst only — see `IOSRootView` for the
/// iOS variant.
struct InspectorSidebar: View {
    @Environment(\.codeEditorTheme) private var theme
    let configuration: EditorConfiguration

    var body: some View {
        EditorSidebarShell(
            sectionTitle: "Configuration",
            content: {
                ScrollView {
                    Text(rendered)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color(tokens: theme.style.text.base))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
            },
            footer: {
                HStack {
                    Spacer()
                    Button("Copy") {
                        copyToPasteboard(rendered)
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        )
        .frame(width: 360)
    }

    private var rendered: String {
        ConfigurationCodeFormatter.render(configuration)
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
#endif
