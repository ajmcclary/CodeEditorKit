//
//  CodeEditorTheme+Extensions.swift
//  CodeEditorPlugin
//
//  Convenience SwiftUI modifiers for the editor's selected-line color.
//  The full `Theme` type and `.codeTheme(_:)` modifier live in
//  `Sources/CodeEditorPlugin/Theming/`.
//

import SwiftUI

@available(macOS 12.0, iOS 16.0, *)
extension View {
    /// Set the selected line highlight color for the code editor.
    public func codeEditorLineHighlightColor(_ color: PlatformColor) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            var display = config.display
            display.selectedLineHighlightColor = color
            config = config.with(display: display)
        }
    }
}
