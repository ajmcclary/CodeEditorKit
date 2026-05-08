import Foundation
#if canImport(UIKit)
import UIKit
#if canImport(GameController)
import GameController
#endif
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Input Capabilities

extension PlatformCapabilities {
    /// Input method support information
    public struct InputCapabilities {
        /// Whether keyboard shortcuts are supported and functional
        public let supportsKeyboardShortcuts: Bool

        /// Whether Apple Pencil input is supported (iPad only)
        public let supportsPencilInput: Bool

        /// Whether trackpad gestures are supported
        public let supportsTrackpad: Bool

        /// Whether haptic feedback is available
        public let supportsHapticFeedback: Bool

        /// Whether gesture recognizers can be used
        public let supportsGestureRecognizers: Bool

        /// Set of preferred input methods for the current platform
        public let preferredInputMethods: Set<InputMethod>
    }

    /// Available input methods
    public enum InputMethod: CaseIterable {
        case keyboard
        case mouse
        case trackpad
        case touch
        case pencil
        case gameController
    }

    /// Get comprehensive input capabilities
    ///
    /// This computed property provides a complete overview of input support
    /// on the current platform, enabling adaptive input handling.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let input = capabilities.inputCapabilities
    /// 
    /// // Configure input based on capabilities
    /// if input.supportsKeyboardShortcuts {
    ///     setupKeyboardShortcuts()
    /// }
    /// 
    /// if input.supportsPencilInput {
    ///     enablePencilGestures()
    /// }
    /// 
    /// // Use preferred input methods for UI
    /// for method in input.preferredInputMethods {
    ///     configureInputMethod(method)
    /// }
    /// ```
    ///
    /// - Returns: Comprehensive input capability information
    public var inputCapabilities: InputCapabilities {
        var preferred: Set<InputMethod> = []

        // Determine preferred input methods based on platform
        switch currentPlatform {
        case .macOS:
            preferred = [.keyboard, .mouse, .trackpad]

        case .iOS:
            preferred = [.touch]
            if supportsPencilInput {
                preferred.insert(.pencil)
            }
            if supportsTrackpad {
                preferred.insert(.trackpad)
            }
        }

        return InputCapabilities(
            supportsKeyboardShortcuts: supportsKeyboardShortcuts,
            supportsPencilInput: supportsPencilInput,
            supportsTrackpad: supportsTrackpad,
            supportsHapticFeedback: supportsHapticFeedback,
            supportsGestureRecognizers: supportsGestureRecognizers,
            preferredInputMethods: preferred
        )
    }

    /// Whether keyboard shortcuts are supported
    ///
    /// Keyboard shortcuts provide efficient navigation and editing for
    /// users with physical keyboards.
    ///
    /// ## Platform Support
    /// - **macOS**: Full support with extensive shortcut system
    /// - **iOS**: Limited support, mainly on iPad with external keyboard
    /// - **Catalyst**: Full support matching macOS behavior
    ///
    /// - Returns: True if keyboard shortcuts are available
    public var supportsKeyboardShortcuts: Bool {
        currentPlatform == .macOS
    }

    /// Whether Apple Pencil input is supported
    ///
    /// Apple Pencil provides precise input for drawing, annotation,
    /// and navigation on supported devices.
    ///
    /// ## Device Support
    /// - **iPad**: All models with Apple Pencil compatibility
    /// - **iPhone**: Not supported
    /// - **Mac**: Not applicable
    ///
    /// - Returns: True if Apple Pencil is supported
    public var supportsPencilInput: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }

    /// Whether trackpad/touchpad input is supported
    ///
    /// Trackpad support enables cursor-based interaction and
    /// precision pointing on touch devices.
    ///
    /// ## Platform Support
    /// - **macOS**: Built-in trackpad and external trackpads
    /// - **iPadOS**: Magic Trackpad and keyboard cases (13.4+)
    /// - **iOS**: Not supported on iPhone
    ///
    /// - Returns: True if trackpad input is available
    public var supportsTrackpad: Bool {
        #if canImport(AppKit)
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

    /// Whether haptic feedback is supported
    ///
    /// Haptic feedback provides tactile response to user interactions,
    /// enhancing the editing experience on supported devices.
    ///
    /// ## Device Support
    /// - **iPhone**: All models with Taptic Engine
    /// - **iPad**: Not supported (no Taptic Engine)
    /// - **Mac**: Not applicable
    ///
    /// - Returns: True if haptic feedback is available
    public var supportsHapticFeedback: Bool {
        #if canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .phone
        #else
        return false
        #endif
    }

    /// Whether gesture recognizers are supported
    ///
    /// Gesture recognizers enable touch-based navigation and
    /// interaction patterns on touch-capable devices.
    ///
    /// ## Platform Support
    /// - **iOS**: Full gesture support
    /// - **Catalyst**: Touch gesture support with mouse fallbacks
    /// - **macOS**: Not applicable (uses mouse events)
    ///
    /// - Returns: True if gesture recognizers are available
    public var supportsGestureRecognizers: Bool {
        currentPlatform == .iOS
    }

    /// Check for external keyboard connectivity
    ///
    /// Detects whether an external keyboard is connected to the device,
    /// which affects UI layout and available shortcuts.
    ///
    /// ## Detection Method
    /// - **iOS**: Checks for hardware keyboard presence
    /// - **macOS**: Always returns true (built-in keyboard)
    /// - **Catalyst**: Always returns true (desktop environment)
    ///
    /// - Returns: True if external keyboard is connected
    public var hasExternalKeyboard: Bool {
        #if canImport(UIKit)
        // Check for external keyboard on iOS
        return UIDevice.current.userInterfaceIdiom == .pad &&
               isExternalKeyboardConnected()
        #else
        // Always true on macOS and Catalyst
        return true
        #endif
    }

    /// Check for pointing device connectivity
    ///
    /// Detects whether a pointing device (mouse, trackpad) is available,
    /// which affects hover states and interaction patterns.
    ///
    /// ## Detection Method
    /// - **iOS**: Checks for trackpad/mouse connectivity
    /// - **macOS**: Always returns true (built-in trackpad/mouse)
    /// - **Catalyst**: Always returns true (desktop environment)
    ///
    /// - Returns: True if pointing device is connected
    public var hasPointingDevice: Bool {
        #if canImport(UIKit)
        return supportsTrackpad && isPointingDeviceConnected()
        #else
        return true
        #endif
    }

    /// Get recommended input configuration for optimal UX
    ///
    /// This method provides platform-specific recommendations for input
    /// handling configuration based on available input methods.
    ///
    /// ## Configuration Areas
    /// - **Gesture sensitivity**: Touch gesture thresholds
    /// - **Shortcut availability**: Which shortcuts to enable
    /// - **Hover behavior**: Mouse/trackpad hover handling
    /// - **Touch targets**: Minimum touch target sizes
    ///
    /// - Returns: Recommended input configuration
    public func recommendedInputConfiguration() -> InputConfiguration {
        var config = InputConfiguration()

        // Platform-specific base configuration
        switch currentPlatform {
        case .macOS:
            config.enableKeyboardShortcuts = true
            config.enableHoverEffects = true
            config.minimumTouchTargetSize = 24.0
            config.gestureThreshold = 10.0

        case .iOS:
            config.enableKeyboardShortcuts = hasExternalKeyboard
            config.enableHoverEffects = hasPointingDevice
            config.minimumTouchTargetSize = 44.0 // iOS HIG
            config.gestureThreshold = 15.0

            if supportsPencilInput {
                config.enablePencilGestures = true
                config.pencilSensitivity = 0.8
            }
        }

        // Adjust for device capabilities
        if supportsHapticFeedback {
            config.enableHapticFeedback = true
            config.hapticIntensity = 0.7
        }

        return config
    }

    /// Configuration for input handling and behavior
    public struct InputConfiguration {
        /// Whether to enable keyboard shortcuts
        public var enableKeyboardShortcuts: Bool = false

        /// Whether to enable hover effects
        public var enableHoverEffects: Bool = false

        /// Whether to enable haptic feedback
        public var enableHapticFeedback: Bool = false

        /// Whether to enable Apple Pencil gestures
        public var enablePencilGestures: Bool = false

        /// Minimum touch target size in points
        public var minimumTouchTargetSize: CGFloat = 44.0

        /// Gesture recognition threshold in points
        public var gestureThreshold: CGFloat = 15.0

        /// Haptic feedback intensity (0.0 - 1.0)
        public var hapticIntensity: CGFloat = 0.7

        /// Apple Pencil pressure sensitivity (0.0 - 1.0)
        public var pencilSensitivity: CGFloat = 1.0

        /// Creates default input configuration for the current platform
        public init() {}
    }

    // MARK: - Private Helper Methods

    /// Check if external keyboard is connected (iOS only)
    private func isExternalKeyboardConnected() -> Bool {
        #if canImport(UIKit)
        // Use GCKeyboard to detect hardware keyboards (iOS 14+)
        #if canImport(GameController)
        if #available(iOS 14.0, *) {
            return GCKeyboard.coalesced != nil
        }
        #endif

        // Fallback: Check for command key availability (hardware keyboards support Command key)
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            return window.canBecomeFirstResponder && UIDevice.current.userInterfaceIdiom == .pad
        }

        return false
        #else
        return false
        #endif
    }

    /// Check if pointing device is connected (iOS only)
    private func isPointingDeviceConnected() -> Bool {
        #if canImport(UIKit)
        // Check for trackpad/mouse support on iPadOS 13.4+
        if #available(iOS 13.4, *) {
            // Check if any scene supports indirect input (trackpad/mouse)
            let windowScenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }

            for scene in windowScenes where scene.traitCollection.userInterfaceIdiom == .pad {
                // Check if we have any windows on iPadOS (simplified check)
                if !scene.windows.isEmpty {
                    return true
                }
            }

            return false
        }

        // For older iOS versions, assume no pointing device
        return false
        #else
        return false
        #endif
    }
}
