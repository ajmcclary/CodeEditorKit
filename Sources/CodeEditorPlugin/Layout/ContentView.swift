import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

// MARK: - ContentView

/// Content view that contains layout fragments
public class ContentView: NSView, @preconcurrency NSTextInputClient {
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
    }

    /// Text views need a flipped coordinate system on macOS
    override public var isFlipped: Bool {
        true
    }

    /// Accept first responder for text input
    override public var acceptsFirstResponder: Bool {
        if let textView = superview?.superview as? CodeEditorView {
            return textView.isEditable
        }
        return true
    }

    override public func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            needsDisplay = true
        }
        return result
    }

    // MARK: - Keyboard Events

    override public func keyDown(with event: NSEvent) {
        // Use input method system for proper text input
        interpretKeyEvents([event])
    }

    /// Handle mouse events for text selection
    override public func mouseDown(with event: NSEvent) {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            textView.mouseDown(with: event)
        } else {
            super.mouseDown(with: event)
        }
    }

    override public func mouseDragged(with event: NSEvent) {
        if let textView = superview?.superview as? CodeEditorView {
            textView.mouseDragged(with: event)
        } else {
            super.mouseDragged(with: event)
        }
    }

    override public func mouseUp(with event: NSEvent) {
        if let textView = superview?.superview as? CodeEditorView {
            textView.mouseUp(with: event)
        } else {
            super.mouseUp(with: event)
        }
    }

    // MARK: - NSTextInputClient

    /// Forward insertText to CodeEditorAPI's insertText(_:) method to avoid ambiguity
    public func insertText(_ string: Any, replacementRange _: NSRange) {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            if let str = string as? String {
                textView.insertText(str)
            } else {
                textView.insertText("\(string)")
            }
        }
    }

    /// Forward setMarkedText to CodeEditorAPI's method to avoid ambiguity
    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            textView.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        }
    }

    /// Forward unmarkText to CodeEditorAPI's method
    public func unmarkText() {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            textView.unmarkText()
        }
    }

    /// Forward selectedRange to CodeEditorAPI's selectedRange()
    public func selectedRange() -> NSRange {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            return textView.selectedRange()
        }
        return NSRange(location: 0, length: 0)
    }

    /// Forward markedRange to CodeEditorAPI's markedRange()
    public func markedRange() -> NSRange {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            return textView.markedRange()
        }
        return NSRange(location: NSNotFound, length: 0)
    }

    /// Forward hasMarkedText to CodeEditorAPI's hasMarkedText()
    public func hasMarkedText() -> Bool {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            return textView.hasMarkedText()
        }
        return false
    }

    /// Forward attributedSubstring to CodeEditorAPI's method
    public func attributedSubstring(
        forProposedRange range: NSRange,
        actualRange: NSRangePointer?
    ) -> NSAttributedString? {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            return textView.attributedSubstring(forProposedRange: range, actualRange: actualRange)
        }
        return nil
    }

    /// Forward validAttributesForMarkedText to CodeEditorAPI's method
    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            return textView.validAttributesForMarkedText()
        }
        return []
    }

    /// Forward firstRect(forCharacterRange:) to CodeEditorAPI's method
    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            return textView.firstRect(forCharacterRange: range, actualRange: actualRange)
        }
        return NSRect.zero
    }

    /// Forward characterIndex(for:) to CodeEditorAPI's method
    public func characterIndex(for point: NSPoint) -> Int {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            return textView.characterIndex(for: point)
        }
        return 0
    }

    override public func doCommand(by selector: Selector) {
        // Forward to parent CodeEditorView
        if let textView = superview?.superview as? CodeEditorView {
            textView.doCommand(by: selector)
        }
    }

    deinit {
        // Cleanup if needed
    }
}

#elseif canImport(UIKit)
import UIKit

// MARK: - EditorContentView (iOS)

/// Content view that provides text input support on iOS
@MainActor
public class EditorContentView: UIView {
    // MARK: - Properties
    
    /// The parent text view
    private weak var textView: CodeEditorView?
    
    /// Input accessory view for keyboard shortcuts
    private var inputAccessoryToolbar: UIToolbar?
    
    // MARK: - Initialization
    
    override public init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        
        // Set up gesture recognizers
        setupGestureRecognizers()
        
        // Configure accessibility
        isAccessibilityElement = true
        accessibilityTraits = [.allowsDirectInteraction]
        accessibilityLabel = "Code Editor"
    }
    
    // MARK: - Parent View Connection
    
    /// Set the parent text view
    public func setTextView(_ textView: CodeEditorView?) {
        self.textView = textView
    }
    
    // MARK: - Touch Handling
    
    private func setupGestureRecognizers() {
        // Tap gesture for positioning cursor
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
        
        // Long press for selection
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)
        
        // Pan gesture for selection dragging
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        addGestureRecognizer(panGesture)
        
        // Double tap for word selection
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTapGesture)
        
        // Triple tap for line selection
        let tripleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTripleTap(_:)))
        tripleTapGesture.numberOfTapsRequired = 3
        addGestureRecognizer(tripleTapGesture)
        
        // Ensure tap gestures don't conflict
        tapGesture.require(toFail: doubleTapGesture)
        doubleTapGesture.require(toFail: tripleTapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let textView else { return }
        
        let location = gesture.location(in: self)
        
        // Convert tap location to text position
        if let position = textView.closestPosition(to: location) {
            textView.selectedTextRange = textView.textRange(from: position, to: position)
        }
        
        // Ensure text view becomes first responder
        if textView.isEditable && !textView.isFirstResponder {
            _ = textView.becomeFirstResponder()
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let textView else { return }
        
        let location = gesture.location(in: self)
        
        // Select word at tap location
        if let position = textView.closestPosition(to: location),
           let range = textView.tokenizer.rangeEnclosingPosition(
               position,
               with: .word,
               inDirection: .storage(.forward)
           ) {
            textView.selectedTextRange = range
        }
    }
    
    @objc private func handleTripleTap(_ gesture: UITapGestureRecognizer) {
        guard let textView else { return }
        
        let location = gesture.location(in: self)
        
        // Select line at tap location
        if let position = textView.closestPosition(to: location),
           let range = textView.tokenizer.rangeEnclosingPosition(
               position,
               with: .line,
               inDirection: .storage(.forward)
           ) {
            textView.selectedTextRange = range
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let textView else { return }
        
        switch gesture.state {
        case .began:
            let location = gesture.location(in: self)
            
            // Start selection at location
            if let position = textView.closestPosition(to: location) {
                textView.selectedTextRange = textView.textRange(from: position, to: position)
                
                // Show magnifier or selection handles
                showSelectionUI(at: location)
            }
            
        case .changed:
            let location = gesture.location(in: self)
            updateSelection(to: location)
            
        case .ended, .cancelled:
            hideSelectionUI()
            
        default:
            break
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let textView,
              textView.selectedTextRange != nil else { return }
        
        switch gesture.state {
        case .began, .changed:
            let location = gesture.location(in: self)
            updateSelection(to: location)
            
        case .ended, .cancelled:
            hideSelectionUI()
            
        default:
            break
        }
    }
    
    // MARK: - Selection UI
    
    private func showSelectionUI(at _: CGPoint) {
        // Show magnifier or selection handles
        // This would typically show a magnifying glass for precise cursor positioning
    }
    
    private func updateSelection(to location: CGPoint) {
        guard let textView,
              let selectedRange = textView.selectedTextRange,
              let position = textView.closestPosition(to: location) else { return }
        
        // Update selection end point
        if let newRange = textView.textRange(from: selectedRange.start, to: position) {
            textView.selectedTextRange = newRange
        }
    }
    
    private func hideSelectionUI() {
        // Hide magnifier or selection handles
    }
    
    // MARK: - Input Accessory
    
    /// Create an input accessory view with common actions
    public func createInputAccessory() -> UIView {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        var items: [UIBarButtonItem] = []
        
        // Undo/Redo buttons
        items.append(UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.backward"),
            style: .plain,
            target: self,
            action: #selector(performUndo)
        ))
        
        items.append(UIBarButtonItem(
            image: UIImage(systemName: "arrow.uturn.forward"),
            style: .plain,
            target: self,
            action: #selector(performRedo)
        ))
        
        items.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))
        
        // Tab button
        items.append(UIBarButtonItem(
            title: "Tab",
            style: .plain,
            target: self,
            action: #selector(insertTab)
        ))
        
        items.append(UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil))
        
        // Find button
        items.append(UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(showFind)
        ))
        
        // Done button
        items.append(UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissKeyboard)
        ))
        
        toolbar.items = items
        self.inputAccessoryToolbar = toolbar
        return toolbar
    }
    
    // MARK: - Actions
    
    @objc private func performUndo() {
        textView?.undoManager?.undo()
    }
    
    @objc private func performRedo() {
        textView?.undoManager?.redo()
    }
    
    @objc private func insertTab() {
        if let textView {
            (textView as CodeEditorAPI).insertText("\t")
        }
    }
    
    @objc private func showFind() {
        // Trigger find UI
        NotificationCenter.default.post(
            name: NSNotification.Name("CodeEditorShowFind"), // swiftlint:disable:this legacy_objc_type
            object: textView
        )
    }
    
    @objc private func dismissKeyboard() {
        textView?.resignFirstResponder()
    }
    
    // MARK: - Hit Testing
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Allow touches to pass through to text view if needed
        let hitView = super.hitTest(point, with: event)
        
        // If the hit view is self, forward to text view
        if hitView == self, let textView {
            return textView
        }
        
        return hitView
    }
    
    deinit {
        // Cleanup if needed
    }
}

// MARK: - UIGestureRecognizerDelegate

extension EditorContentView: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
    ) -> Bool {
        // Allow pan gesture to work with selection
        if gestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
}
#endif
