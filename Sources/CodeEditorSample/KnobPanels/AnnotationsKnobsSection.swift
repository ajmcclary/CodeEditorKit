import CodeEditorPlugin
import SwiftUI

/// Settings-sidebar section with buttons to drive the demo annotations
/// (TODO / FIXME / WARNING / ERROR) at the caret line, plus a "clear
/// all" affordance.
struct AnnotationsKnobsSection: View {
    @Bindable var appState: AppState
    @State private var expanded: Bool = false
    var expansion: KnobSectionExpansion = .toggleable

    var body: some View {
        KnobSection(
            title: "Annotations",
            icon: "exclamationmark.bubble",
            accentIndex: 5,
            expanded: $expanded,
            expansion: expansion
        ) {
            VStack(alignment: .leading, spacing: 0) {
                KnobSubsection(title: "Add at Cursor")
                ButtonRow(
                    label: "Add TODO",
                    icon: "checkmark.circle"
                ) {
                    addAnnotation(.todo)
                }
                ButtonRow(
                    label: "Add FIXME",
                    icon: "wrench"
                ) {
                    addAnnotation(.fixme)
                }
                ButtonRow(
                    label: "Add WARNING",
                    icon: "exclamationmark.triangle"
                ) {
                    addAnnotation(.warning)
                }

                KnobSubsection(title: "Cleanup")
                ButtonRow(
                    label: "Clear Demo Annotations",
                    icon: "trash"
                ) {
                    appState.annotationsHub.clearAllDemoAnnotations()
                }
                ButtonRow(
                    label: "Clear Breakpoints",
                    icon: "stop.circle"
                ) {
                    appState.annotationsHub.clearAllBreakpoints()
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func addAnnotation(_ kind: AnnotationKind) {
        guard let line = appState.editorController.currentLineNumber else { return }
        appState.annotationsHub.addDemoAnnotation(kind: kind, at: line)
    }
}

private struct ButtonRow: View {
    @Environment(\.codeEditorTheme) private var theme
    let label: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color(tokens: theme.style.icon.muted))
                    .frame(width: 18, height: 18)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}
