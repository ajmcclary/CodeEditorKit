import CodeEditorLanguages
import CodeEditorPlugin
import CodeEditorSwiftUI
import DesignKitTokens
import SwiftUI

/// Inspector surface that lists the host-managed annotations and
/// breakpoint markers, plus the current document's symbols. Drives no
/// editor state directly — purely reflects what's in `AnnotationsHub`
/// and `EditorController.symbols`.
struct AnnotationsInspectorPanel: View {
    @Environment(\.designTheme) private var theme
    let hub: AnnotationsHub
    let controller: EditorController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            breakpointSection
            demoSection
            symbolSection
        }
        .padding(12)
        .background(panelBackground)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var breakpointSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            header(icon: "stop.circle.fill", title: "Breakpoints", accent: .red)
            if hub.breakpointLines.isEmpty {
                empty("No breakpoints set. Try ⌘⇧P → Toggle Breakpoint at Cursor.")
            } else {
                ForEach(hub.breakpointLines.sorted(), id: \.self) { line in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Line \(line)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(tokens: theme.style.text.base))
                        Spacer()
                        Button {
                            hub.toggleBreakpoint(at: line)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(tokens: theme.style.text.muted))
                        .help("Remove breakpoint")
                    }
                }
            }
        }
    }

    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            header(icon: "exclamationmark.bubble", title: "Demo Annotations", accent: .yellow)
            if hub.demoAnnotations.isEmpty {
                empty("Add a TODO/FIXME from the command palette or the Annotations knob section.")
            } else {
                ForEach(hub.demoAnnotations.keys.sorted(), id: \.self) { line in
                    HStack(spacing: 8) {
                        Text(hub.demoAnnotations[line]?.rawValue ?? "")
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(tokens: theme.style.elements.element.background))
                            )
                        Text("Line \(line)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(tokens: theme.style.text.base))
                        Spacer()
                        Button {
                            hub.removeDemoAnnotation(at: line)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(tokens: theme.style.text.muted))
                    }
                }
            }
        }
    }

    private var symbolSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            header(icon: "list.bullet.indent", title: "Symbols", accent: .blue)
            if controller.symbols.isEmpty {
                empty("No symbols detected for the active language.")
            } else {
                let flattened = flatten(controller.symbols).prefix(20)
                ForEach(Array(flattened), id: \.id) { symbol in
                    Button {
                        controller.gotoSymbol(symbol)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "function")
                                .font(.system(size: 10))
                                .foregroundStyle(Color(tokens: theme.style.text.accent))
                                .frame(width: 12)
                            Text(symbol.name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color(tokens: theme.style.text.base))
                                .lineLimit(1)
                            Spacer()
                            Text(symbol.kind.rawValue)
                                .font(.system(size: 9))
                                .foregroundStyle(Color(tokens: theme.style.text.muted))
                        }
                    }
                    .buttonStyle(.plain)
                }
                if controller.symbols.count > 20 {
                    Text("…and more (open Go to Symbol… to filter all).")
                        .font(.system(size: 9))
                        .foregroundStyle(Color(tokens: theme.style.text.muted))
                }
            }
        }
    }

    private func header(icon: String, title: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(accent)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(tokens: theme.style.text.base))
        }
    }

    private func empty(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 10))
            .foregroundStyle(Color(tokens: theme.style.text.muted))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func flatten(_ symbols: [DocumentSymbol]) -> [DocumentSymbol] {
        var out: [DocumentSymbol] = []
        for symbol in symbols {
            out.append(symbol)
            out.append(contentsOf: flatten(symbol.children))
        }
        return out
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(tokens: theme.style.elements.element.background))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(tokens: theme.style.borders.variant), lineWidth: 0.5)
            )
    }
}
