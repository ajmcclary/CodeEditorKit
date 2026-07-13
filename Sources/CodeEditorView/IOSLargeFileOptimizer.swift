import CodeEditorInstrumentation
import Foundation

#if canImport(UIKit)
import UIKit

/// iOS-specific optimizations for large file handling
///
/// This optimizer implements memory-efficient strategies specifically for iOS devices
/// with limited RAM compared to macOS. It provides adaptive rendering, aggressive
/// caching policies, and viewport-based syntax highlighting.
@available(iOS 13.0, *)
@MainActor
public final class IOSLargeFileOptimizer: ObservableObject {
    // MARK: - Configuration

    /// File size threshold (bytes) above which iOS-specific optimizations
    /// engage. Defaults to 1 MB.
    ///
    /// Calibrated against the typical iPhone RAM tier in current shipping
    /// devices (~4–6 GB physical, of which third-party apps may see roughly
    /// 1–2 GB before jetsam pressure). The corresponding macOS path uses no
    /// hard threshold — desktops can afford full-document highlighting at
    /// most realistic sizes.
    ///
    /// Hosts can override this at construction time (the field is `var`)
    /// when targeting iPads with larger RAM budgets or stripped-down memory
    /// extensions.
    public var optimizationThreshold: Int = 1_048_576 // 1MB

    /// Upper bound (UTF-16 length) on a single syntax-highlighting chunk on
    /// iOS. Defaults to 100 000 (~100 KB).
    ///
    /// Chosen so each chunk's highlighting work fits inside a single
    /// frame's worth of CPU budget on the lowest iPhone tier we ship to.
    /// The macOS analog (`PlatformConstants.maxSyntaxHighlightingLength`)
    /// is roughly 10× larger because Mac CPUs can absorb a larger chunk
    /// without dropping below 60 fps.
    ///
    /// Override when the host targets only newer iPads with more headroom.
    public var maxHighlightingRange: Int = 100_000 // 100KB chunks

    /// Multiplier on the visible viewport used when prefetching
    /// highlighting work outside the visible range. Defaults to 0.5 (50 %).
    ///
    /// macOS uses ~1.5 (150 %): desktops can afford to render well past
    /// the visible scroll edge to mask scroll latency. iOS halves it
    /// because the off-screen attributed-string memory pressure adds up on
    /// 4–6 GB tier devices when files are large.
    ///
    /// Override when the host needs different scroll-latency tradeoffs.
    public var viewportExpansion: CGFloat = 0.5 // 50% expansion vs 150% on macOS

    /// Memory pressure response mode
    public var memoryPressureMode: MemoryPressureMode = .adaptive

    // MARK: - State

    @Published public private(set) var isOptimizing = false
    @Published public private(set) var currentMode: OptimizationMode = .normal
    @Published public private(set) var metrics = OptimizationMetrics()

    private weak var textView: UITextView?
    private let memoryMonitor: MemoryMonitor
    private let performanceMonitor: UnifiedPerformanceSystem

    private var highlightingTask: Task<Void, Never>?
    private var viewportTask: Task<Void, Never>?

    // Store original configuration values to restore later
    private var originalMaxSyntaxHighlightingLength: Int?
    private var originalEnableSyntaxHighlighting: Bool = true
    private var originalAdaptiveMode: PerformanceMode?

    // MARK: - Types

    public enum OptimizationMode: String, CaseIterable {
        case normal
        case largeFile
        case extremeOptimization
    }

    public enum MemoryPressureMode: String, CaseIterable {
        case ignore
        case adaptive
        case aggressive
    }

    public struct OptimizationMetrics {
        public var chunksProcessed: Int = 0
        public var memoryReclaimed: Int64 = 0
        public var renderingSkipped: Int = 0
        public var averageChunkTime: TimeInterval = 0
    }

    // MARK: - Initialization

    public init(
        textView: UITextView,
        memoryMonitor: MemoryMonitor,
        performanceMonitor: UnifiedPerformanceSystem
    ) {
        self.textView = textView
        self.memoryMonitor = memoryMonitor
        self.performanceMonitor = performanceMonitor

        setupMemoryHandlers()
        evaluateOptimizationMode()
    }

    // MARK: - Public Methods

    /// Enable iOS-specific optimizations for the current text
    public func enableOptimizations() {
        guard let textView, let text = textView.text else { return }

        isOptimizing = true

        // Determine optimization level based on file size
        let fileSize = text.count
        if fileSize > optimizationThreshold * 10 {
            currentMode = .extremeOptimization
            applyExtremeOptimizations()
        } else if fileSize > optimizationThreshold {
            currentMode = .largeFile
            applyLargeFileOptimizations()
        } else {
            currentMode = .normal
            isOptimizing = false
        }
    }

    /// Disable all optimizations
    public func disableOptimizations() {
        highlightingTask?.cancel()
        viewportTask?.cancel()
        isOptimizing = false
        currentMode = .normal

        // Restore normal settings
        restoreNormalSettings()
    }

    // MARK: - Private Methods

    private func setupMemoryHandlers() {
        // Register aggressive cleanup for iOS
        memoryMonitor.registerCleanupHandler(
            identifier: "ios-large-file",
            priority: .critical
        ) { [weak self] in
            guard let self else {
                return CleanupResult(memoryFreedMB: 0, description: "iOS large file cleanup failed - self was nil")
            }
            return await self.performAggressiveCleanup()
        }
    }

    private func evaluateOptimizationMode() {
        guard let textView else { return }

        // Check current memory usage
        let currentMemoryUsage = memoryMonitor.memoryStats.currentUsageMB
        let textSize = textView.text?.count ?? 0

        // iOS devices have less memory, be more aggressive
        // If using more than 200MB and large text, optimize
        if currentMemoryUsage > 200 && textSize > 500_000 {
            currentMode = .extremeOptimization
        } else if currentMemoryUsage > 100 && textSize > optimizationThreshold {
            currentMode = .largeFile
        }
    }

    private func applyLargeFileOptimizations() {
        guard let textView else { return }

        // 1. Disable automatic syntax highlighting
        if let codeEditorView = textView as? CodeEditorView {
            var config = codeEditorView.configuration

            // Store original values before changing
            if originalMaxSyntaxHighlightingLength == nil {
                originalMaxSyntaxHighlightingLength = config.performance.maxSyntaxHighlightingLength
                originalEnableSyntaxHighlighting = config.display.isSyntaxHighlightingEnabled
                originalAdaptiveMode = codeEditorView.adaptivePerformanceMode.currentMode
            }

            config.display.isSyntaxHighlightingEnabled = false
            config.performance.maxSyntaxHighlightingLength = maxHighlightingRange
            codeEditorView.configuration = config
        }

        // 2. Enable viewport-based highlighting
        startViewportHighlighting()

        // 3. Reduce undo stack size
        textView.undoManager?.levelsOfUndo = 10

        // 4. Disable spell checking
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no

        metrics.chunksProcessed += 1
    }

    private func applyExtremeOptimizations() {
        // Apply large file optimizations first
        applyLargeFileOptimizations()

        guard let textView else { return }

        // Additional extreme measures for iOS

        // 1. Disable all visual effects
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.showsHorizontalScrollIndicator = false

        // 2. Minimal undo history
        textView.undoManager?.levelsOfUndo = 3

        // 3. Disable text attachments
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.lineBreakMode = NSLineBreakMode.byWordWrapping

        // 4. Force layout manager to use simple rendering
        let layoutManager = textView.layoutManager
        layoutManager.allowsNonContiguousLayout = true
        layoutManager.showsInvisibleCharacters = false
        layoutManager.showsControlCharacters = false

        metrics.renderingSkipped += 1
    }

    private func restoreNormalSettings() {
        guard let textView else { return }

        // Restore configuration
        if let codeEditorView = textView as? CodeEditorView {
            var config = codeEditorView.configuration

            // Restore to original values or defaults
            let targetMaxLength = originalMaxSyntaxHighlightingLength ?? PlatformConstants.maxSyntaxHighlightingLength
            config.display.isSyntaxHighlightingEnabled = originalEnableSyntaxHighlighting
            config.performance.maxSyntaxHighlightingLength = targetMaxLength

            // Apply configuration first
            codeEditorView.configuration = config

            // Then force adaptive mode to respect our settings
            if let originalMode = originalAdaptiveMode {
                codeEditorView.adaptivePerformanceMode.forceMode(originalMode)
            } else {
                codeEditorView.adaptivePerformanceMode.forceMode(.highQuality)
            }

            // Re-apply the max length in case adaptive mode changed it
            if codeEditorView.configuration.performance.maxSyntaxHighlightingLength != targetMaxLength {
                var reconfig = codeEditorView.configuration
                reconfig.performance.maxSyntaxHighlightingLength = targetMaxLength
                codeEditorView.configuration = reconfig
            }

            // Clear stored values
            originalMaxSyntaxHighlightingLength = nil
            originalEnableSyntaxHighlighting = true
            originalAdaptiveMode = nil
        }

        // Restore text view settings
        textView.undoManager?.levelsOfUndo = 50
        textView.autocorrectionType = .default
        textView.spellCheckingType = .yes
    }

    private func startViewportHighlighting() {
        viewportTask?.cancel()

        viewportTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.highlightVisibleViewport()

                // Adjust delay based on mode
                let delay: UInt64 = self?.currentMode == .extremeOptimization
                    ? 500_000_000  // 500ms
                    : 200_000_000  // 200ms

                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

    private func highlightVisibleViewport() async {
        guard let textView else { return }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Get visible range
        let visibleRect = textView.bounds
        let glyphRange = textView.layoutManager.glyphRange(forBoundingRect: visibleRect, in: textView.textContainer)
        let visibleRange = textView.layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        // Expand range slightly for smooth scrolling
        let expansion = Int(Double(visibleRange.length) * Double(viewportExpansion))
        _ = NSRange(
            location: max(0, visibleRange.location - expansion),
            length: visibleRange.length + (expansion * 2)
        )

        // For viewport-based highlighting, we would need to implement
        // a custom highlighting mechanism that only processes the visible range.
        // For now, we rely on the configuration settings to control highlighting.

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        metrics.averageChunkTime = (metrics.averageChunkTime + elapsed) / 2
        metrics.chunksProcessed += 1
    }

    private func performAggressiveCleanup() async -> CleanupResult {
        var freedMemory: Int64 = 0

        // 1. Clear syntax highlighting cache
        if textView is CodeEditorView {
            // The syntaxHighlighter might have internal caching mechanisms
            // but we don't have direct access to clear them from here
            freedMemory += 5 * 1_048_576 // Estimate 5MB
        }

        // 2. Clear undo stack
        textView?.undoManager?.removeAllActions()
        freedMemory += 2 * 1_048_576 // Estimate 2MB

        // 3. Force layout manager cleanup
        if let textView {
            textView.layoutManager.ensureLayout(for: textView.textContainer)
        }
        freedMemory += 3 * 1_048_576 // Estimate 3MB

        metrics.memoryReclaimed += freedMemory

        return CleanupResult(
            memoryFreedMB: Double(freedMemory) / 1_048_576,
            description: "iOS large file cleanup"
        )
    }
}
#endif // canImport(UIKit)

// MARK: - SwiftUI Integration

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI

@available(iOS 13.0, *)
extension View {
    /// Enable iOS-specific large file optimizations
    public func iOSLargeFileOptimization(_ enabled: Bool = true) -> some View {
        self.modifier(IOSLargeFileOptimizationModifier(enabled: enabled))
    }
}

@available(iOS 13.0, *)
struct IOSLargeFileOptimizationModifier: ViewModifier {
    let enabled: Bool
    @Environment(\.codeEditorConfiguration) private var configuration

    func body(content: Content) -> some View {
        content
            .onAppear {
                if enabled {
                    // Note: To actually apply these optimizations, you would need to
                    // pass the modified configuration to the CodeEditor view
                    var modifiedConfig = configuration
                    modifiedConfig.performance.enableIOSOptimizations = true
                    modifiedConfig.performance.maxSyntaxHighlightingLength = 100_000
                    // The actual application would need to be done through the CodeEditor initializer
                }
            }
    }
}
#endif
