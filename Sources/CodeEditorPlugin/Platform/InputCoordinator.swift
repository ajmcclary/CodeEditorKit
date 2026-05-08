import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Coordinator responsible for handling cross-platform input events
///
/// `InputCoordinator` provides unified input handling across different platforms,
/// translating platform-specific events (keyboard, mouse, touch, pencil) into
/// common actions that the code editor can understand.
///
/// ## Overview
///
/// This coordinator abstracts the differences between:
/// - macOS: NSEvent-based input (keyboard, mouse, trackpad)
/// - iOS: UIEvent-based input (touch, gestures, Apple Pencil)
/// - Mac Catalyst: Hybrid input supporting both paradigms
///
/// ## Features
///
/// - **Keyboard Input**: Key combinations, shortcuts, text input
/// - **Mouse Input**: Clicks, drags, hover, scroll events
/// - **Touch Input**: Taps, gestures, multi-touch
/// - **Pencil Input**: Apple Pencil with pressure and tilt
/// - **Gesture Recognition**: Platform-appropriate gestures
///
/// ## Example Usage
///
/// ```swift
/// let coordinator = InputCoordinator()
/// 
/// // Handle a platform input event
/// let handled = coordinator.handleInput(event, in: textView)
/// 
/// // Configure gestures for a view
/// coordinator.configureGestures(for: textView)
/// ```
///
/// - SeeAlso: ``CrossPlatformCoordinator`` for overall coordination
/// - SeeAlso: ``PlatformInputEvent`` for input event types
@MainActor
public final class InputCoordinator: ObservableObject {
    private let logger = CrossPlatformLogger.logger(subsystem: "CodeEditorPlugin", category: "InputCoordinator")
    private let capabilities: PlatformCapabilities

    // MARK: - Initialization

    /// Creates a new InputCoordinator instance
    /// - Parameter capabilities: Platform capabilities provider (defaults to shared instance)
    public init(capabilities: PlatformCapabilities? = nil) {
        self.capabilities = capabilities ?? CodeEditorDependencies.makePlatformCapabilities()
        logger.debug("InputCoordinator initialized")
    }

    // MARK: - Public Methods

    /// Handle platform-specific input events
    ///
    /// This method processes input events from any platform and translates them
    /// into appropriate editor actions.
    ///
    /// - Parameters:
    ///   - event: The platform input event to handle
    ///   - textView: The target text view
    /// - Returns: True if the event was handled, false otherwise
    public func handleInput(_ event: PlatformInputEvent, in textView: CodeEditorView) -> Bool {
        switch event {
        case let .keyDown(key, modifiers):
            return handleKeyInput(key: key, modifiers: modifiers, in: textView)

        case let .touch(touches, phase):
            return handleTouchInput(touches: touches, phase: phase, in: textView)

        case let .mouse(location, type):
            return handleMouseInput(location: location, type: type, in: textView)

        case let .pencil(location, pressure, azimuth):
            return handlePencilInput(location: location, pressure: pressure, azimuth: azimuth, in: textView)
        }
    }

    /// Configure platform-appropriate gestures for a text view
    ///
    /// This method sets up gesture recognizers based on the current platform
    /// and available input methods.
    ///
    /// - Parameter textView: The text view to configure
    public func configureGestures(for textView: CodeEditorView) {
        #if canImport(UIKit)
        configureIOSGestures(for: textView)
        #else
        configureMacOSGestures(for: textView)
        #endif
    }

    /// Remove all configured gestures from a text view
    ///
    /// - Parameter textView: The text view to clean up
    public func removeGestures(from textView: CodeEditorView) {
        #if canImport(UIKit)
        textView.gestureRecognizers?.removeAll()
        #endif
    }

    // MARK: - Platform-Specific Input Handling

    private func handleKeyInput(key: String, modifiers: PlatformModifierFlags, in textView: CodeEditorView) -> Bool {
        #if canImport(AppKit)
        return handleMacOSKeyInput(key: key, modifiers: modifiers, in: textView)
        #else
        return handleIOSKeyInput(key: key, modifiers: modifiers, in: textView)
        #endif
    }

    private func handleTouchInput(touches: Set<TouchInfo>, phase: PlatformTouchPhase, in textView: CodeEditorView) -> Bool {
        #if canImport(UIKit)
        return handleIOSTouchInput(touches: touches, phase: phase, in: textView)
        #else
        return false // macOS doesn't have touch input
        #endif
    }

    private func handleMouseInput(location: CGPoint, type: PlatformMouseEventType, in textView: CodeEditorView) -> Bool {
        #if canImport(AppKit)
        return handleMacOSMouseInput(location: location, type: type, in: textView)
        #else
        return handleIOSMouseInput(location: location, type: type, in: textView)
        #endif
    }

    private func handlePencilInput(location: CGPoint, pressure: CGFloat, azimuth: CGFloat, in textView: CodeEditorView) -> Bool {
        #if canImport(AppKit)
        return handleMacOSPencilInput(location: location, pressure: pressure, azimuth: azimuth, in: textView)
        #else
        return handleIOSPencilInput(location: location, pressure: pressure, azimuth: azimuth, in: textView)
        #endif
    }

    // MARK: - MacOS Input Implementation

    #if canImport(AppKit)
    private func handleMacOSKeyInput(key: String, modifiers: PlatformModifierFlags, in textView: CodeEditorView) -> Bool {
        logger.debug("Handling macOS key input: \(key) with modifiers: \(modifiers.rawValue)")

        // Handle common keyboard shortcuts
        if modifiers.contains(.command) {
            switch key.lowercased() {
            case "a":
                textView.selectAll(nil)
                return true

            case "c":
                textView.copy(nil)
                return true

            case "v":
                textView.paste(nil)
                return true

            case "x":
                textView.cut(nil)
                return true

            case "z":
                if modifiers.contains(.shift) {
                    textView.undoManager?.redo()
                } else {
                    textView.undoManager?.undo()
                }
                return true

            case "f":
                // Trigger find
                return true

            case "d":
                // Trigger go to definition
                return true

            default:
                break
            }
        }

        return false
    }

    private func handleMacOSMouseInput(location: CGPoint, type: PlatformMouseEventType, in _: CodeEditorView) -> Bool {
        logger.debug("Handling macOS mouse input at \(String(describing: location))")

        switch type {
        case .down:
            // Set cursor position
            return true

        case .dragged:
            // Extend selection
            return true

        case .rightClick:
            // Show context menu
            return true

        default:
            return false
        }
    }

    private func handleMacOSPencilInput(location _: CGPoint, pressure: CGFloat, azimuth _: CGFloat, in _: CodeEditorView) -> Bool {
        // macOS doesn't typically have pencil input, but we can handle pressure-sensitive input devices
        logger.debug("Handling macOS pressure input at location: pressure=\(pressure)")
        return false
    }

    private func configureMacOSGestures(for _: CodeEditorView) {
        logger.debug("Configuring macOS gestures")
        // macOS uses built-in NSResponder methods rather than gesture recognizers
    }
    #endif

    // MARK: - IOS Input Implementation

    #if canImport(UIKit)
    private func handleIOSKeyInput(key: String, modifiers: PlatformModifierFlags, in textView: CodeEditorView) -> Bool {
        logger.debug("Handling iOS key input: \(key) with modifiers: \(modifiers.rawValue)")

        // Handle external keyboard shortcuts
        if modifiers.contains(.command) {
            switch key.lowercased() {
            case "a":
                textView.selectAll(nil)
                return true

            case "c":
                textView.copy(nil)
                return true

            case "v":
                textView.paste(nil)
                return true

            case "x":
                textView.cut(nil)
                return true

            case "z":
                textView.undoManager?.undo()
                return true

            default:
                break
            }
        }

        return false
    }

    private func handleIOSTouchInput(touches: Set<TouchInfo>, phase: PlatformTouchPhase, in _: CodeEditorView) -> Bool {
        logger.debug("Handling iOS touch input: \(touches.count) touches, phase: \(String(describing: phase))")

        switch phase {
        case .began:
            // Start selection or cursor positioning
            return true

        case .moved:
            // Update selection
            return true

        case .ended:
            // Finalize selection
            return true

        case .cancelled:
            // Cancel operation
            return true

        case .stationary:
            return false
        }
    }

    private func handleIOSMouseInput(location: CGPoint, type: PlatformMouseEventType, in _: CodeEditorView) -> Bool {
        logger.debug("Handling iOS mouse input at \(String(describing: location))")

        // Handle trackpad/mouse on iOS (iPad with trackpad)
        switch type {
        case .down:
            return true

        case .hover:
            // Show hover effects if supported
            return true

        default:
            return false
        }
    }

    private func handleIOSPencilInput(location _: CGPoint, pressure: CGFloat, azimuth: CGFloat, in _: CodeEditorView) -> Bool {
        logger.debug("Handling iOS pencil input: pressure=\(pressure), azimuth=\(azimuth)")

        // Handle Apple Pencil input for annotations or selection
        if capabilities.supportsPencilInput {
            // Use pressure and azimuth for advanced input
            return true
        }

        return false
    }

    private func configureIOSGestures(for textView: CodeEditorView) {
        logger.debug("Configuring iOS gestures")

        // Tap gesture for cursor positioning
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        textView.addGestureRecognizer(tapGesture)

        // Long press for selection
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        textView.addGestureRecognizer(longPressGesture)

        // Pan gesture for scrolling and selection
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        textView.addGestureRecognizer(panGesture)

        // Pinch gesture for zooming
        if capabilities.isFeatureAvailable(.gestureNavigation) {
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            textView.addGestureRecognizer(pinchGesture)
        }
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let textView = gesture.view as? CodeEditorView else { return }
        let location = gesture.location(in: textView)
        logger.debug("Tap gesture at (\(location.x), \(location.y))")

        // Position cursor at tap location
        // Implementation would convert location to text position
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let textView = gesture.view as? CodeEditorView else { return }

        let location = gesture.location(in: textView)
        logger.debug("Long press gesture at (\(location.x), \(location.y))")

        // Start text selection or show context menu
        // Implementation would handle selection logic
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let textView = gesture.view as? CodeEditorView else { return }
        let translation = gesture.translation(in: textView)
        logger.debug("Pan gesture with translation (\(translation.x), \(translation.y))")

        // Handle scrolling or text selection
        // Implementation would update scroll position or selection
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.view is CodeEditorView else { return }
        let scale = gesture.scale
        logger.debug("Pinch gesture with scale \(scale)")

        // Handle text scaling/zooming
        // Implementation would adjust font size
    }
    #endif
}

// MARK: - Input Event Convenience

extension InputCoordinator {
    /// Create a keyboard input event
    public static func keyboardEvent(key: String, modifiers: PlatformModifierFlags = []) -> PlatformInputEvent {
        .keyDown(key: key, modifiers: modifiers)
    }

    /// Create a mouse input event
    public static func mouseEvent(at location: CGPoint, type: PlatformMouseEventType) -> PlatformInputEvent {
        .mouse(location: location, type: type)
    }

    /// Create a touch input event
    public static func touchEvent(touches: Set<TouchInfo>, phase: PlatformTouchPhase) -> PlatformInputEvent {
        .touch(touches: touches, phase: phase)
    }

    /// Create a pencil input event
    public static func pencilEvent(at location: CGPoint, pressure: CGFloat, azimuth: CGFloat) -> PlatformInputEvent {
        .pencil(location: location, pressure: pressure, azimuth: azimuth)
    }
}
