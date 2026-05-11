#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import Foundation
import SwiftUI

/// Read-only inspector surface for the LSP subsystem. Registers a handful
/// of common language-server configs and probes their availability on
/// disk. This makes `EditorConfiguration.workspaceRoot` + `LSPManager`
/// addressable from the sample without requiring a live server connection;
/// connection-state wiring through the SwiftUI `CodeEditor` wrapper still
/// needs a framework-side modifier and is out of scope for the sample.
struct LSPStatusPanel: View {
    @Environment(\.codeEditorTheme) private var theme
    let workspaceRoot: URL?

    @State private var availability: [String: Bool] = [:]
    @State private var resolvedPaths: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            workspaceRow
            Divider()
                .background(Color(tokens: theme.style.borders.variant))
            ForEach(Self.probes, id: \.languageId) { config in
                serverRow(config)
            }
            footer
        }
        .padding(12)
        .background(panelBackground)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .onAppear { refresh() }
        .onChange(of: workspaceRoot) { _, _ in refresh() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "network")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.text.accent))
            Text("Language Servers")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(tokens: theme.style.text.base))
            Spacer()
            Button {
                refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Re-probe server availability")
            .foregroundStyle(Color(tokens: theme.style.text.muted))
        }
    }

    private var workspaceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 11))
                .foregroundStyle(Color(tokens: theme.style.icon.muted))
                .frame(width: 14)
            Text("workspaceRoot:")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
            Text(workspaceRoot?.path ?? "Not set")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(tokens: workspaceRoot == nil
                                       ? theme.style.text.muted
                                       : theme.style.text.base))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func serverRow(_ config: LanguageServerConfig) -> some View {
        let isAvailable = availability[config.languageId] ?? false
        let resolved = resolvedPaths[config.languageId]
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                statusDot(available: isAvailable)
                Text(config.languageId)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                Spacer()
                Text(isAvailable ? "available" : "not found")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color(tokens: isAvailable
                                           ? theme.style.text.accent
                                           : theme.style.text.muted))
            }
            Text(resolved ?? config.serverPath)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.leading, 22)
        }
        .padding(.vertical, 2)
    }

    private func statusDot(available: Bool) -> some View {
        Circle()
            .fill(available ? Color.green : Color.secondary.opacity(0.4))
            .frame(width: 8, height: 8)
            .frame(width: 14)
    }

    private var footer: some View {
        Text("Probing only — connection wiring requires a framework-side modifier on CodeEditor.")
            .font(.system(size: 9))
            .foregroundStyle(Color(tokens: theme.style.text.muted))
            .padding(.top, 4)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(tokens: theme.style.elements.element.background))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(tokens: theme.style.borders.variant), lineWidth: 0.5)
            )
    }

    @MainActor
    private func refresh() {
        let monitor = MemoryMonitor()
        let manager = LSPManager(memoryMonitor: monitor, workspaceRoot: workspaceRoot)
        var avail: [String: Bool] = [:]
        var paths: [String: String] = [:]
        for config in Self.probes {
            manager.registerLanguageServer(config)
            avail[config.languageId] = manager.isLanguageServerAvailable(config)
            paths[config.languageId] = manager.resolveLanguageServerPath(config)
        }
        availability = avail
        resolvedPaths = paths
    }

    private static let probes: [LanguageServerConfig] = [
        LanguageServerConfig(
            languageId: "swift",
            serverPath: "sourcekit-lsp",
            fileExtensions: ["swift"],
            autoStart: false
        ),
        LanguageServerConfig(
            languageId: "python",
            serverPath: "pyright-langserver",
            fileExtensions: ["py", "pyw"],
            autoStart: false
        ),
        LanguageServerConfig(
            languageId: "typescript",
            serverPath: "typescript-language-server",
            fileExtensions: ["ts", "tsx", "js", "jsx"],
            autoStart: false
        )
    ]
}
#endif
