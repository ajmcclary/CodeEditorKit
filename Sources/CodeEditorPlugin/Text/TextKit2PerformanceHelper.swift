import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Helper for optimizing TextKit2 performance across different scenarios
@MainActor
enum TextKit2PerformanceHelper {
    // MARK: - File Size Categories

    enum FileSize {
        case small      // < 10KB
        case medium     // 10KB - 100KB  
        case large      // 100KB - 1MB
        case veryLarge  // > 1MB

        init(characterCount: Int) {
            switch characterCount {
            case 0..<10_000:
                self = .small

            case 10_000..<100_000:
                self = .medium

            case 100_000..<1_000_000:
                self = .large

            default:
                self = .veryLarge
            }
        }
    }

    // MARK: - Performance Configuration

    struct PerformanceConfiguration {
        var enableViewportOptimization: Bool
        var enableFragmentRecycling: Bool
        var enableAsyncLayout: Bool
        var maxCachedFragments: Int
        var layoutChunkSize: Int
        var prefetchDistance: Int

        static func optimal(for fileSize: FileSize) -> Self {
            switch fileSize {
            case .small:
                return Self(
                    enableViewportOptimization: false,
                    enableFragmentRecycling: false,
                    enableAsyncLayout: false,
                    maxCachedFragments: 100,
                    layoutChunkSize: 1_000,
                    prefetchDistance: 2_000
                )

            case .medium:
                return Self(
                    enableViewportOptimization: true,
                    enableFragmentRecycling: false,
                    enableAsyncLayout: true,
                    maxCachedFragments: 300,
                    layoutChunkSize: 2_000,
                    prefetchDistance: 5_000
                )

            case .large:
                return Self(
                    enableViewportOptimization: true,
                    enableFragmentRecycling: true,
                    enableAsyncLayout: true,
                    maxCachedFragments: 500,
                    layoutChunkSize: 3_000,
                    prefetchDistance: 10_000
                )

            case .veryLarge:
                return Self(
                    enableViewportOptimization: true,
                    enableFragmentRecycling: true,
                    enableAsyncLayout: true,
                    maxCachedFragments: 1_000,
                    layoutChunkSize: 5_000,
                    prefetchDistance: 20_000
                )
            }
        }
    }

    // MARK: - Public Methods

    /// Configure TextKit2 performance settings based on file size
    /// - Parameters:
    ///   - textView: The text view to optimize
    ///   - characterCount: Number of characters in the document
    /// - Returns: The applied performance configuration
    @discardableResult
    static func configureForOptimalPerformance(
        textView: PlatformTextView,
        characterCount: Int
    ) -> PerformanceConfiguration {
        let fileSize = FileSize(characterCount: characterCount)
        let config = PerformanceConfiguration.optimal(for: fileSize)

        applyConfiguration(config, to: textView)
        return config
    }

    /// Apply specific performance configuration to text view
    /// - Parameters:
    ///   - config: Performance configuration to apply
    ///   - textView: Target text view
    static func applyConfiguration(
        _ config: PerformanceConfiguration,
        to textView: PlatformTextView
    ) {
        // Configure text container for performance
        configureTextContainer(textView.textContainer, for: config)

        // Configure layout manager if using TextKit2
        if let textLayoutManager = textView.textLayoutManager {
            configureTextLayoutManager(textLayoutManager, for: config)
        }

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Configure NSTextView specific optimizations
        configureNSTextView(textView, for: config)
        #elseif canImport(UIKit)
        // Configure UITextView specific optimizations
        configureUITextView(textView, for: config)
        #endif
    }

    /// Optimize text view for real-time editing performance
    /// - Parameter textView: Text view to optimize
    static func optimizeForRealTimeEditing(_ textView: PlatformTextView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        guard let textContainer = textView.textContainer else { return }

        // Disable expensive visual features during editing
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        // Optimize layout
        textContainer.heightTracksTextView = false
        textContainer.widthTracksTextView = true

        // Reduce line fragment padding for better performance
        textContainer.lineFragmentPadding = 0

        #elseif canImport(UIKit)
        // textView is already UITextView when we're in UIKit
        let uiTextView = textView

        // Disable autocorrection features
        uiTextView.autocorrectionType = .no
        uiTextView.spellCheckingType = .no
        uiTextView.autocapitalizationType = .none

        // Optimize scrolling
        uiTextView.showsVerticalScrollIndicator = true
        uiTextView.showsHorizontalScrollIndicator = false
        #endif
    }

    /// Optimize text view for read-only viewing performance
    /// - Parameter textView: Text view to optimize
    static func optimizeForReadOnlyViewing(_ textView: PlatformTextView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)

        // Disable editing features
        textView.isEditable = false
        textView.isSelectable = true

        // Disable all text processing features
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.allowsUndo = false

        // Optimize for display
        textView.drawsBackground = true
        textView.usesFindPanel = true

        #elseif canImport(UIKit)
        // Disable editing
        textView.isEditable = false
        textView.isSelectable = true

        // Optimize display
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        #endif
    }

    /// Enable TextKit2 if available and beneficial
    /// - Parameters:
    ///   - textView: Text view to configure
    ///   - characterCount: Number of characters in document
    /// - Returns: Whether TextKit2 was enabled
    @discardableResult
    static func enableTextKit2IfBeneficial(
        _ textView: PlatformTextView,
        characterCount: Int
    ) -> Bool {
        // TextKit2 is generally beneficial for larger files
        let fileSize = FileSize(characterCount: characterCount)
        let shouldUseTextKit2 = fileSize == .large || fileSize == .veryLarge

        if shouldUseTextKit2 && textView.textLayoutManager == nil {
            // Try to enable TextKit2
            return ModernTextKitHelper.ensureTextKit2(for: textView)
        }

        return textView.textLayoutManager != nil
    }

    /// Configure async layout processing for large files
    /// - Parameters:
    ///   - textView: Text view to configure
    ///   - enable: Whether to enable async layout
    static func configureAsyncLayout(_ textView: PlatformTextView, enable: Bool) {
        guard let textLayoutManager = textView.textLayoutManager else { return }

        if enable {
            // Configure for async layout processing
            textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)
        }
    }

    // MARK: - Private Configuration Methods

    private static func configureTextContainer(
        _ textContainer: NSTextContainer?,
        for config: PerformanceConfiguration
    ) {
        guard let textContainer else { return }

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Configure container for performance
        textContainer.heightTracksTextView = false
        textContainer.widthTracksTextView = true

        // Adjust line fragment padding based on performance needs
        if config.enableViewportOptimization {
            textContainer.lineFragmentPadding = 2.0 // Minimal padding for performance
        } else {
            textContainer.lineFragmentPadding = 5.0 // Standard padding
        }
        #endif

        // Set size constraints for large files
        if config.maxCachedFragments > 500 {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textContainer.containerSize = NSSize(width: 1_000, height: 10_000_000)
            #endif
        }
    }

    private static func configureTextLayoutManager(
        _ layoutManager: NSTextLayoutManager,
        for config: PerformanceConfiguration
    ) {
        // Configure TextKit2 layout manager for performance
        if config.enableAsyncLayout {
            // Enable async layout processing
            layoutManager.ensureLayout(for: layoutManager.documentRange)
        }

        // Configure viewport optimization
        if config.enableViewportOptimization {
            // This would configure viewport-based layout
            // Implementation depends on specific TextKit2 APIs
        }
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private static func configureNSTextView(
        _ textView: NSTextView,
        for config: PerformanceConfiguration
    ) {
        // Configure NSTextView specific performance settings

        // Disable expensive features for large files
        if config.maxCachedFragments > 300 {
            textView.isContinuousSpellCheckingEnabled = false
            textView.isGrammarCheckingEnabled = false
            textView.isAutomaticQuoteSubstitutionEnabled = false
            textView.isAutomaticDashSubstitutionEnabled = false
            textView.isAutomaticTextReplacementEnabled = false
        }

        // Configure scrolling performance
        textView.isVerticallyResizable = true
        // Don't override horizontal resizability here - let the configuration handle it

        // Set appropriate size constraints
        if config.enableViewportOptimization {
            textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.minSize = NSSize(width: 0, height: 0)
        }

        // Configure find panel for large files
        textView.usesFindPanel = true
        textView.usesFindBar = true
    }
    #endif

    #if canImport(UIKit)
    private static func configureUITextView(
        _ textView: UITextView,
        for config: PerformanceConfiguration
    ) {
        // Configure UITextView specific performance settings

        // Disable expensive features for large files
        if config.maxCachedFragments > 300 {
            textView.autocorrectionType = .no
            textView.spellCheckingType = .no
            textView.autocapitalizationType = .none
        }

        // Configure scrolling
        textView.showsVerticalScrollIndicator = true
        textView.showsHorizontalScrollIndicator = false
        textView.alwaysBounceVertical = true
        textView.alwaysBounceHorizontal = false

        // Optimize content size for large files
        if config.enableViewportOptimization {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            textView.textContainer?.maximumNumberOfLines = 0
            // Don't override line break mode - let configuration handle it
            #else
            let textContainer = textView.textContainer
            textContainer.maximumNumberOfLines = 0
            // Don't override line break mode - let configuration handle it
            #endif
        }
    }
    #endif
}

// MARK: - Performance Monitoring

/// Monitors TextKit2 performance metrics
@MainActor
public final class TextKit2PerformanceMonitor: ObservableObject {
    // MARK: - Metrics

    @Published public private(set) var layoutOperations: Int = 0
    @Published public private(set) var averageLayoutTime: TimeInterval = 0
    @Published public private(set) var peakLayoutTime: TimeInterval = 0
    @Published public private(set) var totalRenderingTime: TimeInterval = 0
    @Published public private(set) var fragmentsGenerated: Int = 0
    @Published public private(set) var fragmentsRecycled: Int = 0
    @Published public private(set) var cacheHitRate: Double = 0
    @Published public private(set) var memoryUsage: Double = 0 // In MB
    @Published public private(set) var lastMeasurement = Date()

    // MARK: - Private State

    private var layoutTimes: [TimeInterval] = []
    private var cacheHits: Int = 0
    private var cacheMisses: Int = 0
    private let maxSamples = 100

    // MARK: - Public Methods

    /// Record a layout operation
    /// - Parameter duration: Time taken for the layout operation
    public func recordLayoutOperation(duration: TimeInterval) {
        layoutOperations += 1
        totalRenderingTime += duration
        peakLayoutTime = max(peakLayoutTime, duration)

        layoutTimes.append(duration)
        if layoutTimes.count > maxSamples {
            layoutTimes.removeFirst()
        }

        averageLayoutTime = layoutTimes.reduce(0, +) / Double(layoutTimes.count)
        lastMeasurement = Date()
    }

    /// Record fragment generation
    public func recordFragmentGenerated() {
        fragmentsGenerated += 1
    }

    /// Record fragment recycling
    public func recordFragmentRecycled() {
        fragmentsRecycled += 1
    }

    /// Record cache hit
    public func recordCacheHit() {
        cacheHits += 1
        updateCacheHitRate()
    }

    /// Record cache miss
    public func recordCacheMiss() {
        cacheMisses += 1
        updateCacheHitRate()
    }

    /// Update memory usage estimate
    /// - Parameter memoryMB: Current memory usage in MB
    public func updateMemoryUsage(_ memoryMB: Double) {
        memoryUsage = memoryMB
        lastMeasurement = Date()
    }

    /// Reset all metrics
    public func reset() {
        layoutOperations = 0
        averageLayoutTime = 0
        peakLayoutTime = 0
        totalRenderingTime = 0
        fragmentsGenerated = 0
        fragmentsRecycled = 0
        cacheHitRate = 0
        memoryUsage = 0
        cacheHits = 0
        cacheMisses = 0
        layoutTimes.removeAll()
        lastMeasurement = Date()
    }

    /// Get performance summary
    public var performanceSummary: String {
        """
        TextKit2 Performance Summary:
        - Layout Operations: \(layoutOperations)
        - Average Layout Time: \(String(format: "%.3f", averageLayoutTime))s
        - Peak Layout Time: \(String(format: "%.3f", peakLayoutTime))s
        - Total Rendering Time: \(String(format: "%.3f", totalRenderingTime))s
        - Fragments Generated: \(fragmentsGenerated)
        - Fragments Recycled: \(fragmentsRecycled)
        - Cache Hit Rate: \(String(format: "%.1f", cacheHitRate * 100))%
        - Memory Usage: \(String(format: "%.1f", memoryUsage))MB
        - Recycling Rate: \(fragmentsGenerated > 0 ? String(format: "%.1f", Double(fragmentsRecycled) / Double(fragmentsGenerated) * 100) : "0")%
        """
    }

    // MARK: - Private Methods

    private func updateCacheHitRate() {
        let totalRequests = cacheHits + cacheMisses
        cacheHitRate = totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0
    }
}
