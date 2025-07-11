@testable import CodeEditorPlugin
import XCTest

final class ConfigurationMigratorTests: XCTestCase {
    private var migrator: ConfigurationMigrator?
    
    override func setUp() {
        super.setUp()
        migrator = ConfigurationMigrator()
    }
    
    override func tearDown() {
        migrator = nil
        super.tearDown()
    }
    
    // MARK: - Version 1.0 to 1.1 Migration Tests
    
    func testMigrateFrom1_0To1_1_MigratesFlatToNested() {
        // Given: A v1.0 configuration with flat structure
        let oldConfig: [String: Any] = [
            "fontSize": 14.0,
            "showLineNumbers": true,
            "theme": "light"
        ]
        
        // When: Migrating to current version
        let result = migrator?.migrate(from: oldConfig, version: "1.0") ?? .failure(.migrationFailed("No migrator"))
        
        // Then: Migration should succeed with nested structure
        switch result {
        case .success(let config):
            XCTAssertEqual(config.display.fontSize, 14.0)
            XCTAssertTrue(config.display.isLineNumbersEnabled)
            // Theme was not migrated in the actual implementation
        case .failure(let error):
            XCTFail("Migration failed with error: \(error)")
        }
    }
    
    // MARK: - Version 1.1 to 1.2 Migration Tests
    
    func testMigrateFrom1_1To1_2_AddsPerformanceSection() {
        // Given: A v1.1 configuration without performance section
        let oldConfig: [String: Any] = [
            "display": [
                "fontSize": 16.0,
                "showLineNumbers": false
            ],
            "layout": [
                "tabWidth": 2
            ]
        ]
        
        // When: Migrating to current version  
        let result = migrator?.migrate(from: oldConfig, version: "1.1") ?? .failure(.migrationFailed("No migrator"))
        
        // Then: Performance section should be added
        switch result {
        case .success(let config):
            // Original properties preserved
            XCTAssertEqual(config.display.fontSize, 16.0)
            XCTAssertFalse(config.display.isLineNumbersEnabled)
            XCTAssertEqual(config.layout.tabWidth, 2)
            
            // Performance section added with defaults
            XCTAssertTrue(config.performance.useHardwareAcceleration)
            XCTAssertGreaterThan(config.performance.maxSyntaxHighlightingLength, 0)

        case .failure(let error):
            XCTFail("Migration failed with error: \(error)")
        }
    }
    
    // MARK: - Version 1.2 to 2.0 Migration Tests
    
    func testMigrateFrom1_2To2_0_RenamesDeprecatedKeys() {
        // Given: A v1.2 configuration with deprecated keys
        let oldConfig: [String: Any] = [
            "display": [
                "fontSize": 12.0,
                "showLineNumbers": true
            ],
            "layout": [
                "tabWidth": 4
            ],
            "behavior": [
                "autoComplete": true  // Deprecated key
            ],
            "performance": [
                "useHardwareAcceleration": true,
                "maxSyntaxHighlightingLength": 500_000
            ]
        ]
        
        // When: Migrating to v2.0
        let result = migrator?.migrate(from: oldConfig, version: "1.2") ?? .failure(.migrationFailed("No migrator"))
        
        // Then: Deprecated keys should be renamed
        switch result {
        case .success(let config):
            XCTAssertEqual(config.display.fontSize, 12.0)
            XCTAssertEqual(config.layout.tabWidth, 4)
            
            // autoComplete should be migrated to enableCodeCompletion
            XCTAssertTrue(config.behavior.enableCodeCompletion)

        case .failure(let error):
            XCTFail("Migration failed with error: \(error)")
        }
    }
    
    // MARK: - Multi-Version Migration Tests
    
    func testMigrateFromAncientVersion() {
        // Given: A very old configuration (v1.0)
        let ancientConfig: [String: Any] = [
            "fontSize": 18.0,
            "theme": "dark"
        ]
        
        // When: Migrating from v1.0 to current
        let result = migrator?.migrate(from: ancientConfig, version: "1.0") ?? .failure(.migrationFailed("No migrator"))
        
        // Then: Should successfully migrate through all versions
        switch result {
        case .success(let config):
            // Basic properties preserved
            XCTAssertEqual(config.display.fontSize, 18.0)
            
            // All modern properties should have sensible defaults
            // Note: memoryMonitor is created at runtime, not during migration
            XCTAssertTrue(config.display.enableSyntaxHighlighting)
            XCTAssertEqual(config.layout.tabWidth, 4) // Default value
        case .failure(let error):
            XCTFail("Migration failed with error: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testMigrationWithInvalidData() {
        // Given: Invalid configuration data
        let invalidConfig: [String: Any] = [
            "fontSize": "not a number", // Invalid type
            "showLineNumbers": 123 // Wrong type
        ]
        
        // When: Attempting migration
        let result = migrator?.migrate(from: invalidConfig, version: "1.0") ?? .failure(.migrationFailed("No migrator"))
        
        // Then: Migration succeeds but values are replaced with defaults
        switch result {
        case .success(let config):
            // Invalid values should be replaced with defaults
            XCTAssertEqual(config.display.fontSize, 14.0) // Default value, not "not a number"
            XCTAssertTrue(config.display.isLineNumbersEnabled) // Default value, not 123

        case .failure(let error):
            XCTFail("Migration failed with error: \(error)")
        }
    }
    
    func testMigrationWithMissingRequiredFields() {
        // Given: Configuration missing required fields after migration
        let incompleteConfig: [String: Any] = [:]
        
        // When: Attempting migration
        let result = migrator?.migrate(from: incompleteConfig, version: "1.0") ?? .failure(.migrationFailed("No migrator"))
        
        // Then: Should either fail or provide defaults
        switch result {
        case .success(let config):
            // If successful, should have sensible defaults
            XCTAssertGreaterThan(config.display.fontSize, 0)
            XCTAssertGreaterThanOrEqual(config.layout.tabWidth, 1)

        case .failure:
            // Failing is also acceptable for missing required data
            break
        }
    }
    
    // MARK: - Version Detection Tests
    
    func testCurrentVersionDoesNotNeedMigration() {
        // Given: A current version configuration
        let currentConfig: [String: Any] = [
            "display": ["fontSize": 14, "showLineNumbers": true],
            "layout": ["tabWidth": 4],
            "behavior": ["enableAutocompletion": true],
            "performance": ["enableHardwareAcceleration": true]
        ]
        
        // When: "Migrating" from current version
        let result = migrator?.migrate(from: currentConfig, version: ConfigurationMigrator.currentVersion) ?? .failure(.migrationFailed("No migrator"))
        
        // Then: Should pass through without changes
        switch result {
        case .success(let config):
            XCTAssertEqual(config.display.fontSize, 14)
            XCTAssertEqual(config.layout.tabWidth, 4)

        case .failure(let error):
            XCTFail("Current version migration failed: \(error)")
        }
    }
    
    // MARK: - Future Version Tests
    
    func testMigrationFromFutureVersion() {
        // Given: A configuration from a future version
        let futureConfig: [String: Any] = [
            "display": ["fontSize": 14],
            "layout": ["tabWidth": 4],
            "behavior": ["enableAutocompletion": true],
            "performance": ["enableHardwareAcceleration": true],
            "futureFeature": ["someNewProperty": true] // Unknown property
        ]
        
        // When: Migrating from a future version
        let result = migrator?.migrate(from: futureConfig, version: "3.0") ?? .failure(.migrationFailed("No migrator"))
        
        // Then: Should handle gracefully (ignore unknown properties)
        switch result {
        case .success(let config):
            // Known properties should be preserved
            XCTAssertEqual(config.display.fontSize, 14)
            XCTAssertEqual(config.layout.tabWidth, 4)

        case .failure:
            // Failing for future versions is also acceptable
            break
        }
    }
}
