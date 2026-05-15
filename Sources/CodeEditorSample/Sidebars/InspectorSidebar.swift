#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// Right-rail inspector chrome for macOS. Wraps `InspectorPanelStack`
/// in an `EditorSidebarShell` and pins a fixed 360-pt width. The
/// stack reads from `AppState` and owns the panel composition; this
/// view owns only the macOS-specific chrome and the performance-report
/// sheet binding.
struct InspectorSidebar: View {
    @Bindable var appState: AppState
    @State private var showingPerformanceReport = false

    var body: some View {
        EditorSidebarShell(sectionTitle: "Configuration") {
            InspectorPanelStack(
                appState: appState,
                showingPerformanceReport: $showingPerformanceReport
            )
        }
        .frame(width: 360)
    }
}
#endif
