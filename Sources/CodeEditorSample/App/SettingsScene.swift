#if canImport(AppKit)
import CodeEditorPlugin
import SwiftUI

/// Standalone Settings window content (cmd-, opens this). Uses the same
/// shared `AppState` that the main window reads, so any change here is
/// reflected immediately in the editor and vice versa.
///
/// The window uses a `NavigationSplitView` with a sidebar listing the
/// sample's knob categories and a detail pane that reuses the same knob
/// sections rendered in always-expanded mode.
struct SettingsScene: View {
    @Bindable var appState: AppState
    @State private var selection: Category = .display

    enum Category: String, CaseIterable, Identifiable {
        case display, layout, behavior, performance, workspace, annotations, theme

        var id: String { rawValue }

        var title: String {
            switch self {
            case .display: return "Display"
            case .layout: return "Layout"
            case .behavior: return "Behavior"
            case .performance: return "Performance"
            case .workspace: return "Workspace"
            case .annotations: return "Annotations"
            case .theme: return "Theme"
            }
        }

        var icon: String {
            switch self {
            case .display: return "square.grid.2x2"
            case .layout: return "rectangle.split.3x1"
            case .behavior: return "wand.and.stars"
            case .performance: return "gauge.with.dots.needle.bottom.50percent"
            case .workspace: return "folder"
            case .annotations: return "exclamationmark.bubble"
            case .theme: return "paintbrush"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarList
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 220)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .codeTheme(appState.theme)
        .preferredColorScheme(appState.theme.appearance == .dark ? .dark : .light)
        .frame(minWidth: 760, idealWidth: 880, minHeight: 540, idealHeight: 660)
    }

    @ViewBuilder
    private var sidebarList: some View {
        List(Category.allCases, selection: $selection) { category in
            CategoryRow(category: category, isSelected: selection == category)
                .tag(category)
        }
        .listStyle(.sidebar)
        .navigationTitle("Settings")
    }

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                detailContent
            }
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .navigationTitle(selection.title)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection {
        case .display:
            DisplayKnobsSection(configuration: $appState.configuration, expansion: .always)

        case .layout:
            LayoutKnobsSection(configuration: $appState.configuration, expansion: .always)

        case .behavior:
            BehaviorKnobsSection(configuration: $appState.configuration, expansion: .always)

        case .performance:
            PerformanceKnobsSection(configuration: $appState.configuration, expansion: .always)

        case .workspace:
            WorkspaceKnobsSection(workspaceRoot: $appState.workspaceRoot, expansion: .always)

        case .annotations:
            AnnotationsKnobsSection(appState: appState, expansion: .always)

        case .theme:
            SwitcherSection(
                theme: $appState.theme,
                configuration: $appState.configuration,
                documents: appState.documents
            )
            .padding(.top, 4)
        }
    }
}

/// One sidebar row: SF Symbol + title, with hover/selection treatment.
private struct CategoryRow: View {
    @Environment(\.codeEditorTheme) private var theme

    let category: SettingsScene.Category
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: category.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 22, height: 22)
            Text(category.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(Color(tokens: theme.style.text.base))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var iconColor: Color {
        let palette = theme.style.accents
        guard !palette.isEmpty else { return Color(tokens: theme.style.icon.muted) }
        let accent = palette[index % palette.count]
        return Color(tokens: accent)
    }

    private var index: Int {
        switch category {
        case .display: return 0
        case .layout: return 1
        case .behavior: return 2
        case .performance: return 3
        case .workspace: return 4
        case .annotations: return 5
        case .theme: return 6
        }
    }
}
#endif
