import DesignKitTokens
import CodeEditorLanguages
import CodeEditorSwiftUI
import DesignKitThemes
import SwiftUI

/// One file tab in the chrome's tab strip.
///
/// Public so custom `EditorTabStripStyle` implementations can compose
/// the same primitive. Renders a leading language glyph, the tab name,
/// and a trailing close button (or dirty dot when `tab.isDirty` is true).
public struct EditorTab: View {
    @Environment(\.codeEditorTheme) private var theme

    private let tab: TabModel
    private let isActive: Bool
    private let onSelect: () -> Void
    private let onClose: (() -> Void)?

    /// Creates a tab.
    /// - Parameters:
    ///   - tab: model.
    ///   - isActive: true when this tab is the foreground tab.
    ///   - onSelect: tap action.
    ///   - onClose: close-button action; nil suppresses the close button.
    public init(
        tab: TabModel,
        isActive: Bool,
        onSelect: @escaping () -> Void,
        onClose: (() -> Void)? = nil
    ) {
        self.tab = tab
        self.isActive = isActive
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 6) {
            languageGlyph
            Text(tab.name)
                .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                .foregroundStyle(Color(tokens: theme.style.text.base))
                .lineLimit(1)
                .truncationMode(.middle)
            trailingControl
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(background)
        .overlay(activeIndicator, alignment: .top)
        .contentShape(Rectangle())
        .accessibilityAddTraits(.isButton)
        .onTapGesture(perform: onSelect)
    }

    private var background: some View {
        Color(tokens: isActive
              ? theme.style.chrome.tabActiveBackground
              : theme.style.chrome.tabInactiveBackground)
    }

    @ViewBuilder
    private var activeIndicator: some View {
        if isActive {
            Rectangle()
                .fill(Color(tokens: theme.style.text.accent))
                .frame(height: 1.5)
        }
    }

    @ViewBuilder
    private var languageGlyph: some View {
        Image(systemName: Self.systemImageName(for: tab.language))
            .imageScale(.small)
            .foregroundStyle(Color(tokens: theme.style.icon.base))
    }

    private static func systemImageName(for language: Language?) -> String {
        switch language {
        case .some(.swift):                       return "swift"
        case .some(.typescript), .some(.javascript): return "curlybraces"
        case .some(.python):                      return "p.circle"
        case .some(.json):                        return "doc.text"
        case .some(.markdown):                    return "text.alignleft"
        default:                                  return "doc"
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        if tab.isDirty {
            Circle()
                .fill(Color(tokens: theme.style.text.muted))
                .frame(width: 8, height: 8)
        } else if let onClose {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .imageScale(.small)
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
            }
            .buttonStyle(.plain)
        }
    }
}
