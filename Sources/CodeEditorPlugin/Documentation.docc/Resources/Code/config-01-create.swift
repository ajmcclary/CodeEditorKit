import CodeEditorPlugin

// Create a configuration
let kConfig = EditorConfiguration()

// The configuration starts with default values
let kLogger = CrossPlatformLogger.logger()

kLogger.debug("Show line numbers: \(kConfig.display.isLineNumbersEnabled)")  // true
kLogger.debug("Font size: \(kConfig.display.fontSize)")          // 13.0
kLogger.debug("Minimap visible: \(kConfig.display.isMinimapVisible)")             // false
