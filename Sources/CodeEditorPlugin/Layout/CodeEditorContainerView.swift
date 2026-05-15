import Foundation
#if canImport(AppKit)
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
    internal var minimapDataProvider: MinimapDataProvider?
    internal var isApplyingConfiguration = false

    #if canImport(UIKit)
    public let contentView: EditorContentView
    internal var keyboardObservers: [NSObjectProtocol] = []
    internal var keyboardHeight: CGFloat = 0
    #else
    public let scrollView: NSScrollView
    #endif

    /// Configuration for the editor
    public var configuration: EditorConfiguration = .default {
        didSet {
            // Prevent recursive configuration updates
            if !isApplyingConfiguration {
                applyConfiguration()
            }
        }
    }

    /// Theme last applied via `apply(theme:)`. nil before first apply.
    /// Sub-project 3 establishes the storage; per-subview fan-out lands in
    /// later tasks (subviews currently use hardcoded PlatformColors).
    public private(set) var appliedTheme: Theme?

    /// Apply a theme to the container and every subview that consumes a
    /// theme. Expensive subview fan-out is equality-gated, but the text view
    /// still receives same-theme applications so it can re-stamp mutable
    /// text-storage attributes after content replacement or configuration
    /// churn.
    public func apply(theme: Theme) {
        CodeEditorRenderingDiagnostics.logContainer(
            "container.apply.begin",
            container: self,
            theme: theme,
            note: "sameTheme=\(appliedTheme == theme)"
        )
        #if canImport(AppKit)
        let appKitAppearance = theme.appKitAppearance
        appearance = appKitAppearance
        scrollView.appearance = appKitAppearance
        gutterView.appearance = appKitAppearance
        minimapView.appearance = appKitAppearance
        textView.appearance = appKitAppearance
        scrollView.verticalRulerView?.appearance = appKitAppearance
        #endif

        if appliedTheme == theme {
            textView.apply(theme: theme)
            CodeEditorRenderingDiagnostics.logContainer(
                "container.apply.end.sameTheme",
                container: self,
                theme: theme
            )
            return
        }
        appliedTheme = theme
        gutterView.apply(theme: theme)
        minimapView.apply(theme: theme)
        textView.apply(theme: theme)
        #if canImport(AppKit)
        (textView.enclosingScrollView?.verticalRulerView as? LineNumberRulerView)?.apply(theme: theme)
        #endif
        CodeEditorRenderingDiagnostics.logContainer(
            "container.apply.end.changedTheme",
            container: self,
            theme: theme
        )
    }

    // MARK: - Initialization

    override public init(frame: CGRect) {
        // Create initialization parameters and views using unified logic
        let parameters = ContainerViewInitializer.InitializationParameters(frame: frame)
        let components = ContainerViewInitializer.createViews(with: parameters)

        // Initialize view properties
        textView = components.textView
        gutterView = components.gutterView
        minimapView = components.minimapView

        #if canImport(UIKit)
        if let contentView = components.contentView {
            self.contentView = contentView
        } else {
            let logger = CrossPlatformLogger.logger()
            logger.error("Failed to create content view for iOS platform, using fallback")
            self.contentView = EditorContentView()
        }
        #else
        if let scrollView = components.scrollView {
            self.scrollView = scrollView
        } else {
            let logger = CrossPlatformLogger.logger()
            logger.error("Failed to create scroll view for macOS platform, using fallback")
            self.scrollView = NSScrollView(frame: parameters.initialFrame)
        }
        #endif

        super.init(frame: parameters.initialFrame)

        setupViews()
        setupObservers()
    }

    /// Initializes the container view with custom services for dependency injection
    /// - Parameters:
    ///   - frame: The frame rectangle for the view
    ///   - featureDependencies: Service registry for business logic dependencies
    public convenience init(frame: CGRect, featureDependencies: EditorFeatureRuntimeDependencies) {
        self.init(frame: frame)
        textView.runtime.update(featureDependencies: featureDependencies)
    }

    public required init?(coder: NSCoder) {
        // Create initialization parameters and views using unified logic
        let parameters = ContainerViewInitializer.InitializationParameters(frame: .zero)
        let components = ContainerViewInitializer.createViews(with: parameters)

        // Initialize view properties
        textView = components.textView
        gutterView = components.gutterView
        minimapView = components.minimapView

        #if canImport(UIKit)
        if let contentView = components.contentView {
            self.contentView = contentView
        } else {
            let logger = CrossPlatformLogger.logger()
            logger.error("Failed to create content view for iOS platform, using fallback")
            self.contentView = EditorContentView()
        }
        #else
        if let scrollView = components.scrollView {
            self.scrollView = scrollView
        } else {
            let logger = CrossPlatformLogger.logger()
            logger.error("Failed to create scroll view for macOS platform, using fallback")
            self.scrollView = NSScrollView(frame: .zero)
        }
        #endif

        super.init(coder: coder)

        setupViews()
        setupObservers()
    }

    // MARK: - Setup

    private func setupViews() {
        // Use unified container view setup
        #if canImport(UIKit)
        let components = ViewComponents(
            textView: textView,
            gutterView: gutterView,
            minimapView: minimapView,
            contentView: contentView
        )
        #else
        let components = ViewComponents(
            textView: textView,
            gutterView: gutterView,
            minimapView: minimapView,
            scrollView: scrollView
        )
        #endif

        // Perform common setup using unified logic
        ContainerViewInitializer.performCommonSetup(for: self, with: components)

        // Setup platform-specific views using unified patterns
        ContainerViewInitializer.setupPlatformViews(for: self, with: components)

        // Platform-specific additional setup
        #if canImport(AppKit)
        // Ensure we don't clip subviews on macOS - minimap might extend beyond bounds
        clipsToBounds = false
        #endif
    }

    private func setupObservers() {
        #if canImport(UIKit)
        setupKeyboardObservers()
        #endif
    }

    // Minimap setup moved to CodeEditorContainerView+Minimap.swift

    // Navigation and minimap update methods moved to CodeEditorContainerView+Minimap.swift

    // MARK: - Layout

    #if canImport(AppKit)
    override public func layout() {
        // Ensure we're on the main thread for layout operations
        if Thread.isMainThread {
            super.layout()
            layoutViews()
        } else {
            // Use Swift concurrency to dispatch to main actor
            Task { @MainActor [weak self] in
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

    func layoutViews() {
        // Delegate to platform-specific implementations
        #if canImport(AppKit)
        layoutViewsAppKit()
        #else
        layoutViewsUIKit()
        #endif

        // Force gutter to update when layout changes
        gutterView.setNeedsDisplayLineNumbers()

        // Update minimap if shown
        if configuration.display.isMinimapVisible {
            updateMinimap()
        }
    }

    // Text container insets method moved to CodeEditorContainerView+Configuration.swift

    // MARK: - Configuration

    /// Updates whether line numbers are shown
    public var showsLineNumbers: Bool {
        get { configuration.display.isLineNumbersEnabled }
        set {
            // Update configuration
            var display = configuration.display
            display.isLineNumbersEnabled = newValue
            configuration = configuration.with(display: display)

            #if canImport(AppKit)
            // On macOS, line numbers are handled by NSRulerView, not GutterView
            // Update the ruler view instead
            updateMacOSRuler()
            #else
            // On iOS, use the GutterView
            gutterView.isHidden = !newValue
            #endif

            updateTextContainerInsets()

            #if canImport(AppKit)
            needsLayout = true
            #else
            setNeedsLayout()
            #endif
        }
    }

    // Configuration application method moved to CodeEditorContainerView+Configuration.swift

    // MARK: - Platform-Specific Extensions

    // iOS-specific keyboard handling moved to CodeEditorContainerView+Keyboard.swift

    deinit {
        // Remove any selector-based observers
        // NotificationCenter automatically removes all observers for an object when it's deallocated
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UIScrollViewDelegate
