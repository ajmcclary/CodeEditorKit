#if canImport(AppKit)
import AppKit
#endif
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Section that surfaces `EditorConfiguration.workspaceRoot`. The picker
/// is macOS-only (NSOpenPanel); iOS shows the current value with a clear
/// button. The framework's LSP and file-relative features key off this
/// URL, so wiring it from the sample makes those subsystems addressable
/// at all.
struct WorkspaceKnobsSection: View {
    @Environment(\.codeEditorTheme) private var theme
    @Binding var configuration: EditorConfiguration
    @State private var expanded: Bool = true
    var expansion: KnobSectionExpansion = .toggleable

    var body: some View {
        KnobSection(
            title: "Workspace",
            icon: "folder",
            accentIndex: 4,
            expanded: $expanded,
            expansion: expansion
        ) {
            VStack(alignment: .leading, spacing: 0) {
                KnobSubsection(title: "Workspace Root")
                pathRow
                actionRow
            }
        }
        .padding(.horizontal, 12)
    }

    private var pathRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(tokens: theme.style.icon.muted))
                .frame(width: 18, height: 18)
            Text(pathDisplay)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(tokens: configuration.workspaceRoot == nil
                                       ? theme.style.text.muted
                                       : theme.style.text.base))
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Spacer().frame(width: 28, height: 0)
            #if canImport(AppKit)
            Button {
                presentOpenPanel()
            } label: {
                Label("Choose…", systemImage: "folder.badge.plus")
                    .labelStyle(.titleAndIcon)
            }
            .controlSize(.small)
            #endif
            if configuration.workspaceRoot != nil {
                Button(role: .destructive) {
                    configuration.workspaceRoot = nil
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                        .labelStyle(.titleAndIcon)
                }
                .controlSize(.small)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var pathDisplay: String {
        configuration.workspaceRoot?.path ?? "Not set"
    }

    #if canImport(AppKit)
    @MainActor
    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Workspace"
        if let current = configuration.workspaceRoot {
            panel.directoryURL = current
        }
        if panel.runModal() == .OK, let url = panel.url {
            configuration.workspaceRoot = url
        }
    }
    #endif
}
