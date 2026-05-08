# Code Folding API

Learn how to use the enhanced code folding API with boolean return values for better error handling.

## Overview

The Code Folding API in CodeEditorPlugin has been enhanced to provide better feedback about folding operations. Methods now return boolean values indicating success or failure, allowing you to handle edge cases gracefully.

## Basic Usage

### Checking Foldability

Before attempting to fold code, check if a line is foldable:

```swift
let editor = CodeEditorView()

// Check if line 10 can be folded
if editor.isFoldable(at: 10) {
    print("Line 10 is part of a foldable region")
} else {
    print("Line 10 cannot be folded")
}
```

### Toggle Folding with Feedback

The `toggleFold()` method now returns a `Bool` indicating whether the operation succeeded:

```swift
// Toggle folding at line 15
if editor.toggleFold(at: 15) {
    print("Successfully toggled fold at line 15")
} else {
    print("Could not toggle fold at line 15 - not a foldable region")
}
```

### Programmatic Folding

Use the `@discardableResult` methods when you don't need to check the result:

```swift
// Fold a specific region (result can be ignored)
editor.fold(region)

// Or check the result if needed
let region = editor.foldableRegion(at: 20)
if let region = region {
    editor.fold(region)
}

// Unfold a region
editor.unfold(region)
```

## Advanced Operations

### Fold All Regions

Fold all foldable regions in the document:

```swift
// Fold all regions and get count of folded regions
let foldedCount = editor.foldAll()
print("Folded \(foldedCount) regions")

// With filtering by minimum line count
let foldedCount = editor.foldAll(minimumLineCount: 5)
print("Folded \(foldedCount) regions with at least 5 lines")
```

### Unfold All Regions

Unfold all currently folded regions:

```swift
// Unfold all and get count
let unfoldedCount = editor.unfoldAll()
print("Unfolded \(unfoldedCount) regions")
```

### Query Folding State

Check the current folding state:

```swift
// Get all foldable regions
let allRegions = editor.allFoldableRegions()
print("Document has \(allRegions.count) foldable regions")

// Get currently folded regions
let foldedRegions = editor.foldedRegions
print("\(foldedRegions.count) regions are currently folded")

// Check if a specific line is in a folded region
if editor.isLineInFoldedRegion(25) {
    print("Line 25 is hidden in a folded region")
}
```

## Language-Specific Folding

Different languages have different folding rules:

```swift
// Swift - folds functions, classes, closures
editor.language = .swift

// JavaScript - folds functions, objects, arrays
editor.language = .javascript

// Python - folds functions, classes, multi-line strings
editor.language = .python

// The folding engine automatically adapts to the language
```

## Error Handling Patterns

### Safe Folding with User Feedback

```swift
func foldCurrentSelection() {
    guard let selectedRange = editor.selectedRange else {
        showAlert("No selection")
        return
    }
    
    let line = editor.lineNumber(for: selectedRange.location)
    
    if editor.toggleFold(at: line) {
        showStatus("Region folded")
    } else {
        showAlert("Cannot fold at this location")
    }
}
```

### Batch Operations with Progress

```swift
func foldAllLargeFunctions() async {
    let regions = editor.allFoldableRegions()
    let largeFunctions = regions.filter { $0.lineCount > 20 }
    
    var foldedCount = 0
    for region in largeFunctions {
        editor.fold(region)
        foldedCount += 1
        
        // Update progress
        await updateProgress(current: foldedCount, total: largeFunctions.count)
    }
    
    showStatus("Folded \(foldedCount) large functions")
}
```

## Visual Indicators

The folding system provides visual feedback:

```swift
// Enable folding controls in the gutter
var config = editor.configuration
config.display.isCodeFoldingEnabled = true
config.display.areFoldingControlsVisible = true
config.apply(to: editor)

// Folding indicators:
// ▶️ - Collapsed/folded region (click to expand)
// ▼ - Expanded region (click to collapse)
```

## Performance Considerations

### Efficient Folding Queries

```swift
// Inefficient - multiple calls
for line in 1...100 {
    if editor.isFoldable(at: line) {
        // Process...
    }
}

// Efficient - single call
let allRegions = editor.allFoldableRegions()
for region in allRegions {
    if region.range.location <= 100 {
        // Process...
    }
}
```

### Viewport-Based Folding

For large documents, fold only visible regions:

```swift
// Get visible range
let visibleRange = editor.visibleRange

// Find foldable regions in visible area
let visibleRegions = editor.allFoldableRegions().filter { region in
    NSLocationInRange(region.range.location, visibleRange)
}

// Fold visible regions
for region in visibleRegions {
    editor.fold(region)
}
```

## Integration with SwiftUI

Use the folding API in SwiftUI views:

```swift
struct EditorToolbar: View {
    let editor: CodeEditorView
    @State private var lastFoldResult = ""
    
    var body: some View {
        HStack {
            Button("Fold All") {
                let count = editor.foldAll()
                lastFoldResult = "Folded \(count) regions"
            }
            
            Button("Unfold All") {
                let count = editor.unfoldAll()
                lastFoldResult = "Unfolded \(count) regions"
            }
            
            Text(lastFoldResult)
                .foregroundColor(.secondary)
        }
    }
}
```

## Custom Folding Providers

While the built-in language support handles most cases, you can implement custom folding logic:

```swift
// Future API (coming in v2.0)
protocol FoldingProvider {
    func foldableRegions(for text: String, language: Language) -> [FoldableRegion]
}

// Example custom provider
struct CustomMarkdownFoldingProvider: FoldingProvider {
    func foldableRegions(for text: String, language: Language) -> [FoldableRegion] {
        // Custom logic for markdown sections
        // Fold based on heading levels
    }
}
```

## Troubleshooting

### Folding Not Working

If folding operations return false:

1. Verify code folding is enabled in configuration
2. Check that the language is properly set
3. Ensure the line is at the start of a foldable construct
4. Verify the document has been parsed (may take a moment for large files)

```swift
// Debug folding state
print("Folding enabled: \(editor.configuration.display.isCodeFoldingEnabled)")
print("Language: \(editor.language)")
print("Foldable regions: \(editor.allFoldableRegions().count)")
```

### Performance Issues

For documents with many foldable regions:

```swift
// Disable automatic folding updates during batch operations
editor.beginBatchUpdate()
defer { editor.endBatchUpdate() }

// Perform multiple folding operations
for region in regions {
    editor.fold(region)
}
```

## See Also

- [Configuration-System](../Configuration/system.md)
- [SwiftUI-Integration](../SwiftUI/integration.md)
- `CodeEditorView/fold(at:)`
- `CodeEditorView/unfold(at:)`
- `CodeEditorView/isFoldable(at:)`