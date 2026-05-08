import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
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
        let languageService = businessLogicServices.languageDetectionService
        language = languageService.detectLanguage(fromExtension: fileExtension)
    }

    /// Get all supported file extensions for syntax highlighting
    public var supportedFileExtensions: [String] {
        let languageService = businessLogicServices.languageDetectionService
        return Array(languageService.getAllSupportedExtensions())
    }

    internal var gutterView: GutterView? {
        gutterViewStorage
    }

    // MARK: - IOS Specific Methods

    #if canImport(UIKit)
    #endif

    // MARK: - MacOS Specific Methods

    #if canImport(AppKit)
    override public func toggleRuler(_: Any?) {
        isLineNumbersEnabled.toggle()
    }
    #endif

    // MARK: - Tab Handling

    #if canImport(AppKit)
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

    /// Handles completion item selection from the completion view controller.
    ///
    /// This method is called when a user selects a completion item from the completion popup.
    /// It extracts the appropriate text to insert and performs the text insertion at the
    /// current cursor position, then hides the completion popup.
    ///
    /// ## Implementation Details
    ///
    /// - Extracts insert text from `CompletionItemAdapter` models
    /// - Falls back to empty string for unrecognized item types
    /// - Only inserts non-empty text to prevent unnecessary changes
    /// - Automatically hides the completion popup after insertion
    ///
    /// ## Parameters
    ///
    /// - Parameter controller: The completion view controller (unused)
    /// - Parameter item: The selected completion item containing text to insert
    /// - Parameter movement: The text movement that triggered completion (unused)
    ///
    /// ## Example
    ///
    /// ```swift
    /// // This method is typically called automatically by the completion system
    /// // when users select items from the completion popup
    /// ```
    ///
    /// - SeeAlso: `CompletionItemAdapter`, `hideCompletionPopup()`
    public func completionViewController(
        _: some CompletionViewControllerRepresentable,
        complete item: any CompletionItemView,
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
