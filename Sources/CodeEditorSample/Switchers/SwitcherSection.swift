import CodeEditorPlugin
import CodeEditorTheming
import SwiftUI

/// Rounded card containing the Theme switcher chip. Language and preset
/// switching are demo-only and live in the command palette (and the iOS
/// language panel) so this Settings tab stays focused on theme selection.
struct SwitcherSection: View {
    @Bindable var theme: ThemeModel

    var body: some View {
        VStack(spacing: 0) {
            SwitcherChip(
                icon: "paintbrush.pointed",
                label: "Theme",
                options: ThemeCatalog.all,
                optionLabel: { $0.name },
                selection: themeBinding
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(tokens: theme.current.style.chrome.elevatedSurfaceBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(tokens: theme.current.style.borders.base), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    // MARK: - Bindings

    private var themeBinding: Binding<Theme> {
        Binding(
            get: { theme.current },
            set: { newValue in theme.current = ThemeCatalog.theme(named: newValue.name) }
        )
    }
}
