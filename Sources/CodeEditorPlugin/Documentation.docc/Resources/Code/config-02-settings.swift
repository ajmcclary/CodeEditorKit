import CodeEditorPlugin

// Create and customize configuration
var config = EditorConfiguration()

// Display settings
config.display.showLineNumbers = true
config.display.fontSize = 16
config.display.theme = .vsDark
config.display.showMinimap = true

// Layout settings
config.layout.tabWidth = 4
config.layout.lineWrapping = true
config.layout.gutterWidth = 50

// Behavior settings
config.behavior.autoIndent = true
config.behavior.enableCodeCompletion = true
config.behavior.insertSpacesForTabs = true
