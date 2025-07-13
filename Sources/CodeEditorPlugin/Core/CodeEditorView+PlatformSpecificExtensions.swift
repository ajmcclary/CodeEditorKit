import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Platform-Specific Methods

extension CodeEditorView {
    // MARK: - Convenience Methods
    
    /// Set the programming language for syntax highlighting
    /// Sets the programming language based on a file extension.
    ///
    /// This method automatically detects the appropriate language from common file extensions
    /// and applies the corresponding syntax highlighting rules.
    ///
    /// - Parameter fileExtension: The file extension (with or without leading dot)
    ///
    /// ## Supported Extensions
    ///
    /// - **Swift**: .swift
    /// - **Python**: .py, .pyw
    /// - **JavaScript**: .js, .mjs, .cjs
    /// - **TypeScript**: .ts, .tsx
    /// - **HTML**: .html, .htm
    /// - **CSS**: .css, .scss, .sass
    /// - **JSON**: .json
    /// - **And many more...**
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Set language from file extension
    /// editor.setLanguage(fileExtension: "swift")
    /// editor.setLanguage(fileExtension: ".py")
    /// 
    /// // Language detection from file path
    /// let url = URL(fileURLWithPath: "/path/to/script.js")
    /// editor.setLanguage(fileExtension: url.pathExtension)
    /// ```
    ///
    /// - Note: If the extension is not recognized, the language defaults to `.plainText`
    ///
    /// - SeeAlso: `language`, `Language`
    public func setLanguage(fileExtension: String) {
        let languageService = BusinessLogic.languageDetection
        language = languageService.detectLanguage(fromExtension: fileExtension)
    }

    /// Get all supported file extensions for syntax highlighting
    public var supportedFileExtensions: [String] {
        let languageService = BusinessLogic.languageDetection
        return Array(languageService.getAllSupportedExtensions())
    }
    
    internal var gutterView: GutterView? {
        gutterViewStorage
    }
    
    // MARK: - IOS Specific Methods
    
    #if canImport(UIKit)
    override open func didMoveToWindow() {
        super.didMoveToWindow()
        
        #if targetEnvironment(macCatalyst)
        // On Mac Catalyst, we need to reapply text color when the view is added to window
        if window != nil {
            // Apply immediately
            applyTextColorForMacCatalyst()
            
            // Also apply after a short delay to ensure view hierarchy is ready
            Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    self?.applyTextColorForMacCatalyst()
                } catch {
                    // Sleep was cancelled, ignore
                }
            }
        }
        #endif
    }
    #endif
    
    // MARK: - MacOS Specific Methods
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    override public func toggleRuler(_: Any?) {
        isLineNumbersEnabled.toggle()
    }
    #endif
    
    // MARK: - Tab Handling
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Handle tab key press for macOS
    override public func insertTab(_ sender: Any?) {
        if configuration.layout.insertSpacesForTabs {
            // Insert spaces instead of a tab character
            let spaces = String(repeating: " ", count: configuration.layout.tabWidth)
            insertText(spaces)
        } else {
            // Insert a regular tab character
            super.insertTab(sender)
        }
    }
    
    /// Handle backtab (shift+tab) for macOS
    override public func insertBacktab(_ sender: Any?) {
        if configuration.layout.insertSpacesForTabs {
            // Remove up to tabWidth spaces before cursor
            let tabWidth = configuration.layout.tabWidth
            guard let textStorage = self.textStorage else {
                super.insertBacktab(sender)
                return
            }
            
            let currentRange = selectedRange()
            guard currentRange.location > 0 else {
                super.insertBacktab(sender)
                return
            }
            
            // Look backwards to find spaces to remove
            let maxCheck = min(tabWidth, currentRange.location)
            let checkRange = NSRange(location: currentRange.location - maxCheck, length: maxCheck)
            let text = textStorage.string
            guard let range = Range(checkRange, in: text) else {
                super.insertBacktab(sender)
                return
            }
            let substring = String(text[range])
            
            // Count trailing spaces
            var spacesToRemove = 0
            for char in substring.reversed() {
                if char == " " {
                    spacesToRemove += 1
                } else {
                    break
                }
            }
            
            if spacesToRemove > 0 {
                let removeRange = NSRange(location: currentRange.location - spacesToRemove, length: spacesToRemove)
                replaceCharacters(in: removeRange, with: "")
            } else {
                super.insertBacktab(sender)
            }
        } else {
            super.insertBacktab(sender)
        }
    }
    #endif
    
    // MARK: - Notifications
    
    /// Custom notification for CodeEditorView selection changes
    public static let codeEditorViewDidChangeSelectionNotification = Notification
        .Name("CodeEditorViewDidChangeSelectionNotification")
        
    // MARK: - CompletionViewControllerDelegate
    
    public func completionViewController(
        _: some CompletionViewControllerRepresentable,
        complete item: any CompletionItem,
        movement _: PlatformTextMovement
    ) {
        // Get the insert text based on the item type
        let textToInsert: String
        if let adapter = item as? CompletionItemAdapter {
            textToInsert = adapter.model.insertText
        } else {
            // Fallback - use a default or empty string
            textToInsert = ""
        }
        
        // Insert the completion text if not empty
        if !textToInsert.isEmpty {
            insertText(textToInsert)
        }
        
        // Hide the completion window
        hideCompletionPopup()
    }
}
