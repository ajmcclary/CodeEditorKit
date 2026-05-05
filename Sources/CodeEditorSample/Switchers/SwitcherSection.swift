import CodeEditorPlugin
import SwiftUI

/// Three Picker rows wired to environment + DocumentStore + binding.
/// Sits at the top of the settings sidebar above the knob playground.
struct SwitcherSection: View {
    @Binding var theme: Theme
    @Binding var configuration: EditorConfiguration
    @Bindable var documents: DocumentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            themePicker
            languagePicker
            presetPicker
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Theme").font(.system(size: 11, weight: .semibold))
            Picker("Theme", selection: themeBinding) {
                ForEach(ThemeCatalog.all, id: \.name) { theme in
                    Text(theme.name).tag(theme.name)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Language").font(.system(size: 11, weight: .semibold))
            Picker("Language", selection: languageBinding) {
                ForEach(LanguageCatalog.all, id: \.self) { language in
                    Text(language.name).tag(language)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .disabled(documents.activeTabID == nil)
        }
    }

    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Preset").font(.system(size: 11, weight: .semibold))
            Picker("Preset", selection: presetBinding) {
                ForEach(PresetCatalog.all) { preset in
                    Text(preset.name).tag(preset.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }

    // MARK: - Bindings

    private var themeBinding: Binding<String> {
        Binding(
            get: { theme.name },
            set: { theme = ThemeCatalog.theme(named: $0) }
        )
    }

    private var languageBinding: Binding<Language> {
        Binding(
            get: { documents.activeLanguage ?? LanguageCatalog.default },
            set: { newValue in
                guard let id = documents.activeTabID else { return }
                documents.setLanguage(newValue, of: id)
            }
        )
    }

    private var presetBinding: Binding<String> {
        Binding(
            get: {
                PresetCatalog.all.first { $0.configuration == configuration }?.id
                    ?? PresetCatalog.default.id
            },
            set: { newID in
                if let preset = PresetCatalog.all.first(where: { $0.id == newID }) {
                    configuration = preset.configuration
                }
            }
        )
    }
}
