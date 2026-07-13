import CodeEditorPlugin
import CodeEditorSwiftUI
import DesignKitTokens
import SwiftUI

/// How a `KnobSection`'s content area behaves.
enum KnobSectionExpansion {
    /// User-controlled disclosure with chevron. Default for the sidebar.
    case toggleable
    /// Always-expanded; renders no chevron. Used in the Settings window
    /// where each detail pane shows a single category.
    case always
}

/// Reusable collapsible section for the settings sidebar and Settings
/// window. Renders an accent-striped header with icon + title + chevron,
/// and an expand/collapse animation around the supplied content.
struct KnobSection<Content: View>: View {
    @Environment(\.designTheme) private var theme

    let title: String
    let icon: String
    let accentIndex: Int
    let expansion: KnobSectionExpansion
    @Binding var expanded: Bool
    @ViewBuilder let content: () -> Content

    @State private var isHovering: Bool = false

    init(
        title: String,
        icon: String,
        accentIndex: Int,
        expanded: Binding<Bool>,
        expansion: KnobSectionExpansion = .toggleable,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.accentIndex = accentIndex
        self.expansion = expansion
        self._expanded = expanded
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if isExpanded {
                content()
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 4)
    }

    private var isExpanded: Bool {
        switch expansion {
        case .always: return true
        case .toggleable: return expanded
        }
    }

    private var header: some View {
        Button {
            guard expansion == .toggleable else { return }
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
        } label: {
            HStack(spacing: 10) {
                accentStripe
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(tokens: accentColor))
                    .frame(width: 18, height: 18)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                Spacer(minLength: 0)
                if expansion == .toggleable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(tokens: theme.style.text.muted))
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.18), value: expanded)
                }
            }
            .padding(.leading, 8)
            .padding(.trailing, 12)
            .frame(height: 44)
            .background(headerBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(expansion == .always)
        .onHover { hovering in
            guard expansion == .toggleable else { return }
            isHovering = hovering
        }
    }

    private var accentStripe: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color(tokens: accentColor))
            .frame(width: 3, height: 22)
    }

    @ViewBuilder
    private var headerBackground: some View {
        if isHovering, expansion == .toggleable {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(tokens: theme.style.elements.element.hover))
        } else {
            Color.clear
        }
    }

    private var accentColor: Tokens.Color {
        let palette = theme.style.accents
        guard !palette.isEmpty else { return theme.style.text.accent }
        return palette[accentIndex % palette.count]
    }
}
