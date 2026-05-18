import CodeEditorConfiguration
import CodeEditorPlugin
import CodeEditorSwiftUI
import Foundation

/// Demo presets exposed by the sample's preset picker. The iOS preset is
/// reachable from the macOS demo so its effects can be previewed via the
/// inspector even though some behaviors only fully manifest on the matching
/// platform.
struct ConfigurationPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let configuration: EditorConfiguration

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum PresetCatalog {
    static let all: [ConfigurationPreset] = [
        ConfigurationPreset(id: "default", name: "Default", configuration: .default),
        ConfigurationPreset(id: "minimal", name: "Minimal", configuration: .minimal),
        ConfigurationPreset(id: "readOnly", name: "Read-only", configuration: .readOnly),
        ConfigurationPreset(id: "markdown", name: "Markdown", configuration: .markdown),
        ConfigurationPreset(id: "presentation", name: "Presentation", configuration: .presentation),
        ConfigurationPreset(id: "macOS", name: "macOS", configuration: .macOS),
        ConfigurationPreset(id: "iOS", name: "iOS", configuration: .iOS),
        ConfigurationPreset(
            id: "platformOptimized",
            name: "Platform-Optimized",
            configuration: .platformOptimized
        )
    ]

    /// Default on launch.
    static let `default`: ConfigurationPreset = all.first { $0.id == "default" } ?? all[0]

    /// Merge a preset's user-facing knobs into `current` without
    /// overwriting the user-tuned performance section. Display, behavior,
    /// and layout come from the preset; performance survives. The preset
    /// "feels" applied while the user's machine-tuned settings stay put.
    /// For a wholesale replace use `preset.configuration` directly.
    static func apply(_ preset: ConfigurationPreset, onto current: EditorConfiguration) -> EditorConfiguration {
        current
            .with(display: preset.configuration.display)
            .with(behavior: preset.configuration.behavior)
            .with(layout: preset.configuration.layout)
    }
}
