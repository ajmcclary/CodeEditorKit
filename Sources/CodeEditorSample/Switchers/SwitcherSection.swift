import CodeEditorPlugin
import SwiftUI

/// Single rounded card containing three switcher chips: Theme, Language,
/// Preset. Replaces the previous trio of stacked `Picker(.menu)` blocks.
struct SwitcherSection: View {
    @Binding var theme: Theme
    @Binding var configuration: EditorConfiguration
    @Bindable var documents: EditorDocuments

    var body: some View {
        VStack(spacing: 0) {
            SwitcherChip(
                icon: "paintbrush.pointed",
                label: "Theme",
                options: ThemeCatalog.all,
                optionLabel: { $0.name },
                selection: themeBinding
            )

            divider

            SwitcherChip(
                icon: "chevron.left.forwardslash.chevron.right",
                label: "Language",
                options: LanguageCatalog.all,
                optionLabel: { $0.name },
                selection: languageBinding,
                disabled: documents.activeID == nil
            )

            divider

            SwitcherChip(
                icon: "slider.horizontal.3",
                label: "Preset",
                options: PresetCatalog.all,
                optionLabel: { $0.name },
                selection: presetBinding
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(tokens: theme.style.chrome.elevatedSurfaceBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(tokens: theme.style.borders.base), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color(tokens: theme.style.borders.variant))
            .frame(height: 0.5)
            .padding(.horizontal, 12)
    }

    // MARK: - Bindings

    private var themeBinding: Binding<Theme> {
        Binding(
            get: { theme },
            set: { newValue in theme = ThemeCatalog.theme(named: newValue.name) }
        )
    }

    private var languageBinding: Binding<Language> {
        Binding(
            get: { documents.active?.language ?? LanguageCatalog.default },
            set: { newValue in
                guard let id = documents.activeID else { return }
                documents.setLanguageRenaming(newValue, of: id)
            }
        )
    }

    private var presetBinding: Binding<ConfigurationPreset> {
        Binding(
            get: {
                PresetCatalog.all.first { $0.configuration == configuration }
                    ?? PresetCatalog.default
            },
            set: { newValue in
                // Non-destructive apply: keep the user's tuned performance
                // section; pull display/behavior/layout from the preset.
                // Pair with the palette "Reset to preset" entry for the
                // wholesale-replace variant.
                configuration = PresetCatalog.apply(newValue, onto: configuration)
            }
        )
    }
}
