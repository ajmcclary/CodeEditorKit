import Foundation

// MARK: - Adaptive Performance Mode System

/// System for automatically adjusting performance settings based on file size and system conditions
@MainActor
public final class AdaptivePerformanceMode: ObservableObject {
    // MARK: - Properties

    /// Current performance mode
    @Published public private(set) var currentMode: PerformanceMode = .balanced

    /// Performance configuration for current mode
    @Published public private(set) var configuration: PerformanceModeConfiguration

    /// File size threshold for mode transitions
    private let fileSizeThresholds = FileSizeThresholds()

    /// System resource monitor
    private let memoryMonitor: MemoryMonitor

    /// Performance metrics for mode decisions
    private let performanceMetrics = ProductionPerformanceMetrics.shared

    // MARK: - Initialization

    public init(memoryMonitor: MemoryMonitor) {
        self.memoryMonitor = memoryMonitor
        self.configuration = PerformanceModeConfiguration(mode: .balanced)
    }

    // MARK: - Public API

    /// Update performance mode based on file characteristics
    public func updateMode(for fileSize: Int, language: Language) {
        let suggestedMode = determineMode(fileSize: fileSize, language: language)

        if suggestedMode != currentMode {
            transitionToMode(suggestedMode)
        }
    }

    /// Apply adaptive configuration to editor
    public func applyConfiguration(to config: inout EditorConfiguration) {
        // Display settings
        config.display.isLineNumbersEnabled = configuration.isLineNumbersEnabled
        config.display.enableCodeFolding = configuration.enableCodeFolding
        config.display.enableSyntaxHighlighting = configuration.enableSyntaxHighlighting

        // Performance settings
        config.performance.maxSyntaxHighlightingLength = configuration.maxSyntaxHighlightingLength
        config.performance.maxVisibleLines = configuration.maxVisibleLines
        config.performance.renderingUpdateStrategy = configuration.renderingStrategy

        // Note: highlightingDebounce and lineHeightMultiplier are not available in current config
        // These would need to be added to EditorConfiguration if needed
    }

    /// Force a specific performance mode
    public func forceMode(_ mode: PerformanceMode) {
        transitionToMode(mode)
    }

    // MARK: - Private Methods

    private func determineMode(fileSize: Int, language: Language) -> PerformanceMode {
        // Check memory pressure first
        let memoryPressure = memoryMonitor.getMemoryPressure()
        if memoryPressure == .critical {
            return .performance
        }

        // Complex languages need more resources
        let complexityFactor = language.complexityFactor
        let adjustedSize = fileSize * complexityFactor

        // Determine based on adjusted size
        switch adjustedSize {
        case 0..<fileSizeThresholds.small:
            return .highQuality

        case fileSizeThresholds.small..<fileSizeThresholds.medium:
            return memoryPressure == .warning ? .performance : .balanced

        default:
            return .performance
        }
    }

    private func transitionToMode(_ newMode: PerformanceMode) {
        currentMode = newMode
        configuration = PerformanceModeConfiguration(mode: newMode)

        // Log mode change
        CrossPlatformLogger.logger().info("Performance mode changed to: \(newMode.rawValue)")
    }
}

// MARK: - Supporting Types

/// Performance mode levels
public enum PerformanceMode: String, CaseIterable, Sendable {
    case highQuality = "High Quality"
    case balanced = "Balanced"
    case performance = "Performance"

    var description: String {
        switch self {
        case .highQuality:
            return "Best visual quality for small files"

        case .balanced:
            return "Good balance of features and performance"

        case .performance:
            return "Optimized for large files and low memory"
        }
    }
}

/// Configuration for each performance mode
public struct PerformanceModeConfiguration: Sendable {
    public let mode: PerformanceMode

    // Display features
    public let isLineNumbersEnabled: Bool
    public let enableCodeFolding: Bool
    public let enableSyntaxHighlighting: Bool
    public let enableMinimap: Bool

    // Performance settings
    public let highlightingDebounce: Duration
    public let maxSyntaxHighlightingLength: Int
    public let maxVisibleLines: Int
    public let renderingStrategy: EditorConfiguration.Performance.RenderingUpdateStrategy
    public let prefetchMultiplier: CGFloat

    // Visual settings
    public let lineHeightMultiplier: CGFloat
    public let enableAnimations: Bool

    public init(mode: PerformanceMode) {
        self.mode = mode

        switch mode {
        case .highQuality:
            // All features enabled, minimal debouncing
            isLineNumbersEnabled = true
            enableCodeFolding = true
            enableSyntaxHighlighting = true
            enableMinimap = true
            highlightingDebounce = .milliseconds(100)
            maxSyntaxHighlightingLength = 1_000_000 // 1MB
            maxVisibleLines = 1_000
            renderingStrategy = .immediate
            prefetchMultiplier = 2.0
            lineHeightMultiplier = 1.2
            enableAnimations = true

        case .balanced:
            // Most features enabled, moderate debouncing
            isLineNumbersEnabled = true
            enableCodeFolding = true
            enableSyntaxHighlighting = true
            enableMinimap = false
            highlightingDebounce = .milliseconds(300)
            maxSyntaxHighlightingLength = 500_000 // 500KB
            maxVisibleLines = 500
            renderingStrategy = .batched
            prefetchMultiplier = 1.5
            lineHeightMultiplier = 1.15
            enableAnimations = true

        case .performance:
            // Minimal features, aggressive optimization
            isLineNumbersEnabled = true
            enableCodeFolding = false
            enableSyntaxHighlighting = true // But with limits
            enableMinimap = false
            highlightingDebounce = .milliseconds(500)
            maxSyntaxHighlightingLength = 100_000 // 100KB
            maxVisibleLines = 200
            renderingStrategy = .adaptive
            prefetchMultiplier = 1.0
            lineHeightMultiplier = 1.1
            enableAnimations = false
        }
    }
}

/// File size thresholds
struct FileSizeThresholds {
    let small = 10_000      // 10KB
    let medium = 100_000    // 100KB
    let large = 1_000_000   // 1MB
}

// MARK: - Language Complexity

extension Language {
    /// Complexity factor for performance calculations
    var complexityFactor: Int {
        switch self {
        // Simple languages
        case .plainText, .markdown, .json, .yaml:
            return 1

        // Moderate complexity
        case .javascript, .python, .ruby, .go, .shell, .sql:
            return 2

        // High complexity (nested structures, complex syntax)
        case .swift, .rust, .cpp, .java, .typescript:
            return 3

        // Very high complexity
        case .html, .xml: // Due to nested tag matching
            return 4

        default:
            return 2 // Default to moderate
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// Environment key for adaptive performance mode
private struct AdaptivePerformanceModeKey: EnvironmentKey {
    static let defaultValue: AdaptivePerformanceMode? = nil
}

extension EnvironmentValues {
    /// The current adaptive performance mode, if any.
    public var adaptivePerformanceMode: AdaptivePerformanceMode? {
        get { self[AdaptivePerformanceModeKey.self] }
        set { self[AdaptivePerformanceModeKey.self] = newValue }
    }
}

/// View modifier for adaptive performance
public struct AdaptivePerformanceModifier: ViewModifier {
    @StateObject private var performanceMode: AdaptivePerformanceMode

    public init(memoryMonitor: MemoryMonitor) {
        _performanceMode = StateObject(wrappedValue: AdaptivePerformanceMode(memoryMonitor: memoryMonitor))
    }

    public func body(content: Content) -> some View {
        content
            .environment(\.adaptivePerformanceMode, performanceMode)
            .overlay(alignment: .topTrailing) {
                if ProcessInfo.processInfo.environment["SHOW_PERFORMANCE_MODE"] != nil {
                    PerformanceModeIndicator(mode: performanceMode.currentMode)
                }
            }
    }
}

/// Visual indicator for current performance mode
struct PerformanceModeIndicator: View {
    let mode: PerformanceMode

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(mode.rawValue)
                .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(backgroundColor.opacity(0.9))
        .foregroundColor(.white)
        .cornerRadius(4)
        .padding(8)
    }

    private var icon: String {
        switch mode {
        case .highQuality: return "sparkles"
        case .balanced: return "slider.horizontal.3"
        case .performance: return "bolt.fill"
        }
    }

    private var backgroundColor: Color {
        switch mode {
        case .highQuality: return .blue
        case .balanced: return .green
        case .performance: return .orange
        }
    }
}

extension View {
    /// Enable adaptive performance mode
    public func adaptivePerformance(memoryMonitor: MemoryMonitor) -> some View {
        modifier(AdaptivePerformanceModifier(memoryMonitor: memoryMonitor))
    }
}
