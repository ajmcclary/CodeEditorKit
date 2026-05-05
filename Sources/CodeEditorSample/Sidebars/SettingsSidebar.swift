import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Left sidebar shell: switchers on top, four knob sections below.
struct SettingsSidebar: View {
    @Binding var theme: Theme
    @Binding var configuration: EditorConfiguration
    @Bindable var documents: DocumentStore

    var body: some View {
        EditorSidebarShell(sectionTitle: "Settings") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SwitcherSection(
                        theme: $theme,
                        configuration: $configuration,
                        documents: documents
                    )
                    knobSections
                    Spacer(minLength: 8)
                }
                .padding(.bottom, 12)
            }
        }
        .frame(width: 280)
    }

    @ViewBuilder
    private var knobSections: some View {
        VStack(alignment: .leading, spacing: 6) {
            DisplayKnobsSection(configuration: $configuration)
            LayoutKnobsSection(configuration: $configuration)
            BehaviorKnobsSection(configuration: $configuration)
            PerformanceKnobsSection(configuration: $configuration)
        }
    }
}
