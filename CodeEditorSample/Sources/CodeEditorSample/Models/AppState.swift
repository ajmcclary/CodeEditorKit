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
    
    // MARK: - Configuration Import/Export
    
    func exportConfigurationAsJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(currentConfiguration)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Failed to encode configuration: \(error)")
            return nil
        }
    }
    
    func importConfiguration(from json: String) -> Bool {
        guard let data = json.data(using: .utf8) else { return false }
        
        let decoder = JSONDecoder()
        do {
            let configuration = try decoder.decode(EditorConfiguration.self, from: data)
            currentConfiguration = configuration
            selectedPreset = .fullFeatured // Reset to custom after import
            return true
        } catch {
            print("Failed to decode configuration: \(error)")
            return false
        }
    }
    
    func resetConfiguration() {
        currentConfiguration = EditorConfiguration()
        selectedPreset = .fullFeatured
    }
}
