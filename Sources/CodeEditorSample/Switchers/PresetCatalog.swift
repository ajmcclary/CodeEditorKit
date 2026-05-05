import CodeEditorPlugin
import Foundation

/// Six demo presets exposed by the sample's preset picker. iOS- and
/// Catalyst-optimized presets are intentionally omitted — they're
/// platform-optimized variants whose effects don't read on a macOS demo.
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
        ConfigurationPreset(id: "macOS", name: "macOS", configuration: .macOS)
    ]

    /// Default on launch.
    static let `default`: ConfigurationPreset = all.first { $0.id == "default" } ?? all[0]
}
