import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

// MARK: - Accessibility Support

extension CodeEditorView {
    /// Set up accessibility properties for the code editor
    internal func setupAccessibility() {
        #if canImport(UIKit)
        setupAccessibilityUIKit()
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
        setupAccessibilityAppKit()
        #endif
    }

    #if canImport(UIKit)
    private func setupAccessibilityUIKit() {
        // Basic accessibility configuration
        isAccessibilityElement = true
        accessibilityTraits = [.allowsDirectInteraction, .updatesFrequently]

        // Set initial accessibility label and hint
        updateAccessibilityLabel()
        accessibilityHint = "Code editor. Use VoiceOver typing mode to edit code."

        // Enable accessibility notifications for text changes
        shouldGroupAccessibilityChildren = true

        // Support for larger text sizes
        adjustsFontForContentSizeCategory = true

        // Configure text input traits for better accessibility
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 13.0, *) {
            // accessibilityTextualContext is a property on UITextView in iOS 13+
            // CodeEditorView inherits from UITextView on iOS
            self.accessibilityTextualContext = .sourceCode
        }
        #endif
    }

    /// Update accessibility label with current editor state
    internal func updateAccessibilityLabel() {
        var components: [String] = []

        // Add language information
        components.append("\(language.name) code editor")

        // Add line and column information if available
        if let selectedRange = selectedTextRange {
            let position = selectedRange.start
            let location = offset(from: beginningOfDocument, to: position)
            let lineInfo = getLineAndColumn(for: location)
            components.append("Line \(lineInfo.line), Column \(lineInfo.column)")
        }

        // Add file information if available
        if let fileName = currentFileName {
            components.append("Editing \(fileName)")
        }

        // Add word count for context
        let wordCount = String(text).components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        components.append("\(wordCount) words")

        accessibilityLabel = components.joined(separator: ", ")
    }

    /// Announce changes for VoiceOver users
    internal func announceChange(_ change: String) {
        UIAccessibility.post(notification: .announcement, argument: change)
    }

    /// Update accessibility when text changes
    internal func notifyAccessibilityTextDidChange() {
        UIAccessibility.post(notification: .announcement, argument: "Text changed")
        updateAccessibilityLabel()
    }

    #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func setupAccessibilityAppKit() {
        // macOS accessibility configuration
        setAccessibilityRole(.textArea)
        setAccessibilityRoleDescription("Code editor")

        // Set initial accessibility label
        updateAccessibilityLabel()

        // Enable accessibility features
        setAccessibilityEnabled(true)

        // Configure for source code context
        if responds(to: NSSelectorFromString("setAccessibilityTextualContext:")) {
            perform(NSSelectorFromString("setAccessibilityTextualContext:"), with: "sourceCode")
        }
    }

    /// Update accessibility label with current editor state (macOS)
    internal func updateAccessibilityLabel() {
        var components: [String] = []

        // Add language information
        components.append("\(language.name) code editor")

        // Add line and column information
        let location = selectedRange().location
        let lineInfo = getLineAndColumn(for: location)
        components.append("Line \(lineInfo.line), Column \(lineInfo.column)")

        // Add file information if available
        if let fileName = currentFileName {
            components.append("Editing \(fileName)")
        }

        // Add word count for context
        let wordCount = String(string).components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }.count
        components.append("\(wordCount) words")

        setAccessibilityLabel(components.joined(separator: ", "))
        setAccessibilityHelp("Code editor. Use VoiceOver to navigate and edit code.")
    }

    /// Announce changes for VoiceOver users (macOS)
    internal func announceChange(_ change: String) {
        NSAccessibility.post(
            element: self,
            notification: .announcementRequested,
            userInfo: [.announcement: change]
        )
    }

    /// Update accessibility when text changes (macOS)
    internal func notifyAccessibilityTextDidChange() {
        NSAccessibility.post(element: self, notification: .valueChanged)
        updateAccessibilityLabel()
    }
    #endif

    // MARK: - Helper Methods

    /// Get line and column for a given character offset
    private func getLineAndColumn(for location: Int) -> (line: Int, column: Int) {
        guard location >= 0 else { return (1, 1) }

        #if canImport(UIKit)
        let text = self.text ?? ""
        #else
        let text = self.string
        #endif
        let substring = String(text.prefix(location))
        let lines = substring.components(separatedBy: CharacterSet.newlines)
        let line = lines.count
        let column = (lines.last?.count ?? 0) + 1

        return (line, column)
    }

    /// Store current file name for accessibility announcements
    private var currentFileName: String? {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.currentFileName) as? String
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.currentFileName, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Set the current file name for accessibility context
    public func setAccessibilityFileName(_ fileName: String?) {
        currentFileName = fileName
        updateAccessibilityLabel()
    }
}

// MARK: - Associated Keys

private enum AssociatedKeys {
    @MainActor static var currentFileName: UInt8 = 0
}

// MARK: - Dynamic Type Support

extension CodeEditorView {
    #if canImport(UIKit)
    /// Apply Dynamic Type scaling to the editor font
    internal func applyDynamicTypeScaling() {
        guard let baseFont = font else { return }

        // Get the current content size category
        _ = traitCollection.preferredContentSizeCategory

        // Create a font metrics instance for the code text style
        let fontMetrics = UIFontMetrics(forTextStyle: .body)

        // Scale the font based on the user's text size preference
        let scaledFont = fontMetrics.scaledFont(for: baseFont)

        // Apply the scaled font
        self.font = scaledFont

        // Update line height and other layout metrics
        updateLayoutForDynamicType()

        // Notify accessibility about the change
        announceChange("Text size updated")
    }

    /// Update layout metrics for Dynamic Type
    private func updateLayoutForDynamicType() {
        // Adjust line spacing based on text size
        let baseLineSpacing = configuration.layout.lineHeightMultiple
        let scaleFactor = font?.pointSize ?? configuration.display.fontSize / configuration.display.fontSize

        // Update paragraph style with scaled line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.0 + (baseLineSpacing * scaleFactor / 100.0)
        paragraphStyle.tabStops = []

        // Calculate scaled tab width
        let spaceWidth: CGFloat
        if let font {
            #if canImport(UIKit)
            // iOS and Mac Catalyst don't have maximumAdvancement, calculate manually
            let spaceAttributes = [NSAttributedString.Key.font: font]
            spaceWidth = " ".size(withAttributes: spaceAttributes).width
            #else
            // macOS has maximumAdvancement
            spaceWidth = font.maximumAdvancement(for: " ").width
            #endif
        } else {
            spaceWidth = 8.0
        }
        let tabWidth = CGFloat(configuration.layout.tabWidth) * spaceWidth
        for index in 0..<50 {
            paragraphStyle.tabStops.append(NSTextTab(textAlignment: .left, location: tabWidth * CGFloat(index + 1)))
        }

        // Apply to the entire text
        textStorage.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: textStorage.length)
        )
    }

    // Override trait collection changes to respond to Dynamic Type
    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.preferredContentSizeCategory != previousTraitCollection?.preferredContentSizeCategory {
            applyDynamicTypeScaling()
        }
    }
    #endif
}
