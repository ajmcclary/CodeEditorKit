import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Type-safe representation of device types across Apple platforms
public enum DeviceType: String, CaseIterable, Sendable {
    case iPhone = "iPhone"
    case iPad = "iPad"
    case mac = "Mac"
    case appleTV = "Apple TV"
    case carPlay = "CarPlay"
    case appleWatch = "Apple Watch"
    case visionPro = "Vision Pro"
    case unspecified = "Unspecified"
    case unknown = "Unknown"
    
    /// Initialize DeviceType from the current device
    @MainActor
    public static var current: Self {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return .mac
        #elseif canImport(UIKit)
        return Self(from: UIDevice.current.userInterfaceIdiom)
        #else
        return .unknown
        #endif
    }
    
    #if canImport(UIKit)
    /// Initialize DeviceType from UIUserInterfaceIdiom
    public init(from idiom: UIUserInterfaceIdiom) {
        switch idiom {
        case .phone:
            self = .iPhone
            
        case .pad:
            self = .iPad
            
        case .tv:
            self = .appleTV
            
        case .carPlay:
            self = .carPlay
            
        case .mac:
            self = .mac
            
        case .unspecified:
            self = .unspecified
        
        #if swift(>=5.9)

        case .vision:
            self = .visionPro
        #endif
            
        @unknown default:
            self = .unknown
        }
    }
    #endif
    
    /// User-friendly display name
    public var displayName: String {
        rawValue
    }
    
    /// Check if device has a notch
    @MainActor
    public var hasNotch: Bool {
        switch self {
        case .iPhone:
            #if canImport(UIKit) && !targetEnvironment(macCatalyst)
            guard let window = UIApplication.shared.windows.first else { return false }
            return window.safeAreaInsets.bottom > 0
            #else
            return false
            #endif
            
        default:
            return false
        }
    }
    
    /// Check if device supports hover interactions
    @MainActor
    public var supportsHover: Bool {
        switch self {
        case .mac, .visionPro:
            return true
            
        case .iPad:
            #if canImport(UIKit)
            if #available(iOS 13.4, *) {
                return UIDevice.current.userInterfaceIdiom == .pad
            }
            #endif
            return false
            
        default:
            return false
        }
    }
    
    /// Check if device typically uses touch input
    public var isTouchPrimary: Bool {
        switch self {
        case .iPhone, .iPad, .appleWatch, .carPlay:
            return true
            
        case .mac:
            // Mac might have touch bar or be using Mac Catalyst
            #if targetEnvironment(macCatalyst)
            return true
            #else
            return false
            #endif
            
        case .visionPro:
            return true // Vision Pro uses gesture/touch-like interactions
            
        default:
            return false
        }
    }
    
    /// Check if device has limited screen space
    public var hasLimitedScreenSpace: Bool {
        switch self {
        case .iPhone, .appleWatch, .carPlay:
            return true
            
        default:
            return false
        }
    }
    
    /// Recommended editor configuration based on device type
    public func recommendedConfiguration() -> EditorConfiguration {
        switch self {
        case .iPhone, .appleWatch:
            // Limited screen space - use minimal configuration
            return .minimal
            
        case .iPad:
            // Medium screen space with touch
            var config = EditorConfiguration.default
            config.display.showLineNumbers = true
            config.display.showMinimap = false // Save horizontal space
            config.display.fontSize = 14
            return config
            
        case .mac:
            // Full desktop experience
            return .default
            
        case .appleTV:
            // TV interface - larger fonts, simplified UI
            var config = EditorConfiguration.presentation
            config.display.fontSize = 24
            config.display.showLineNumbers = false
            return config
            
        case .carPlay:
            // Very limited, mostly read-only
            return .readOnly
            
        case .visionPro:
            // Spatial computing - optimize for comfort
            var config = EditorConfiguration.default
            config.display.fontSize = 16
            config.layout.lineHeightMultiple = 1.3
            return config
            
        default:
            return .default
        }
    }
}

// MARK: - Comparable

extension DeviceType: Comparable {
    public static func < (lhs: DeviceType, rhs: DeviceType) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Codable

extension DeviceType: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .unknown
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
