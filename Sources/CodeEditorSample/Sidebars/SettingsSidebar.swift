#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Left sidebar shell: prominent header with active preset subtitle,
/// switcher card, then the four knob sections.
///
/// Uses `EditorSidebarShell` from `CodeEditorUI`, which is macOS / Catalyst
/// only. The iOS variant (`IOSRootView`) presents the same controls in a
/// `NavigationSplitView`.
struct SettingsSidebar: View {
    @Binding var theme: Theme
    @Binding var configuration: EditorConfiguration
    @Bindable var documents: DocumentStore

    var body: some View {
        EditorSidebarShell(
            prominentTitle: "Editor",
            prominentSubtitle: subtitle,
            onReset: { configuration = PresetCatalog.default.configuration }
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    SwitcherSection(
                        theme: $theme,
                        configuration: $configuration,
                        documents: documents
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
        let activePreset = PresetCatalog.all.first { $0.configuration == configuration }
        return "\(activePreset?.name ?? "Custom") preset"
    }

    @ViewBuilder
    private var knobSections: some View {
        VStack(alignment: .leading, spacing: 4) {
            DisplayKnobsSection(configuration: $configuration)
            LayoutKnobsSection(configuration: $configuration)
            BehaviorKnobsSection(configuration: $configuration)
            PerformanceKnobsSection(configuration: $configuration)
            WorkspaceKnobsSection(configuration: $configuration)
        }
    }
}
#endif
