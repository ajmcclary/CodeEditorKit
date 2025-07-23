import Foundation
#if canImport(SwiftUI)
import SwiftUI // For Duration type
#endif

extension EditorConfiguration {
    /// Performance configuration options for optimization settings.
    ///
    /// Controls performance-related features including syntax highlighting limits,
    /// rendering optimizations, and resource usage.
    public struct Performance: Sendable {
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

        /// Maximum file size in bytes (0 = use platform default)
        /// 
        /// Files larger than this limit may have degraded performance
        /// or limited features. Default values:
        /// - macOS: 10MB
        /// - iOS: 5MB
        /// - iPad: 8MB
        /// 
        /// Set to 0 to use platform-specific defaults from PlatformAdjustments.
        public var maxFileSize: Int = 0

        /// Delay before triggering syntax highlighting
        public var highlightingDebounceInterval: Duration = .seconds(PlatformConstants.defaultHighlightingDebounceInterval)

        /// Whether to enable smooth scrolling
        public var smoothScrolling: Bool = true

        /// Debounce interval for text changes.
        ///
        /// Delays processing of rapid text changes to improve performance.
        /// Syntax highlighting and other expensive operations wait for this
        /// duration of inactivity before processing.
        ///
        /// - Note: Lower values provide more responsive feedback but use more CPU.
        public var textChangeDebounceInterval: Duration = .milliseconds(100)

        /// Whether to animate code folding operations.
        ///
        /// When enabled, folding and unfolding operations are animated
        /// for a smoother visual experience. May impact performance on slower systems.
        ///
        /// - Note: Disable for better performance with very large files.
        public var animateCodeFolding: Bool = true

        /// Maximum events per second for each event type in the event system.
        ///
        /// Controls throttling of high-frequency events to prevent performance issues.
        /// Events that exceed this rate will be dropped. Default is 60 events/second.
        ///
        /// - Note: This only affects the UnifiedEventSystem when explicitly configured.
        public var maxEventsPerSecond: Int = 60

        /// Enable iOS-specific large file optimizations
        /// 
        /// When enabled on iOS, the framework will automatically apply memory-efficient
        /// strategies for files exceeding the threshold, including viewport-based
        /// rendering and chunked syntax highlighting.
        public var enableIOSOptimizations: Bool = {
            #if canImport(UIKit) && !targetEnvironment(macCatalyst)
            return true
            #else
            return false
            #endif
        }()

        /// iOS large file threshold (bytes)
        /// 
        /// Files larger than this size will trigger iOS-specific optimizations
        /// to maintain performance on memory-constrained devices.
        public var iOSLargeFileThreshold: Int = 1_048_576 // 1MB

        /// iOS maximum highlighting chunk size
        /// 
        /// On iOS, syntax highlighting is performed in chunks to prevent
        /// memory spikes. This sets the maximum characters per chunk.
        public var iOSMaxHighlightingChunk: Int = 100_000 // 100KB

        /// Custom memory monitor instance for tracking memory usage.
        ///
        /// When nil, the code editor will create its own instance.
        /// Set this to share a memory monitor across multiple views or
        /// to provide a custom implementation for testing.
        ///
        /// ## Example
        ///
        /// ```swift
        /// // Create custom monitor
        /// let monitor = MemoryMonitor()
        /// monitor.memoryThresholdMB = 200.0
        /// monitor.enableAutomaticCleanup = true
        /// 
        /// // Inject via configuration
        /// var config = EditorConfiguration()
        /// config.performance.memoryMonitor = monitor
        /// config.apply(to: editorView)
        /// ```
        /// 
        /// ## Shared Monitor Pattern
        /// 
        /// ```swift
        /// // Share monitor across multiple editors
        /// let sharedMonitor = MemoryMonitor()
        /// 
        /// var config = EditorConfiguration()
        /// config.performance.memoryMonitor = sharedMonitor
        /// 
        /// config.apply(to: editor1)
        /// config.apply(to: editor2)
        /// ```
        ///
        /// - SeeAlso: <doc:MemoryMonitor-Injection>
        public var memoryMonitor: MemoryMonitor?

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
        case maxFileSize
        case highlightingDebounceInterval
        case textChangeDebounceInterval
        case smoothScrolling
        case animateCodeFolding
        case maxEventsPerSecond
        case enableIOSOptimizations
        case iOSLargeFileThreshold
        case iOSMaxHighlightingChunk
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxSyntaxHighlightingLength = try container.decodeIfPresent(Int.self, forKey: .maxSyntaxHighlightingLength) ?? 500_000
        useHardwareAcceleration = try container.decodeIfPresent(Bool.self, forKey: .useHardwareAcceleration) ?? true
        renderingUpdateStrategy = try container.decodeIfPresent(RenderingUpdateStrategy.self, forKey: .renderingUpdateStrategy) ?? .adaptive
        maxVisibleLines = try container.decodeIfPresent(Int.self, forKey: .maxVisibleLines) ?? 1_000
        maxFileSize = try container.decodeIfPresent(Int.self, forKey: .maxFileSize) ?? 0
        // Decode as TimeInterval for backward compatibility, then convert to Duration
        let highlightInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .highlightingDebounceInterval) ?? 0.1
        highlightingDebounceInterval = .seconds(highlightInterval)

        let textInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .textChangeDebounceInterval) ?? 0.1
        textChangeDebounceInterval = .seconds(textInterval)

        smoothScrolling = try container.decodeIfPresent(Bool.self, forKey: .smoothScrolling) ?? true
        animateCodeFolding = try container.decodeIfPresent(Bool.self, forKey: .animateCodeFolding) ?? true
        maxEventsPerSecond = try container.decodeIfPresent(Int.self, forKey: .maxEventsPerSecond) ?? 60
        enableIOSOptimizations = try container.decodeIfPresent(Bool.self, forKey: .enableIOSOptimizations) ?? {
            #if canImport(UIKit) && !targetEnvironment(macCatalyst)
            return true
            #else
            return false
            #endif
        }()
        iOSLargeFileThreshold = try container.decodeIfPresent(Int.self, forKey: .iOSLargeFileThreshold) ?? 1_048_576
        iOSMaxHighlightingChunk = try container.decodeIfPresent(Int.self, forKey: .iOSMaxHighlightingChunk) ?? 100_000
        // memoryMonitor is not decoded - it's a runtime dependency
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(maxSyntaxHighlightingLength, forKey: .maxSyntaxHighlightingLength)
        try container.encode(useHardwareAcceleration, forKey: .useHardwareAcceleration)
        try container.encode(renderingUpdateStrategy, forKey: .renderingUpdateStrategy)
        try container.encode(maxVisibleLines, forKey: .maxVisibleLines)
        try container.encode(maxFileSize, forKey: .maxFileSize)
        // Encode as TimeInterval for backward compatibility
        try container.encode(highlightingDebounceInterval.timeInterval, forKey: .highlightingDebounceInterval)
        try container.encode(textChangeDebounceInterval.timeInterval, forKey: .textChangeDebounceInterval)
        try container.encode(smoothScrolling, forKey: .smoothScrolling)
        try container.encode(animateCodeFolding, forKey: .animateCodeFolding)
        try container.encode(maxEventsPerSecond, forKey: .maxEventsPerSecond)
        try container.encode(enableIOSOptimizations, forKey: .enableIOSOptimizations)
        try container.encode(iOSLargeFileThreshold, forKey: .iOSLargeFileThreshold)
        try container.encode(iOSMaxHighlightingChunk, forKey: .iOSMaxHighlightingChunk)
        // memoryMonitor is not encoded - it's a runtime dependency
    }
}

// MARK: - Equatable Implementation

extension EditorConfiguration.Performance: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        // Compare all properties except memoryMonitor
        lhs.maxSyntaxHighlightingLength == rhs.maxSyntaxHighlightingLength &&
        lhs.useHardwareAcceleration == rhs.useHardwareAcceleration &&
        lhs.renderingUpdateStrategy == rhs.renderingUpdateStrategy &&
        lhs.maxVisibleLines == rhs.maxVisibleLines &&
        lhs.maxFileSize == rhs.maxFileSize &&
        lhs.highlightingDebounceInterval == rhs.highlightingDebounceInterval &&
        lhs.smoothScrolling == rhs.smoothScrolling &&
        lhs.textChangeDebounceInterval == rhs.textChangeDebounceInterval &&
        lhs.animateCodeFolding == rhs.animateCodeFolding &&
        lhs.maxEventsPerSecond == rhs.maxEventsPerSecond &&
        lhs.enableIOSOptimizations == rhs.enableIOSOptimizations &&
        lhs.iOSLargeFileThreshold == rhs.iOSLargeFileThreshold &&
        lhs.iOSMaxHighlightingChunk == rhs.iOSMaxHighlightingChunk
        // memoryMonitor is intentionally excluded from equality comparison
    }
}
