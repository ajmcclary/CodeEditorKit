/// Canonical logging identities shared by every CodeEditor module.
public enum CodeEditorLog {
    /// Default subsystem for framework and editor-surface features.
    public static let subsystem = "com.codeeditor.plugin"

    /// Subsystem for language-server transport and protocol features.
    public static let lspSubsystem = "com.codeeditor.lsp"

    /// Subsystem for project-search features.
    public static let searchSubsystem = "com.codeeditor.search"

    /// Subsystem for the sample application's diagnostics.
    public static let sampleSubsystem = "com.codeeditor.sample"

    /// Creates a categorized framework logger.
    public static func logger(category: String) -> CrossPlatformLogger.Logger {
        CrossPlatformLogger.logger(subsystem: subsystem, category: category)
    }

    /// Creates a categorized language-server logger.
    public static func lsp(category: String) -> CrossPlatformLogger.Logger {
        CrossPlatformLogger.logger(subsystem: lspSubsystem, category: category)
    }

    /// Creates a categorized project-search logger.
    public static func search(category: String) -> CrossPlatformLogger.Logger {
        CrossPlatformLogger.logger(subsystem: searchSubsystem, category: category)
    }

    /// Creates a categorized sample-application logger.
    public static func sample(category: String) -> CrossPlatformLogger.Logger {
        CrossPlatformLogger.logger(subsystem: sampleSubsystem, category: category)
    }
}
