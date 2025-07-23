import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Performance Capabilities

extension PlatformCapabilities {
    /// Performance characteristics and optimization recommendations
    public struct PerformanceCapabilities {
        /// Whether hardware-accelerated rendering is available
        public let supportsHardwareAcceleration: Bool

        /// Whether background processing queues are supported
        public let supportsBackgroundProcessing: Bool

        /// Whether smooth scrolling animations are supported
        public let supportsSmoothScrolling: Bool

        /// Whether CADisplayLink is available for frame-rate synchronization
        public let supportsCADisplayLink: Bool

        /// Recommended cache size in bytes for optimal performance
        public let recommendedCacheSize: Int

        /// Maximum recommended file size in bytes for smooth operation
        public let maxRecommendedFileSize: Int

        /// The processor architecture of the current device
        public let processorArchitecture: ProcessorArchitecture

        /// The memory profile classification for the current device
        public let memoryProfile: MemoryProfile
    }

    /// Processor architecture types
    public enum ProcessorArchitecture {
        /// Intel x86_64 architecture
        case intel64
        /// Apple Silicon (M-series) processors
        case appleSilicon
        /// ARM64 architecture (iOS devices)
        case arm64
        /// Unknown or unsupported architecture
        case unknown

        /// Whether this architecture supports advanced SIMD operations
        public var supportsAdvancedSIMD: Bool {
            switch self {
            case .appleSilicon, .arm64:
                return true

            case .intel64:
                return true // AVX support
            case .unknown:
                return false
            }
        }
    }

    /// Memory profile for performance tuning
    public enum MemoryProfile {
        /// Low memory devices (< 4GB)
        case low
        /// Medium memory devices (4-8GB)
        case medium
        /// High memory devices (8-16GB)
        case high
        /// Ultra high memory devices (> 16GB)
        case ultra

        /// Recommended cache multiplier for this memory profile
        public var cacheMultiplier: Double {
            switch self {
            case .low: return 0.5
            case .medium: return 1.0
            case .high: return 2.0
            case .ultra: return 4.0
            }
        }
    }

    /// Get comprehensive performance capabilities
    ///
    /// This computed property provides a complete overview of performance
    /// characteristics, enabling intelligent optimization decisions.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let perf = capabilities.performanceCapabilities
    /// 
    /// // Configure based on capabilities
    /// if perf.supportsHardwareAcceleration {
    ///     enableGPUAcceleration()
    /// }
    /// 
    /// // Adjust cache size based on memory
    /// let cacheSize = perf.recommendedCacheSize
    /// configureCache(size: cacheSize)
    /// 
    /// // Optimize for processor architecture
    /// if perf.processorArchitecture.supportsAdvancedSIMD {
    ///     enableSIMDOptimizations()
    /// }
    /// ```
    ///
    /// - Returns: Comprehensive performance capability information
    public var performanceCapabilities: PerformanceCapabilities {
        PerformanceCapabilities(
            supportsHardwareAcceleration: supportsHardwareAcceleration,
            supportsBackgroundProcessing: supportsBackgroundProcessing,
            supportsSmoothScrolling: supportsSmoothScrolling,
            supportsCADisplayLink: supportsCADisplayLink,
            recommendedCacheSize: recommendedCacheSize,
            maxRecommendedFileSize: maxRecommendedFileSize,
            processorArchitecture: processorArchitecture,
            memoryProfile: memoryProfile
        )
    }

    /// Whether hardware acceleration is supported
    ///
    /// Hardware acceleration uses GPU resources for rendering and
    /// computational tasks, providing significant performance improvements.
    ///
    /// ## Support Details
    /// - **macOS**: Metal support on all supported versions
    /// - **iOS**: Metal support on all supported devices
    /// - **Catalyst**: Inherits macOS Metal support
    ///
    /// - Returns: True if hardware acceleration is available
    public var supportsHardwareAcceleration: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Metal is available on all supported macOS versions
        return true
        #elseif canImport(UIKit)
        // Check for Metal support on iOS (excludes Apple TV)
        return UIDevice.current.userInterfaceIdiom != .tv
        #else
        return false
        #endif
    }

    /// Whether background processing is supported
    ///
    /// Background processing allows for syntax highlighting, parsing,
    /// and other tasks to run concurrently with user interaction.
    ///
    /// ## Implementation
    /// - Uses Swift concurrency (async/await)
    /// - Falls back to GCD for older platforms
    /// - Respects system background processing policies
    ///
    /// - Returns: True if background processing is available
    public var supportsBackgroundProcessing: Bool {
        // All platforms support GCD/async-await
        true
    }

    /// Whether smooth scrolling is supported
    ///
    /// Smooth scrolling provides fluid, high-framerate scrolling
    /// experiences on capable displays.
    ///
    /// ## Support Details
    /// - **macOS**: Always supported
    /// - **iOS**: ProMotion displays (120Hz)
    /// - **Catalyst**: Always supported (inherits macOS behavior)
    /// - **Standard displays**: 60Hz scrolling
    ///
    /// - Returns: True if smooth scrolling is available
    public var supportsSmoothScrolling: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // ProMotion displays and smooth scrolling
        return true
        #elseif targetEnvironment(macCatalyst)
        // Catalyst should support smooth scrolling like macOS
        return true
        #elseif canImport(UIKit)
        // iOS devices with ProMotion
        return UIScreen.main.maximumFramesPerSecond > 60
        #else
        return false
        #endif
    }

    /// Whether CADisplayLink is supported for frame synchronization
    ///
    /// CADisplayLink provides precise frame timing for smooth animations
    /// and updates synchronized with the display refresh rate.
    ///
    /// ## Platform Support
    /// - **iOS**: Available on all versions
    /// - **macOS**: Available on 14.0+
    /// - **Catalyst**: Follows macOS availability (14.0+)
    ///
    /// - Returns: True if CADisplayLink is available
    public var supportsCADisplayLink: Bool {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        return true
        #elseif canImport(AppKit) || targetEnvironment(macCatalyst)
        return systemVersionComponents.major >= 14
        #else
        return false
        #endif
    }

    /// Current processor architecture
    ///
    /// Identifies the processor architecture for architecture-specific
    /// optimizations and feature detection.
    ///
    /// - Returns: Current processor architecture
    public var processorArchitecture: ProcessorArchitecture {
        #if arch(arm64)
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return .appleSilicon
            #else
            return .arm64
            #endif
        #elseif arch(x86_64)
        return .intel64
        #else
        return .unknown
        #endif
    }

    /// Current memory profile classification
    ///
    /// Classifies available system memory for performance tuning
    /// and resource allocation decisions.
    ///
    /// - Returns: Current memory profile
    public var memoryProfile: MemoryProfile {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryGB = Double(physicalMemory) / (1_024 * 1_024 * 1_024)

        if memoryGB > 16 {
            return .ultra
        } else if memoryGB > 8 {
            return .high
        } else if memoryGB > 4 {
            return .medium
        } else {
            return .low
        }
    }

    /// Recommended cache size based on available memory
    ///
    /// Calculates optimal cache size considering system memory,
    /// platform characteristics, and concurrent app usage.
    ///
    /// ## Calculation Method
    /// - Base size: 50MB
    /// - Multiplied by memory profile factor
    /// - Adjusted for platform overhead
    ///
    /// - Returns: Recommended cache size in bytes
    public var recommendedCacheSize: Int {
        let baseSize = 50 * 1_024 * 1_024 // 50MB base
        let multiplier = memoryProfile.cacheMultiplier

        return Int(Double(baseSize) * multiplier)
    }

    /// Maximum recommended file size for optimal performance
    ///
    /// Determines the largest file size that can be efficiently
    /// handled without performance degradation.
    ///
    /// ## Considerations
    /// - Available memory
    /// - Platform processing power
    /// - Concurrent operation overhead
    /// - Syntax highlighting complexity
    ///
    /// - Returns: Maximum recommended file size in bytes
    public var maxRecommendedFileSize: Int {
        switch memoryProfile {
        case .ultra:
            return 100 * 1_024 * 1_024 // 100MB
        case .high:
            return 50 * 1_024 * 1_024 // 50MB
        case .medium:
            return 20 * 1_024 * 1_024 // 20MB
        case .low:
            return 10 * 1_024 * 1_024 // 10MB
        }
    }

    /// Whether Apple Silicon-specific optimizations are available
    ///
    /// Apple Silicon processors offer unique optimization opportunities
    /// through unified memory architecture and advanced neural engines.
    ///
    /// - Returns: True if running on Apple Silicon
    public var isAppleSilicon: Bool {
        processorArchitecture == .appleSilicon
    }

    /// Get performance optimization recommendations
    ///
    /// This method provides comprehensive performance tuning recommendations
    /// based on current system capabilities and constraints.
    ///
    /// ## Optimization Areas
    /// - **Threading**: Optimal thread pool sizes
    /// - **Memory**: Cache and buffer configurations
    /// - **Rendering**: Hardware acceleration settings
    /// - **Background tasks**: Processing priorities
    ///
    /// - Returns: Recommended performance configuration
    public func recommendedPerformanceConfiguration() -> PerformanceConfiguration {
        var config = PerformanceConfiguration()

        // Base configuration from memory profile
        switch memoryProfile {
        case .low:
            config.maxConcurrentOperations = 2
            config.enableBackgroundSyntaxHighlighting = false
            config.syntaxHighlightingBatchSize = 1_000
            config.enableIncrementalParsing = true

        case .medium:
            config.maxConcurrentOperations = 4
            config.enableBackgroundSyntaxHighlighting = true
            config.syntaxHighlightingBatchSize = 2_000
            config.enableIncrementalParsing = true

        case .high:
            config.maxConcurrentOperations = 6
            config.enableBackgroundSyntaxHighlighting = true
            config.syntaxHighlightingBatchSize = 5_000
            config.enableIncrementalParsing = true

        case .ultra:
            config.maxConcurrentOperations = 8
            config.enableBackgroundSyntaxHighlighting = true
            config.syntaxHighlightingBatchSize = 10_000
            config.enableIncrementalParsing = true
        }

        // Hardware acceleration
        config.enableHardwareAcceleration = supportsHardwareAcceleration

        // Architecture-specific optimizations
        if processorArchitecture.supportsAdvancedSIMD {
            config.enableSIMDOptimizations = true
        }

        // Platform-specific adjustments
        switch currentPlatform {
        case .macOS:
            // macOS can handle more aggressive optimizations
            config.enableAgressiveOptimizations = true

        case .iOS:
            // iOS needs to be more conservative for battery life
            config.enableAgressiveOptimizations = false
            config.respectBatteryState = true

        case .catalyst:
            // Catalyst can use desktop-class optimizations
            config.enableAgressiveOptimizations = true
        }

        // Display-specific optimizations
        if supportsSmoothScrolling {
            config.enableHighRefreshRateOptimizations = true
        }

        return config
    }

    /// Configuration for performance optimization
    public struct PerformanceConfiguration {
        /// Maximum number of concurrent background operations
        public var maxConcurrentOperations: Int = 4

        /// Whether to enable hardware acceleration
        public var enableHardwareAcceleration: Bool = false

        /// Whether to enable background syntax highlighting
        public var enableBackgroundSyntaxHighlighting: Bool = true

        /// Whether to enable incremental parsing
        public var enableIncrementalParsing: Bool = true

        /// Whether to enable SIMD optimizations
        public var enableSIMDOptimizations: Bool = false

        /// Whether to enable aggressive optimizations
        public var enableAgressiveOptimizations: Bool = false

        /// Whether to respect battery state on mobile devices
        public var respectBatteryState: Bool = true

        /// Whether to enable high refresh rate optimizations
        public var enableHighRefreshRateOptimizations: Bool = false

        /// Batch size for syntax highlighting operations
        public var syntaxHighlightingBatchSize: Int = 2_000

        /// Maximum memory usage for caches (in bytes)
        public var maxCacheMemoryUsage: Int = 50 * 1_024 * 1_024

        /// Creates default performance optimization settings
        public init() {}
    }

    // MARK: - Runtime Performance Monitoring

    /// Get current system performance metrics
    ///
    /// Provides real-time performance information for adaptive
    /// optimization and debugging purposes.
    ///
    /// - Returns: Current performance metrics
    public func currentPerformanceMetrics() -> PerformanceMetrics {
        let processInfo = ProcessInfo.processInfo

        return PerformanceMetrics(
            physicalMemory: processInfo.physicalMemory,
            activeProcessorCount: processInfo.activeProcessorCount,
            thermalState: getThermalState(),
            lowPowerMode: isLowPowerModeEnabled(),
            batteryLevel: getBatteryLevel()
        )
    }

    /// Current system performance metrics
    public struct PerformanceMetrics {
        /// Total physical memory in bytes
        public let physicalMemory: UInt64

        /// Number of active processor cores
        public let activeProcessorCount: Int

        /// Current thermal state of the device
        public let thermalState: ThermalState

        /// Whether low power mode is enabled
        public let lowPowerMode: Bool

        /// Current battery level (0.0-1.0), nil if unavailable
        public let batteryLevel: Float?

        /// Whether the system is under performance pressure
        public var isUnderPressure: Bool {
            thermalState != .nominal || lowPowerMode
        }
    }

    /// System thermal state
    public enum ThermalState {
        /// Normal operating temperature
        case nominal
        /// Slightly elevated temperature
        case fair
        /// High temperature, performance may be reduced
        case serious
        /// Critical temperature, significant performance reduction
        case critical
    }

    // MARK: - Private Helper Methods

    private func getThermalState() -> ThermalState {
        let state = ProcessInfo.processInfo.thermalState

        switch state {
        case .nominal:
            return .nominal

        case .fair:
            return .fair

        case .serious:
            return .serious

        case .critical:
            return .critical

        @unknown default:
            return .nominal
        }
    }

    private func isLowPowerModeEnabled() -> Bool {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        return ProcessInfo.processInfo.isLowPowerModeEnabled
        #else
        return false
        #endif
    }

    private func getBatteryLevel() -> Float? {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level >= 0 ? level : nil
        #else
        return nil
        #endif
    }
}
