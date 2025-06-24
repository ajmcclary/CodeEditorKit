import XCTest

@MainActor
final class CodeEditorSampleUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Application Launch Tests
    
    func testApplicationLaunches() {
        XCTAssertTrue(app.windows.count > 0, "Application should have at least one window")
        
        // Check for main window title
        let window = app.windows["CodeEditor Sample"]
        XCTAssertTrue(window.exists, "Main window should exist with correct title")
    }
    
    // MARK: - Configuration Sidebar Tests
    
    func testConfigurationSidebarExists() {
        // Check for configuration presets section
        let configPresets = app.staticTexts["Configuration Presets"]
        XCTAssertTrue(configPresets.exists, "Configuration Presets section should exist")
        
        // Check for sample code section
        let sampleCode = app.staticTexts["Sample Code"]
        XCTAssertTrue(sampleCode.exists, "Sample Code section should exist")
        
        // Check for editor settings section
        let editorSettings = app.staticTexts["Editor Settings"]
        XCTAssertTrue(editorSettings.exists, "Editor Settings section should exist")
    }
    
    func testConfigurationPresets() {
        // Check that all presets are visible
        let presets = ["Full Featured", "Minimal", "Read Only", "Markdown", "Presentation"]
        
        for preset in presets {
            let presetElement = app.staticTexts[preset]
            XCTAssertTrue(presetElement.exists, "\(preset) preset should exist")
        }
    }
    
    func testSampleCodeSelection() {
        // Check for Swift sample (should be selected by default)
        let swiftSample = app.staticTexts["Swift"]
        XCTAssertTrue(swiftSample.exists, "Swift sample should exist")
        
        // Check for other language samples
        let languages = ["JavaScript", "TypeScript", "Python", "Go", "Rust", "C++", "Java", "HTML", "CSS", "JSON"]
        
        for language in languages {
            let languageSample = app.staticTexts[language]
            XCTAssertTrue(languageSample.exists, "\(language) sample should exist")
        }
    }
    
    // MARK: - Editor Settings Tests
    
    func testLineNumbersToggle() {
        let lineNumbersToggle = app.checkBoxes["Show Line Numbers"]
        XCTAssertTrue(lineNumbersToggle.exists, "Show Line Numbers toggle should exist")
        
        // Check initial state
        let initialValue = lineNumbersToggle.value as? Int ?? 0
        
        // Toggle it
        lineNumbersToggle.click()
        
        // Verify state changed
        let newValue = lineNumbersToggle.value as? Int ?? 0
        XCTAssertNotEqual(initialValue, newValue, "Line numbers toggle state should change")
    }
    
    func testEditingToggle() {
        let editingToggle = app.checkBoxes["Enable Editing"]
        XCTAssertTrue(editingToggle.exists, "Enable Editing toggle should exist")
        
        // Toggle to disable editing
        if editingToggle.value as? Int == 1 {
            editingToggle.click()
        }
        
        // Verify editing is disabled
        XCTAssertEqual(editingToggle.value as? Int, 0, "Editing should be disabled")
        
        // TODO: Verify that the text view is actually non-editable
    }
    
    // MARK: - Code Editor Tests
    
    func testCodeEditorVisible() {
        // The code editor should be visible and contain some text
        // Since we can't directly access STTextView, we'll look for text content
        
        // Wait for initial content to load
        let predicate = NSPredicate(format: "exists == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: app.textViews.firstMatch)
        
        wait(for: [expectation], timeout: 5.0)
    }
    
    func testPresetSwitching() {
        // Test switching between presets
        let minimalPreset = app.staticTexts["Minimal"]
        minimalPreset.click()
        
        // Small delay to allow UI to update
        sleep(1)
        
        // Switch to Read Only
        let readOnlyPreset = app.staticTexts["Read Only"]
        readOnlyPreset.click()
        
        // Verify Enable Editing toggle is off
        let editingToggle = app.checkBoxes["Enable Editing"]
        XCTAssertEqual(editingToggle.value as? Int, 0, "Editing should be disabled in Read Only preset")
    }
    
    func testLanguageSwitching() {
        // Switch to Python
        let pythonSample = app.staticTexts["Python"]
        pythonSample.click()
        
        // Small delay for content to update
        sleep(1)
        
        // Switch to JavaScript
        let jsSample = app.staticTexts["JavaScript"]
        jsSample.click()
        
        // Verify language switched (would need to check editor content in real test)
    }
    
    // MARK: - Visual Regression Tests
    
    func testCodeEditorRendering() {
        // This test captures the current state to help identify rendering issues
        
        // Enable line numbers
        let lineNumbersToggle = app.checkBoxes["Show Line Numbers"]
        if lineNumbersToggle.value as? Int == 0 {
            lineNumbersToggle.click()
        }
        
        // Wait for UI to stabilize
        sleep(1)
        
        // Take a screenshot for visual verification
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Code Editor with Line Numbers"
        attachment.lifetime = .keepAlways
        add(attachment)
        
        // Visual checks that a human can verify:
        // 1. Text should be right-side up (not upside down)
        // 2. Line numbers should be visible on the left
        // 3. Code editor should fill the available space (not be a small square)
    }
    
    func testThemeSwitching() {
        // Find and click on a dark theme
        let themes = app.staticTexts.matching(identifier: "VS Code Dark")
        if themes.count > 0 {
            themes.firstMatch.click()
            
            sleep(1)
            
            // Take screenshot of dark theme
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "Code Editor with Dark Theme"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() {
        // Ensure important UI elements have accessibility labels
        XCTAssertTrue(app.checkBoxes["Show Line Numbers"].exists)
        XCTAssertTrue(app.checkBoxes["Enable Editing"].exists)
        XCTAssertTrue(app.checkBoxes["Wrap Lines"].exists)
        XCTAssertTrue(app.checkBoxes["Highlight Current Line"].exists)
    }
}