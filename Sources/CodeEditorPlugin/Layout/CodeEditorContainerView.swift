import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Cross-platform container view that holds the text view, gutter view, and minimap
/// This allows the gutter and minimap to remain fixed while the text view scrolls
@MainActor
public final class CodeEditorContainerView: PlatformView {
    // MARK: - Properties
    
    public let textView: CodeEditorView
    public let gutterView: GutterView
    public let minimapView: MinimapView
    private var minimapDataProvider: MinimapDataProvider?
    
    #if canImport(UIKit)
    public let contentView: EditorContentView
    private var keyboardObservers: [NSObjectProtocol] = []
    private nonisolated(unsafe) var keyboardObserversForDeinit: [NSObjectProtocol] = []
    private var keyboardHeight: CGFloat = 0
    #else
    public let scrollView: NSScrollView
    #endif
    
    /// Configuration for the editor
    public var configuration: EditorConfiguration = .default {
        didSet {
            applyConfiguration()
        }
    }
    
    // MARK: - Initialization
    
    override public init(frame: CGRect) {
        // Create the text view
        textView = CodeEditorView(frame: .zero)
        
        // Create the gutter view
        gutterView = GutterView(frame: .zero)
        
        // Create the minimap view
        minimapView = MinimapView(frame: .zero)
        
        #if canImport(UIKit)
        // Create the content view for iOS
        contentView = EditorContentView(frame: CGRect.zero)
        #else
        // Create scroll view for macOS
        scrollView = NSScrollView(frame: NSRect.zero)
        #endif
        
        super.init(frame: frame)
        
        setupViews()
        setupObservers()
    }
    
    public required init?(coder: NSCoder) {
        // Create the text view
        textView = CodeEditorView(frame: .zero)
        
        // Create the gutter view
        gutterView = GutterView(frame: .zero)
        
        // Create the minimap view
        minimapView = MinimapView(frame: .zero)
        
        #if canImport(UIKit)
        // Create the content view for iOS
        contentView = EditorContentView(frame: CGRect.zero)
        #else
        // Create scroll view for macOS
        scrollView = NSScrollView(frame: NSRect.zero)
        #endif
        
        super.init(coder: coder)
        
        setupViews()
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        setupMacOSViews()
        #else
        setupIOSViews()
        #endif
        
        // Common setup
        gutterView.textView = textView
        gutterView.observeTextView()          // start listening for changes
        setupMinimap()
        
        // Apply initial text container insets
        updateTextContainerInsets()
        
        // Set container background using platform colors
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS uses layer background
        wantsLayer = true
        layer?.backgroundColor = PlatformColors.systemBackground.cgColor
        #else
        backgroundColor = PlatformColors.systemBackground
        #endif
    }
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func setupMacOSViews() {
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !configuration.layout.wrapLines
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        
        // Configure text view for scroll view
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !configuration.layout.wrapLines
        textView.textContainer?.widthTracksTextView = configuration.layout.wrapLines
        textView.textContainer?.heightTracksTextView = false
        textView.autoresizingMask = [.width, .height]
        
        // Set container width for non-wrapping mode
        if !configuration.layout.wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        
        // Set text view as document view
        scrollView.documentView = textView
        
        // Add subviews
        addSubview(scrollView)
        addSubview(gutterView)
        addSubview(minimapView)
        
        // Ensure text view background is transparent where gutter is
        textView.backgroundColor = PlatformColors.clear
    }
    #endif
    
    #if canImport(UIKit)
    private func setupIOSViews() {
        // Add all views
        addSubview(contentView)
        contentView.addSubview(textView)
        addSubview(gutterView)
        addSubview(minimapView)
        
        // Connect components
        contentView.setTextView(textView)
        
        // Set up input accessory
        if configuration.behavior.isEditable {
            textView.inputAccessoryView = contentView.createInputAccessory()
        }
        
        // Ensure text view scrolls and doesn't resize with keyboard
        textView.alwaysBounceVertical = true
        textView.isScrollEnabled = true
        
        // Ensure text view background is transparent where gutter is
        textView.backgroundColor = PlatformColors.clear
        
        // Ensure gutter stays on top
        bringSubviewToFront(gutterView)
        
        // Set up scroll delegate for minimap updates
        // CodeEditorView inherits from UIScrollView on iOS
        textView.delegate = self
    }
    #endif
    
    private func setupObservers() {
        #if canImport(UIKit)
        setupKeyboardObservers()
        #endif
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
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            forName: NSText.didChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        #else
        NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        #endif
        
        // Set up scroll observer to update minimap
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMinimap()
            }
        }
        #else
        // On iOS, set up scroll delegate for minimap updates
        // The textView (UITextView) handles scrolling internally
        // We'll monitor scroll changes through the delegate pattern in setupIOSViews
        #endif
    }
    
    // MARK: - Navigation
    
    private func navigateToLine(_ lineNumber: Int) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS navigation
        let text = textView.string
        let lines = text.components(separatedBy: .newlines)
        
        guard lineNumber < lines.count else { return }
        
        // Calculate character position for the line
        let lineStart = lines.prefix(lineNumber).joined(separator: "\n").count
        if lineNumber > 0 {
            // Add 1 for the newline character
            let targetPosition = lineStart + 1
            textView.setSelectedRange(NSRange(location: targetPosition, length: 0))
            textView.scrollRangeToVisible(NSRange(location: targetPosition, length: 0))
        } else {
            // First line
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }
        #else
        // iOS navigation
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
        #endif
    }
    
    private func updateMinimap() {
        guard configuration.display.showMinimap,
              let dataProvider = minimapDataProvider,
              let data = dataProvider.generateData() else {
            return
        }
        
        minimapView.updateData(data)
    }
    
    // MARK: - Layout
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func layout() {
        // Ensure we're on the main thread for layout operations
        if Thread.isMainThread {
            super.layout()
            layoutViews()
        } else {
            // Dispatch to main thread if called from background
            DispatchQueue.main.async { [weak self] in
                self?.layout()
            }
        }
    }
    #else
    override public func layoutSubviews() {
        super.layoutSubviews()
        layoutViews()
    }
    #endif
    
    private func layoutViews() {
        // Calculate layout dimensions
        let gutterWidth = configuration.layout.gutterWidth
        let minimapWidth = configuration.display.showMinimap ? configuration.layout.minimapWidth : 0
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS layout
        
        // Position scroll view to take remaining space between gutter and minimap
        scrollView.frame = CGRect(
            x: gutterWidth,
            y: 0,
            width: bounds.width - gutterWidth - minimapWidth,
            height: bounds.height
        )
        
        // Position gutter on the left
        gutterView.frame = CGRect(
            x: 0,
            y: 0,
            width: gutterWidth,
            height: bounds.height
        )
        
        // Position minimap on the right
        if configuration.display.showMinimap {
            minimapView.frame = CGRect(
                x: bounds.width - minimapWidth,
                y: 0,
                width: minimapWidth,
                height: bounds.height
            )
            minimapView.isHidden = false
        } else {
            minimapView.isHidden = true
        }
        #else
        // iOS layout
        
        // Get the text view's content size
        let contentSize = textView.contentSize
        
        // Position content view to fill the container
        contentView.frame = bounds
        
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
        
        // Position text view within content view to take remaining space between gutter and minimap
        let textViewWidth = bounds.width - minimapWidth
        textView.frame = CGRect(
            x: 0,  // Text view starts at 0, but has inset for gutter
            y: 0,
            width: textViewWidth,
            height: bounds.height
        )
        
        // Ensure content insets are maintained
        updateContentInsets()
        #endif
        
        // Force gutter to update when layout changes
        gutterView.setNeedsDisplayLineNumbers()
        
        // Update minimap if shown
        if configuration.display.showMinimap {
            updateMinimap()
        }
    }
    
    // MARK: - Text Container Insets
    
    private func updateTextContainerInsets() {
        let gutterWidth = showsLineNumbers ? configuration.layout.gutterWidth : 0
        let padding = configuration.layout.lineNumberPadding
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let currentInsets = textView.textContainerInset
        textView.textContainerInset = NSSize(
            width: gutterWidth + padding,
            height: currentInsets.height
        )
        #else
        let currentInsets = textView.textContainerEdgeInsets
        let newInsets = EdgeInsets(
            top: currentInsets.top,
            left: gutterWidth + padding,
            bottom: currentInsets.bottom,
            right: currentInsets.right
        )
        textView.setTextContainerEdgeInsets(newInsets)
        #endif
    }
    
    // MARK: - Configuration
    
    /// Updates whether line numbers are shown
    public var showsLineNumbers: Bool = false {
        didSet {
            gutterView.isHidden = !showsLineNumbers
            updateTextContainerInsets()
            
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            needsLayout = true
            #else
            setNeedsLayout()
            #endif
        }
    }
    
    private func applyConfiguration() {
        // Apply configuration to text view, but disable its internal line numbers
        // since we manage the gutter externally
        var textViewConfig = configuration
        textViewConfig.display.showLineNumbers = false
        textView.configuration = textViewConfig
        
        // Update our own properties based on configuration
        showsLineNumbers = configuration.display.showLineNumbers
        
        // Update minimap visibility
        minimapView.isHidden = !configuration.display.showMinimap
        
        // Update scroll view settings on macOS
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        scrollView.hasHorizontalScroller = !configuration.layout.wrapLines
        textView.isHorizontallyResizable = !configuration.layout.wrapLines
        textView.textContainer?.widthTracksTextView = configuration.layout.wrapLines
        
        if !configuration.layout.wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        #endif
        
        // Force layout update
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        needsLayout = true
        #else
        setNeedsLayout()
        #endif
        
        // Update minimap if it's now visible
        if configuration.display.showMinimap {
            updateMinimap()
        }
    }
    
    // MARK: - Platform-Specific Extensions
    
    #if canImport(UIKit)
    // iOS-specific keyboard handling and content insets
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
        keyboardObserversForDeinit = keyboardObservers
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
        
        let contentInsets = EdgeInsets(
            top: 0,
            left: 0,
            bottom: bottomInset,
            right: 0
        )
        textView.contentInset = contentInsets.uiEdgeInsets
        
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
    
    private func cleanupKeyboardObservers() {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
        keyboardObservers.removeAll()
        keyboardObserversForDeinit = keyboardObservers
    }
    #endif
    
    deinit {
        #if canImport(UIKit)
        // Perform cleanup synchronously to avoid capturing self after deinit begins
        keyboardObserversForDeinit.forEach { NotificationCenter.default.removeObserver($0) }
        keyboardObserversForDeinit.removeAll()
        #endif
        
        // Remove any selector-based observers
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UIScrollViewDelegate

#if canImport(UIKit)
extension CodeEditorContainerView: UITextViewDelegate {
    public func scrollViewDidScroll(_: UIScrollView) {
        // Update minimap when text view scrolls
        updateMinimap()
    }
}
#endif
