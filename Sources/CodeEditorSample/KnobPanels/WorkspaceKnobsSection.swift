#if canImport(AppKit)
import AppKit
import CodeEditorSwiftUI
#endif
import DesignKitTokens
import CodeEditorPlugin
import SwiftUI

/// Section that surfaces the runtime workspace root. The picker
/// is macOS-only (NSOpenPanel); iOS shows the current value with a clear
/// button. The framework's LSP and file-relative features key off this
/// URL, so wiring it from the sample makes those subsystems addressable
/// at all.
struct WorkspaceKnobsSection: View {
    @Environment(\.designTheme) private var theme
    @Binding var workspaceRoot: URL?
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
                .foregroundStyle(Color(tokens: workspaceRoot == nil
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
                WorkspacePicker.choose(currentRoot: workspaceRoot) { workspaceRoot = $0 }
            } label: {
                Label("Choose…", systemImage: "folder.badge.plus")
                    .labelStyle(.titleAndIcon)
            }
            .controlSize(.small)
            #endif
            if workspaceRoot != nil {
                Button(role: .destructive) {
                    workspaceRoot = nil
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
        workspaceRoot?.path ?? "Not set"
    }
}
