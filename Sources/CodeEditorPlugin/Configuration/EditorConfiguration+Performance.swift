import Foundation

extension EditorConfiguration {
    /// Performance configuration options for optimization settings.
    ///
    /// Controls performance-related features including syntax highlighting limits,
    /// rendering optimizations, and resource usage.
    public struct Performance: Equatable, Sendable {
        // MARK: - Properties
        
        /// Maximum file length for syntax highlighting (0 = unlimited)
        public var maxSyntaxHighlightingLength: Int = PlatformConstants.maxSyntaxHighlightingLength
        
        /// Alias for maxSyntaxHighlightingLength for backward compatibility
        @available(*, deprecated, renamed: "maxSyntaxHighlightingLength")
        public var maxHighlightingLength: Int {
            get { maxSyntaxHighlightingLength }
            set { maxSyntaxHighlightingLength = newValue }
        }
        
        /// Whether to use hardware acceleration
        public var useHardwareAcceleration: Bool = true
        
        /// Rendering update strategy
        public var renderingUpdateStrategy: RenderingUpdateStrategy = .adaptive
        
        /// Maximum number of visible lines to render
        public var maxVisibleLines: Int = PlatformConstants.maxVisibleLines
        
        /// Delay before triggering syntax highlighting
        public var highlightingDebounceInterval: TimeInterval = PlatformConstants.defaultHighlightingDebounceInterval
        
        /// Whether to enable smooth scrolling
        public var smoothScrolling: Bool = true
        
        /// Debounce interval for text changes (in seconds).
        ///
        /// Delays processing of rapid text changes to improve performance.
        /// Syntax highlighting and other expensive operations wait for this
        /// duration of inactivity before processing.
        ///
        /// - Note: Lower values provide more responsive feedback but use more CPU.
        public var textChangeDebounceInterval: TimeInterval = 0.1
        
        /// Whether to animate code folding operations.
        ///
        /// When enabled, folding and unfolding operations are animated
        /// for a smoother visual experience. May impact performance on slower systems.
        ///
        /// - Note: Disable for better performance with very large files.
        public var animateCodeFolding: Bool = true
        
        // MARK: - Initialization
        
        public init() {}
        
        // MARK: - Nested Types
        
        /// Strategy for rendering updates
        public enum RenderingUpdateStrategy: String, Codable, Sendable {
            /// Update immediately on changes
            case immediate
            /// Batch updates for better performance
            case batched
            /// Adapt based on content and system performance
            case adaptive
        }
    }
}

// MARK: - Codable Implementation

extension EditorConfiguration.Performance: Codable {
    private enum CodingKeys: String, CodingKey {
        case maxSyntaxHighlightingLength
        case useHardwareAcceleration
        case renderingUpdateStrategy
        case maxVisibleLines
        case highlightingDebounceInterval
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxSyntaxHighlightingLength = try container.decodeIfPresent(Int.self, forKey: .maxSyntaxHighlightingLength) ?? 500_000
        useHardwareAcceleration = try container.decodeIfPresent(Bool.self, forKey: .useHardwareAcceleration) ?? true
        renderingUpdateStrategy = try container.decodeIfPresent(RenderingUpdateStrategy.self, forKey: .renderingUpdateStrategy) ?? .adaptive
        maxVisibleLines = try container.decodeIfPresent(Int.self, forKey: .maxVisibleLines) ?? 1_000
        highlightingDebounceInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .highlightingDebounceInterval) ?? 0.1
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(maxSyntaxHighlightingLength, forKey: .maxSyntaxHighlightingLength)
        try container.encode(useHardwareAcceleration, forKey: .useHardwareAcceleration)
        try container.encode(renderingUpdateStrategy, forKey: .renderingUpdateStrategy)
        try container.encode(maxVisibleLines, forKey: .maxVisibleLines)
        try container.encode(highlightingDebounceInterval, forKey: .highlightingDebounceInterval)
    }
}
