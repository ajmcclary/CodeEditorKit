import Foundation

#if canImport(UIKit) && !targetEnvironment(macCatalyst)
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
    
    /// File size threshold for enabling optimizations (in bytes)
    public var optimizationThreshold: Int = 1_048_576 // 1MB
    
    /// Maximum syntax highlighting range for iOS
    public var maxHighlightingRange: Int = 100_000 // 100KB chunks
    
    /// Viewport expansion factor for prefetching
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
                return CleanupResult(success: false, memoryFreedMB: 0)
            }
            return await self.performAggressiveCleanup()
        }
    }
    
    private func evaluateOptimizationMode() {
        guard let textView else { return }
        
        // Check available memory
        let availableMemory = memoryMonitor.memoryStats.availableMemoryMB
        let textSize = textView.text?.count ?? 0
        
        // iOS devices have less memory, be more aggressive
        if availableMemory < 500 && textSize > 500_000 {
            currentMode = .extremeOptimization
        } else if availableMemory < 1_000 && textSize > optimizationThreshold {
            currentMode = .largeFile
        }
    }
    
    private func applyLargeFileOptimizations() {
        guard let textView else { return }
        
        // 1. Disable automatic syntax highlighting
        if let config = (textView as? CodeEditorView)?.configuration {
            config.display.syntaxHighlighting = false
            config.performance.maxSyntaxHighlightingLength = maxHighlightingRange
        }
        
        // 2. Enable viewport-based highlighting
        startViewportHighlighting()
        
        // 3. Reduce undo stack size
        textView.undoManager?.levelsOfUndo = 10
        
        // 4. Disable spell checking
        textView.autocorrectionType = .no
        if #available(iOS 13.0, *) {
            textView.spellCheckingType = .no
        }
        
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
        if let layoutManager = textView.layoutManager {
            layoutManager.allowsNonContiguousLayout = true
            layoutManager.showsInvisibleCharacters = false
            layoutManager.showsControlCharacters = false
        }
        
        metrics.renderingSkipped += 1
    }
    
    private func restoreNormalSettings() {
        guard let textView else { return }
        
        // Restore configuration
        if let config = (textView as? CodeEditorView)?.configuration {
            config.display.syntaxHighlighting = true
            config.performance.maxSyntaxHighlightingLength = 0 // unlimited
        }
        
        // Restore text view settings
        textView.undoManager?.levelsOfUndo = 50
        textView.autocorrectionType = .default
        if #available(iOS 13.0, *) {
            textView.spellCheckingType = .yes
        }
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
        guard let textView,
              let codeEditorView = textView as? CodeEditorView else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Get visible range
        let visibleRect = textView.bounds
        let glyphRange = textView.layoutManager?.glyphRange(forBoundingRect: visibleRect, in: textView.textContainer) ?? NSRange()
        let visibleRange = textView.layoutManager?.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil) ?? NSRange()
        
        // Expand range slightly for smooth scrolling
        let expansion = Int(Double(visibleRange.length) * Double(viewportExpansion))
        let expandedRange = NSRange(
            location: max(0, visibleRange.location - expansion),
            length: visibleRange.length + (expansion * 2)
        )
        
        // Highlight only the expanded visible range
        if let highlighter = codeEditorView.syntaxHighlighter {
            await highlighter.highlightRange(expandedRange)
        }
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        metrics.averageChunkTime = (metrics.averageChunkTime + elapsed) / 2
        metrics.chunksProcessed += 1
    }
    
    private func performAggressiveCleanup() async -> CleanupResult {
        var freedMemory: Int64 = 0
        
        // 1. Clear syntax highlighting cache
        if let codeEditorView = textView as? CodeEditorView,
           let cache = codeEditorView.syntaxHighlighter?.tokenCache {
            cache.clearCache()
            freedMemory += 5 * 1_048_576 // Estimate 5MB
        }
        
        // 2. Clear undo stack
        textView?.undoManager?.removeAllActions()
        freedMemory += 2 * 1_048_576 // Estimate 2MB
        
        // 3. Force layout manager cleanup
        textView?.layoutManager?.ensureLayout(for: textView?.textContainer ?? NSTextContainer())
        freedMemory += 3 * 1_048_576 // Estimate 3MB
        
        metrics.memoryReclaimed += freedMemory
        
        return CleanupResult(
            success: true,
            memoryFreedMB: Double(freedMemory) / 1_048_576,
            description: "iOS large file cleanup"
        )
    }
}
#endif // canImport(UIKit) && !targetEnvironment(macCatalyst)

// MARK: - SwiftUI Integration

#if canImport(SwiftUI) && canImport(UIKit) && !targetEnvironment(macCatalyst)
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
    
    func body(content: Content) -> some View {
        content
            .onPreferenceChange(CodeEditorConfigurationKey.self) { config in
                if enabled {
                    config?.performance.enableIOSOptimizations = true
                    config?.performance.maxSyntaxHighlightingLength = 100_000
                }
            }
    }
}
#endif
