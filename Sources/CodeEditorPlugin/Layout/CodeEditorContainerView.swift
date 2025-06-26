#if canImport(UIKit)
import UIKit

/// Container view that holds both the text view and the gutter view side by side
/// This allows the gutter to remain fixed while the text view scrolls
@MainActor
public class CodeEditorContainerView: UIView {
    public let textView: CodeEditorView
    public let gutterView: GutterView
    public let minimapView: MinimapView
    private var minimapDataProvider: MinimapDataProvider?
    
    private var keyboardObservers: [NSObjectProtocol] = []
    private var keyboardHeight: CGFloat = 0
    
    /// Configuration for the editor
    public var configuration: EditorConfiguration = .default {
        didSet {
            applyConfiguration()
        }
    }
    
    override public init(frame: CGRect) {
        // Create the text view
        textView = CodeEditorView(frame: .zero)
        
        // Create the gutter view
        gutterView = GutterView(frame: .zero)
        
        // Create the minimap view
        minimapView = MinimapView(frame: .zero)
        
        super.init(frame: frame)
        
        setupViews()
        setupKeyboardObservers()
    }
    
    public required init?(coder: NSCoder) {
        // Create the text view
        textView = CodeEditorView(frame: .zero)
        
        // Create the gutter view
        gutterView = GutterView(frame: .zero)
        
        // Create the minimap view
        minimapView = MinimapView(frame: .zero)
        
        super.init(coder: coder)
        
        setupViews()
        setupKeyboardObservers()
    }
    
    private func setupViews() {
        // Add all views
        addSubview(textView)
        addSubview(gutterView)
        addSubview(minimapView)
        
        // Connect gutter to text view
        gutterView.textView = textView
        
        // Set up minimap
        setupMinimap()
        
        // Set up the text view to account for the gutter
        let gutterWidth = configuration.layout.gutterWidth
        let padding = configuration.layout.lineNumberPadding
        textView.textContainerInset = UIEdgeInsets(
            top: textView.textContainerInset.top,
            left: gutterWidth + padding,
            bottom: textView.textContainerInset.bottom,
            right: textView.textContainerInset.right
        )
        
        // Ensure text view scrolls and doesn't resize with keyboard
        textView.alwaysBounceVertical = true
        textView.isScrollEnabled = true
        
        // Ensure text view background is transparent where gutter is
        textView.backgroundColor = .clear
        
        // Set container background
        backgroundColor = .systemBackground
        
        // Ensure gutter stays on top
        bringSubviewToFront(gutterView)
    }
    
    private func setupMinimap() {
        // Create data provider
        minimapDataProvider = MinimapDataProvider(textView: textView)
        
        // Set up navigation callback
        minimapView.onNavigate = { [weak self] lineNumber in
            self?.navigateToLine(lineNumber)
        }
        
        // Initially hidden based on configuration
        minimapView.isHidden = !configuration.display.showMinimap
        
        // Set up text change observer to update minimap
        NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        
        // Set up scroll observer to update minimap  
        NotificationCenter.default.addObserver(
            forName: UIScrollView.contentOffsetDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
    }
    
    private func navigateToLine(_ lineNumber: Int) {
        // Navigate text view to the specified line
        let text = textView.text ?? ""
        let lines = text.components(separatedBy: .newlines)
        
        guard lineNumber < lines.count else { return }
        
        // Calculate character position for the line
        let lineStart = lines.prefix(lineNumber).joined(separator: "\n").count
        if lineNumber > 0 {
            // Add 1 for the newline character
            let targetPosition = lineStart + 1
            if let position = textView.position(from: textView.beginningOfDocument, offset: targetPosition) {
                textView.selectedTextRange = textView.textRange(from: position, to: position)
                
                // Scroll to make the line visible
                let rect = textView.caretRect(for: position)
                textView.scrollRectToVisible(rect, animated: true)
            }
        } else {
            // First line
            textView.selectedTextRange = textView.textRange(from: textView.beginningOfDocument, to: textView.beginningOfDocument)
            textView.scrollRectToVisible(CGRect(x: 0, y: 0, width: 1, height: 1), animated: true)
        }
    }
    
    private func updateMinimap() {
        guard configuration.display.showMinimap,
              let dataProvider = minimapDataProvider,
              let data = dataProvider.generateData() else {
            return
        }
        
        minimapView.updateData(data)
    }
    
    private func setupKeyboardObservers() {
        // Listen for keyboard notifications
        let willShow = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Extract data from notification before entering Task
            let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            
            Task { @MainActor in
                self.handleKeyboardWillShow(keyboardFrame: keyboardFrame, duration: duration)
            }
        }
        
        let willHide = NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            // Extract data from notification before entering Task
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
            
            Task { @MainActor in
                self.handleKeyboardWillHide(duration: duration)
            }
        }
        
        keyboardObservers = [willShow, willHide]
    }
    
    private func handleKeyboardWillShow(keyboardFrame: CGRect?, duration: Double?) {
        guard let keyboardFrame,
              let duration else {
            return
        }
        
        // Convert keyboard frame to our coordinate system
        let convertedFrame = convert(keyboardFrame, from: nil)
        keyboardHeight = bounds.maxY - convertedFrame.minY
        
        // Adjust text view content inset instead of resizing
        UIView.animate(withDuration: duration) {
            self.updateContentInsets()
        }
    }
    
    private func handleKeyboardWillHide(duration: Double?) {
        guard let duration else {
            return
        }
        
        keyboardHeight = 0
        
        UIView.animate(withDuration: duration) {
            self.updateContentInsets()
        }
    }
    
    private func updateContentInsets() {
        // Adjust the text view's content inset to account for keyboard
        // This keeps the content scrollable without compressing the view
        let bottomInset = keyboardHeight > 0 ? keyboardHeight : 0
        
        textView.contentInset = UIEdgeInsets(
            top: 0,
            left: 0,
            bottom: bottomInset,
            right: 0
        )
        
        // Also adjust the scroll indicator insets
        textView.scrollIndicatorInsets = textView.contentInset
        
        // Make sure the gutter redraws with proper positioning
        gutterView.setNeedsDisplay()
        
        // If keyboard is showing, ensure we can still scroll to see all content
        if keyboardHeight > 0 {
            // Adjust content size if needed to ensure full scrolling
            let minContentHeight = bounds.height - keyboardHeight + textView.contentSize.height
            if textView.contentSize.height < minContentHeight {
                textView.contentSize = CGSize(width: textView.contentSize.width, height: minContentHeight)
            }
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        
        // IMPORTANT: We need to maintain the text view's natural content size
        // even when the container is resized by SwiftUI for keyboard
        
        // Get the text view's content size
        let contentSize = textView.contentSize
        
        // Calculate layout dimensions
        let gutterWidth = configuration.layout.gutterWidth
        let minimapWidth = configuration.display.showMinimap ? 120 : 0
        
        // Position gutter on the left - it should match content height, not bounds
        gutterView.frame = CGRect(
            x: 0,
            y: 0,
            width: gutterWidth,
            height: max(bounds.height, contentSize.height + textView.contentInset.top + textView.contentInset.bottom)
        )
        
        // Position minimap on the right
        if configuration.display.showMinimap {
            minimapView.frame = CGRect(
                x: bounds.width - minimapWidth,
                y: 0,
                width: minimapWidth,
                height: max(bounds.height, contentSize.height + textView.contentInset.top + textView.contentInset.bottom)
            )
            minimapView.isHidden = false
        } else {
            minimapView.isHidden = true
        }
        
        // Position text view to take remaining space between gutter and minimap
        let textViewWidth = bounds.width - minimapWidth
        textView.frame = CGRect(
            x: 0,  // Text view starts at 0, but has inset for gutter
            y: 0,
            width: textViewWidth,
            height: bounds.height
        )
        
        // Ensure content insets are maintained
        updateContentInsets()
        
        // Force gutter to update when layout changes
        gutterView.setNeedsDisplay()
        
        // Update minimap if shown
        if configuration.display.showMinimap {
            updateMinimap()
        }
    }
    
    /// Updates whether line numbers are shown
    public var showsLineNumbers: Bool = false {
        didSet {
            gutterView.isHidden = !showsLineNumbers
            
            // Update text container inset
            let gutterWidth = configuration.layout.gutterWidth
            let padding = configuration.layout.lineNumberPadding
            if showsLineNumbers {
                textView.textContainerInset = UIEdgeInsets(
                    top: textView.textContainerInset.top,
                    left: gutterWidth + padding,
                    bottom: textView.textContainerInset.bottom,
                    right: textView.textContainerInset.right
                )
            } else {
                textView.textContainerInset = UIEdgeInsets(
                    top: textView.textContainerInset.top,
                    left: padding,
                    bottom: textView.textContainerInset.bottom,
                    right: textView.textContainerInset.right
                )
            }
        }
    }
    
    // MARK: - Configuration
    
    private func applyConfiguration() {
        // Apply configuration to text view
        textView.configuration = configuration
        
        // Update our own properties based on configuration
        showsLineNumbers = configuration.display.showLineNumbers
        
        // Update minimap visibility
        minimapView.isHidden = !configuration.display.showMinimap
        
        // Force layout update
        setNeedsLayout()
        
        // Update minimap if it's now visible
        if configuration.display.showMinimap {
            updateMinimap()
        }
    }
    
    // Cleanup happens automatically when observers are deallocated
    
    deinit {
        // Observers are automatically removed when deallocated
    }
}
#endif
