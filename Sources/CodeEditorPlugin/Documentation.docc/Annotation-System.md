# Annotation System

@Metadata {
    @PageColor(green)
}

Add interactive inline annotations to highlight important comments in your code.

## Overview

The annotation system automatically detects and displays special comments like TODO, FIXME, NOTE, WARNING, and ERROR as interactive badges within your code. This helps developers track important items without leaving the editor.

## Supported Annotations

### TODO
Tasks that need to be completed:
```swift
// TODO: Implement user authentication
// TODO: Add error handling for network requests
```

### FIXME
Bugs or issues that need fixing:
```swift
// FIXME: Memory leak when processing large files
// FIXME: Race condition in concurrent updates
```

### NOTE
Important information or explanations:
```swift
// NOTE: This algorithm has O(n²) complexity
// NOTE: Deprecated in iOS 17, use new API
```

### WARNING
Potential issues or cautions:
```swift
// WARNING: This operation is expensive
// WARNING: Not thread-safe
```

### ERROR
Critical issues that must be addressed:
```swift
// ERROR: This will crash in production
// ERROR: Security vulnerability
```

## Enabling Annotations

### SwiftUI

```swift
struct AnnotatedEditor: View {
    @State private var config = EditorConfiguration()
    
    var body: some View {
        CodeEditor(text: $code)
            .onAppear {
                config.display.enableAnnotations = true
            }
            .environment(\.codeEditorConfiguration, config)
    }
}
```

### UIKit/AppKit

```swift
let editor = CodeEditorView()
var config = EditorConfiguration()
config.display.enableAnnotations = true
config.apply(to: editor)
```

## Annotation Appearance

### Inline Badges

Annotations appear as colored badges next to the line:

- **TODO**: Blue badge
- **FIXME**: Orange badge
- **NOTE**: Gray badge
- **WARNING**: Yellow badge
- **ERROR**: Red badge

### Hover Details

Hovering over an annotation shows:
- Full annotation text
- Line number
- File location
- Timestamp (if available)

## Customization

### Custom Annotation Types

Add your own annotation types:

```swift
// Coming in v1.5
AnnotationRegistry.register(
    type: "HACK",
    color: PlatformColor(hex: "#9C27B0"),
    priority: .medium
)
```

### Annotation Filtering

Show only specific annotation types:

```swift
config.display.annotationFilter = [.todo, .fixme]
// Only shows TODO and FIXME annotations
```

### Custom Rendering

Customize annotation appearance:

```swift
config.display.annotationRenderingMode = .inline  // Default
config.display.annotationRenderingMode = .gutter  // In gutter
config.display.annotationRenderingMode = .both    // Both locations
```

## Performance

### Efficient Detection

Annotations are detected during syntax highlighting:
- No additional passes needed
- Minimal performance impact
- Cached for repeated access

### Large File Optimization

For files with many annotations:
```swift
config.performance.maxAnnotationsPerFile = 100
// Limits displayed annotations for performance
```

## Integration with Other Features

### Symbol Navigation

Annotations appear in the symbol navigator:
```swift
// Jump to annotations quickly
symbolNavigator.includeAnnotations = true
```

### Search

Find all annotations in your project:
```swift
// Search for all TODOs
// Use search functionality to find annotation patterns
```

## Best Practices

1. **Consistent Format**: Use standard annotation format
2. **Clear Descriptions**: Write descriptive annotation text
3. **Regular Review**: Periodically review and resolve annotations
4. **Team Standards**: Agree on annotation usage within teams
5. **Avoid Overuse**: Too many annotations reduce their value

## Advanced Usage

### Annotation Actions

Add actions to annotations:

```swift
// Coming in v2.0
annotation.addAction("Create Issue") { annotation in
    GitHubIntegration.createIssue(
        title: annotation.text,
        labels: [annotation.type.rawValue]
    )
}
```


### CI Integration

Fail builds with too many annotations:

```swift
// In your CI script
let annotationCount = editor.getAnnotationCount(type: .error)
if annotationCount > 0 {
    exit(1) // Fail the build
}
```

## See Also

- <doc:Configuration-System>
- <doc:Syntax-Highlighting>
- <doc:Performance-Monitoring>