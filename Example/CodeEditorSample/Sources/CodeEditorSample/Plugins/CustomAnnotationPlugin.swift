import Foundation
import AppKit
import CodeEditorPlugin

// MARK: - Custom Annotation Plugin

final class CustomAnnotationPlugin: STPlugin {
    typealias Coordinator = CustomAnnotationCoordinator
    
    private var context: (any Context)?
    
    func setUp(context: any Context) {
        self.context = context
        
        // Store context for later use
        // Text change notifications will be handled through the coordinator
    }
    
    func makeCoordinator(context: CoordinatorContext) -> CustomAnnotationCoordinator {
        return CustomAnnotationCoordinator(textView: context.textView)
    }
    
    func tearDown() {
        // Cleanup if needed
    }
    
    private func analyzeText() {
        // Text analysis will be handled by the coordinator
    }
}

// MARK: - Custom Annotation Coordinator

@MainActor
final class CustomAnnotationCoordinator {
    weak var textView: STTextView?
    private var annotations: [CustomAnnotation] = []
    private var annotationViews: [NSView] = []
    
    init(textView: STTextView) {
        self.textView = textView
        analyzeAndUpdateAnnotations()
    }
    
    func analyzeAndUpdateAnnotations() {
        guard let textView = textView else { return }
        
        // Clear existing annotations
        clearAnnotations()
        
        // Get the text
        let text = textView.text ?? ""
        let lines = text.components(separatedBy: .newlines)
        
        // Analyze each line
        for (lineIndex, line) in lines.enumerated() {
            // Check for TODO
            if let range = line.range(of: "TODO:", options: .caseInsensitive) {
                let message = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                let annotation = CustomAnnotation(
                    lineNumber: lineIndex + 1,
                    type: .todo,
                    message: message.isEmpty ? "TODO item" : message
                )
                annotations.append(annotation)
            }
            
            // Check for FIXME
            if let range = line.range(of: "FIXME:", options: .caseInsensitive) {
                let message = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                let annotation = CustomAnnotation(
                    lineNumber: lineIndex + 1,
                    type: .fixme,
                    message: message.isEmpty ? "Fix required" : message
                )
                annotations.append(annotation)
            }
            
            // Check for WARNING
            if let range = line.range(of: "WARNING:", options: .caseInsensitive) {
                let message = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                let annotation = CustomAnnotation(
                    lineNumber: lineIndex + 1,
                    type: .warning,
                    message: message.isEmpty ? "Warning" : message
                )
                annotations.append(annotation)
            }
            
            // Check for NOTE
            if let range = line.range(of: "NOTE:", options: .caseInsensitive) {
                let message = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                let annotation = CustomAnnotation(
                    lineNumber: lineIndex + 1,
                    type: .note,
                    message: message.isEmpty ? "Note" : message
                )
                annotations.append(annotation)
            }
        }
        
        // Display annotations
        displayAnnotations()
    }
    
    private func clearAnnotations() {
        annotations.removeAll()
        annotationViews.forEach { $0.removeFromSuperview() }
        annotationViews.removeAll()
    }
    
    private func displayAnnotations() {
        guard let textView = textView else { return }
        
        for annotation in annotations {
            // Create annotation view
            let annotationView = CustomAnnotationView(annotation: annotation)
            
            // Calculate position
            if let lineFragment = getLineFragment(for: annotation.lineNumber) {
                let frame = NSRect(
                    x: textView.bounds.width - 200,
                    y: lineFragment.layoutFragmentFrame.minY,
                    width: 180,
                    height: 24
                )
                annotationView.frame = frame
                
                // Add to text view
                textView.addSubview(annotationView)
                annotationViews.append(annotationView)
            }
        }
    }
    
    private func getLineFragment(for lineNumber: Int) -> NSTextLayoutFragment? {
        guard let textView = textView else { return nil }
        
        let textLayoutManager = textView.textLayoutManager
        
        var currentLine = 1
        var targetFragment: NSTextLayoutFragment?
        
        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.location, options: [.ensuresLayout]) { fragment in
            let lineCount = fragment.textLineFragments.count
            
            if currentLine <= lineNumber && lineNumber < currentLine + lineCount {
                targetFragment = fragment
                return false // Stop enumeration
            }
            
            currentLine += lineCount
            return true // Continue enumeration
        }
        
        return targetFragment
    }
}

// MARK: - Custom Annotation Model

struct CustomAnnotation {
    let lineNumber: Int
    let type: AnnotationType
    let message: String
    
    enum AnnotationType {
        case todo
        case fixme
        case warning
        case note
        
        var color: NSColor {
            switch self {
            case .todo:
                return .systemBlue
            case .fixme:
                return .systemOrange
            case .warning:
                return .systemYellow
            case .note:
                return .systemGray
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
            }
        }
    }
}

// MARK: - Custom Annotation View

class CustomAnnotationView: NSView {
    let annotation: CustomAnnotation
    
    init(annotation: CustomAnnotation) {
        self.annotation = annotation
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.backgroundColor = annotation.type.color.withAlphaComponent(0.1).cgColor
        layer?.borderColor = annotation.type.color.withAlphaComponent(0.3).cgColor
        layer?.borderWidth = 1
        
        // Add label
        let label = NSTextField(labelWithString: "\(annotation.type.label): \(annotation.message)")
        label.font = .systemFont(ofSize: 11)
        label.textColor = annotation.type.color
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Add hover effect
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            layer?.backgroundColor = annotation.type.color.withAlphaComponent(0.2).cgColor
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            layer?.backgroundColor = annotation.type.color.withAlphaComponent(0.1).cgColor
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        // Show full message in tooltip or popover
        let popover = NSPopover()
        popover.behavior = .transient
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 60))
        
        let messageLabel = NSTextField(wrappingLabelWithString: annotation.message)
        messageLabel.font = .systemFont(ofSize: 12)
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            messageLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            messageLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
        
        let viewController = NSViewController()
        viewController.view = contentView
        
        popover.contentViewController = viewController
        popover.show(relativeTo: bounds, of: self, preferredEdge: .minY)
    }
}