import CodeEditorPlugin
import SwiftUI

/// Central state management for the CodeEditor Sample application.
///
/// `AppState` serves as the single source of truth for the entire sample app,
/// managing editor configuration, sample code selection, and user preferences
/// using SwiftUI's `@ObservableObject` pattern.
///
/// ## Overview
///
/// This class coordinates between various components:
/// - Editor configuration through `ConfigurationCoordinator`
/// - Sample code selection and language detection
/// - Custom code input and management
/// - Configuration import/export functionality
///
/// ## State Management
///
/// The app state includes:
/// - Current editor configuration and preset selection
/// - Selected programming language and sample code
/// - Custom code input from the user
/// - Computed properties for backward compatibility
///
/// ## Example Usage
///
/// ```swift
/// @StateObject private var appState = AppState()
///
/// var body: some View {
///     CodeEditor(text: $appState.code)
///         .environment(\.codeEditorConfiguration, appState.currentConfiguration)
/// }
/// ```
///
/// ## Thread Safety
///
/// This class is marked with `@MainActor` to ensure all UI updates
/// happen on the main thread, following SwiftUI best practices.
///
/// - Note: All published properties automatically trigger UI updates
///   when changed, thanks to the `@ObservableObject` protocol.
///
/// - SeeAlso: `ConfigurationCoordinator` for configuration management
/// - SeeAlso: `SampleCodeStore` for sample code storage
/// - SeeAlso: `LanguageDetectionService` for language detection
@MainActor
class AppState: ObservableObject {
    /// Configuration coordinator managing editor settings.
    @Published var coordinator = ConfigurationCoordinator()
    
    /// Currently selected configuration preset.
    @Published var selectedPreset: ConfigurationPreset = .fullFeatured
    
    /// Currently selected sample code type (legacy compatibility).
    @Published var selectedSample: SampleCode = .swift
    
    /// Currently selected language information.
    @Published var selectedLanguage: LanguageDetectionService.LanguageInfo?
    
    /// Custom code entered by the user.
    @Published var customCode: String = ""
    
    /// Current code content displayed in the editor.
    @Published var code: String = ""
    
    /// Current editor configuration.
    ///
    /// This computed property provides backward compatibility while
    /// delegating to the configuration coordinator.
    ///
    /// - Returns: The current `EditorConfiguration` from the coordinator.
    var currentConfiguration: EditorConfiguration {
        get { coordinator.configuration }
        set { 
            coordinator.update { $0 = newValue }
            // Force SwiftUI to detect the change
            objectWillChange.send()
        }
    }

    /// Initializes the app state with default settings.
    ///
    /// Sets up the full-featured configuration preset and
    /// initializes with Swift language as the default.
    init() {
        applyPreset(.fullFeatured)
        // Initialize with Swift language
        selectedLanguage = LanguageDetectionService.language(for: "swift")
        updateCode()
    }

    /// Applies a configuration preset to the editor.
    ///
    /// Updates both the selected preset and applies the corresponding
    /// configuration through the coordinator.
    ///
    /// - Parameter preset: The `ConfigurationPreset` to apply.
    ///
    /// ## Example
    ///
    /// ```swift
    /// appState.applyPreset(.minimal)
    /// appState.applyPreset(.fullFeatured)
    /// ```
    func applyPreset(_ preset: ConfigurationPreset) {
        selectedPreset = preset
        coordinator.applyPreset(preset)
    }

    /// Updates the code content based on current selection.
    ///
    /// Determines the code to display based on:
    /// 1. Custom code entered by the user (highest priority)
    /// 2. Sample code for the selected language
    /// 3. Legacy sample code (fallback for compatibility)
    ///
    /// This method is called automatically when language or sample selection changes.
    func updateCode() {
        if customCode.isEmpty {
            if let language = selectedLanguage,
               let sampleCode = SampleCodeStore.getSampleCode(for: language) {
                code = sampleCode
            } else {
                // Fallback to old method for backward compatibility
                code = SampleCodeProvider.getCode(for: selectedSample)
            }
        } else {
            code = customCode
        }
    }

    /// Selects a sample code type and updates the editor content.
    ///
    /// This method provides backward compatibility with the legacy
    /// sample selection system while updating the modern language detection.
    ///
    /// - Parameter sample: The `SampleCode` type to select.
    ///
    /// ## Side Effects
    ///
    /// - Clears any custom code
    /// - Updates the selected language
    /// - Refreshes the editor content
    func selectSample(_ sample: SampleCode) {
        selectedSample = sample
        selectedLanguage = LanguageDetectionService.language(for: sample.rawValue)
        customCode = ""
        updateCode()
    }
    
    /// Selects a programming language and updates the editor content.
    ///
    /// This is the modern method for language selection, with automatic
    /// fallback to legacy sample selection for compatibility.
    ///
    /// - Parameter language: The `LanguageDetectionService.LanguageInfo` to select.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let python = LanguageDetectionService.language(for: "python") {
    ///     appState.selectLanguage(python)
    /// }
    /// ```
    ///
    /// ## Side Effects
    ///
    /// - Clears any custom code
    /// - Updates legacy sample selection if possible
    /// - Refreshes the editor content
    func selectLanguage(_ language: LanguageDetectionService.LanguageInfo) {
        selectedLanguage = language
        // Update selectedSample if possible for backward compatibility
        if let sample = SampleCode(rawValue: language.id) {
            selectedSample = sample
        }
        customCode = ""
        updateCode()
    }

    /// Sets custom code content in the editor.
    ///
    /// When custom code is set, it takes precedence over any sample code
    /// and is immediately displayed in the editor.
    ///
    /// - Parameter text: The custom code content to display.
    ///
    /// ## Example
    ///
    /// ```swift
    /// appState.setCustomCode("""
    /// func customFunction() {
    ///     print("User-defined code")
    /// }
    /// """)
    /// ```
    func setCustomCode(_ text: String) {
        customCode = text
        code = text
    }
    
    // MARK: - Configuration Import/Export
    
    /// Exports the current editor configuration as formatted JSON.
    ///
    /// Creates a JSON representation of the current editor configuration
    /// with pretty printing and sorted keys for readability.
    ///
    /// - Returns: A formatted JSON string, or `nil` if encoding fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// if let json = appState.exportConfigurationAsJSON() {
    ///     // Save or share the configuration JSON
    ///     #if canImport(UIKit)
    ///     if #available(iOS 16.0, *) {
    ///         UIPasteboard.general.items = [[UIPasteboard.typeAutomatic: json]]
    ///     } else {
    ///         UIPasteboard.general.string = json
    ///     }
    ///     #endif
    /// }
    /// ```
    ///
    /// ## JSON Format
    ///
    /// The exported JSON includes all configuration properties:
    /// ```json
    /// {
    ///   "display": {
    ///     "showLineNumbers": true,
    ///     "fontSize": 14.0,
    ///     ...
    ///   },
    ///   "behavior": { ... },
    ///   "layout": { ... },
    ///   "performance": { ... }
    /// }
    /// ```
    func exportConfigurationAsJSON() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        do {
            let data = try encoder.encode(currentConfiguration)
            return String(data: data, encoding: .utf8)
        } catch {
            CrossPlatformLogger.logger().error("Failed to encode configuration: \(error)")
            return nil
        }
    }
    
    /// Imports an editor configuration from JSON.
    ///
    /// Parses JSON configuration data and applies it to the current editor.
    /// The preset selection is reset to indicate a custom configuration.
    ///
    /// - Parameter json: The JSON string containing configuration data.
    ///
    /// - Returns: `true` if the import succeeded, `false` otherwise.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let jsonConfig = """
    /// {
    ///   "display": {
    ///     "showLineNumbers": false,
    ///     "fontSize": 16.0
    ///   }
    /// }
    /// """
    ///
    /// if appState.importConfiguration(from: jsonConfig) {
    ///     print("Configuration imported successfully")
    /// } else {
    ///     print("Failed to import configuration")
    /// }
    /// ```
    ///
    /// ## Error Handling
    ///
    /// Returns `false` for:
    /// - Invalid JSON syntax
    /// - Missing required configuration properties
    /// - Type mismatches in the JSON data
    func importConfiguration(from json: String) -> Bool {
        guard let data = json.data(using: .utf8) else { return false }
        
        let decoder = JSONDecoder()
        do {
            let configuration = try decoder.decode(EditorConfiguration.self, from: data)
            currentConfiguration = configuration
            selectedPreset = .fullFeatured // Reset to custom after import
            return true
        } catch {
            CrossPlatformLogger.logger().error("Failed to decode configuration: \(error)")
            return false
        }
    }
    
    /// Resets the editor configuration to default values.
    ///
    /// Restores the configuration coordinator to its initial state
    /// and resets the preset selection to full-featured mode.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Reset after experimenting with settings
    /// appState.resetConfiguration()
    /// ```
    ///
    /// ## Side Effects
    ///
    /// - All custom configuration changes are lost
    /// - Preset selection returns to `.fullFeatured`
    /// - UI automatically updates to reflect default settings
    func resetConfiguration() {
        coordinator.reset()
        selectedPreset = .fullFeatured
    }
    
    /// Helper method for updating configuration and triggering UI updates.
    ///
    /// This method consolidates the common pattern of updating configuration
    /// through the coordinator and notifying SwiftUI of the change.
    ///
    /// - Parameter updateBlock: A closure that modifies the configuration.
    ///
    /// ## Example
    ///
    /// ```swift
    /// appState.updateConfiguration { config in
    ///     config.display.isLineNumbersEnabled = true
    ///     config.display.fontSize = 16
    /// }
    /// ```
    ///
    /// ## Benefits
    ///
    /// - Ensures consistent update pattern across the app
    /// - Prevents forgetting to call `objectWillChange.send()`
    /// - Reduces code duplication in configuration sections
    func updateConfiguration(_ updateBlock: @escaping (inout EditorConfiguration) -> Void) {
        coordinator.update(updateBlock)
        objectWillChange.send()
    }
}
