import Foundation

extension EditorConfiguration {
    // MARK: - Preset Configurations
    
    /// Default configuration with standard settings
    public static let `default` = EditorConfiguration()
    
    /// Minimal configuration for lightweight editing
    public static let minimal: EditorConfiguration = {
        var config = EditorConfiguration()
        config.display.showLineNumbers = false
        config.display.enableSyntaxHighlighting = false
        config.display.enableAnnotations = false
        config.display.enableCodeFolding = false
        config.display.showMinimap = false
        config.behavior.enableCodeCompletion = false
        return config
    }()
    
    /// Read-only configuration for viewing code
    public static let readOnly: EditorConfiguration = {
        var config = EditorConfiguration()
        config.behavior.isEditable = false
        config.behavior.enableCodeCompletion = false
        config.behavior.isAutomaticQuoteSubstitutionEnabled = false
        config.behavior.isAutomaticDashSubstitutionEnabled = false
        return config
    }()
    
    /// Configuration optimized for Markdown editing
    public static let markdown: EditorConfiguration = {
        var config = EditorConfiguration()
        config.layout.wrapLines = true
        config.behavior.isAutomaticLinkDetectionEnabled = true
        config.behavior.isAutomaticQuoteSubstitutionEnabled = true
        config.behavior.isAutomaticDashSubstitutionEnabled = true
        config.display.enableCodeFolding = false
        return config
    }()
    
    /// Configuration for presentation/demo mode
    public static let presentation: EditorConfiguration = {
        var config = EditorConfiguration()
        config.display.fontSize = 18
        config.display.showLineNumbers = false
        config.display.enableAnnotations = false
        config.display.highlightSelectedLine = false
        config.layout.wrapLines = true
        config.behavior.isEditable = false
        config.behavior.enableCodeCompletion = false
        return config
    }()
}
