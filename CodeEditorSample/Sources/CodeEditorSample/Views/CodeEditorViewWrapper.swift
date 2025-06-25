#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import CodeEditorPlugin
import SwiftUI

// MARK: - CodeEditorViewWrapper

#if canImport(AppKit)
struct CodeEditorViewWrapper: View {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: ((CodeEditorView) -> Void)?

    init(
        configuration: EditorConfiguration,
        text: Binding<String>,
        language: String,
        onTextViewReady: ((CodeEditorView) -> Void)? = nil
    ) {
        self.configuration = configuration
        self._text = text
        self.language = language
        self.onTextViewReady = onTextViewReady
    }

    var body: some View {
        UnifiedCodeEditorView(
            configuration: configuration,
            text: $text,
            language: language,
            onTextViewReady: onTextViewReady
        )
        .background(Color(configuration.theme.backgroundColor))
    }
}

// MARK: - UnifiedCodeEditorView

struct UnifiedCodeEditorView: NSViewRepresentable {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: ((CodeEditorView) -> Void)?

    func makeNSView(context: Context) -> NSScrollView {
        // Create NSScrollView
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !configuration.wrapLines
        scrollView.autohidesScrollers = false
        scrollView.borderType = .noBorder
        
        // Configure smooth scrolling
        if configuration.smoothScrolling {
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScrollElasticity = .automatic
            scrollView.horizontalScrollElasticity = .automatic
        } else {
            scrollView.scrollerStyle = .legacy
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
        }

        let textView = CodeEditorView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))

        // Set delegate
        textView.textDelegate = context.coordinator

        // Set the text content
        textView.text = text

        // Apply configuration
        applyConfiguration(to: textView)
        
        // Set up annotation manager if enabled
        if configuration.enableAnnotations {
            context.coordinator.annotationManager = AnnotationManager(textView: textView)
            context.coordinator.annotationManager?.scanForAnnotations()
        }

        // Configure text view for scroll view based on word wrap setting
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !configuration.wrapLines
        textView.textContainer?.widthTracksTextView = configuration.wrapLines
        textView.textContainer?.heightTracksTextView = false
        
        // Set container width for non-wrapping mode
        if !configuration.wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        // Set the text view as the document view
        scrollView.documentView = textView

        // Ensure the text view is properly laid out
        textView.invalidateIntrinsicContentSize()
        textView.needsLayout = true
        textView.needsDisplay = true

        // Notify that text view is ready if callback provided
        onTextViewReady?(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? CodeEditorView else { return }
        
        // Update text if changed
        if textView.text != text {
            textView.text = text
        }

        // Update configuration
        applyConfiguration(to: textView)
        
        // Update scroll view settings based on word wrap
        scrollView.hasHorizontalScroller = !configuration.wrapLines
        
        // Update smooth scrolling settings
        if configuration.smoothScrolling {
            scrollView.scrollerStyle = .overlay
            scrollView.verticalScrollElasticity = .automatic
            scrollView.horizontalScrollElasticity = .automatic
        } else {
            scrollView.scrollerStyle = .legacy
            scrollView.verticalScrollElasticity = .none
            scrollView.horizontalScrollElasticity = .none
        }
        
        // Update text container settings for word wrap
        textView.isHorizontallyResizable = !configuration.wrapLines
        textView.textContainer?.widthTracksTextView = configuration.wrapLines
        
        // Set container width for non-wrapping mode
        if !configuration.wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            // Reset container size for wrapping mode
            if let scrollViewWidth = scrollView.enclosingScrollView?.contentSize.width {
                textView.textContainer?.containerSize = NSSize(
                    width: scrollViewWidth,
                    height: CGFloat.greatestFiniteMagnitude
                )
            }
        }
        
        // Update annotations
        if configuration.enableAnnotations {
            if context.coordinator.annotationManager == nil {
                context.coordinator.annotationManager = AnnotationManager(textView: textView)
            }
            context.coordinator.annotationManager?.scanForAnnotations()
        } else {
            // Clear annotations if disabled
            context.coordinator.annotationManager?.clearAnnotations()
            context.coordinator.annotationManager = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyConfiguration(to textView: CodeEditorView) {
        // Basic settings
        textView.isEditable = configuration.isEditable
        textView.isSelectable = true
        textView.allowsUndo = true

        // Line numbers
        textView.showsLineNumbers = configuration.showLineNumbers

        // Font
        textView.font = NSFont.monospacedSystemFont(
            ofSize: configuration.fontSize,
            weight: .regular
        )

        // Colors
        textView.textColor = configuration.theme.textColor
        textView.backgroundColor = configuration.theme.backgroundColor
        textView.selectedLineHighlightColor = configuration.theme.selectedLineColor
        textView.insertionPointColor = configuration.insertionPointColor
        
        // Selection attributes based on theme
        textView.selectedTextAttributes = [
            .backgroundColor: PlatformColor.selectedTextBackgroundColor,
            .foregroundColor: PlatformColor.selectedTextColor
        ]

        // Line highlighting
        textView.highlightSelectedLine = configuration.highlightSelectedLine

        // Invisible characters
        textView.showsInvisibleCharacters = configuration.showInvisibleCharacters

        // Text container settings
        textView.textContainerInset = configuration.textContainerInset
        textView.textContainer?.lineFragmentPadding = configuration.lineFragmentPadding

        // Make sure the text view is properly sized
        textView.isVerticallyResizable = true

        // Tab settings
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.tabStops = []
        paragraphStyle.defaultTabInterval = CGFloat(configuration.tabWidth) * 7.0
        paragraphStyle.lineSpacing = configuration.lineSpacing
        textView.defaultParagraphStyle = paragraphStyle
        
        // Text processing settings
        textView.isContinuousSpellCheckingEnabled = configuration.isContinuousSpellCheckingEnabled
        textView.isGrammarCheckingEnabled = configuration.isGrammarCheckingEnabled
        textView.isAutomaticQuoteSubstitutionEnabled = configuration.isAutomaticQuoteSubstitutionEnabled
        textView.isAutomaticDashSubstitutionEnabled = configuration.isAutomaticDashSubstitutionEnabled
        textView.isAutomaticTextReplacementEnabled = configuration.isAutomaticTextReplacementEnabled
        textView.isAutomaticSpellingCorrectionEnabled = configuration.isAutomaticSpellingCorrectionEnabled
        textView.isAutomaticTextCompletionEnabled = configuration.isAutomaticTextCompletionEnabled
        textView.isIncrementalSearchingEnabled = configuration.isIncrementalSearchingEnabled
        
        // Advanced text settings
        textView.allowsDocumentBackgroundColorChange = configuration.allowsDocumentBackgroundColorChange
        textView.allowsImageEditing = configuration.allowsImageEditing
        textView.allowsCharacterPickerTouchBarItem = configuration.allowsCharacterPickerTouchBarItem
        textView.isRichText = configuration.isRichText
        textView.importsGraphics = configuration.importsGraphics
        textView.usesInspectorBar = configuration.usesInspectorBar
        textView.usesFindBar = configuration.usesFindBar
        // Note: allowsNonContiguousLayout is not available on CodeEditorView
        textView.displaysLinkToolTips = configuration.displaysLinkToolTips
        
        // Performance settings
        if configuration.useHardwareAcceleration {
            textView.wantsLayer = true
            textView.layer?.drawsAsynchronously = true
        }

        // Set language for syntax highlighting using file extension
        textView.setLanguage(fileExtension: language)
    }

    // MARK: - Coordinator

    @MainActor
    class Coordinator: NSObject, @preconcurrency CodeEditorViewDelegate {
        var parent: UnifiedCodeEditorView
        var annotationManager: AnnotationManager?

        init(_ parent: UnifiedCodeEditorView) {
            self.parent = parent
            super.init()
        }

        // MARK: - CodeEditorViewDelegate

        func undoManager(for _: CodeEditorView) -> UndoManager? {
            nil
        }

        func textViewWillChangeText(_: Notification) {
            // Default implementation
        }

        func textViewDidChangeText(_ notification: Notification) {
            if let textView = notification.object as? CodeEditorView {
                parent.text = textView.text ?? ""
                
                // Re-scan for annotations if enabled
                if parent.configuration.enableAnnotations {
                    annotationManager?.scanForAnnotations()
                }
            }
        }

        func textViewDidChangeSelection(_: Notification) {
            // Handle selection changes if needed
        }

        func textView(
            _ textView: CodeEditorView,
            shouldChangeTextIn affectedCharRange: NSTextRange,
            replacementString: String?
        ) -> Bool {
            guard replacementString != nil else { return true }
            
            // Note: Tab handling and auto-indent would require deeper integration with CodeEditorView's
            // text system. For now, these features are documented but not implemented.
            
            return true
        }

        func textView(
            _ textView: CodeEditorView,
            willChangeTextIn affectedCharRange: NSTextRange,
            replacementString: String
        ) {
            // Default implementation
        }

        func textView(
            _: CodeEditorView,
            didChangeTextIn _: NSTextRange,
            replacementString _: String
        ) {
            // Default implementation
        }

        func textView(_: CodeEditorView, clickedOnLink _: Any, at _: any NSTextLocation) -> Bool {
            false
        }

        func textView(_: CodeEditorView, insertCompletionItem _: any CompletionItem) {
            // Default implementation
        }

        func textViewCompletionViewController(_: CodeEditorView) -> any CompletionViewControllerProtocol {
            fatalError("Completion view controller not implemented")
        }

        func textViewInsertionPointView(
            _: CodeEditorView,
            frame _: CGRect
        ) -> (any InsertionPointIndicatorProtocol)? {
            nil
        }

        func textView(
            _: CodeEditorView,
            clickedOnAttachment _: NSTextAttachment,
            at _: any NSTextLocation
        ) -> Bool {
            false
        }

        func textView(
            _: CodeEditorView,
            shouldAllowInteractionWith _: NSTextAttachment,
            at _: any NSTextLocation
        ) -> Bool {
            true
        }
    }
}
#endif

// MARK: - iOS Implementation

#if canImport(UIKit)
struct CodeEditorViewWrapper: View {
    let configuration: EditorConfiguration
    @Binding var text: String
    let language: String
    let onTextViewReady: ((CodeEditorView) -> Void)?

    init(
        configuration: EditorConfiguration,
        text: Binding<String>,
        language: String,
        onTextViewReady: ((CodeEditorView) -> Void)? = nil
    ) {
        self.configuration = configuration
        self._text = text
        self.language = language
        self.onTextViewReady = onTextViewReady
    }

    var body: some View {
        // Use the actual CodeEditorSwiftUIView implementation
        CodeEditorSwiftUIView(
            text: $text,
            language: detectLanguage(from: language),
            showLineNumbers: configuration.showLineNumbers,
            highlightSelectedLine: configuration.highlightSelectedLine,
            isEditable: configuration.isEditable,
            becomeFirstResponderOnAppear: configuration.isEditable
        )
    }
    
    private func detectLanguage(from fileExtension: String) -> Language {
        switch fileExtension.lowercased() {
        case "swift":
            return .swift
        case "py", "python":
            return .python
        case "js", "javascript":
            return .javascript
        case "json":
            return .json
        default:
            return .plainText
        }
    }
}
#endif
