#if canImport(SwiftUI)
import SwiftUI

#if os(macOS) && !targetEnvironment(macCatalyst)
import AppKit

/// SwiftUI wrapper for CodeEditorView on macOS
@available(macOS 12.0, *)
public struct CodeEditorSwiftUIView: NSViewRepresentable {
    @Binding public var text: String
    public let language: Language
    public let theme: CodeEditorSwiftUITheme
    public let configuration: EditorConfiguration
    
    // Callbacks for handling editor events
    public var onTextChange: ((String) -> Void)?
    public var onSelectionChange: ((NSRange) -> Void)?
    
    public init(
        text: Binding<String>,
        language: Language = .plainText,
        theme: CodeEditorSwiftUITheme = .default,
        configuration: EditorConfiguration = .default,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        self._text = text
        self.language = language
        self.theme = theme
        self.configuration = configuration
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
    }
    
    // Legacy compatibility initializer 
    public init(
        text: Binding<String>,
        showLineNumbers: Bool,
        highlightSelectedLine: Bool,
        isEditable: Bool,
        language: Language = .plainText,
        theme: CodeEditorSwiftUITheme = .default,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        self._text = text
        self.language = language
        self.theme = theme
        
        // Create configuration from individual parameters
        var config = EditorConfiguration.default
        config.display.showLineNumbers = showLineNumbers
        config.display.highlightSelectedLine = highlightSelectedLine
        config.behavior.isEditable = isEditable
        self.configuration = config
        
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
    }
    
    public func makeNSView(context: Context) -> NSView {
        // Create container view for editor and minimap
        let containerView = NSView()
        let editorView = CodeEditorView()
        
        // Store references in coordinator
        context.coordinator.editorView = editorView
        context.coordinator.containerView = containerView
        
        // Apply configuration
        configuration.apply(to: editorView)
        
        // Configure the editor
        editorView.language = language
        
        // Set initial text
        editorView.text = text
        
        // Add editor to container
        containerView.addSubview(editorView)
        
        // Set up minimap if enabled
        if configuration.display.showMinimap {
            context.coordinator.setupMinimap()
        }
        
        // Set up simplified delegate using notification observation
        setupNotificationObservers(for: editorView, coordinator: context.coordinator)
        
        return containerView
    }
    
    public func updateNSView(_: NSView, context: Context) {
        guard let editorView = context.coordinator.editorView else { return }
        
        // Update text if it changed externally
        if editorView.string != text {
            editorView.string = text
        }
        
        // Apply configuration updates
        configuration.apply(to: editorView)
        
        // Update language
        editorView.language = language
        
        // Update minimap if needed
        context.coordinator.updateMinimapVisibility(configuration.display.showMinimap)
        context.coordinator.layoutViews()
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setupNotificationObservers(for editorView: CodeEditorView, coordinator: Coordinator) {
        // Use NotificationCenter instead of delegate for simplicity
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(coordinator.textDidChange(_:)),
            name: NSText.didChangeNotification,
            object: editorView
        )
        
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(coordinator.selectionDidChange(_:)),
            name: NSTextView.didChangeSelectionNotification,
            object: editorView
        )
    }
    
    @MainActor
    public class Coordinator: NSObject {
        var parent: CodeEditorSwiftUIView
        weak var containerView: NSView?
        weak var editorView: CodeEditorView?
        private var minimapView: MinimapView?
        private var minimapDataProvider: MinimapDataProvider?
        
        init(_ parent: CodeEditorSwiftUIView) {
            self.parent = parent
        }
        
        @objc func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CodeEditorView else { return }
            let newText = textView.text ?? ""
            if parent.text != newText {
                parent.text = newText
                parent.onTextChange?(newText)
            }
        }
        
        @objc func selectionDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CodeEditorView else { return }
            let selectedRange = textView.selectedRange()
            parent.onSelectionChange?(selectedRange)
        }
        
        func setupMinimap() {
            guard let editorView,
                  let containerView else { return }
            
            // Create minimap
            let minimap = MinimapView()
            minimapView = minimap
            
            // Create data provider
            minimapDataProvider = MinimapDataProvider(textView: editorView)
            
            // Set up navigation callback
            minimap.onNavigate = { [weak self] lineNumber in
                self?.navigateToLine(lineNumber)
            }
            
            // Add to container
            containerView.addSubview(minimap)
            
            // Set up observers
            NotificationCenter.default.addObserver(
                forName: NSText.didChangeNotification,
                object: editorView,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.updateMinimap()
                }
            }
        }
        
        func updateMinimapVisibility(_ shouldShow: Bool) {
            if shouldShow && minimapView == nil {
                setupMinimap()
            }
            minimapView?.isHidden = !shouldShow
        }
        
        func layoutViews() {
            guard let containerView,
                  let editorView else { return }
            
            let bounds = containerView.bounds
            let minimapWidth: CGFloat = (minimapView?.isHidden == false) ? 120 : 0
            
            // Layout editor
            editorView.frame = CGRect(
                x: 0,
                y: 0,
                width: bounds.width - minimapWidth,
                height: bounds.height
            )
            
            // Layout minimap
            if let minimapView, !minimapView.isHidden {
                minimapView.frame = CGRect(
                    x: bounds.width - minimapWidth,
                    y: 0,
                    width: minimapWidth,
                    height: bounds.height
                )
                updateMinimap()
            }
        }
        
        private func navigateToLine(_ lineNumber: Int) {
            guard let editorView else { return }
            
            let text = editorView.text ?? ""
            let lines = text.components(separatedBy: .newlines)
            
            guard lineNumber < lines.count else { return }
            
            // Calculate character position for the line
            let lineStart = lines.prefix(lineNumber).joined(separator: "\n").count
            let targetPosition = lineNumber > 0 ? lineStart + 1 : lineStart
            
            // Navigate to position  
            let nsRange = NSRange(location: targetPosition, length: 0)
            editorView.setSelectedRange(nsRange)
            editorView.scrollRangeToVisible(nsRange)
        }
        
        private func updateMinimap() {
            guard let minimapView,
                  let dataProvider = minimapDataProvider,
                  let data = dataProvider.generateData() else {
                return
            }
            
            minimapView.updateData(data)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

#elseif os(iOS) || os(visionOS)
import UIKit

/// SwiftUI wrapper for CodeEditorView on iOS/iPadOS
@available(iOS 16.0, *)
public struct CodeEditorSwiftUIView: UIViewRepresentable {
    public typealias UIViewType = CodeEditorContainerView
    
    @Binding public var text: String
    public let language: Language
    public let theme: CodeEditorSwiftUITheme
    public let configuration: EditorConfiguration
    
    // Environment values
    @Environment(\.codeEditorBecomeFirstResponder) private var becomeFirstResponderOnAppear
    
    // Callbacks for handling editor events
    public var onTextChange: ((String) -> Void)?
    public var onSelectionChange: ((NSRange) -> Void)?
    
    public init(
        text: Binding<String>,
        language: Language = .plainText,
        theme: CodeEditorSwiftUITheme = .default,
        configuration: EditorConfiguration = .default,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        self._text = text
        self.language = language
        self.theme = theme
        self.configuration = configuration
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
    }
    
    // Legacy compatibility initializer 
    public init(
        text: Binding<String>,
        showLineNumbers: Bool,
        highlightSelectedLine: Bool,
        isEditable: Bool,
        language: Language = .plainText,
        theme: CodeEditorSwiftUITheme = .default,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        self._text = text
        self.language = language
        self.theme = theme
        
        // Create configuration from individual parameters
        var config = EditorConfiguration.default
        config.display.showLineNumbers = showLineNumbers
        config.display.highlightSelectedLine = highlightSelectedLine
        config.behavior.isEditable = isEditable
        self.configuration = config
        
        // becomeFirstResponderOnAppear is now handled via environment
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
    }
    
    public func makeUIView(context: Context) -> CodeEditorContainerView {
        let containerView = CodeEditorContainerView()
        let editorView = containerView.textView
        
        // Apply configuration
        containerView.configuration = configuration
        
        // Configure the editor
        editorView.language = language
        
        // Set initial text
        editorView.text = text
        
        // Store container view reference in coordinator
        context.coordinator.containerView = containerView
        
        // Set up simplified delegate using notification observation
        setupNotificationObservers(for: editorView, coordinator: context.coordinator)
        
        // Make the text view focusable by tapping on it when editable
        if configuration.behavior.isEditable {
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
            editorView.addGestureRecognizer(tapGesture)
        }
        
        // Set up input accessory view to help maintain keyboard
        if configuration.behavior.isEditable && becomeFirstResponderOnAppear {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()
            let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(context.coordinator.doneButtonTapped))
            let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            toolbar.setItems([flexSpace, doneButton], animated: false)
            editorView.inputAccessoryView = toolbar
        }
        
        // Ensure the text view can scroll properly
        editorView.alwaysBounceVertical = true
        editorView.showsVerticalScrollIndicator = true
        
        return containerView
    }
    
    public func updateUIView(_ containerView: CodeEditorContainerView, context: Context) {
        let uiView = containerView.textView
        
        // Prevent update storms that can interfere with first responder
        guard context.coordinator.shouldUpdate(
            text: text,
            language: language,
            configuration: configuration
        ) else {
            return
        }
        
        // Update text if it changed externally
        if uiView.text != text {
            uiView.text = text
        }
        
        // Apply configuration updates
        containerView.configuration = configuration
        
        // Update language
        uiView.language = language
        
        // Update coordinator state
        context.coordinator.updateState(
            text: text,
            language: language,
            configuration: configuration
        )
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func setupNotificationObservers(for editorView: CodeEditorView, coordinator: Coordinator) {
        // Store reference to container view in coordinator
        // This is done in makeUIView instead
        
        // Use NotificationCenter instead of delegate for simplicity
        NotificationCenter.default.addObserver(
            coordinator,
            selector: #selector(coordinator.textDidChange(_:)),
            name: UITextView.textDidChangeNotification,
            object: editorView
        )
        
        // Note: iOS doesn't have the same selection change notification as macOS
        // We could use a timer-based approach or KVO for selection changes if needed
    }
    
    @MainActor
    public class Coordinator: NSObject {
        var parent: CodeEditorSwiftUIView
        weak var containerView: CodeEditorContainerView?
        
        // State tracking to prevent unnecessary updates
        private var lastText: String = ""
        private var lastLanguage: Language = .plainText
        private var lastConfiguration: EditorConfiguration = .default
        
        init(_ parent: CodeEditorSwiftUIView) {
            self.parent = parent
        }
        
        func shouldUpdate(
            text: String,
            language: Language,
            configuration: EditorConfiguration
        ) -> Bool {
            text != lastText ||
                   language != lastLanguage ||
                   configuration != lastConfiguration
        }
        
        func updateState(
            text: String,
            language: Language,
            configuration: EditorConfiguration
        ) {
            lastText = text
            lastLanguage = language
            lastConfiguration = configuration
        }
        
        @objc func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? CodeEditorView else { return }
            let newText = textView.text ?? ""
            if parent.text != newText {
                parent.text = newText
                parent.onTextChange?(newText)
            }
        }
        
        @objc func doneButtonTapped() {
            // Find the text view and resign first responder
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.endEditing(true)
            }
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            if let textView = gesture.view as? CodeEditorView {
                if textView.configuration.behavior.isEditable && !textView.isFirstResponder {
                    _ = textView.becomeFirstResponder()
                }
            }
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}

#endif

// MARK: - SwiftUI Modifiers

@available(macOS 12.0, iOS 16.0, *)
// swiftlint:disable:next no_grouping_extension
extension CodeEditorSwiftUIView {
    /// Helper method to create a new instance with modified configuration
    private func with(configuration newConfig: EditorConfiguration) -> CodeEditorSwiftUIView {
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            configuration: newConfig,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
    }
    /// Set the programming language for syntax highlighting
    public func language(_ language: Language) -> CodeEditorSwiftUIView {
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            configuration: configuration,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
    }
    
    /// Configure whether line numbers are shown
    public func showLineNumbers(_ show: Bool) -> CodeEditorSwiftUIView {
        var newConfig = configuration
        newConfig.display.showLineNumbers = show
        return with(configuration: newConfig)
    }
    
    /// Configure whether the selected line is highlighted
    public func highlightSelectedLine(_ highlight: Bool) -> CodeEditorSwiftUIView {
        var newConfig = configuration
        newConfig.display.highlightSelectedLine = highlight
        return with(configuration: newConfig)
    }
    
    /// Configure whether the editor is editable
    public func editable(_ editable: Bool) -> CodeEditorSwiftUIView {
        var newConfig = configuration
        newConfig.behavior.isEditable = editable
        return with(configuration: newConfig)
    }
    
    /// Set a callback for text changes
    public func onTextChange(_ callback: @escaping (String) -> Void) -> CodeEditorSwiftUIView {
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            configuration: configuration,
            onTextChange: callback,
            onSelectionChange: onSelectionChange
        )
    }
    
    /// Set a callback for selection changes
    public func onSelectionChange(_ callback: @escaping (NSRange) -> Void) -> CodeEditorSwiftUIView {
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            configuration: configuration,
            onTextChange: onTextChange,
            onSelectionChange: callback
        )
    }
    
    /// Configure whether the editor becomes first responder on appear (iOS only)
    public func becomeFirstResponder(_ become: Bool) -> some View {
        #if os(iOS) || os(visionOS)
        self.environment(\.codeEditorBecomeFirstResponder, become)
        #else
        // This is iOS-only functionality
        self
        #endif
    }
    
    /// Configure whether to show the minimap
    public func showMinimap(_ show: Bool) -> CodeEditorSwiftUIView {
        var newConfig = configuration
        newConfig.display.showMinimap = show
        return with(configuration: newConfig)
    }
}

// MARK: - SwiftUI Theme Support

@available(macOS 12.0, iOS 16.0, *)
public struct CodeEditorSwiftUITheme: Sendable, Hashable {
    public let backgroundColor: Color
    public let textColor: Color
    public let lineNumberColor: Color
    public let selectedLineColor: Color
    public let name: String
    
    public init(
        name: String = "default",
        backgroundColor: Color = Color.clear,
        textColor: Color = Color.primary,
        lineNumberColor: Color = Color.secondary,
        selectedLineColor: Color = Color.accentColor.opacity(0.1)
    ) {
        self.name = name
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.lineNumberColor = lineNumberColor
        self.selectedLineColor = selectedLineColor
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name
    }
    
    public static let `default` = Self(name: "default")
    
    public static let dark: Self = {
        #if os(macOS)
        return Self(
            name: "dark",
            backgroundColor: Color(.controlBackgroundColor),
            textColor: .white,
            lineNumberColor: .gray,
            selectedLineColor: .blue.opacity(0.2)
        )
        #else
        return Self(
            name: "dark",
            backgroundColor: Color(.systemBackground),
            textColor: .white,
            lineNumberColor: .gray,
            selectedLineColor: .blue.opacity(0.2)
        )
        #endif
    }()
}

// MARK: - SwiftUI Environment Support

@available(macOS 12.0, iOS 16.0, *)
public struct CodeEditorThemeKey: EnvironmentKey {
    public static let defaultValue: CodeEditorSwiftUITheme = .default
    
    public typealias Value = CodeEditorSwiftUITheme
}

@available(macOS 12.0, iOS 16.0, *)
public struct CodeEditorBecomeFirstResponderKey: EnvironmentKey {
    public static let defaultValue: Bool = true
    
    public typealias Value = Bool
}

@available(macOS 12.0, iOS 16.0, *)
extension EnvironmentValues {
    public var codeEditorTheme: CodeEditorSwiftUITheme {
        get { self[CodeEditorThemeKey.self] }
        set { self[CodeEditorThemeKey.self] = newValue }
    }
    
    public var codeEditorBecomeFirstResponder: Bool {
        get { self[CodeEditorBecomeFirstResponderKey.self] }
        set { self[CodeEditorBecomeFirstResponderKey.self] = newValue }
    }
}

// MARK: - Convenience View Modifier

@available(macOS 12.0, iOS 16.0, *)
extension View {
    /// Set the code editor theme for this view hierarchy
    public func codeEditorTheme(_ theme: CodeEditorSwiftUITheme) -> some View {
        environment(\.codeEditorTheme, theme)
    }
    
    /// Configure whether code editors become first responder on appear (iOS only)
    public func codeEditorBecomeFirstResponder(_ become: Bool = true) -> some View {
        environment(\.codeEditorBecomeFirstResponder, become)
    }
}

#endif
