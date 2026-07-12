import CodeEditorConfiguration
import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Configuration Application

@MainActor extension CodeEditorView {
    /// Apply an editor configuration to this view.
    ///
    /// Updates the view with all settings from the configuration, handling
    /// platform-specific differences. Equivalent to assigning the configuration
    /// to the view's `configuration` property and triggering platform-specific
    /// text-input feature application.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let config = EditorConfiguration.minimal
    /// try view.apply(configuration: config)
    /// ```
    ///
    /// - Parameter configuration: The configuration to apply.
    /// - Throws: A `CodeEditorError` if the configuration fails validation.
    public func apply(configuration: EditorConfiguration) throws {
        try configuration.validateAndThrow()
        self.configuration = configuration
        configuration.applyTextInputFeatures(to: self)
    }
}
