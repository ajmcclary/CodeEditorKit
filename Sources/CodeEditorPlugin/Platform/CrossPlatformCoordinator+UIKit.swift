#if canImport(UIKit)
import Foundation
import os.log
import UIKit

// MARK: - IOS Specific Implementation

extension CrossPlatformCoordinator {
    func optimizeForIOS(_ textView: CodeEditorView) {
        // Configure for touch
        textView.isSelectable = true
        textView.isEditable = true
        
        // Adjust content insets for safe area
        if let window = textView.window {
            let safeArea = window.safeAreaInsets
            let insets = EdgeInsets(
                top: safeArea.top + 8,
                left: 0,
                bottom: safeArea.bottom + 8,
                right: 0
            )
            textView.setUnifiedTextContainerInsets(insets)
        }
        
        // Configure keyboard
        textView.keyboardType = .default
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        
        // Add input accessory view for iPad
        if UIDevice.current.userInterfaceIdiom == .pad {
            textView.inputAccessoryView = createInputAccessoryView()
        }
    }
    
    func createInputAccessoryView() -> UIView {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let items = [
            UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.backward"), style: .plain, target: self, action: #selector(undo)),
            UIBarButtonItem(image: UIImage(systemName: "arrow.uturn.forward"), style: .plain, target: self, action: #selector(redo)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(image: UIImage(systemName: "magnifyingglass"), style: .plain, target: self, action: #selector(find)),
            UIBarButtonItem(image: UIImage(systemName: "keyboard.chevron.compact.down"), style: .plain, target: self, action: #selector(dismissKeyboard))
        ]
        
        toolbar.items = items
        return toolbar
    }
    
    func setupIOSNotifications() {
        // Keyboard notifications
        let keyboardObserver = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract values outside the Task to avoid actor isolation issues
            let keyboardInfo = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            
            Task { @MainActor in
                self?.handleKeyboardWillShow(keyboardInfo: keyboardInfo, duration: duration)
            }
        }
        addObserver(keyboardObserver)
        
        // Orientation change notifications
        let orientationObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.orientationDidChange()
            }
        }
        addObserver(orientationObserver)
    }
    
    func handleIOSKeyInput(key: String, modifiers: PlatformModifierFlags, in textView: CodeEditorView) -> Bool {
        // Limited keyboard support on iOS
        if isExternalKeyboardConnected() && modifiers.contains(.command) {
            switch key {
            case "f": showFind(in: textView); return true
            case "z": textView.undoManager?.undo(); return true
            default: break
            }
        }
        return false
    }
    
    func handleIOSTouchInput(touches: Set<AnyHashable>, phase: PlatformTouchPhase, in textView: CodeEditorView) -> Bool {
        // Handle multi-touch gestures
        if touches.count == 2 {
            // Two-finger tap for context menu
            if phase == .ended {
                showContextMenu(in: textView)
                return true
            }
        }
        return false
    }
    
    func handleIOSMouseInput(location: CGPoint, type: PlatformMouseEventType, in textView: CodeEditorView) -> Bool {
        // Limited mouse support on iOS
        if isPointingDeviceConnected() {
            switch type {
            case .rightClick:
                showContextMenu(at: location, in: textView)
                return true
                
            default:
                return false
            }
        }
        return false
    }
    
    func handleIOSPencilInput(location: CGPoint, pressure: CGFloat, azimuth _: CGFloat, in textView: CodeEditorView) -> Bool {
        // Handle Apple Pencil input
        if pressure > 0.5 {
            // Heavy pressure for selection
            startSelection(at: location, in: textView)
            return true
        }
        return false
    }
    
    // MARK: - IOS Context Menu
    
    func createIOSContextMenu(for textView: CodeEditorView, at _: CGPoint) -> UIMenu {
        var actions: [UIMenuElement] = []
        
        // Standard editing
        actions.append(UIAction(title: "Cut", image: UIImage(systemName: "scissors")) { _ in
            textView.cut(nil)
        })
        actions.append(UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
            textView.copy(nil)
        })
        actions.append(UIAction(title: "Paste", image: UIImage(systemName: "doc.on.clipboard")) { _ in
            textView.paste(nil)
        })
        
        // Code-specific actions
        let codeActions = UIMenu(title: "Code", children: [
            UIAction(title: "Toggle Comment", image: UIImage(systemName: "text.bubble")) { [weak self] _ in
                self?.toggleComment()
            },
            UIAction(title: "Format Selection", image: UIImage(systemName: "text.alignleft")) { [weak self] _ in
                self?.logger.debug("Format selection requested")
            }
        ])
        actions.append(codeActions)
        
        return UIMenu(children: actions)
    }
    
    // MARK: - IOS Keyboard Management
    
    @MainActor
    private func handleKeyboardWillShow(keyboardInfo: CGRect?, duration: Double?) {
        guard keyboardInfo != nil,
              let duration else {
            return
        }
        
        // Update keyboard height
        logger.debug("Keyboard shown")
        
        // Animate adjustment
        UIView.animate(withDuration: duration) {
            self.objectWillChange.send()
        }
    }
    
    // MARK: - IOS Specific Helpers
    
    func isExternalKeyboardConnected() -> Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        // Check for external keyboard by examining the input view controller
        // When an external keyboard is connected, the software keyboard is typically hidden
        // Note: firstResponder is not available on UIWindow in newer iOS versions
        // For now, assume no external keyboard on iOS simulator/device
        return false
        #endif
    }
    
    // MARK: - IOS Gesture Setup
    
    func setupIOSGestures(for textView: CodeEditorView) {
        // Long press for context menu
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressUIKit(_:)))
        textView.addGestureRecognizer(longPress)
        
        // Two-finger tap for quick actions
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        textView.addGestureRecognizer(twoFingerTap)
    }
    
    @objc private func handleLongPressUIKit(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let textView = gesture.view as? CodeEditorView else { return }
        
        let location = gesture.location(in: textView)
        showContextMenu(at: location, in: textView)
    }
    
    @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.view is CodeEditorView else { return }
        logger.debug("Two-finger tap detected")
        // Could trigger quick actions menu
    }
    
    // MARK: - IOS Device Detection
    
    func isPointingDeviceConnected() -> Bool {
        // Check if mouse/trackpad is connected
        if #available(iOS 13.4, *) {
            return UIDevice.current.userInterfaceIdiom == .pad
        }
        return false
    }
    
    private func keyboardDidConnect() {
        adjustFeaturesForPlatform()
    }
    
    internal func orientationDidChange() {
        // Adjust UI for new orientation
        let orientation = UIDevice.current.orientation
        
        // Update platform adjustments based on orientation
        if orientation.isLandscape {
            // In landscape, we can use slightly smaller touch targets
            updatePlatformAdjustments { adjustments in
                adjustments.minimumTouchTargetSize = 40
            }
        } else {
            // Portrait uses standard iOS touch target size
            updatePlatformAdjustments { adjustments in
                adjustments.minimumTouchTargetSize = 44
            }
        }
        
        // Notify observers of the change
        objectWillChange.send()
    }
}
#endif
