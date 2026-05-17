import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Centralized platform capability detection and feature availability system.
///
/// `PlatformCapabilities` provides runtime detection of platform features and capabilities,
/// allowing the code editor to adapt its behavior and UI based on the current environment.
/// This ensures optimal performance and user experience across native macOS and iOS / iPadOS.
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
/// let capabilities = PlatformCapabilities()
/// 
/// // Check platform
/// if capabilities.currentPlatform == .macOS {
///     // Enable macOS-specific features
/// }
/// 
/// // Check feature availability
/// if capabilities.supportsRequiredTextKit2Surface {
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
    /// Cached platform value since it's determined at compile time
    private let _currentPlatform: Platform

    /// Public initializer for dependency injection
    public init() {
        // Cache the platform since it's compile-time determined
        #if canImport(AppKit)
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

        /// iOS / iPadOS application
        case iOS

        /// Human-readable platform name. Returns "macOS" or "iOS".
        public var name: String {
            switch self {
            case .macOS: return "macOS"
            case .iOS: return "iOS"
            }
        }
    }

    /// The current runtime platform (macOS or iOS / iPadOS).
    public var currentPlatform: Platform {
        _currentPlatform
    }

    /// The current operating system version as a string
    public var systemVersion: String {
        #if canImport(AppKit)
        return ProcessInfo.processInfo.operatingSystemVersionString
        #elseif canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return "Unknown"
        #endif
    }

    /// The current operating system version broken down into major, minor, and patch components
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

    // hasNotch moved to PlatformCapabilities+UI.swift

    // MARK: - Feature Recommendations

    /// Returns a runtime-optimized configuration based on current device capabilities.
    ///
    /// This method analyzes the current device's actual capabilities (CPU cores, memory,
    /// display characteristics) to provide an optimized configuration. It differs from
    /// `EditorConfiguration.platformOptimized` which is a compile-time preset.
    ///
    /// ## Differences from platformOptimized
    ///
    /// - **platformOptimized**: Returns a compile-time preset based on the build target
    ///   (iOS or macOS). Static configuration that doesn't adapt to device.
    /// - **recommendedConfiguration()**: Returns a runtime-optimized configuration based
    ///   on actual device capabilities. Adapts to different hardware within same platform.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Compile-time preset (same for all iOS devices)
    /// let preset = EditorConfiguration.platformOptimized
    /// 
    /// // Runtime-optimized (adapts to iPhone SE vs iPad Pro)
    /// let optimized = PlatformCapabilities().recommendedConfiguration()
    /// ```
    ///
    /// - Returns: An EditorConfiguration optimized for the current device's capabilities
    /// - Note: Must be called on the main actor as it accesses UI-related capabilities
    public func recommendedConfiguration() -> EditorConfiguration {
        // Delegate to the new PlatformConfigurations system
        PlatformConfigurations.recommended()
    }

    // MARK: - Debug Information

    /// Comprehensive debug information about platform capabilities
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
        - TextKit2 Required Surface: \(textKit.supportsRequiredTextKit2Surface)
        - Hardware Acceleration: \(perf.supportsHardwareAcceleration)
        - Recommended Cache Size: \(ByteCountFormatter.string(fromByteCount: Int64(perf.recommendedCacheSize), countStyle: .binary))
        - Max File Size: \(ByteCountFormatter.string(fromByteCount: Int64(perf.maxRecommendedFileSize), countStyle: .binary))
        """
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

        case .smartBrackets, .isAutoIndentEnabled:
            return true // Always available

        case .findReplace:
            return true // Basic version available everywhere

        case .columnSelection:
            return currentPlatform == .macOS

        // Navigation features
        case .symbolNavigation, .breadcrumbs:
            return true // Software features with platform-specific UI

        case .goToDefinition:
            // Check platform-specific availability
            if currentPlatform == .macOS {
                return true
            } else if isIPad {
                return true // Partial support
            } else {
                return false // Unavailable on iPhone
            }

        case .quickOpen:
            return currentPlatform == .macOS

        // Performance features
        case .hardwareAcceleration:
            return supportsHardwareAcceleration

        case .virtualScrolling, .incrementalParsing, .backgroundProcessing:
            return true // Software optimizations

        // Integration features
        case .languageServerProtocol:
            // For backward compatibility, this refers to local LSP support
            // Use .localLSP or .remoteLSP for specific capabilities
            return currentPlatform == .macOS

        case .localLSP:
            return currentPlatform == .macOS // Process API required

        case .remoteLSP:
            return true // WebSocket available on all platforms

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
            return currentPlatform == .macOS

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
            // Check for partial support on iPad
            if currentPlatform == .iOS && isIPad {
                return true // iPad has partial keyboard shortcut support
            }
            return supportsKeyboardShortcuts

        case .mouseSupport:
            return currentPlatform == .macOS || supportsTrackpad

        case .touchSupport:
            return currentPlatform == .iOS

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
            if currentPlatform == .macOS {
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
            } else if false {
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
        case .findReplace, .symbolNavigation, .breadcrumbs, .toolbars:
            return currentPlatform == .macOS ? .full : .partial

        case .goToDefinition:
            if currentPlatform == .macOS {
                return .full
            } else if isIPad {
                return .partial
            } else {
                return .unavailable // iPhone doesn't support go to definition
            }

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
    /// - `isAutoIndentEnabled`: Intelligent indentation
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
        /// Syntax highlighting and colorization
        case syntaxHighlighting
        /// Code completion and IntelliSense
        case codeCompletion
        /// Line number display in gutter
        case lineNumbers
        /// Code folding and outlining
        case codeFolding
        /// Document minimap overview
        case minimap

        // Editing features
        /// Multiple cursor editing
        case multipleCursors
        /// Automatic bracket matching and insertion
        case smartBrackets
        /// Automatic code indentation
        case isAutoIndentEnabled
        /// Find and replace functionality
        case findReplace
        /// Column/block selection mode
        case columnSelection

        // Navigation features
        /// Symbol navigation and outline
        case symbolNavigation
        /// File path breadcrumbs
        case breadcrumbs
        /// Go to definition/declaration
        case goToDefinition
        /// Quick file/symbol opening
        case quickOpen

        // Performance features
        /// Hardware-accelerated rendering
        case hardwareAcceleration
        /// Virtual scrolling for large files
        case virtualScrolling
        /// Incremental parsing and analysis
        case incrementalParsing
        /// Background processing support
        case backgroundProcessing

        // Integration features
        /// Language Server Protocol support
        case languageServerProtocol
        /// Local language server integration
        case localLSP
        /// Remote language server support
        case remoteLSP
        /// Plugin system architecture
        case pluginSystem
        /// External tool integration
        case externalTools
        /// File system watching
        case fileWatching

        // UI features
        /// Split view/pane support
        case splitView
        /// Tab interface for multiple files
        case tabs
        /// Collapsible sidebars
        case sidebars
        /// Floating panel windows
        case floatingPanels
        /// Context menu support
        case contextMenus
        /// Toolbar interface
        case toolbars
        /// macOS Touch Bar support
        case touchBarSupport

        // Input features
        /// Keyboard shortcut support
        case keyboardShortcuts
        /// Mouse interaction support
        case mouseSupport
        /// Touch gesture support
        case touchSupport
        /// Gesture-based navigation
        case gestureNavigation
        /// Apple Pencil support
        case pencilSupport
    }
}
