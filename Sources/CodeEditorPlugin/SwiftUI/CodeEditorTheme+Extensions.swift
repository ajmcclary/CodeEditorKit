//
//  CodeEditorTheme.swift
//  CodeEditorPlugin
//
//  Theme support for CodeEditor SwiftUI view
//

import SwiftUI

// MARK: - Theme Definition

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
        Self(
            name: "dark",
            backgroundColor: Color(PlatformColors.controlBackground),
            textColor: Color(PlatformColors.label),
            lineNumberColor: Color(PlatformColors.secondaryLabel),
            selectedLineColor: Color(PlatformColors.tintColor).opacity(0.2)
        )
    }()
}

// MARK: - SwiftUI Environment Support
// Note: Individual environment keys have been deprecated in favor of CodeEditorEnvironment
// The extensions in CodeEditorEnvironment.swift provide backward compatibility

// MARK: - Convenience View Modifier

@available(macOS 12.0, iOS 16.0, *)
extension View {
    /// Set the code editor theme for this view hierarchy
    public func codeEditorTheme(_ theme: CodeEditorSwiftUITheme) -> some View {
        environment(\.codeEditorTheme, theme)
    }

    /// Control whether the code editor should become first responder
    @available(*, deprecated, renamed: "becomeFirstResponder(_:)", message: "Use becomeFirstResponder(_:) instead")
    public func codeEditorBecomeFirstResponder(_ become: Bool) -> some View {
        environment(\.codeEditorBecomeFirstResponder, become)
    }

    /// Set the selected line highlight color for the code editor
    public func codeEditorLineHighlightColor(_ color: PlatformColor) -> some View {
        transformEnvironment(\.codeEditorConfiguration) { config in
            var display = config.display
            display.selectedLineHighlightColor = color
            config = config.with(display: display)
        }
    }
}
