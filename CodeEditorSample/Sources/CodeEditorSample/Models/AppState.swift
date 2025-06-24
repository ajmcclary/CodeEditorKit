import CodeEditorPlugin
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var currentConfiguration = EditorConfiguration()
    @Published var selectedPreset: ConfigurationPreset = .fullFeatured
    @Published var selectedSample: SampleCode = .swift
    @Published var customCode: String = ""
    @Published var code: String = ""

    init() {
        applyPreset(.fullFeatured)
        updateCode()
    }

    func applyPreset(_ preset: ConfigurationPreset) {
        selectedPreset = preset
        currentConfiguration = preset.configuration
    }

    func updateCode() {
        if customCode.isEmpty {
            code = SampleCodeProvider.getCode(for: selectedSample)
        } else {
            code = customCode
        }
    }

    func selectSample(_ sample: SampleCode) {
        selectedSample = sample
        customCode = ""
        updateCode()
    }

    func setCustomCode(_ text: String) {
        customCode = text
        code = text
    }
}
