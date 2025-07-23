import Foundation

// MARK: - Configuration Diff

/// Utility to compare configurations
public enum ConfigurationDiff {
    /// Compare two configurations and return differences
    public static func diff(
        _ config1: EditorConfiguration,
        _ config2: EditorConfiguration
    ) -> [ConfigurationChange] {
        var changes: [ConfigurationChange] = []

        // Compare display settings
        if config1.display.fontSize != config2.display.fontSize {
            changes.append(ConfigurationChange(
                path: "display.fontSize",
                oldValue: config1.display.fontSize,
                newValue: config2.display.fontSize
            ))
        }

        if config1.display.isLineNumbersEnabled != config2.display.isLineNumbersEnabled {
            changes.append(ConfigurationChange(
                path: "display.isLineNumbersEnabled",
                oldValue: config1.display.isLineNumbersEnabled,
                newValue: config2.display.isLineNumbersEnabled
            ))
        }

        // Compare layout settings
        if config1.layout.tabWidth != config2.layout.tabWidth {
            changes.append(ConfigurationChange(
                path: "layout.tabWidth",
                oldValue: config1.layout.tabWidth,
                newValue: config2.layout.tabWidth
            ))
        }

        // Compare behavior settings
        if config1.behavior.isEditable != config2.behavior.isEditable {
            changes.append(ConfigurationChange(
                path: "behavior.isEditable",
                oldValue: config1.behavior.isEditable,
                newValue: config2.behavior.isEditable
            ))
        }

        // Compare performance settings
        if config1.performance.useHardwareAcceleration != config2.performance.useHardwareAcceleration {
            changes.append(ConfigurationChange(
                path: "performance.useHardwareAcceleration",
                oldValue: config1.performance.useHardwareAcceleration,
                newValue: config2.performance.useHardwareAcceleration
            ))
        }

        // Add more comparisons as needed...

        return changes
    }
}

/// Represents a change between configurations
public struct ConfigurationChange {
    public let path: String
    public let oldValue: Any
    public let newValue: Any

    public var description: String {
        "\(path): \(oldValue) → \(newValue)"
    }
}
