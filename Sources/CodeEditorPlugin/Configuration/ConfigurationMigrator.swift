import Foundation

// MARK: - Configuration Migration

/// Migrator for updating configurations between versions
public struct ConfigurationMigrator {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "ConfigurationMigrator")

    /// Current configuration version
    public static let currentVersion = "2.0"

    /// Migrate a configuration from an older version
    public func migrate(
        from configuration: [String: Any],
        version: String
    ) -> Result<EditorConfiguration, MigrationError> {
        logger.info("Migrating configuration from version \(version) to \(Self.currentVersion)")

        var migrated = configuration

        // Apply migrations in sequence
        if version < "1.1" {
            migrated = migrateFrom1_0To1_1(migrated)
        }

        if version < "1.2" {
            migrated = migrateFrom1_1To1_2(migrated)
        }

        if version < "2.0" {
            migrated = migrateFrom1_2To2_0(migrated)
        }

        // Ensure all required sections exist
        migrated = ensureRequiredSections(migrated)

        // Decode the migrated configuration
        do {
            let data = try JSONSerialization.data(withJSONObject: migrated)
            let decoder = JSONDecoder()
            let config = try decoder.decode(EditorConfiguration.self, from: data)

            // Validate the migrated configuration
            let validator = ConfigurationValidator()
            let issues = validator.validate(config)

            if issues.contains(where: { $0.severity == .error }) {
                throw MigrationError.validationFailed(issues)
            }

            return .success(config)
        } catch {
            return .failure(.decodingFailed(error))
        }
    }

    // MARK: - Helper Methods

    private func ensureRequiredSections(_ config: [String: Any]) -> [String: Any] {
        var migrated = config

        // Ensure all required top-level sections exist
        if migrated["display"] == nil {
            migrated["display"] = [:]
        }
        if migrated["layout"] == nil {
            migrated["layout"] = [:]
        }
        if migrated["behavior"] == nil {
            migrated["behavior"] = [:]
        }
        if migrated["performance"] == nil {
            migrated["performance"] = [:]
        }

        return migrated
    }

    // MARK: - Version Migrations

    private func migrateFrom1_0To1_1(_ config: [String: Any]) -> [String: Any] {
        var migrated = config

        // Migrate flat structure to nested structure
        if let fontSize = config["fontSize"] as? Double {
            migrated.removeValue(forKey: "fontSize")
            var display = migrated["display"] as? [String: Any] ?? [:]
            display["fontSize"] = fontSize
            migrated["display"] = display
        }

        if let showLineNumbers = config["showLineNumbers"] as? Bool {
            migrated.removeValue(forKey: "showLineNumbers")
            var display = migrated["display"] as? [String: Any] ?? [:]
            display["showLineNumbers"] = showLineNumbers
            migrated["display"] = display
        }

        return migrated
    }

    private func migrateFrom1_1To1_2(_ config: [String: Any]) -> [String: Any] {
        var migrated = config

        // Add performance section if missing
        if migrated["performance"] == nil {
            migrated["performance"] = [
                "useHardwareAcceleration": true,
                "maxSyntaxHighlightingLength": 500_000,
                "largeFileThreshold": 1_000_000
            ]
        }

        return migrated
    }

    private func migrateFrom1_2To2_0(_ config: [String: Any]) -> [String: Any] {
        var migrated = config

        // Rename deprecated keys
        if var behavior = migrated["behavior"] as? [String: Any] {
            if let autoComplete = behavior["autoComplete"] as? Bool {
                behavior.removeValue(forKey: "autoComplete")
                behavior["enableCodeCompletion"] = autoComplete
                migrated["behavior"] = behavior
            }
        }

        // Add new display options
        if var display = migrated["display"] as? [String: Any] {
            if display["enableAnnotations"] == nil {
                display["enableAnnotations"] = true
            }
            migrated["display"] = display
        }

        return migrated
    }
}

/// Errors that can occur during configuration migration
public enum MigrationError: LocalizedError {
    case unsupportedVersion(String)
    case decodingFailed(Error)
    case validationFailed([ValidationIssue])
    case missingRequiredField(String)
    case migrationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Unsupported configuration version: \(version)"

        case .decodingFailed(let error):
            return "Failed to decode configuration: \(error.localizedDescription)"

        case .validationFailed(let issues):
            let errors = issues.filter { $0.severity == .error }
            return "Configuration validation failed with \(errors.count) errors"

        case .missingRequiredField(let field):
            return "Missing required field: \(field)"

        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        }
    }
}
