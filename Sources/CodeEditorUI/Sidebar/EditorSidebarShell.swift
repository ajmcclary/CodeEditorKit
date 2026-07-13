import CodeEditorSwiftUI
import DesignKitThemes
import DesignKitTokens
import SwiftUI

/// Styled sidebar container. *No tree* — the host fills `content` with
/// whatever workspace/file/search view is appropriate. Provides a
/// glass-backed panel with optional header (tab bar in the prototype),
/// a section title, and a footer slot.
///
/// Two title styles are supported:
/// - `sectionTitle` (default): tiny uppercase muted label.
/// - `prominentTitle` + optional `prominentSubtitle`: airy two-line
///   header used by the sample's settings sidebar. May be paired with
///   an inline reset action via `onReset`.
///
/// Used by both platforms. Renders a glass-backed panel with optional
/// section/prominent header, content slot, and footer slot. Pure
/// SwiftUI — `.platformGlassSurface(.panel)` provides the chrome.
public struct EditorSidebarShell<Header: View, Content: View, Footer: View>: View {
    @Environment(\.designTheme) private var theme

    private let sectionTitle: String?
    private let prominentTitle: String?
    private let prominentSubtitle: String?
    private let onReset: (() -> Void)?
    private let header: () -> Header
    private let content: () -> Content
    private let footer: () -> Footer

    /// Creates a sidebar shell with the compact "SECTION" header style.
    public init(
        sectionTitle: String? = nil,
        @ViewBuilder header: @escaping () -> Header = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) {
        self.sectionTitle = sectionTitle
        self.prominentTitle = nil
        self.prominentSubtitle = nil
        self.onReset = nil
        self.header = header
        self.content = content
        self.footer = footer
    }

    /// Creates a sidebar shell with the prominent two-line header style.
    /// Optional `onReset` adds an inline reset icon button on the trailing edge.
    public init(
        prominentTitle: String,
        prominentSubtitle: String? = nil,
        onReset: (() -> Void)? = nil,
        @ViewBuilder header: @escaping () -> Header = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer = { EmptyView() }
    ) {
        self.sectionTitle = nil
        self.prominentTitle = prominentTitle
        self.prominentSubtitle = prominentSubtitle
        self.onReset = onReset
        self.header = header
        self.content = content
        self.footer = footer
    }

    public var body: some View {
        VStack(spacing: 0) {
            if Header.self != EmptyView.self {
                header()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(separator, alignment: .bottom)
            }

            if let prominentTitle {
                prominentHeader(title: prominentTitle, subtitle: prominentSubtitle)
                    .overlay(separator, alignment: .bottom)
            } else if let sectionTitle {
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

    private func prominentHeader(title: String, subtitle: String?) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color(tokens: theme.style.text.muted))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if let onReset {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(tokens: theme.style.icon.muted))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color(tokens: theme.style.elements.element.background))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(
                                    Color(tokens: theme.style.borders.variant),
                                    lineWidth: 0.5
                                )
                        )
                }
                .buttonStyle(.plain)
                .help("Reset to default preset")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(tokens: theme.style.borders.base).opacity(0.5))
            .frame(height: 0.5)
    }
}
