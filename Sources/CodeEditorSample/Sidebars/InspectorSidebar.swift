import AppKit
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Right sidebar: live `EditorConfiguration` rendered as Swift source,
/// with a Copy button.
struct InspectorSidebar: View {
    let configuration: EditorConfiguration

    var body: some View {
        EditorSidebarShell(
            sectionTitle: "Configuration",
            content: {
                ScrollView {
                    Text(rendered)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
            },
            footer: {
                HStack {
                    Spacer()
                    Button("Copy") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(rendered, forType: .string)
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
}
