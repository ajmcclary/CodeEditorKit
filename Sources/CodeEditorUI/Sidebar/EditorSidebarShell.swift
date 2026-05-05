#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// Styled sidebar container. *No tree* — the host fills `content` with
/// whatever workspace/file/search view is appropriate. Provides a
/// glass-backed panel with optional header (tab bar in the prototype),
/// a section title, and a footer slot.
///
/// Available on macOS and Mac Catalyst. Absent on iOS — sidebars on
/// iPad have a different navigation idiom and aren't covered by this
/// component.
public struct EditorSidebarShell<Header: View, Content: View, Footer: View>: View {
    @Environment(\.codeEditorTheme) private var theme

    private let sectionTitle: String?
    private let header: () -> Header
    private let content: () -> Content
    private let footer: () -> Footer

    /// Creates a sidebar shell.
    /// - Parameters:
    ///   - sectionTitle: optional uppercase section header above content.
    ///   - header: top slot (e.g., tab bar, search field).
    ///   - content: main slot — the host's tree or list.
    ///   - footer: bottom slot (e.g., language switchers, status row).
    public init(
        sectionTitle: String? = nil,
        @ViewBuilder header: @escaping () -> Header = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) {
        self.sectionTitle = sectionTitle
        self.header = header
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        VStack(spacing: 0) {
            header()
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(separator, alignment: .bottom)

            if let sectionTitle {
                Text(sectionTitle.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            footer()
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(separator, alignment: .top)
        }
        .platformGlassSurface(.panel)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(tokens: theme.style.borders.base).opacity(0.5))
            .frame(height: 0.5)
    }
}
#endif
