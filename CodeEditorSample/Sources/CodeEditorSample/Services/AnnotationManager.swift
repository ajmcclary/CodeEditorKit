#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import CodeEditorPlugin
import Foundation

// MARK: - AnnotationManager

/// Manages code annotations (TODO, FIXME, WARNING, NOTE) for the editor
@MainActor
final class AnnotationManager: NSObject {
    // MARK: - Properties
    
    private weak var textView: CodeEditorView?
    private var annotations: [CodeAnnotation] = []
    
    // MARK: - Initialization
    
    init(textView: CodeEditorView) {
        self.textView = textView
        super.init()
        print("DEBUG AnnotationManager: Initializing with textView")
        textView.annotationsDataSource = self
        print("DEBUG AnnotationManager: Set annotationsDataSource on textView")
    }
    
    // MARK: - Public Methods
    
    /// Scan the text and update annotations
    func scanForAnnotations() {
        guard let textView else { 
            print("DEBUG AnnotationManager: No textView")
            return 
        }
        
        print("DEBUG AnnotationManager: Scanning for annotations...")
        
        // Clear existing annotations
        textView.removeAllAnnotations()
        annotations.removeAll()
        
        // Get the text
        let text = textView.text ?? ""
        print("DEBUG AnnotationManager: Text length: \(text.count)")
        print("DEBUG AnnotationManager: Text preview (first 100 chars): \(String(text.prefix(100)))")
        
        guard !text.isEmpty else { 
            print("DEBUG AnnotationManager: No text to scan")
            return 
        }
        
        // Simple pattern check first
        let todoCount = text.components(separatedBy: "TODO:").count - 1
        let fixmeCount = text.components(separatedBy: "FIXME:").count - 1
        print("DEBUG AnnotationManager: Found \(todoCount) TODO patterns and \(fixmeCount) FIXME patterns")
        
        // Use a TextKit1-compatible approach for annotations
        print("DEBUG AnnotationManager: Using TextKit1-compatible approach")
        createAnnotationsUsingTextKit1(text: text)
    }
    
    /// Clear all annotations
    func clearAnnotations() {
        textView?.removeAllAnnotations()
        annotations.removeAll()
        
        // Also remove any manually added annotation views
        #if canImport(AppKit)
        textView?.subviews.filter { $0 is AnnotationView }.forEach { $0.removeFromSuperview() }
        #endif
    }
    
    /// Create annotations using TextKit1-compatible approach
    private func createAnnotationsUsingTextKit1(text: String) {
        guard textView != nil else {
            print("DEBUG AnnotationManager: No textView available")
            return
        }
        
        print("DEBUG AnnotationManager: Creating annotations using TextKit1 approach")
        
        // For now, create a simple test annotation at a fixed position
        // We'll use NSRange and convert it to NSTextRange manually
        
        // Find the first occurrence of "TODO:"
        if let todoRange = text.range(of: "TODO:") {
            let nsRange = NSRange(todoRange, in: text)
            print("DEBUG AnnotationManager: Found TODO at NSRange: \(nsRange)")
            
            // Use the annotation API instead of direct TextKit access
            print("DEBUG AnnotationManager: Using CodeEditorView annotation API")
            
            // Create annotation through the public API
            createSimpleAnnotationMarker(
                at: nsRange,
                type: CodeAnnotation.AnnotationType.todo,
                message: "TODO found here"
            )
        }
    }
    
    /// Create a simple annotation marker at the specified range
    private func createSimpleAnnotationMarker(at range: NSRange, type: CodeAnnotation.AnnotationType, message: String) {
        guard let textView = textView else { return }
        
        print("DEBUG AnnotationManager: Creating simple annotation marker at range: \(range)")
        
        // Create a dummy NSTextRange using the document start
        #if canImport(AppKit)
        guard let textStorage = textView.textStorage,
              textStorage.length > 0 else { 
            print("DEBUG AnnotationManager: No text storage or empty text")
            return 
        }
        #else
        let textStorage = textView.textStorage
        guard textStorage.length > 0 else { 
            print("DEBUG AnnotationManager: Empty text")
            return 
        }
        #endif
        
        // Create a simple range at the location we found
        let location = max(0, min(range.location, textStorage.length - 1))
        let length = min(range.length, textStorage.length - location)
        let clampedRange = NSRange(location: location, length: length)
        
        // For now, create annotation without the complex NSTextRange
        // We'll position it manually using the NSRange
        print("DEBUG AnnotationManager: Creating annotation at clamped range: \(clampedRange)")
        
        let annotation = CodeAnnotation(
            lineNumber: 1, // We'll calculate this later
            type: type,
            message: message,
            range: nil // We'll handle positioning differently
        )
        
        annotations.append(annotation)
        
        // Calculate proper position using TextKit1 layout
        #if canImport(AppKit)
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            print("DEBUG AnnotationManager: No layout manager or text container")
            return
        }
        #else
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        #endif
        
        // Convert NSRange to glyph range
        let glyphRange = layoutManager.glyphRange(forCharacterRange: clampedRange, actualCharacterRange: nil)
        print("DEBUG AnnotationManager: Glyph range: \(glyphRange)")
        
        // Get the bounding rect for the text
        let boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        print("DEBUG AnnotationManager: Bounding rect: \(boundingRect)")
        
        // Position annotation inline, right after the text
        let badgeSize: CGFloat = 20
        let badgePadding: CGFloat = 4
        #if canImport(AppKit)
        let annotationX = textView.textContainerInset.width + boundingRect.maxX + badgePadding
        let annotationY = textView.textContainerInset.height + boundingRect.midY - (badgeSize / 2)
        #else
        let annotationX = textView.textContainerInset.left + boundingRect.maxX + badgePadding
        let annotationY = textView.textContainerInset.top + boundingRect.midY - (badgeSize / 2)
        #endif
        
        let annotationFrame = CGRect(
            x: annotationX,
            y: annotationY,
            width: badgeSize,
            height: badgeSize
        )
        
        print("DEBUG AnnotationManager: Calculated annotation frame: \(annotationFrame)")
        
        // Create a simple annotation view and add it directly to the text view
        #if canImport(AppKit)
        let annotationView = AnnotationView(annotation: annotation, frame: annotationFrame)
        #else
        // iOS doesn't have AnnotationView yet - create a simple UIView instead
        let annotationView = UIView(frame: annotationFrame)
        annotationView.backgroundColor = type.color
        annotationView.layer.cornerRadius = badgeSize / 2
        #endif
        #if canImport(AppKit)
        annotationView.wantsLayer = true
        annotationView.layer?.backgroundColor = type.color.cgColor
        annotationView.layer?.cornerRadius = badgeSize / 2
        #else
        // Already configured above for iOS
        #endif
        
        print("DEBUG AnnotationManager: Adding annotation view at calculated position")
        textView.addSubview(annotationView)
        
        print("DEBUG AnnotationManager: Annotation view added, textView subviews: \(textView.subviews.count)")
    }
}

// MARK: - AnnotationsDataSource

extension AnnotationManager: @preconcurrency AnnotationsDataSource {
    func annotations(for textRange: NSTextRange) -> [Annotation] {
        print("DEBUG AnnotationManager: annotations(for:) called with range: \(textRange)")
        print("DEBUG AnnotationManager: total annotations: \(annotations.count)")
        
        // Return annotations that intersect with the given range
        let result: [Annotation] = annotations.compactMap { annotation in
            guard let annotationRange = annotation.range else {
                print("DEBUG AnnotationManager: annotation \(annotation.id) has no range")
                return nil
            }
            if annotationRange.intersects(textRange) {
                print("DEBUG AnnotationManager: annotation \(annotation.id) intersects with range")
                return Annotation(
                    range: annotationRange,
                    content: annotation.message,
                    id: annotation.id
                )
            }
            return nil
        }
        print("DEBUG AnnotationManager: returning \(result.count) annotations for range")
        return result
    }
    
    var textViewAnnotations: [CodeEditorViewAnnotation] {
        // Convert our annotations to CodeEditorViewAnnotation
        annotations.compactMap { annotation in
            guard let range = annotation.range else { return nil }
            return CodeEditorViewAnnotation(
                location: range.location,
                content: annotation.message,
                id: annotation.id
            )
        }
    }
    
    #if canImport(AppKit)
    func textView(
        _ textView: CodeEditorView,
        viewForLineAnnotation annotation: CodeEditorViewAnnotation,
        textLineFragment: NSTextLineFragment,
        proposedViewFrame: CGRect
    ) -> NSView? {
        print("DEBUG AnnotationManager: textView(_:viewForLineAnnotation:) called")
        print("DEBUG AnnotationManager: annotation id: \(annotation.id)")
        print("DEBUG AnnotationManager: proposedViewFrame: \(proposedViewFrame)")
        
        // Find the matching annotation
        guard let codeAnnotation = annotations.first(where: { $0.id == annotation.id }) else {
            print("DEBUG AnnotationManager: No matching code annotation found for id: \(annotation.id)")
            return nil
        }
        
        #if canImport(AppKit)
        print("DEBUG AnnotationManager: Creating AnnotationView for: \(codeAnnotation.type.label)")
        
        // Create and return annotation view
        let annotationView = AnnotationView(annotation: codeAnnotation, frame: proposedViewFrame)
        print("DEBUG AnnotationManager: Created AnnotationView with frame: \(annotationView.frame)")
        return annotationView
        #else
        // iOS doesn't have AnnotationView yet
        return nil
        #endif
    }
    #else
    func textView(
        _ textView: CodeEditorView,
        viewForLineAnnotation annotation: CodeEditorViewAnnotation,
        textLineFragment: NSTextLineFragment,
        proposedViewFrame: CGRect
    ) -> UIView? {
        // iOS stub implementation
        return nil
    }
    #endif
}

// MARK: - CodeAnnotation

struct CodeAnnotation {
    let id: String = UUID().uuidString
    let lineNumber: Int
    let type: AnnotationType
    let message: String
    let range: NSTextRange?
    
    enum AnnotationType {
        case todo
        case fixme
        case warning
        case note
        case error
        
        #if canImport(AppKit)
        var color: PlatformColor {
            switch self {
            case .todo:
                return .systemBlue
            case .fixme:
                return .systemOrange
            case .warning:
                return .systemYellow
            case .note:
                return .systemGray
            case .error:
                return .systemRed
            }
        }
        #else
        var color: UIColor {
            switch self {
            case .todo:
                return .systemBlue
            case .fixme:
                return .systemOrange
            case .warning:
                return .systemYellow
            case .note:
                return .systemGray
            case .error:
                return .systemRed
            }
        }
        #endif
        
        var icon: String {
            switch self {
            case .todo:
                return "checklist"
            case .fixme:
                return "wrench.and.screwdriver"
            case .warning:
                return "exclamationmark.triangle"
            case .note:
                return "note.text"
            case .error:
                return "xmark.circle"
            }
        }
        
        var label: String {
            switch self {
            case .todo:
                return "TODO"
            case .fixme:
                return "FIXME"
            case .warning:
                return "WARNING"
            case .note:
                return "NOTE"
            case .error:
                return "ERROR"
            }
        }
    }
}

// MARK: - AnnotationView

#if canImport(AppKit)
class AnnotationView: NSView {
    private let annotation: CodeAnnotation
    private var trackingArea: NSTrackingArea?
    private var popover: NSPopover?
    
    init(annotation: CodeAnnotation, frame: NSRect) {
        self.annotation = annotation
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        
        // Create circular badge
        layer?.cornerRadius = bounds.width / 2
        layer?.backgroundColor = annotation.type.color.cgColor
        
        // Add icon or symbol
        let iconView = NSImageView(frame: bounds.insetBy(dx: 4, dy: 4))
        iconView.image = NSImage(systemSymbolName: getIconName(), accessibilityDescription: annotation.type.label)
        iconView.contentTintColor = .white
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)
        
        // Set up cursor
        addCursorRect(bounds, cursor: .pointingHand)
    }
    
    private func getIconName() -> String {
        switch annotation.type {
        case .todo:
            return "checkmark.circle"
        case .fixme:
            return "wrench"
        case .warning:
            return "exclamationmark.triangle"
        case .note:
            return "info.circle"
        case .error:
            return "xmark"
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        // Remove old tracking area
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        // Add new tracking area
        let newTrackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newTrackingArea)
        self.trackingArea = newTrackingArea
    }
    
    override func mouseEntered(with event: NSEvent) {
        // Show tooltip-style annotation on hover
        showAnnotationPopup()
    }
    
    override func mouseExited(with event: NSEvent) {
        // Delay hiding to prevent flicker
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self,
                  let popover = self.popover,
                  popover.isShown else {
                self?.hideAnnotationPopup()
                return
            }
            
            // Check if mouse is still over the popover
            if let popoverWindow = popover.contentViewController?.view.window,
               let screen = NSScreen.main {
                let mouseLocation = NSEvent.mouseLocation
                _ = screen.frame // Screen frame not currently used
                let popoverScreenFrame = popoverWindow.frame
                
                if !popoverScreenFrame.contains(mouseLocation) {
                    self.hideAnnotationPopup()
                }
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        // Keep popover open on click
        if popover?.isShown == true {
            hideAnnotationPopup()
        } else {
            showAnnotationPopup(detachable: true)
        }
    }
    
    private func showAnnotationPopup(detachable: Bool = false) {
        guard popover == nil else { return }
        
        let popover = NSPopover()
        popover.behavior = detachable ? .semitransient : .transient
        popover.animates = true
        
        // Create content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 50))
        
        // Create a styled container
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 6
        containerView.layer?.backgroundColor = PlatformColor.controlBackgroundColor.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Type label
        let typeLabel = NSTextField(labelWithString: annotation.type.label + ":")
        typeLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        typeLabel.textColor = annotation.type.color
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Message label
        let messageLabel = NSTextField(labelWithString: annotation.message)
        messageLabel.font = .systemFont(ofSize: 11)
        messageLabel.textColor = .labelColor
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.maximumNumberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(typeLabel)
        containerView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            typeLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            typeLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            
            messageLabel.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 4),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            messageLabel.centerYAnchor.constraint(equalTo: typeLabel.centerYAnchor),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8)
        ])
        
        let viewController = NSViewController()
        viewController.view = contentView
        
        popover.contentViewController = viewController
        popover.show(relativeTo: bounds, of: self, preferredEdge: .maxX)
        
        self.popover = popover
    }
    
    private func hideAnnotationPopup() {
        popover?.close()
        popover = nil
    }
}
#endif
