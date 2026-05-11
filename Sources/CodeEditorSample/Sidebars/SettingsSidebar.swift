#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Left sidebar shell: prominent header with active preset subtitle,
/// switcher card, then the knob sections.
///
/// Uses `EditorSidebarShell` from `CodeEditorUI`, which is macOS-only.
/// The iOS variant (`IOSRootView`) presents controls in a
/// `NavigationSplitView`.
struct SettingsSidebar: View {
    @Bindable var appState: AppState

    var body: some View {
        EditorSidebarShell(
            prominentTitle: "Editor",
            prominentSubtitle: subtitle,
            onReset: { appState.configuration = PresetCatalog.default.configuration }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SwitcherSection(
                        theme: $appState.theme,
                        configuration: $appState.configuration,
                        documents: appState.documents
                    )
                    knobSections
                    Spacer(minLength: 12)
                }
                .padding(.bottom, 16)
            }
        }
        .frame(width: 300)
    }

    private var subtitle: String {
        let activePreset = PresetCatalog.all.first { $0.configuration == appState.configuration }
        return "\(activePreset?.name ?? "Custom") preset"
    }

    @ViewBuilder
    private var knobSections: some View {
        VStack(alignment: .leading, spacing: 4) {
            DisplayKnobsSection(configuration: $appState.configuration)
            LayoutKnobsSection(configuration: $appState.configuration)
            BehaviorKnobsSection(configuration: $appState.configuration)
            PerformanceKnobsSection(configuration: $appState.configuration)
            WorkspaceKnobsSection(configuration: $appState.configuration)
            AnnotationsKnobsSection(appState: appState)
        }
    }
}
#endif
