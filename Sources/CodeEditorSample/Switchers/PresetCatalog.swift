import CodeEditorPlugin
import Foundation

/// Demo presets exposed by the sample's preset picker. The iOS preset is
/// reachable from the macOS demo so its effects can be previewed via the
/// inspector even though some behaviors only fully manifest on the matching
/// platform. Catalyst was retired in 0.2.0.
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
        ConfigurationPreset(id: "iOS", name: "iOS", configuration: .iOS)
    ]

    /// Default on launch.
    static let `default`: ConfigurationPreset = all.first { $0.id == "default" } ?? all[0]
}
