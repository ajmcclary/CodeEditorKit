import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

/// Centralized platform capability detection and feature availability system
@MainActor
public final class PlatformCapabilities {
    public static let shared = PlatformCapabilities()
    
    private init() {}
    
    deinit {
        // Cleanup is handled automatically by ARC
    }
    
    // MARK: - Platform Detection
    
    public enum Platform {
        case macOS
        case iOS
        case catalyst
        
        public var name: String {
            switch self {
            case .macOS: return "macOS"
            case .iOS: return "iOS"
            case .catalyst: return "Mac Catalyst"
            }
        }
    }
    
    public var currentPlatform: Platform {
        #if targetEnvironment(macCatalyst)
        return .catalyst
        #elseif canImport(AppKit)
        return .macOS
        #else
        return .iOS
        #endif
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
    
    public var supportsTextKit2: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // TextKit2 is stable on macOS 13.0+
        return systemVersionComponents.major >= 13
        #elseif canImport(UIKit)
        // TextKit2 is available on iOS 16.0+
        return systemVersionComponents.major >= 16
        #else
        return false
        #endif
    }
    
    public var preferTextKit2: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Prefer TextKit2 on macOS 14.0+ for better stability
        return systemVersionComponents.major >= 14
        #elseif canImport(UIKit)
        // Always prefer TextKit2 on iOS when available
        return supportsTextKit2
        #else
        return false
        #endif
    }
    
    public var supportsTextLayoutFragments: Bool {
        supportsTextKit2
    }
    
    public var supportsRenderingAttributes: Bool {
        supportsTextKit2
    }
    
    // MARK: - UI Capabilities
    
    public var supportsMinimap: Bool {
        // Currently only implemented for iOS
        currentPlatform == .iOS || currentPlatform == .catalyst
    }
    
    public var supportsMultipleWindows: Bool {
        currentPlatform == .macOS || currentPlatform == .catalyst
    }
    
    public var supportsTouchBar: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return true
        #else
        return false
        #endif
    }
    
    public var supportsHapticFeedback: Bool {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }
    
    public var supportsGestureRecognizers: Bool {
        currentPlatform == .iOS || currentPlatform == .catalyst
    }
    
    public var supportsContextMenus: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return true
        #elseif canImport(UIKit)
        // iOS 13.0+ supports context menus
        return systemVersionComponents.major >= 13
        #else
        return false
        #endif
    }
    
    // MARK: - Performance Capabilities
    
    public var supportsHardwareAcceleration: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // Metal is available on all supported macOS versions
        return true
        #elseif canImport(UIKit)
        // Check for Metal support on iOS
        return UIDevice.current.userInterfaceIdiom != .tv
        #else
        return false
        #endif
    }
    
    public var supportsBackgroundProcessing: Bool {
        // All platforms support GCD/async-await
        true
    }
    
    public var recommendedCacheSize: Int {
        let memorySize = ProcessInfo.processInfo.physicalMemory
        let baseSize = 50 * 1_024 * 1_024 // 50MB base
        
        if memorySize > 16 * 1_024 * 1_024 * 1_024 { // > 16GB
            return baseSize * 4
        } else if memorySize > 8 * 1_024 * 1_024 * 1_024 { // > 8GB
            return baseSize * 2
        } else {
            return baseSize
        }
    }
    
    public var maxRecommendedFileSize: Int {
        let memorySize = ProcessInfo.processInfo.physicalMemory
        
        if memorySize > 16 * 1_024 * 1_024 * 1_024 { // > 16GB
            return 100 * 1_024 * 1_024 // 100MB
        } else if memorySize > 8 * 1_024 * 1_024 * 1_024 { // > 8GB
            return 50 * 1_024 * 1_024 // 50MB
        } else {
            return 20 * 1_024 * 1_024 // 20MB
        }
    }
    
    // MARK: - Rendering Capabilities
    
    public var supportsCADisplayLink: Bool {
        // Available on all iOS versions, macOS 14.0+
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        return true
        #elseif canImport(AppKit)
        return systemVersionComponents.major >= 14
        #else
        return false
        #endif
    }
    
    public var supportsVibrantMaterials: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return true
        #elseif canImport(UIKit)
        // iOS 13.0+ supports materials
        return systemVersionComponents.major >= 13
        #else
        return false
        #endif
    }
    
    public var supportsSmoothScrolling: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // ProMotion displays and smooth scrolling
        return true
        #elseif canImport(UIKit)
        // iOS devices with ProMotion
        return UIScreen.main.maximumFramesPerSecond > 60
        #else
        return false
        #endif
    }
    
    // MARK: - Input Capabilities
    
    public var supportsKeyboardShortcuts: Bool {
        currentPlatform == .macOS || currentPlatform == .catalyst
    }
    
    public var supportsPencilInput: Bool {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    public var supportsTrackpad: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return true
        #elseif canImport(UIKit)
        // iPadOS 13.4+ supports trackpad
        return UIDevice.current.userInterfaceIdiom == .pad && 
               systemVersionComponents.major >= 13 && 
               systemVersionComponents.minor >= 4
        #else
        return false
        #endif
    }
    
    // MARK: - Device Capabilities
    
    public var isAppleSilicon: Bool {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst) && arch(arm64)
        return true
        #else
        return false
        #endif
    }
    
    public var deviceType: String {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return "Mac"
        #elseif canImport(UIKit)
        switch UIDevice.current.userInterfaceIdiom {
        case .phone: return "iPhone"
        case .pad: return "iPad"
        case .tv: return "Apple TV"
        case .mac: return "Mac"
        default: return "Unknown"
        }
        #else
        return "Unknown"
        #endif
    }
    
    public var hasNotch: Bool {
        #if canImport(UIKit) && !targetEnvironment(macCatalyst)
        if #available(iOS 13.0, *) {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows.first else { return false }
            return window.safeAreaInsets.top > 20
        } else {
            guard let window = UIApplication.shared.keyWindow else { return false }
            return window.safeAreaInsets.top > 20
        }
        #else
        return false
        #endif
    }
    
    // MARK: - Feature Recommendations
    
    public func recommendedConfiguration() -> EditorConfiguration {
        var config = EditorConfiguration.default
        
        // Adjust based on platform
        switch currentPlatform {
        case .iOS:
            config.display.fontSize = 16.0 // Larger for touch
            config.layout.gutterWidth = 50.0 // Wider for touch targets
            // Touch-specific behaviors would be configured here
            
        case .catalyst:
            // Catalyst apps run on Mac but may support touch
            config.display.fontSize = 14.0 // Between macOS and iOS
            config.layout.gutterWidth = 45.0 // Slightly wider for potential touch
            config.performance.useHardwareAcceleration = true
            
        case .macOS:
            // Default configuration is already optimized for macOS
            break
        }
        
        // Adjust based on performance
        if !supportsHardwareAcceleration {
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
        """
        Platform Capabilities:
        - Platform: \(currentPlatform.name)
        - System Version: \(systemVersion)
        - Device Type: \(deviceType)
        - Apple Silicon: \(isAppleSilicon)
        - TextKit2 Support: \(supportsTextKit2) (Preferred: \(preferTextKit2))
        - Hardware Acceleration: \(supportsHardwareAcceleration)
        - Recommended Cache Size: \(ByteCountFormatter.string(fromByteCount: Int64(recommendedCacheSize), countStyle: .binary))
        - Max File Size: \(ByteCountFormatter.string(fromByteCount: Int64(maxRecommendedFileSize), countStyle: .binary))
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
        case .languageServerProtocol, .pluginSystem:
            return true // Software features
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
        switch feature {
        // Features with partial support on some platforms
        case .findReplace:
            return currentPlatform == .macOS ? .full : .partial

        case .symbolNavigation, .breadcrumbs, .goToDefinition:
            return currentPlatform == .macOS ? .full : .partial

        case .toolbars:
            return currentPlatform == .macOS ? .full : .partial

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
            } else if currentPlatform == .catalyst {
                return .partial
            } else {
                return .unavailable
            }
            
        // Features that are either fully available or not
        default:
            return isFeatureAvailable(feature) ? .full : .unavailable
        }
    }
    
    private var isIPad: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    public enum FeatureAvailability {
        case full
        case partial
        case unavailable
        
        public var isAvailable: Bool {
            self != .unavailable
        }
        
        public var isFullyAvailable: Bool {
            self == .full
        }
    }
    
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
