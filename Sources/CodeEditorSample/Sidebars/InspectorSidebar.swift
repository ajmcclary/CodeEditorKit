#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Right sidebar: LSP probe, annotation/symbol panel, live
/// `EditorConfiguration` rendered as Swift source, with a Copy button.
/// macOS only — see `IOSRootView` for the iOS variant.
struct InspectorSidebar: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var appState: AppState
    @State private var showingPerformanceReport = false

    var body: some View {
        EditorSidebarShell(
            sectionTitle: "Configuration",
            content: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        LSPInspectorPanel(
                            state: appState.lsp.state,
                            counts: appState.lsp.diagnosticCounts,
                            serverPath: appState.lsp.resolvedServerPath,
                            lastError: appState.lsp.lastError,
                            isSwiftActive: appState.documents.activeLanguage == .swift,
                            onToggle: handleToggle
                        )
                        PerformanceInspectorPanel(
                            state: appState.performance.state,
                            fps: appState.performance.fps,
                            memoryStats: appState.performance.memoryStats,
                            pressure: appState.performance.pressure,
                            adaptiveMode: appState.performance.adaptiveMode,
                            lastHighlightMs: appState.performance.lastHighlightMs,
                            highlightP95Ms: appState.performance.highlightP95Ms,
                            healthScore: appState.performance.healthScore,
                            issuesCount: appState.performance.issuesCount,
                            recommendationsCount: appState.performance.recommendationsCount,
                            memorySparkline: appState.performance.memorySparkline,
                            thresholds: .default(fpsTarget: appState.performance.targetFPS),
                            onResetPeak: { appState.performance.resetPeak() },
                            onShowReport: { showingPerformanceReport = true },
                            onAppear: { appState.performance.start() },
                            onDisappear: { appState.performance.stop() }
                        )
                        .sheet(isPresented: $showingPerformanceReport) {
                            DetailedPerformanceReportView(insights: appState.performance.performanceInsights)
                        }
                        AnnotationsInspectorPanel(
                            hub: appState.annotationsHub,
                            controller: appState.editorController
                        )
                        Text(rendered)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color(tokens: theme.style.text.base))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(12)
                    }
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
        ConfigurationCodeFormatter.render(appState.configuration)
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func handleToggle() {
        Task {
            switch appState.lsp.state {
            case .off, .failed:
                await appState.lsp.start(workspaceRoot: appState.workspaceRoot)
                // Open every Swift tab into the freshly started session.
                if case .running = appState.lsp.state {
                    for tab in appState.documents.tabs where tab.language == .swift {
                        let text = appState.documents.textBinding(for: tab.id).wrappedValue
                        await appState.lsp.openTab(id: tab.id, text: text, language: .swift)
                    }
                }

            case .running:
                await appState.lsp.stop()

            default:
                break
            }
        }
    }
}
#endif
