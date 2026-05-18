import CodeEditorDesignTokens
import CodeEditorPlugin
import CodeEditorSwiftUI
import CodeEditorSymbols
import CodeEditorView
import SwiftUI

/// Renders a breadcrumb trail (workspace › folder › file › symbol).
///
/// Reads `\.editorState.breadcrumbPath` when no `components` are passed;
/// otherwise uses the explicit `components`. Tap callback invoked when
/// the user clicks a segment; nil callback means segments are not
/// interactive.
public struct EditorBreadcrumbView: View {
    @Environment(\.codeEditorTheme) private var theme
    @Environment(\.editorState) private var editorState

    // swiftlint:disable:next discouraged_optional_collection
    private let componentsOverride: [BreadcrumbComponent]?
    private let onSelect: ((BreadcrumbComponent) -> Void)?

    /// Creates a breadcrumb view.
    /// - Parameters:
    ///   - components: explicit path; pass nil to read from `EditorState`.
    ///   - onSelect: tap callback per segment; nil makes segments inert.
    public init(
        // swiftlint:disable:next discouraged_optional_collection
        components: [BreadcrumbComponent]? = nil,
        onSelect: ((BreadcrumbComponent) -> Void)? = nil
    ) {
        self.componentsOverride = components
        self.onSelect = onSelect
    }

    public var body: some View {
        let path = resolvedPath
        HStack(spacing: 4) {
            ForEach(Array(path.enumerated()), id: \.element.id) { index, component in
                segment(component)
                if index < path.count - 1 {
                    chevron
                }
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium))
    }

    private var resolvedPath: [BreadcrumbComponent] {
        componentsOverride ?? editorState.breadcrumbPath
    }

    @ViewBuilder
    private func segment(_ component: BreadcrumbComponent) -> some View {
        let label = HStack(spacing: 4) {
            kindGlyph(for: component.kind)
            Text(component.name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .foregroundStyle(Color(tokens: theme.style.text.base))

        if let onSelect {
            Button {
                onSelect(component)
            } label: {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
        }
    }

    @ViewBuilder
    private func kindGlyph(for kind: BreadcrumbComponent.Kind) -> some View {
        Image(systemName: Self.systemImageName(for: kind))
            .imageScale(.small)
            .foregroundStyle(Color(tokens: theme.style.icon.base))
    }

    private static func systemImageName(for kind: BreadcrumbComponent.Kind) -> String {
        switch kind {
        case .workspace: return "rectangle.stack"
        case .folder:    return "folder"
        case .file:      return "doc"
        case .symbol:    return "function"
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .imageScale(.small)
            .foregroundStyle(Color(tokens: theme.style.text.muted))
    }
}
