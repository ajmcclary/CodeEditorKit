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
        textView.annotationsDataSource = self
    }
    
    // MARK: - Public Methods
    
    /// Scan the text and update annotations
    func scanForAnnotations() {
        guard let textView else { return }
        
        // Clear existing annotations and views
        clearAnnotations()
        
        // Get the text
        let text = textView.text ?? ""
        guard !text.isEmpty else { return }
        
        // Use a TextKit1-compatible approach for annotations
        createAnnotationsUsingTextKit1(text: text)
    }
    
    /// Clear all annotations
    func clearAnnotations() {
        // Clear our internal annotation list
        annotations.removeAll()
        
        // Clear annotations from the text view
        textView?.removeAllAnnotations()
    }
    
    /// Create annotations using TextKit1-compatible approach
    private func createAnnotationsUsingTextKit1(text: String) {
        guard textView != nil else { return }
        
        // Find the first occurrence of "TODO:"
        if let todoRange = text.range(of: "TODO:") {
            let nsRange = NSRange(todoRange, in: text)
            
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
        
        // Get line number from the range
        let text = textView.text ?? ""
        let lines = text.components(separatedBy: .newlines)
        var currentLocation = 0
        var lineNumber = 1
        
        for (index, line) in lines.enumerated() {
            let lineLength = line.count + 1 // +1 for newline
            if currentLocation + lineLength > range.location {
                lineNumber = index + 1
                break
            }
            currentLocation += lineLength
        }
        
        let annotation = CodeAnnotation(
            lineNumber: lineNumber,
            type: type,
            message: message,
            range: nil
        )
        
        annotations.append(annotation)
        
        // For now, skip creating visual annotation views to avoid memory issues
        // The CodeEditorView's annotation system will handle the display
    }
}

// MARK: - AnnotationsDataSource

extension AnnotationManager: @preconcurrency AnnotationsDataSource {
    func annotations(for textRange: NSTextRange) -> [Annotation] {
        // Return annotations that intersect with the given range
        let result: [Annotation] = annotations.compactMap { annotation in
            guard let annotationRange = annotation.range else {
                return nil
            }
            if annotationRange.intersects(textRange) {
                return Annotation(
                    range: annotationRange,
                    content: annotation.message,
                    id: annotation.id
                )
            }
            return nil
        }
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
        // Find the matching annotation
        guard let codeAnnotation = annotations.first(where: { $0.id == annotation.id }) else {
            return nil
        }
        
        #if canImport(AppKit)
        // Create and return annotation view
        let annotationView = SampleAnnotationView(annotation: codeAnnotation, frame: proposedViewFrame)
        return annotationView
        #else
        // iOS doesn't have SampleAnnotationView yet
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
        // Find the matching code annotation
        guard let codeAnnotation = annotations.first(where: { $0.range == annotation.range }) else {
            return nil
        }
        
        // Create and return annotation view
        let annotationView = SampleAnnotationView(annotation: codeAnnotation, frame: proposedViewFrame)
        return annotationView
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
        
        var color: PlatformColor {
            switch self {
            case .todo:
                return PlatformColors.systemBlue
            case .fixme:
                return PlatformColors.systemOrange
            case .warning:
                return PlatformColors.systemYellow
            case .note:
                return PlatformColors.secondaryLabel
            case .error:
                return PlatformColors.systemRed
            }
        }
        
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

// MARK: - SampleAnnotationView

#if canImport(AppKit)
class SampleAnnotationView: NSView {
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
        iconView.contentTintColor = PlatformColors.white
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
            self.trackingArea = nil
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
    
    override func removeFromSuperview() {
        // Clean up before removal
        if let trackingArea {
            removeTrackingArea(trackingArea)
            self.trackingArea = nil
        }
        hideAnnotationPopup()
        discardCursorRects()
        super.removeFromSuperview()
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
        containerView.layer?.backgroundColor = PlatformColors.controlBackground.cgColor
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
        messageLabel.textColor = PlatformColors.label
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
    
    func hideAnnotationPopup() {
        popover?.close()
        popover = nil
    }
}
#endif

// MARK: - SampleAnnotationView (iOS)

#if canImport(UIKit)
class SampleAnnotationView: UIView {
    private let annotation: CodeAnnotation
    private var popoverController: UIViewController?
    
    init(annotation: CodeAnnotation, frame: CGRect) {
        self.annotation = annotation
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Create circular badge
        layer.cornerRadius = bounds.width / 2
        backgroundColor = annotation.type.color
        
        // Add icon
        let iconImageView = UIImageView(frame: bounds.insetBy(dx: 4, dy: 4))
        iconImageView.image = UIImage(systemName: getIconName())
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = PlatformColors.white
        addSubview(iconImageView)
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
        
        // Add long press gesture for more details
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        longPressGesture.minimumPressDuration = 0.5
        addGestureRecognizer(longPressGesture)
        
        // Make accessible
        isAccessibilityElement = true
        accessibilityLabel = "\(annotation.type.label): \(annotation.message)"
        accessibilityTraits = .button
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
            return "xmark.circle"
        }
    }
    
    @objc private func handleTap() {
        showAnnotationPopup()
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        showAnnotationPopup(detachable: true)
    }
    
    private func showAnnotationPopup(detachable: Bool = false) {
        guard let window = self.window,
              let rootViewController = window.rootViewController else { return }
        
        // Dismiss existing popover if any
        hideAnnotationPopup()
        
        // Create content view controller
        let contentVC = UIViewController()
        contentVC.preferredContentSize = CGSize(width: 300, height: 80)
        
        // Create content view
        let contentView = UIView()
        contentView.backgroundColor = PlatformColors.secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentVC.view.addSubview(contentView)
        
        // Type label
        let typeLabel = UILabel()
        typeLabel.text = annotation.type.label + ":"
        typeLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        typeLabel.textColor = annotation.type.color
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Message label
        let messageLabel = UILabel()
        messageLabel.text = annotation.message
        messageLabel.font = .systemFont(ofSize: 13)
        messageLabel.textColor = .label
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Stack view for labels
        let stackView = UIStackView(arrangedSubviews: [typeLabel, messageLabel])
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .top
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Close button for detachable popover
        if detachable {
            let closeButton = UIButton(type: .close)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            closeButton.addTarget(self, action: #selector(closePopover), for: .touchUpInside)
            contentView.addSubview(closeButton)
            
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
                closeButton.widthAnchor.constraint(equalToConstant: 24),
                closeButton.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: contentVC.view.leadingAnchor, constant: 8),
            contentView.trailingAnchor.constraint(equalTo: contentVC.view.trailingAnchor, constant: -8),
            contentView.topAnchor.constraint(equalTo: contentVC.view.topAnchor, constant: 8),
            contentView.bottomAnchor.constraint(equalTo: contentVC.view.bottomAnchor, constant: -8),
            
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: detachable ? -40 : -16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            messageLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 200)
        ])
        
        // Present as popover on iPad or modal on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad || detachable {
            contentVC.modalPresentationStyle = .popover
            
            if let popover = contentVC.popoverPresentationController {
                popover.sourceView = self
                popover.sourceRect = bounds
                popover.permittedArrowDirections = [.up, .down, .left, .right]
                popover.delegate = detachable ? nil : NonDetachablePopoverDelegate.shared
                
                // Style the popover
                popover.backgroundColor = PlatformColors.secondarySystemBackground
            }
            
            rootViewController.present(contentVC, animated: true)
        } else {
            // On iPhone, show as a temporary overlay
            showTemporaryOverlay(contentView: contentView, in: window)
        }
        
        self.popoverController = contentVC
    }
    
    private func showTemporaryOverlay(contentView: UIView, in window: UIWindow) {
        // Convert position to window coordinates
        let annotationFrame = convert(bounds, to: window)
        
        // Position the overlay above or below the annotation
        let overlayY = annotationFrame.maxY + 8
        let overlayFrame = CGRect(
            x: max(8, annotationFrame.midX - 150),
            y: overlayY,
            width: 300,
            height: 80
        )
        
        contentView.frame = overlayFrame
        contentView.alpha = 0
        window.addSubview(contentView)
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            contentView.alpha = 1
        }
        
        // Auto-dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak contentView] in
            UIView.animate(withDuration: 0.3, animations: {
                contentView?.alpha = 0
            }, completion: { _ in
                contentView?.removeFromSuperview()
            })
        }
    }
    
    @objc private func closePopover() {
        hideAnnotationPopup()
    }
    
    func hideAnnotationPopup() {
        popoverController?.dismiss(animated: true)
        popoverController = nil
    }
}

// Helper for non-detachable popovers on iPad
private class NonDetachablePopoverDelegate: NSObject, UIPopoverPresentationControllerDelegate {
    static let shared = NonDetachablePopoverDelegate()
    
    func popoverPresentationControllerShouldDismissPopover(
        _ popoverPresentationController: UIPopoverPresentationController
    ) -> Bool {
        true
    }
}
#endif
