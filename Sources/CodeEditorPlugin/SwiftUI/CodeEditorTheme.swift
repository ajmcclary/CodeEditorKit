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
            textColor: .white,
            lineNumberColor: .gray,
            selectedLineColor: .blue.opacity(0.2)
        )
    }()
}

// MARK: - SwiftUI Environment Support

@available(macOS 12.0, iOS 16.0, *)
public struct CodeEditorThemeKey: EnvironmentKey {
    public static let defaultValue: CodeEditorSwiftUITheme = .default
    
    public typealias Value = CodeEditorSwiftUITheme
}

@available(macOS 12.0, iOS 16.0, *)
public struct CodeEditorBecomeFirstResponderKey: EnvironmentKey {
    public static let defaultValue: Bool = true
    
    public typealias Value = Bool
}

@available(macOS 12.0, iOS 16.0, *)
extension EnvironmentValues {
    public var codeEditorTheme: CodeEditorSwiftUITheme {
        get { self[CodeEditorThemeKey.self] }
        set { self[CodeEditorThemeKey.self] = newValue }
    }
    
    public var codeEditorBecomeFirstResponder: Bool {
        get { self[CodeEditorBecomeFirstResponderKey.self] }
        set { self[CodeEditorBecomeFirstResponderKey.self] = newValue }
    }
}

// MARK: - Convenience View Modifier

@available(macOS 12.0, iOS 16.0, *)
extension View {
    /// Set the code editor theme for this view hierarchy
    public func codeEditorTheme(_ theme: CodeEditorSwiftUITheme) -> some View {
        environment(\.codeEditorTheme, theme)
    }
    
    /// Control whether the code editor should become first responder
    public func codeEditorBecomeFirstResponder(_ become: Bool) -> some View {
        environment(\.codeEditorBecomeFirstResponder, become)
    }
}
