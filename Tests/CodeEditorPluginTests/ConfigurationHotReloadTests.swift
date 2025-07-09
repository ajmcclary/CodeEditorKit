@testable import CodeEditorPlugin
import XCTest

@MainActor
final class ConfigurationHotReloadTests: XCTestCase {
    // MARK: - Test Observer
    
    private class TestObserver: ConfigurationObserver {
        var receivedEvents: [ConfigurationEvent] = []
        var expectation: XCTestExpectation?
        
        func configurationDidChange(_ event: ConfigurationEvent) {
            receivedEvents.append(event)
            expectation?.fulfill()
        }
    }
    
    // MARK: - Basic Functionality Tests
    
    func testUpdateConfiguration() async {
        let hotReload = ConfigurationHotReload()
        let initialConfig = hotReload.configuration
        
        var newConfig = EditorConfiguration()
        newConfig.display.fontSize = 16
        newConfig.display.showLineNumbers = false
        
        hotReload.update(newConfig)
        
        XCTAssertEqual(hotReload.configuration.display.fontSize, 16)
        XCTAssertFalse(hotReload.configuration.display.showLineNumbers)
        XCTAssertNotEqual(hotReload.configuration, initialConfig)
    }
    
    func testObserverNotification() async {
        let hotReload = ConfigurationHotReload()
        let observer = TestObserver()
        let expectation = self.expectation(description: "Observer notification")
        observer.expectation = expectation
        
        let token = hotReload.addObserver(observer)
        XCTAssertNotNil(token)
        
        var config = EditorConfiguration()
        config.display.fontSize = 18
        hotReload.update(config)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        XCTAssertEqual(observer.receivedEvents.count, 1)
        if let event = observer.receivedEvents.first {
            if case .configurationChanged = event {
                // Success
            } else {
                XCTFail("Expected configurationChanged event")
            }
        }
    }
    
    func testRemoveObserver() async {
        let hotReload = ConfigurationHotReload()
        let observer = TestObserver()
        
        let token = hotReload.addObserver(observer)
        hotReload.removeObserver(with: token.id)
        
        var config = EditorConfiguration()
        config.display.fontSize = 16
        hotReload.update(config)
        
        // Observer should not receive events after removal
        XCTAssertEqual(observer.receivedEvents.count, 0)
    }
    
    // MARK: - Batch Update Tests
    
    func testBatchUpdate() async {
        let hotReload = ConfigurationHotReload()
        
        hotReload.batchUpdate { config in
            config.display.fontSize = 20
            config.layout.gutterWidth = 60
            config.behavior.isEditable = false
        }
        
        XCTAssertEqual(hotReload.configuration.display.fontSize, 20)
        XCTAssertEqual(hotReload.configuration.layout.gutterWidth, 60)
        XCTAssertFalse(hotReload.configuration.behavior.isEditable)
    }
    
    func testUpdateProperties() async {
        let hotReload = ConfigurationHotReload()
        
        var displayConfig = EditorConfiguration.Display()
        displayConfig.fontSize = 22
        displayConfig.showMinimap = true
        
        let updates = ConfigurationUpdates(display: displayConfig)
        hotReload.updateProperties(updates)
        
        XCTAssertEqual(hotReload.configuration.display.fontSize, 22)
        XCTAssertTrue(hotReload.configuration.display.showMinimap)
    }
    
    // MARK: - Undo/Redo Tests
    
    func testUndoRedo() async {
        let hotReload = ConfigurationHotReload()
        
        var config1 = EditorConfiguration()
        config1.display.fontSize = 12
        hotReload.update(config1)
        
        var config2 = EditorConfiguration()
        config2.display.fontSize = 14
        hotReload.update(config2)
        
        var config3 = EditorConfiguration()
        config3.display.fontSize = 16
        hotReload.update(config3)
        
        XCTAssertEqual(hotReload.configuration.display.fontSize, 16)
        
        // Test undo
        XCTAssertTrue(hotReload.canUndo)
        hotReload.undo()
        XCTAssertEqual(hotReload.configuration.display.fontSize, 14)
        
        hotReload.undo()
        XCTAssertEqual(hotReload.configuration.display.fontSize, 12)
        
        // Test redo
        XCTAssertTrue(hotReload.canRedo)
        hotReload.redo()
        XCTAssertEqual(hotReload.configuration.display.fontSize, 14)
        
        hotReload.redo()
        XCTAssertEqual(hotReload.configuration.display.fontSize, 16)
        
        XCTAssertFalse(hotReload.canRedo)
    }
    
    func testUndoHistoryLimit() async {
        let hotReload = ConfigurationHotReload()
        
        // Apply more than historyLimit configurations
        for index in 0..<25 {
            var config = EditorConfiguration()
            config.display.fontSize = CGFloat(index)
            hotReload.update(config)
        }
        
        // Should only be able to undo limited times based on maxHistorySize
        var undoCount = 0
        while hotReload.canUndo && undoCount < 30 {
            hotReload.undo()
            undoCount += 1
        }
        
        // Default history size is 20
        XCTAssertLessThanOrEqual(undoCount, 20)
    }
    
    // MARK: - Animation Settings Tests
    
    func testAnimationSettings() async {
        let hotReload = ConfigurationHotReload()
        
        // Test default values
        XCTAssertTrue(hotReload.animateChanges)
        XCTAssertEqual(hotReload.animationDuration.components.seconds, 0)
        XCTAssertEqual(hotReload.animationDuration.components.attoseconds / 1_000_000_000_000_000, 300) // 300ms
        
        // Test setting values
        hotReload.animateChanges = false
        hotReload.animationDuration = .milliseconds(500)
        
        XCTAssertFalse(hotReload.animateChanges)
        XCTAssertEqual(hotReload.animationDuration.components.seconds, 0)
        XCTAssertEqual(hotReload.animationDuration.components.attoseconds / 1_000_000_000_000_000, 500) // 500ms
    }
    
    // MARK: - Validation Tests
    
    func testValidationRules() async {
        let hotReload = ConfigurationHotReload()
        let observer = TestObserver()
        let expectation = self.expectation(description: "Validation failed")
        observer.expectation = expectation
        
        _ = hotReload.addObserver(observer)
        
        hotReload.addValidationRule { config in
            if config.display.fontSize < 8 || config.display.fontSize > 72 {
                return ConfigurationError.invalidFontSize(config.display.fontSize)
            }
            return nil
        }
        
        var config = EditorConfiguration()
        config.display.fontSize = 5 // Invalid
        hotReload.update(config)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Should receive validation failed event
        XCTAssertEqual(observer.receivedEvents.count, 1)
        if let event = observer.receivedEvents.first {
            if case .validationFailed = event {
                // Success
            } else {
                XCTFail("Expected validationFailed event")
            }
        }
    }
    
    // MARK: - Edge Cases
    
    func testEmptyUndoStack() async {
        let hotReload = ConfigurationHotReload()
        
        // Initial state has one item in history
        hotReload.undo()
        XCTAssertFalse(hotReload.canUndo)
        
        hotReload.undo() // Should not crash
        
        XCTAssertFalse(hotReload.canRedo)
        hotReload.redo() // Should not crash
    }
    
    func testClearHistory() async {
        let hotReload = ConfigurationHotReload()
        
        // Add some history
        for index in 1...5 {
            var config = EditorConfiguration()
            config.display.fontSize = CGFloat(index * 10)
            hotReload.update(config)
        }
        
        XCTAssertTrue(hotReload.canUndo)
        
        hotReload.clearHistory()
        
        XCTAssertFalse(hotReload.canUndo)
        XCTAssertFalse(hotReload.canRedo)
    }
    
    // MARK: - Pending Changes Tests
    
    func testApplyPendingChanges() async {
        let hotReload = ConfigurationHotReload()
        
        // Add pending changes
        var newDisplay = hotReload.configuration.display
        newDisplay.fontSize = 20
        hotReload.addPendingChange(.display(old: hotReload.configuration.display, new: newDisplay))
        
        var newLayout = hotReload.configuration.layout
        newLayout.gutterWidth = 55
        hotReload.addPendingChange(.layout(old: hotReload.configuration.layout, new: newLayout))
        
        // Apply pending changes
        hotReload.applyPendingChanges()
        
        XCTAssertEqual(hotReload.configuration.display.fontSize, 20)
        XCTAssertEqual(hotReload.configuration.layout.gutterWidth, 55)
    }
    
    func testClearPendingChanges() async {
        let hotReload = ConfigurationHotReload()
        let initialConfig = hotReload.configuration
        
        // Add pending changes
        var newDisplay = hotReload.configuration.display
        newDisplay.fontSize = 20
        hotReload.addPendingChange(.display(old: hotReload.configuration.display, new: newDisplay))
        
        // Clear without applying
        hotReload.clearPendingChanges()
        hotReload.applyPendingChanges() // Should do nothing
        
        XCTAssertEqual(hotReload.configuration, initialConfig)
    }
}
