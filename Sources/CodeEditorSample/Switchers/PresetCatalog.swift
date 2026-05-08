import CodeEditorPlugin
import Foundation

/// Demo presets exposed by the sample's preset picker. All eight built-in
/// presets are surfaced so the iOS / Catalyst variants are reachable from the
/// demo even when running on macOS — picking them lets you preview their
/// configuration via the inspector even if some platform-specific behaviors
/// only fully manifest on the matching platform.
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
        ConfigurationPreset(id: "catalyst", name: "Catalyst", configuration: .catalyst)
    ]

    /// Default on launch.
    static let `default`: ConfigurationPreset = all.first { $0.id == "default" } ?? all[0]
}
