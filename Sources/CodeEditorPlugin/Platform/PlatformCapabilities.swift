import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Centralized platform capability detection and feature availability system.
///
/// `PlatformCapabilities` provides runtime detection of platform features and capabilities,
/// allowing the code editor to adapt its behavior and UI based on the current environment.
/// This ensures optimal performance and user experience across macOS, iOS, and Mac Catalyst.
///
/// ## Overview
///
/// The capabilities system detects:
/// - Platform type and version
/// - Available system features (TextKit2, hardware acceleration, etc.)
/// - Device capabilities (touch, trackpad, pencil input)
/// - Performance characteristics and recommendations
/// - Feature availability for specific editor functionality
///
/// ## Usage
///
/// ```swift
/// let capabilities = PlatformCapabilities.shared
/// 
/// // Check platform
/// if capabilities.currentPlatform == .macOS {
///     // Enable macOS-specific features
/// }
/// 
/// // Check feature availability
/// if capabilities.supportsTextKit2 {
///     // Use TextKit2 features
/// }
/// 
/// // Get optimized configuration
/// let config = capabilities.recommendedConfiguration()
/// editor.configuration = config
/// 
/// // Check specific features
/// if capabilities.isFeatureAvailable(.hardwareAcceleration) {
///     // Enable GPU acceleration
/// }
/// ```
///
/// ## Platform Detection
///
/// The system accurately detects:
/// - macOS (native)
/// - iOS (iPhone and iPad)
/// - Mac Catalyst (iOS apps on Mac)
///
/// ## Performance Optimization
///
/// Recommendations are based on:
/// - Available memory
/// - CPU architecture (Intel vs Apple Silicon)
/// - Display capabilities (ProMotion, etc.)
/// - Platform-specific optimizations
///
/// - SeeAlso: ``EditorConfiguration``, ``EditorFeature``, ``FeatureAvailability``
@MainActor
public final class PlatformCapabilities {
    public static let shared = PlatformCapabilities()
    
    /// Cached platform value since it's determined at compile time
    private let _currentPlatform: Platform
    
    private init() {
        // Cache the platform since it's compile-time determined
        #if targetEnvironment(macCatalyst)
        self._currentPlatform = .catalyst
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        self._currentPlatform = .macOS
        #else
        self._currentPlatform = .iOS
        #endif
    }
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
    
    // MARK: - Platform Detection
    
    /// Platform type enumeration.
    ///
    /// Represents the current runtime platform with user-friendly names.
    public enum Platform {
        /// Native macOS application
        case macOS
        
        /// iOS application (iPhone or iPad)
        case iOS
        
        /// Mac Catalyst (iOS app running on Mac)
        case catalyst
        
        /// Human-readable platform name.
        ///
        /// Returns "macOS", "iOS", or "Mac Catalyst".
        public var name: String {
            switch self {
            case .macOS: return "macOS"
            case .iOS: return "iOS"
            case .catalyst: return "Mac Catalyst"
            }
        }
    }
    
    public var currentPlatform: Platform {
        _currentPlatform
    }
    
    public var systemVersion: String {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return ProcessInfo.processInfo.operatingSystemVersionString
        #elseif canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return "Unknown"
        #endif
    }
    
    public var systemVersionComponents: (major: Int, minor: Int, patch: Int) {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return (version.majorVersion, version.minorVersion, version.patchVersion)
    }
    
    // MARK: - TextKit Capabilities
    // Moved to PlatformCapabilities+TextKit.swift
    
    // MARK: - UI Capabilities
    // Moved to PlatformCapabilities+UI.swift
    
    // MARK: - Performance Capabilities
    // Moved to PlatformCapabilities+Performance.swift
    
    // MARK: - Rendering Capabilities
    // Moved to PlatformCapabilities+UI.swift and PlatformCapabilities+Performance.swift
    
    // MARK: - Input Capabilities
    // Moved to PlatformCapabilities+Input.swift
    
    // MARK: - Device Capabilities
    
    // Device capabilities moved to PlatformCapabilities+Performance.swift
    
    /// The current device type
    public var deviceType: DeviceType {
        DeviceType.current
    }
    
    /// Legacy string-based device type for backward compatibility
    @available(*, deprecated, message: "Use deviceType property which returns DeviceType enum instead")
    public var deviceTypeString: String {
        deviceType.rawValue
    }
    
    // hasNotch moved to PlatformCapabilities+UI.swift
    
    // MARK: - Feature Recommendations
    
    public func recommendedConfiguration() -> EditorConfiguration {
        // Start with device-specific configuration
        var config = deviceType.recommendedConfiguration()
        
        // Further adjust based on platform specifics
        switch currentPlatform {
        case .iOS:
            // iOS-specific adjustments already handled by deviceType
            break
            
        case .catalyst:
            // Catalyst apps run on Mac but may support touch
            config.display.fontSize = 14.0 // Between macOS and iOS
            config.layout.gutterWidth = 45.0 // Slightly wider for potential touch
            config.performance.useHardwareAcceleration = true
            
        case .macOS:
            // macOS-specific adjustments already handled by deviceType
            break
        }
        
        // Adjust based on performance
        let perf = performanceCapabilities
        if !perf.supportsHardwareAcceleration {
            config.performance.useHardwareAcceleration = false
            config.performance.maxSyntaxHighlightingLength = 50_000
        }
        
        // Adjust based on memory
        if ProcessInfo.processInfo.physicalMemory < 4 * 1_024 * 1_024 * 1_024 {
            config.performance.maxSyntaxHighlightingLength = 100_000
        }
        
        return config
    }
    
    // MARK: - Debug Information
    
    public var debugDescription: String {
        let perf = performanceCapabilities
        let textKit = textKitCapabilities
        
        return """
        Platform Capabilities:
        - Platform: \(currentPlatform.name)
        - System Version: \(systemVersion)
        - Device Type: \(deviceType.displayName)
        - Architecture: \(perf.processorArchitecture)
        - Memory Profile: \(perf.memoryProfile)
        - TextKit2 Support: \(textKit.supportsTextKit2) (Preferred: \(textKit.preferTextKit2))
        - Hardware Acceleration: \(perf.supportsHardwareAcceleration)
        - Recommended Cache Size: \(ByteCountFormatter.string(fromByteCount: Int64(perf.recommendedCacheSize), countStyle: .binary))
        - Max File Size: \(ByteCountFormatter.string(fromByteCount: Int64(perf.maxRecommendedFileSize), countStyle: .binary))
        """
    }
}

// MARK: - Convenience Extensions

extension CodeEditorView {
    /// Apply platform-optimized configuration
    public func applyPlatformOptimizations() {
        let capabilities = PlatformCapabilities.shared
        let config = capabilities.recommendedConfiguration()
        self.configuration = config
    }
}

// MARK: - Feature Availability Checking

extension PlatformCapabilities {
    /// Check if a specific feature is available
    public func isFeatureAvailable(_ feature: EditorFeature) -> Bool {
        switch feature {
        // Core features
        case .syntaxHighlighting, .codeCompletion, .lineNumbers:
            return true // Always available
        case .codeFolding:
            return true // Software feature
        case .minimap:
            return supportsMinimap
            
        // Editing features
        case .multipleCursors:
            return currentPlatform == .macOS

        case .smartBrackets, .autoIndent:
            return true // Always available
        case .findReplace:
            return true // Basic version available everywhere
        case .columnSelection:
            return currentPlatform == .macOS
            
        // Navigation features
        case .symbolNavigation, .breadcrumbs, .goToDefinition:
            return true // Software features with platform-specific UI
        case .quickOpen:
            return currentPlatform == .macOS || currentPlatform == .catalyst
            
        // Performance features
        case .hardwareAcceleration:
            return supportsHardwareAcceleration

        case .virtualScrolling, .incrementalParsing, .backgroundProcessing:
            return true // Software optimizations
            
        // Integration features
        case .languageServerProtocol:
            return currentPlatform == .macOS // Only available on macOS due to process restrictions
        case .pluginSystem:
            return true // Software feature
        case .externalTools:
            return currentPlatform == .macOS

        case .fileWatching:
            return true // Available via GCD/FSEvents
            
        // UI features
        case .splitView:
            return currentPlatform == .macOS || (currentPlatform == .iOS && isIPad)

        case .tabs:
            return currentPlatform == .macOS || currentPlatform == .catalyst

        case .sidebars:
            return currentPlatform == .macOS || (currentPlatform == .iOS && isIPad)

        case .floatingPanels:
            return currentPlatform == .macOS

        case .contextMenus:
            return supportsContextMenus

        case .toolbars:
            return true // Different implementations per platform
        case .touchBarSupport:
            return supportsTouchBar
            
        // Input features
        case .keyboardShortcuts:
            return supportsKeyboardShortcuts

        case .mouseSupport:
            return currentPlatform == .macOS || supportsTrackpad

        case .touchSupport:
            return currentPlatform == .iOS || currentPlatform == .catalyst

        case .gestureNavigation:
            return supportsGestureRecognizers

        case .pencilSupport:
            return supportsPencilInput
        }
    }
    
    /// Get feature availability level (full, partial, or unavailable)
    public func getFeatureAvailability(_ feature: EditorFeature) -> FeatureAvailability {
        // Check input features first
        if let availability = getInputFeatureAvailability(feature) {
            return availability
        }
        
        // Check UI features
        if let availability = getUIFeatureAvailability(feature) {
            return availability
        }
        
        // All other features are either fully available or not
        return isFeatureAvailable(feature) ? .full : .unavailable
    }
    
    /// Get availability for input-related features
    private func getInputFeatureAvailability(_ feature: EditorFeature) -> FeatureAvailability? {
        switch feature {
        case .keyboardShortcuts:
            if currentPlatform == .macOS || currentPlatform == .catalyst {
                return .full
            } else if currentPlatform == .iOS && isIPad {
                return .partial
            } else {
                return .unavailable
            }
            
        case .mouseSupport:
            if currentPlatform == .macOS {
                return .full
            } else if supportsTrackpad {
                return .partial
            } else {
                return .unavailable
            }
            
        case .touchSupport:
            if currentPlatform == .iOS {
                return .full
            } else if currentPlatform == .catalyst {
                return .partial
            } else {
                return .unavailable
            }
            
        default:
            return nil
        }
    }
    
    /// Get availability for UI-related features
    private func getUIFeatureAvailability(_ feature: EditorFeature) -> FeatureAvailability? {
        switch feature {
        case .findReplace, .symbolNavigation, .breadcrumbs, .goToDefinition, .toolbars:
            return currentPlatform == .macOS ? .full : .partial
            
        default:
            return nil
        }
    }
    
    private var isIPad: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    /// Feature availability level.
    ///
    /// Indicates whether a feature is fully supported, partially supported,
    /// or unavailable on the current platform.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let availability = capabilities.getFeatureAvailability(.keyboardShortcuts)
    /// switch availability {
    /// case .full:
    ///     // Enable all keyboard shortcuts
    /// case .partial:
    ///     // Enable basic shortcuts only
    /// case .unavailable:
    ///     // Hide keyboard shortcut UI
    /// }
    /// ```
    public enum FeatureAvailability {
        /// Feature is fully supported with all capabilities
        case full
        
        /// Feature is partially supported with limited capabilities
        case partial
        
        /// Feature is not available on this platform
        case unavailable
        
        /// Whether the feature is available at any level.
        ///
        /// Returns `true` for both full and partial availability.
        public var isAvailable: Bool {
            self != .unavailable
        }
        
        /// Whether the feature is fully available.
        ///
        /// Returns `true` only for full availability.
        public var isFullyAvailable: Bool {
            self == .full
        }
    }
    
    /// Editor features that may have platform-specific availability.
    ///
    /// Represents all features that can be queried for availability
    /// across different platforms and configurations.
    ///
    /// ## Feature Categories
    ///
    /// ### Core Features
    /// Essential editing capabilities available on all platforms:
    /// - `syntaxHighlighting`: Language-aware code coloring
    /// - `codeCompletion`: Intelligent code suggestions
    /// - `lineNumbers`: Line number display in gutter
    /// - `codeFolding`: Collapse/expand code blocks
    /// - `minimap`: Zoomed-out code overview
    ///
    /// ### Editing Features
    /// Advanced text manipulation capabilities:
    /// - `multipleCursors`: Edit multiple locations simultaneously
    /// - `smartBrackets`: Auto-close brackets and quotes
    /// - `autoIndent`: Intelligent indentation
    /// - `findReplace`: Search and replace functionality
    /// - `columnSelection`: Rectangle/column selection mode
    ///
    /// ### Navigation Features
    /// Code navigation and exploration:
    /// - `symbolNavigation`: Jump to symbols/functions
    /// - `breadcrumbs`: Navigation path display
    /// - `goToDefinition`: Navigate to symbol definitions
    /// - `quickOpen`: Fast file/symbol search
    ///
    /// ### Performance Features
    /// Optimization and acceleration:
    /// - `hardwareAcceleration`: GPU-accelerated rendering
    /// - `virtualScrolling`: Efficient large file handling
    /// - `incrementalParsing`: Progressive syntax analysis
    /// - `backgroundProcessing`: Async processing support
    ///
    /// ### Integration Features
    /// External tool and service integration:
    /// - `languageServerProtocol`: LSP support
    /// - `pluginSystem`: Extension/plugin support
    /// - `externalTools`: External tool integration
    /// - `fileWatching`: File system monitoring
    ///
    /// ### UI Features
    /// User interface capabilities:
    /// - `splitView`: Multiple editor panes
    /// - `tabs`: Tabbed interface
    /// - `sidebars`: Side panel support
    /// - `floatingPanels`: Detachable panels
    /// - `contextMenus`: Right-click menus
    /// - `toolbars`: Customizable toolbars
    /// - `touchBarSupport`: MacBook Touch Bar
    ///
    /// ### Input Features
    /// Input method support:
    /// - `keyboardShortcuts`: Keyboard commands
    /// - `mouseSupport`: Mouse interactions
    /// - `touchSupport`: Touch gestures
    /// - `gestureNavigation`: Swipe/pinch gestures
    /// - `pencilSupport`: Apple Pencil support
    public enum EditorFeature {
        // Core features
        case syntaxHighlighting
        case codeCompletion
        case lineNumbers
        case codeFolding
        case minimap
        
        // Editing features
        case multipleCursors
        case smartBrackets
        case autoIndent
        case findReplace
        case columnSelection
        
        // Navigation features
        case symbolNavigation
        case breadcrumbs
        case goToDefinition
        case quickOpen
        
        // Performance features
        case hardwareAcceleration
        case virtualScrolling
        case incrementalParsing
        case backgroundProcessing
        
        // Integration features
        case languageServerProtocol
        case pluginSystem
        case externalTools
        case fileWatching
        
        // UI features
        case splitView
        case tabs
        case sidebars
        case floatingPanels
        case contextMenus
        case toolbars
        case touchBarSupport
        
        // Input features
        case keyboardShortcuts
        case mouseSupport
        case touchSupport
        case gestureNavigation
        case pencilSupport
    }
}
