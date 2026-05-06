import CodeEditorPlugin

// Create and customize configuration
var config = EditorConfiguration()

// Display settings
config.display.isLineNumbersEnabled = true
config.display.fontSize = 16
config.display.isMinimapVisible = true

// Layout settings
config.layout.tabWidth = 4
config.layout.wrapLines = true
config.layout.gutterWidth = 50

// Behavior settings
config.behavior.isAutoIndentEnabled = true
config.behavior.isCodeCompletionEnabled = true
config.layout.insertSpacesForTabs = true
