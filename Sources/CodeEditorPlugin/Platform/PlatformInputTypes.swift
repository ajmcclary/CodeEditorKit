import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Platform Input Event

/// Platform-agnostic input event representation
public enum PlatformInputEvent: Sendable {
    case keyDown(key: String, modifiers: PlatformModifierFlags)
    case touch(touches: Set<TouchInfo>, phase: PlatformTouchPhase)
    case mouse(location: CGPoint, type: PlatformMouseEventType)
    case pencil(location: CGPoint, pressure: CGFloat, azimuth: CGFloat)
}

// MARK: - Platform Modifier Flags

/// Platform-agnostic modifier flags
public struct PlatformModifierFlags: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let command = Self(rawValue: 1 << 0)
    public static let option = Self(rawValue: 1 << 1)
    public static let control = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Create from NSEvent modifier flags
    public init(from flags: NSEvent.ModifierFlags) {
        var result = Self()
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.shift) { result.insert(.shift) }
        self = result
    }
    #endif
    
    #if canImport(UIKit)
    /// Create from UIKeyModifierFlags
    public init(from flags: UIKeyModifierFlags) {
        var result = Self()
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.alternate) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        if flags.contains(.shift) { result.insert(.shift) }
        self = result
    }
    #endif
}

// MARK: - Touch Info

/// Touch information wrapper
public struct TouchInfo: Hashable, Sendable {
    public let location: CGPoint
    public let previousLocation: CGPoint
    public let timestamp: TimeInterval
    public let identifier: Int
    
    public init(
        location: CGPoint,
        previousLocation: CGPoint,
        timestamp: TimeInterval,
        identifier: Int = 0
    ) {
        self.location = location
        self.previousLocation = previousLocation
        self.timestamp = timestamp
        self.identifier = identifier
    }
    
    #if canImport(UIKit)
    /// Create from UITouch
    @MainActor
    public init(from touch: UITouch, in view: UIView) {
        self.location = touch.location(in: view)
        self.previousLocation = touch.previousLocation(in: view)
        self.timestamp = touch.timestamp
        self.identifier = touch.hash
    }
    #endif
}

// MARK: - Platform Touch Phase

/// Platform-agnostic touch phase
public enum PlatformTouchPhase: Sendable {
    case began
    case moved
    case stationary
    case ended
    case cancelled
    
    #if canImport(UIKit)
    /// Create from UITouch phase
    public init(from phase: UITouch.Phase) {
        switch phase {
        case .began: self = .began
        case .moved: self = .moved
        case .stationary: self = .stationary
        case .ended: self = .ended
        case .cancelled: self = .cancelled
        case .regionEntered: self = .moved
        case .regionMoved: self = .moved
        case .regionExited: self = .ended
        @unknown default: self = .cancelled
        }
    }
    #endif
}

// MARK: - Platform Mouse Event Type

/// Platform-agnostic mouse event type
public enum PlatformMouseEventType: Sendable {
    case down
    case up
    case moved
    case dragged
    case entered
    case exited
    case rightClick
    case hover
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Create from NSEvent type
    public init?(from eventType: NSEvent.EventType) {
        switch eventType {
        case .leftMouseDown: self = .down
        case .leftMouseUp: self = .up
        case .mouseMoved: self = .moved
        case .leftMouseDragged: self = .dragged
        case .mouseEntered: self = .entered
        case .mouseExited: self = .exited
        case .rightMouseDown: self = .rightClick
        default: return nil
        }
    }
    #endif
}

// MARK: - Toolbar Item

/// Cross-platform toolbar item representation
public struct ToolbarItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let icon: String
    public let action: ToolbarAction
    public let keyboardShortcut: KeyboardShortcut?
    
    public init(
        title: String,
        icon: String,
        action: ToolbarAction,
        keyboardShortcut: KeyboardShortcut? = nil,
        id: String = UUID().uuidString
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.action = action
        self.keyboardShortcut = keyboardShortcut
    }
    
    public enum ToolbarAction: Sendable {
        case find
        case replace
        case showSymbols
        case format
        case toggleLineNumbers
        case toggleMinimap
        case custom(id: String)
    }
    
    public struct KeyboardShortcut: Sendable {
        public let key: String
        public let modifiers: PlatformModifierFlags
        
        public init(key: String, modifiers: PlatformModifierFlags) {
            self.key = key
            self.modifiers = modifiers
        }
    }
}
