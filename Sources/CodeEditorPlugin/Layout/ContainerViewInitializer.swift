import Foundation
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

/// Unified container view initialization logic to eliminate platform-specific duplication
@MainActor
enum ContainerViewInitializer {
    /// Common initialization parameters
    struct InitializationParameters {
        let initialFrame: CGRect
        let gutterWidth: CGFloat
        let minimapWidth: CGFloat
        
        init(frame: CGRect, gutterWidth: CGFloat = 40, minimapWidth: CGFloat = 100) {
            self.initialFrame = frame == .zero ? CGRect(x: 0, y: 0, width: 600, height: 400) : frame
            self.gutterWidth = gutterWidth
            self.minimapWidth = minimapWidth
        }
    }
    
    /// Create all common views with unified logic
    static func createViews(with parameters: InitializationParameters) -> ViewComponents {
        let textView = CodeEditorView(frame: parameters.initialFrame)
        
        let gutterView = GutterView(frame: CGRect(
            x: 0,
            y: 0,
            width: parameters.gutterWidth,
            height: parameters.initialFrame.height
        ))
        
        let minimapView = MinimapView(frame: CGRect(
            x: parameters.initialFrame.width - parameters.minimapWidth,
            y: 0,
            width: parameters.minimapWidth,
            height: parameters.initialFrame.height
        ))
        
        #if canImport(UIKit)
        let contentView = EditorContentView(frame: parameters.initialFrame)
        return ViewComponents(
            textView: textView,
            gutterView: gutterView,
            minimapView: minimapView,
            contentView: contentView
        )
        #else
        let scrollView = NSScrollView(frame: parameters.initialFrame)
        return ViewComponents(
            textView: textView,
            gutterView: gutterView,
            minimapView: minimapView,
            scrollView: scrollView
        )
        #endif
    }
    
    /// Common setup logic for both platforms
    static func performCommonSetup(
        for container: CodeEditorContainerView,
        with components: ViewComponents
    ) {
        // Set container reference
        components.textView.containerView = container
        
        // Apply common configuration
        container.configuration.apply(to: components.textView)
        
        // Setup minimap (this needs to be called on container directly due to stored property)
        container.setupMinimap()
        
        // Setup common observers
        setupCommonObservers(for: container, with: components)
        
        // Remove any internal gutter from text view before setting up
        components.textView.removeGutter()
        
        // Apply initial text container insets
        container.updateTextContainerInsets()
        
        // Set container background using platform colors
        setupContainerBackground(for: container)
    }
    
    /// Setup platform-specific views using unified patterns
    static func setupPlatformViews(
        for container: CodeEditorContainerView,
        with components: ViewComponents
    ) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        setupAppKitViews(for: container, with: components)
        #else
        setupUIKitViews(for: container, with: components)
        #endif
    }
    
    // MARK: - Private Helpers
    
    private static func setupContainerBackground(for container: CodeEditorContainerView) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS uses layer background
        container.wantsLayer = true
        container.layer?.backgroundColor = PlatformColors.systemBackground.cgColor
        #else
        // iOS uses backgroundColor
        container.backgroundColor = PlatformColors.systemBackground
        #endif
    }
    
    private static func setupCommonObservers(
        for container: CodeEditorContainerView,
        with components: ViewComponents
    ) {
        // Text change observers
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NotificationCenter.default.addObserver(
            container,
            selector: #selector(container.textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: components.textView
        )
        #elseif canImport(UIKit)
        NotificationCenter.default.addObserver(
            container,
            selector: #selector(container.textDidChange(_:)),
            name: UITextView.textDidChangeNotification,
            object: components.textView
        )
        #endif
    }
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private static func setupAppKitViews(
        for container: CodeEditorContainerView,
        with components: ViewComponents
    ) {
        guard let scrollView = components.scrollView else { return }
        
        // Configure scroll view
        scrollView.documentView = components.textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        
        // Add views to container
        container.addSubview(scrollView)
        container.addSubview(components.minimapView, positioned: .above, relativeTo: scrollView)
        
        // Configure minimap layer
        components.minimapView.wantsLayer = true
        components.minimapView.layer?.zPosition = 1_000
        components.minimapView.layer?.backgroundColor = MinimapConfiguration.defaultBackgroundColor.cgColor
        
        // Setup ruler view if line numbers are enabled
        setupRulerView(for: container, scrollView: scrollView, textView: components.textView)
    }
    
    private static func setupRulerView(
        for container: CodeEditorContainerView,
        scrollView: NSScrollView,
        textView: CodeEditorView
    ) {
        let config = container.configuration
        scrollView.hasVerticalRuler = config.display.isLineNumbersEnabled
        scrollView.rulersVisible = config.display.isLineNumbersEnabled
        
        if config.display.isLineNumbersEnabled {
            let rulerView = LineNumberRulerView(scrollView: scrollView, orientation: .verticalRuler)
            rulerView.textView = textView
            rulerView.ruleThickness = config.layout.gutterWidth
            scrollView.verticalRulerView = rulerView
            
            scrollView.hasVerticalRuler = true
            scrollView.rulersVisible = true
            rulerView.needsDisplay = true
            
            // Setup ruler view observer
            NotificationCenter.default.addObserver(
                rulerView,
                selector: #selector(LineNumberRulerView.scrollViewDidScroll(_:)),
                name: NSText.didChangeNotification,
                object: textView
            )
        }
    }
    #else
    private static func setupUIKitViews(
        for container: CodeEditorContainerView,
        with components: ViewComponents
    ) {
        // Add subviews with proper hierarchy check
        addSubviewIfNeeded(components.gutterView, to: container)
        addSubviewIfNeeded(components.textView, to: container)
        addSubviewIfNeeded(components.minimapView, to: container)
        
        // Configure auto layout
        components.gutterView.translatesAutoresizingMaskIntoConstraints = false
        components.textView.translatesAutoresizingMaskIntoConstraints = false
        components.minimapView.translatesAutoresizingMaskIntoConstraints = false
        
        // Set delegate
        components.textView.delegate = container
        
        // Configure gutter-textview relationship
        components.gutterView.textView = components.textView
        components.gutterView.observeTextView()
        
        // Rebuild constraints using container's existing method
        container.rebuildConstraints()
    }
    
    private static func addSubviewIfNeeded(_ subview: PlatformView, to container: CodeEditorContainerView) {
        if !subview.isDescendant(of: container) {
            container.addSubview(subview)
        }
    }
    #endif
}

/// Container for all view components created during initialization
struct ViewComponents {
    let textView: CodeEditorView
    let gutterView: GutterView
    let minimapView: MinimapView
    
    #if canImport(UIKit)
    let contentView: EditorContentView?
    
    #if !targetEnvironment(macCatalyst)
    let scrollView: UIScrollView? = nil
    #endif
    
    init(textView: CodeEditorView, gutterView: GutterView, minimapView: MinimapView, contentView: EditorContentView) {
        self.textView = textView
        self.gutterView = gutterView
        self.minimapView = minimapView
        self.contentView = contentView
    }
    #else
    let scrollView: NSScrollView?
    
    init(textView: CodeEditorView, gutterView: GutterView, minimapView: MinimapView, scrollView: NSScrollView) {
        self.textView = textView
        self.gutterView = gutterView
        self.minimapView = minimapView
        self.scrollView = scrollView
    }
    #endif
}

// MARK: - CodeEditorContainerView Extension for Notification Handling

extension CodeEditorContainerView {
    @objc func textDidChange(_: Notification) {
        // Handle text changes for both platforms
        DispatchQueue.main.async { [weak self] in
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            self?.gutterView.setNeedsDisplay(self?.gutterView.bounds ?? .zero)
            self?.minimapView.setNeedsDisplay(self?.minimapView.bounds ?? .zero)
            #else
            self?.gutterView.setNeedsDisplay()
            self?.minimapView.setNeedsDisplay()
            #endif
        }
    }
}
