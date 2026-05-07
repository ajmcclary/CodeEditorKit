#if canImport(AppKit)
import CodeEditorPlugin
import SwiftUI

/// Standalone Settings window content (cmd-, opens this). Uses the same
/// shared `AppState` that the main window reads, so any change here is
/// reflected immediately in the editor and vice versa.
///
/// Tab layout follows macOS conventions (Display / Layout / Behavior /
/// Performance / Theme), reusing the existing knob sections — no second
/// implementation of the controls.
struct SettingsScene: View {
    @Bindable var appState: AppState

    var body: some View {
        TabView {
            displayTab
                .tabItem { Label("Display", systemImage: "rectangle.lefthalf.inset.filled") }

            layoutTab
                .tabItem { Label("Layout", systemImage: "rectangle.split.3x1") }

            behaviorTab
                .tabItem { Label("Behavior", systemImage: "wand.and.stars") }

            performanceTab
                .tabItem { Label("Performance", systemImage: "speedometer") }

            themeTab
                .tabItem { Label("Theme", systemImage: "paintbrush") }
        }
        .codeTheme(appState.theme)
        .environment(\.codeEditorConfiguration, appState.configuration)
        .preferredColorScheme(appState.theme.appearance == .dark ? .dark : .light)
        .frame(minWidth: 480, idealWidth: 540, minHeight: 380, idealHeight: 520)
        .padding(20)
    }

    @ViewBuilder
    private var displayTab: some View {
        ScrollView {
            DisplayKnobsSection(configuration: $appState.configuration)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var layoutTab: some View {
        ScrollView {
            LayoutKnobsSection(configuration: $appState.configuration)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var behaviorTab: some View {
        ScrollView {
            BehaviorKnobsSection(configuration: $appState.configuration)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var performanceTab: some View {
        ScrollView {
            PerformanceKnobsSection(configuration: $appState.configuration)
                .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var themeTab: some View {
        ScrollView {
            SwitcherSection(
                theme: $appState.theme,
                configuration: $appState.configuration,
                documents: appState.documents
            )
            .padding(.vertical, 8)
        }
    }
}
#endif
