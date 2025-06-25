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
    public let showLineNumbers: Bool
    public let highlightSelectedLine: Bool
    public let isEditable: Bool
    
    // Callbacks for handling editor events
    public var onTextChange: ((String) -> Void)?
    public var onSelectionChange: ((NSRange) -> Void)?
    
    public init(
        text: Binding<String>,
        language: Language = .plainText,
        theme: CodeEditorSwiftUITheme = .default,
        showLineNumbers: Bool = true,
        highlightSelectedLine: Bool = true,
        isEditable: Bool = true,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        self._text = text
        self.language = language
        self.theme = theme
        self.showLineNumbers = showLineNumbers
        self.highlightSelectedLine = highlightSelectedLine
        self.isEditable = isEditable
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
    }
    
    // Configuration-based initializer for the sample app
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
        self.showLineNumbers = showLineNumbers
        self.highlightSelectedLine = highlightSelectedLine
        self.isEditable = isEditable
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
    }
    
    public func makeNSView(context: Context) -> CodeEditorView {
        let editorView = CodeEditorView()
        
        // Configure the editor
        editorView.language = language
        editorView.showsLineNumbers = showLineNumbers
        editorView.highlightSelectedLine = highlightSelectedLine
        editorView.isEditable = isEditable
        
        // Set initial text
        editorView.text = text
        
        // Set up simplified delegate using notification observation
        setupNotificationObservers(for: editorView, coordinator: context.coordinator)
        
        return editorView
    }
    
    public func updateNSView(_ nsView: CodeEditorView, context _: Context) {
        // Update text if it changed externally
        if nsView.string != text {
            nsView.string = text
        }
        
        // Update configuration
        nsView.language = language
        nsView.showsLineNumbers = showLineNumbers
        nsView.highlightSelectedLine = highlightSelectedLine
        nsView.isEditable = isEditable
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
    public let showLineNumbers: Bool
    public let highlightSelectedLine: Bool
    public let isEditable: Bool
    public let becomeFirstResponderOnAppear: Bool
    
    // Callbacks for handling editor events
    public var onTextChange: ((String) -> Void)?
    public var onSelectionChange: ((NSRange) -> Void)?
    
    public init(
        text: Binding<String>,
        language: Language = .plainText,
        theme: CodeEditorSwiftUITheme = .default,
        showLineNumbers: Bool = true,
        highlightSelectedLine: Bool = true,
        isEditable: Bool = true,
        becomeFirstResponderOnAppear: Bool = true,
        onTextChange: ((String) -> Void)? = nil,
        onSelectionChange: ((NSRange) -> Void)? = nil
    ) {
        self._text = text
        self.language = language
        self.theme = theme
        self.showLineNumbers = showLineNumbers
        self.highlightSelectedLine = highlightSelectedLine
        self.isEditable = isEditable
        self.becomeFirstResponderOnAppear = becomeFirstResponderOnAppear
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
    }
    
    // Configuration-based initializer for the sample app
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
        self.showLineNumbers = showLineNumbers
        self.highlightSelectedLine = highlightSelectedLine
        self.isEditable = isEditable
        self.becomeFirstResponderOnAppear = isEditable // Automatically enable keyboard when editable
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
    }
    
    public func makeUIView(context: Context) -> CodeEditorContainerView {
        let containerView = CodeEditorContainerView()
        let editorView = containerView.textView
        
        // Configure the editor
        editorView.language = language
        containerView.showsLineNumbers = showLineNumbers
        editorView.highlightSelectedLine = highlightSelectedLine
        editorView.isEditable = isEditable
        
        // Set initial text
        editorView.text = text
        
        // Store container view reference in coordinator
        context.coordinator.containerView = containerView
        
        // Set up simplified delegate using notification observation
        setupNotificationObservers(for: editorView, coordinator: context.coordinator)
        
        // Make the text view focusable by tapping on it when editable
        if isEditable {
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap(_:)))
            editorView.addGestureRecognizer(tapGesture)
        }
        
        // Set up input accessory view to help maintain keyboard
        if isEditable && becomeFirstResponderOnAppear {
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
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable
        ) else {
            return
        }
        
        // Update text if it changed externally
        if uiView.text != text {
            uiView.text = text
        }
        
        // Update configuration
        uiView.language = language
        containerView.showsLineNumbers = showLineNumbers
        uiView.highlightSelectedLine = highlightSelectedLine
        uiView.isEditable = isEditable
        
        // Update coordinator state
        context.coordinator.updateState(
            text: text,
            language: language,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable
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
        private var lastShowLineNumbers: Bool = true
        private var lastHighlightSelectedLine: Bool = true
        private var lastIsEditable: Bool = true
        
        init(_ parent: CodeEditorSwiftUIView) {
            self.parent = parent
        }
        
        func shouldUpdate(
            text: String,
            language: Language,
            showLineNumbers: Bool,
            highlightSelectedLine: Bool,
            isEditable: Bool
        ) -> Bool {
            text != lastText ||
                   language != lastLanguage ||
                   showLineNumbers != lastShowLineNumbers ||
                   highlightSelectedLine != lastHighlightSelectedLine ||
                   isEditable != lastIsEditable
        }
        
        func updateState(
            text: String,
            language: Language,
            showLineNumbers: Bool,
            highlightSelectedLine: Bool,
            isEditable: Bool
        ) {
            lastText = text
            lastLanguage = language
            lastShowLineNumbers = showLineNumbers
            lastHighlightSelectedLine = highlightSelectedLine
            lastIsEditable = isEditable
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
                if textView.isEditable && !textView.isFirstResponder {
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
    /// Set the programming language for syntax highlighting
    public func language(_ language: Language) -> CodeEditorSwiftUIView {
        #if os(iOS) || os(visionOS)
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable,
            becomeFirstResponderOnAppear: becomeFirstResponderOnAppear,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        #else
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        #endif
    }
    
    /// Configure whether line numbers are shown
    public func showLineNumbers(_ show: Bool) -> CodeEditorSwiftUIView {
        #if os(iOS) || os(visionOS)
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: show,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable,
            becomeFirstResponderOnAppear: becomeFirstResponderOnAppear,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        #else
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: show,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        #endif
    }
    
    /// Configure whether the selected line is highlighted
    public func highlightSelectedLine(_ highlight: Bool) -> CodeEditorSwiftUIView {
        #if os(iOS) || os(visionOS)
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlight,
            isEditable: isEditable,
            becomeFirstResponderOnAppear: becomeFirstResponderOnAppear,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        #else
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlight,
            isEditable: isEditable,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        #endif
    }
    
    /// Configure whether the editor is editable
    public func editable(_ editable: Bool) -> CodeEditorSwiftUIView {
        #if os(iOS) || os(visionOS)
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: editable,
            becomeFirstResponderOnAppear: becomeFirstResponderOnAppear,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        #else
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: editable,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        #endif
    }
    
    /// Set a callback for text changes
    public func onTextChange(_ callback: @escaping (String) -> Void) -> CodeEditorSwiftUIView {
        #if os(iOS) || os(visionOS)
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable,
            becomeFirstResponderOnAppear: becomeFirstResponderOnAppear,
            onTextChange: callback,
            onSelectionChange: onSelectionChange
        )
        #else
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable,
            onTextChange: callback,
            onSelectionChange: onSelectionChange
        )
        #endif
    }
    
    /// Set a callback for selection changes
    public func onSelectionChange(_ callback: @escaping (NSRange) -> Void) -> CodeEditorSwiftUIView {
        #if os(iOS) || os(visionOS)
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable,
            becomeFirstResponderOnAppear: becomeFirstResponderOnAppear,
            onTextChange: onTextChange,
            onSelectionChange: callback
        )
        #else
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable,
            onTextChange: onTextChange,
            onSelectionChange: callback
        )
        #endif
    }
    
    /// Configure whether the editor becomes first responder on appear (iOS only)
    public func becomeFirstResponder(_ become: Bool) -> CodeEditorSwiftUIView {
        #if os(iOS) || os(visionOS)
        CodeEditorSwiftUIView(
            text: _text,
            language: language,
            theme: theme,
            showLineNumbers: showLineNumbers,
            highlightSelectedLine: highlightSelectedLine,
            isEditable: isEditable,
            becomeFirstResponderOnAppear: become,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        #else
        // This is iOS-only functionality
        self
        #endif
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
extension EnvironmentValues {
    public var codeEditorTheme: CodeEditorSwiftUITheme {
        get { self[CodeEditorThemeKey.self] }
        set { self[CodeEditorThemeKey.self] = newValue }
    }
}

// MARK: - Convenience View Modifier

@available(macOS 12.0, iOS 16.0, *)
extension View {
    /// Set the code editor theme for this view hierarchy
    public func codeEditorTheme(_ theme: CodeEditorSwiftUITheme) -> some View {
        environment(\.codeEditorTheme, theme)
    }
}

#endif
