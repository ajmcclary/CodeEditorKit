import CodeEditorDesignTokens
import CodeEditorSwiftUI
import CodeEditorTheming
import SwiftUI

/// One row inside the command palette. Public so custom styles can
/// compose the same primitive.
public struct EditorCommandPaletteRow: View {
    @Environment(\.codeEditorTheme) private var theme

    private let item: CommandPaletteItem
    private let isHighlighted: Bool

    /// Creates a palette row.
    /// - Parameters:
    ///   - item: model.
    ///   - isHighlighted: true when this row is the keyboard-focused row.
    public init(item: CommandPaletteItem, isHighlighted: Bool) {
        self.item = item
        self.isHighlighted = isHighlighted
    }

    public var body: some View {
        HStack(spacing: 10) {
            kindGlyph
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(tokens: theme.style.text.muted))
                }
            }
            Spacer()
            if let shortcut = item.shortcut {
                Text(shortcut)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
    }

    @ViewBuilder
    private var kindGlyph: some View {
        Image(systemName: Self.systemImageName(for: item.kind))
            .imageScale(.medium)
            .foregroundStyle(Color(tokens: theme.style.icon.base))
            .frame(width: 18)
    }

    private static func systemImageName(for kind: CommandPaletteItem.Kind) -> String {
        switch kind {
        case .file:    return "doc"
        case .symbol:  return "function"
        case .action:  return "play.fill"
        case .setting: return "slider.horizontal.3"
        }
    }

    private var rowBackground: Color {
        isHighlighted
            ? Color(tokens: theme.style.text.accent).opacity(0.15)
            : .clear
    }
}
