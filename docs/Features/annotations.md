# Annotation System

Add inline annotation badges to highlight diagnostics, review notes, TODO comments, breakpoints, or app-specific markers.

## Overview

The current annotation system is data-source driven. The framework renders annotations that your app provides through `AnnotationsDataSource`; it does not scan source text automatically for TODO/FIXME comments.

`AnnotationKind` supplies the built-in visual categories used by the default badge view:

- `info`
- `note`
- `todo`
- `fixme`
- `warning`
- `error`

`AnnotationView` infers a kind from the annotation message when a more specific `MessageLineAnnotation` kind is not available.

## Enabling Annotations

Annotations are controlled by `EditorConfiguration.Display.areAnnotationsEnabled`.

### SwiftUI

```swift
struct AnnotatedEditor: View {
    @State private var code = ""
    @State private var config: EditorConfiguration = {
        var config = EditorConfiguration.default
        config.display.areAnnotationsEnabled = true
        return config
    }()

    var body: some View {
        CodeEditor(text: $code)
            .environment(\.codeEditorConfiguration, config)
    }
}
```

### AppKit/UIKit

```swift
let editor = CodeEditorView()

var config = EditorConfiguration.default
config.display.areAnnotationsEnabled = true
config.apply(to: editor)
```

## Providing Annotations

Implement `AnnotationsDataSource` and assign it to the editor view.

```swift
final class ReviewAnnotationsDataSource: AnnotationsDataSource {
    private var annotations: [Annotation] = []

    func replaceAnnotations(_ newAnnotations: [Annotation]) {
        annotations = newAnnotations
    }

    func annotations(for textRange: NSTextRange) -> [Annotation] {
        annotations.filter { annotation in
            rangesOverlap(annotation.range, textRange)
        }
    }

    var textViewAnnotations: [CodeEditorViewAnnotation] {
        annotations.map { annotation in
            CodeEditorViewAnnotation(
                location: annotation.range.location,
                content: annotation.content,
                id: annotation.id
            )
        }
    }

    func textView(
        _ textView: CodeEditorView,
        viewForLineAnnotation annotation: CodeEditorViewAnnotation,
        textLineFragment: NSTextLineFragment,
        proposedViewFrame: CGRect
    ) -> PlatformView? {
        nil // Return nil to use the framework's default annotation view.
    }

    private func rangesOverlap(_ lhs: NSTextRange, _ rhs: NSTextRange) -> Bool {
        // Implement with your app's NSTextLocation indexing policy.
        true
    }
}
```

Then wire the data source:

```swift
let dataSource = ReviewAnnotationsDataSource()
editor.annotationsDataSource = dataSource

dataSource.replaceAnnotations([
    Annotation(
        range: textRangeForLine12,
        content: "TODO: Add empty-state handling"
    )
])

editor.reloadAnnotations()
```

## Appearance

Default annotation badges are theme-aware. `AnnotationKind.color(in:)` maps the annotation kind to colors from the active `Theme`, and `AnnotationKind.iconName` selects the SF Symbol used by `AnnotationView`.

The default view supports hover/tap details and accessibility labels. Apps that need custom rendering can return their own `PlatformView` from:

```swift
func textView(
    _ textView: CodeEditorView,
    viewForLineAnnotation annotation: CodeEditorViewAnnotation,
    textLineFragment: NSTextLineFragment,
    proposedViewFrame: CGRect
) -> PlatformView?
```

## Performance

Only return annotations that intersect the requested `NSTextRange`. `annotations(for:)` can be called during layout, so cache any expensive parsing or diagnostic conversion outside that method.

For large files, keep your own annotation list bounded or paged before assigning it to the data source. There is no `maxAnnotationsPerFile` configuration key in the framework.

## Integration Notes

- Use the search engine if your app wants to find TODO/FIXME comments and turn them into annotations.
- LSP diagnostics can be converted into `Annotation` values by the host app, but the framework does not currently provide a full diagnostics UI.
- The sample app demonstrates annotation controls through its own `AnnotationsHub`; that type belongs to the `CodeEditorSample` target, not the framework library.

## See Also

- [Configuration system](../Configuration/system.md)
- [Syntax highlighting](syntax-highlighting.md)
- [Performance monitoring](../Performance/monitoring.md)
