//
//  CodeEditorTheme+Extensions.swift
//  CodeEditorKit
//
//  Convenience SwiftUI modifiers for the editor's selected-line color.
//  The full `Theme` type and `.designTheme(_:)` modifier lived in the
//  umbrella's `Theming/` directory (then `Sources/CodeEditorPlugin/Theming/`,
//  before the package was renamed to CodeEditorKit).
//

import CodeEditorConfiguration
import CodeEditorPlatform
import CodeEditorView
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
