//
//  CodeEditorSwiftUICommon.swift
//  CodeEditorPlugin
//
//  Created on 2025-06-27.
//

#if canImport(SwiftUI)
import SwiftUI

// MARK: - Common SwiftUI Types and Extensions

/// Common protocol for platform-specific coordinators
@MainActor
public protocol CodeEditorCoordinator: AnyObject {
    associatedtype Parent: View
    
    var parent: Parent { get set }
    
    func textDidChange(_ notification: Notification)
    func selectionDidChange(_ notification: Notification)
    func cleanup()
}

/// Base implementation for common coordinator functionality
@MainActor
public class BaseCodeEditorCoordinator<Parent: View>: NSObject, CodeEditorCoordinator {
    public var parent: Parent
    
    // State tracking to prevent unnecessary updates
    internal var lastText: String = ""
    internal var lastLanguage: Language = .plainText
    internal var lastConfiguration: EditorConfiguration = .default
    
    public init(_ parent: Parent) {
        self.parent = parent
        super.init()
    }
    
    public func shouldUpdate(
        text: String,
        language: Language,
        configuration: EditorConfiguration
    ) -> Bool {
        text != lastText ||
        language != lastLanguage ||
        configuration != lastConfiguration
    }
    
    public func updateState(
        text: String,
        language: Language,
        configuration: EditorConfiguration
    ) {
        lastText = text
        lastLanguage = language
        lastConfiguration = configuration
    }
    
    @objc public func textDidChange(_: Notification) {
        // Override in subclass
    }
    
    @objc public func selectionDidChange(_: Notification) {
        // Override in subclass
    }
    
    public func cleanup() {
        // NotificationCenter automatically removes observers on dealloc
    }
    
    deinit {
        // NotificationCenter automatically removes observers on dealloc
    }
}

// MARK: - Common View Properties

/// Protocol for common CodeEditorSwiftUIView properties
public protocol CodeEditorSwiftUIViewProtocol: View {
    var text: Binding<String> { get }
    var language: Language { get }
    var theme: CodeEditorSwiftUITheme { get }
    var configuration: EditorConfiguration { get }
    var onTextChange: ((String) -> Void)? { get }
    var onSelectionChange: ((NSRange) -> Void)? { get }
}

// MARK: - Configuration Builder

/// Helper for building configurations from legacy parameters
public enum ConfigurationBuilder {
    public static func build(
        showLineNumbers: Bool = true,
        highlightSelectedLine: Bool = true,
        isEditable: Bool = true,
        showMinimap: Bool = false,
        fontSize: CGFloat = 14.0,
        base: EditorConfiguration = .default
    ) -> EditorConfiguration {
        var config = base
        
        config.display.showLineNumbers = showLineNumbers
        config.display.highlightSelectedLine = highlightSelectedLine
        config.behavior.isEditable = isEditable
        config.display.showMinimap = showMinimap
        config.display.fontSize = fontSize
        
        return config
    }
}

// MARK: - Common Helper Functions

/// Set up notification observers for text changes
@MainActor
public func setupTextChangeObservers<T: BaseCodeEditorCoordinator<Parent>, Parent>(
    for textView: CodeEditorView,
    coordinator: T
) {
    #if canImport(AppKit)
    NotificationCenter.default.addObserver(
        coordinator,
        selector: #selector(T.textDidChange(_:)),
        name: NSText.didChangeNotification,
        object: textView
    )
    
    NotificationCenter.default.addObserver(
        coordinator,
        selector: #selector(T.selectionDidChange(_:)),
        name: NSTextView.didChangeSelectionNotification,
        object: textView
    )
    #else
    NotificationCenter.default.addObserver(
        coordinator,
        selector: #selector(T.textDidChange(_:)),
        name: UITextView.textDidChangeNotification,
        object: textView
    )
    
    // Note: iOS doesn't have the same selection change notification as macOS
    // Selection changes would need to be handled differently
    #endif
}

// MARK: - Common Update Logic

/// Apply common updates to a text view
@MainActor
public func updateTextView(
    _ textView: CodeEditorView,
    text: String,
    language: Language,
    configuration: EditorConfiguration
) {
    // Update text if it changed externally
    if textView.text != text {
        textView.text = text
    }
    
    // Apply configuration
    configuration.apply(to: textView)
    
    // Update language
    textView.language = language
}

// MARK: - Minimap Support

@MainActor
public protocol MinimapSupport: AnyObject {
    var minimapView: MinimapView? { get set }
    var minimapDataProvider: MinimapDataProvider? { get set }
    
    func setupMinimap(for textView: CodeEditorView, in containerView: PlatformView)
    func updateMinimapVisibility(_ shouldShow: Bool)
    func updateMinimap()
    func navigateToLine(_ lineNumber: Int, in textView: CodeEditorView)
}

extension MinimapSupport {
    public func setupMinimap(for textView: CodeEditorView, in containerView: PlatformView) {
        // Create minimap
        let minimap = MinimapView()
        minimapView = minimap
        
        // Create data provider
        minimapDataProvider = MinimapDataProvider(textView: textView)
        
        // Set up navigation callback
        minimap.onNavigate = { [weak self] lineNumber in
            self?.navigateToLine(lineNumber, in: textView)
        }
        
        // Add to container
        containerView.addSubview(minimap)
        
        // Set up observers
        #if canImport(AppKit)
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
    }
    
    public func updateMinimapVisibility(_ shouldShow: Bool) {
        if shouldShow && minimapView == nil {
            // Minimap needs to be set up - this should be handled by the specific implementation
            return
        }
        minimapView?.isHidden = !shouldShow
    }
    
    public func updateMinimap() {
        guard let minimapView,
              let dataProvider = minimapDataProvider,
              let data = dataProvider.generateData() else {
            return
        }
        
        minimapView.updateData(data)
    }
    
    public func navigateToLine(_ lineNumber: Int, in textView: CodeEditorView) {
        let text = textView.text ?? ""
        let lines = text.components(separatedBy: .newlines)
        
        guard lineNumber < lines.count else { return }
        
        // Calculate character position for the line
        let lineStart = lines.prefix(lineNumber).joined(separator: "\n").count
        let targetPosition = lineNumber > 0 ? lineStart + 1 : lineStart
        
        // Navigate to position
        #if canImport(AppKit)
        let nsRange = NSRange(location: targetPosition, length: 0)
        textView.setSelectedRange(nsRange)
        textView.scrollRangeToVisible(nsRange)
        #else
        if let position = textView.position(from: textView.beginningOfDocument, offset: targetPosition) {
            textView.selectedTextRange = textView.textRange(from: position, to: position)
            
            // Scroll to make the line visible
            let rect = textView.caretRect(for: position)
            textView.scrollRectToVisible(rect, animated: true)
        }
        #endif
    }
}

#endif
