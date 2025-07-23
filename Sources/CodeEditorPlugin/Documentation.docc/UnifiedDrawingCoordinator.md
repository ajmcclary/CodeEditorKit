# ``CodeEditorPlugin/UnifiedDrawingCoordinator``

@Metadata {
    @PageColor(blue)
}

Abstracts platform-specific drawing operations, providing a unified interface for cross-platform rendering in code editor components.

## Overview

`UnifiedDrawingCoordinator` provides a consistent drawing API across macOS and iOS platforms, handling the differences in coordinate systems, graphics contexts, and drawing methods. It's designed specifically for code editor components like line number gutters, minimaps, and viewport indicators, ensuring consistent rendering behavior across all Apple platforms.

## Key Features

- **Platform Abstraction**: Single API for AppKit and UIKit drawing
- **Coordinate System Handling**: Automatic handling of flipped coordinates
- **Text Drawing**: Optimized methods for editor-specific text rendering  
- **Graphics State Management**: Safe context state save/restore
- **Layer Optimization**: Platform-appropriate layer backing

## Basic Drawing Operations

### Graphics Context Management

```swift
// Get current context
if let context = UnifiedDrawingCoordinator.currentContext() {
    // Perform Core Graphics operations
    context.setFillColor(PlatformColor.blue.cgColor)
    context.fill(rect)
}

// Save and restore graphics state
UnifiedDrawingCoordinator.saveGraphicsState()
// ... perform drawing operations ...
UnifiedDrawingCoordinator.restoreGraphicsState()
```

### Basic Shapes and Lines

```swift
// Fill a rectangle
UnifiedDrawingCoordinator.fillRect(
    CGRect(x: 0, y: 0, width: 100, height: 50),
    with: .systemGray
)

// Stroke a rectangle
UnifiedDrawingCoordinator.strokeRect(
    bounds,
    with: .systemBlue,
    lineWidth: 2.0
)

// Draw a line
UnifiedDrawingCoordinator.drawLine(
    from: CGPoint(x: 0, y: 10),
    to: CGPoint(x: 100, y: 10),
    color: .separator,
    lineWidth: 1.0
)
```

### Text Drawing

```swift
// Draw simple text
UnifiedDrawingCoordinator.drawString(
    "Hello World",
    at: CGPoint(x: 10, y: 20),
    withAttributes: [
        .font: PlatformFont.monospacedSystemFont(ofSize: 12),
        .foregroundColor: PlatformColor.label
    ]
)

// Draw attributed string
let attributed = NSAttributedString(
    string: "Syntax Highlighted",
    attributes: [.foregroundColor: PlatformColor.systemGreen]
)
UnifiedDrawingCoordinator.drawAttributedString(attributed, at: point)

// Draw text in rectangle
UnifiedDrawingCoordinator.drawString(
    longText,
    in: CGRect(x: 0, y: 0, width: 200, height: 100),
    withAttributes: attributes
)
```

## Code Editor Specific Methods

### Line Number Drawing

```swift
// Draw line numbers with proper alignment
UnifiedDrawingCoordinator.drawLineNumber(
    42,
    at: CGPoint(x: 0, y: 100),
    font: .monospacedSystemFont(ofSize: 11),
    color: .secondaryLabel,
    alignment: .right,
    maxWidth: 40  // Right-aligns within this width
)
```

### Minimap Rendering

```swift
// Draw minimap line with performance optimization
UnifiedDrawingCoordinator.drawMinimapLine(
    "func calculateComplexAlgorithm() -> Result",
    at: CGPoint(x: 5, y: 20),
    font: .systemFont(ofSize: 2),
    color: .tertiaryLabel,
    maxWidth: 50  // Truncates if needed
)

// Draw viewport indicator
UnifiedDrawingCoordinator.drawViewportIndicator(
    in: CGRect(x: 0, y: 50, width: 50, height: 100),
    backgroundColor: PlatformColor.systemBlue.withAlphaComponent(0.1),
    borderColor: .systemBlue,
    borderWidth: 1.0
)
```

### Visible Text Area Calculation

```swift
// Get visible text area for viewport calculations
let visibleRect = UnifiedDrawingCoordinator.calculateVisibleTextRect(
    for: codeEditorView
)

// Use for viewport-based rendering optimizations
```

## Coordinate System Handling

### Automatic Coordinate Conversion

```swift
// Convert point to drawing coordinates
// Handles flipped coordinate systems automatically
let drawingPoint = UnifiedDrawingCoordinator.convertToDrawingCoordinates(
    viewPoint,
    in: view,
    bounds: view.bounds
)

// Convert rectangle
let drawingRect = UnifiedDrawingCoordinator.convertToDrawingCoordinates(
    viewRect,
    in: view,
    bounds: view.bounds
)
```

### Platform Differences

On macOS:
- NSView may have flipped coordinates
- Conversion handles isFlipped property
- Focus ring support available

On iOS:
- UIView always uses top-left origin
- No coordinate conversion needed
- No focus ring (iOS handles differently)

## Display Updates

### Requesting Redraws

```swift
// Request full view redraw
UnifiedDrawingCoordinator.setNeedsDisplay(for: view)

// Request partial redraw for better performance
UnifiedDrawingCoordinator.setNeedsDisplay(
    for: view,
    in: CGRect(x: 0, y: 0, width: 100, height: 50)
)
```

## Layer Optimization

### Layer Backing Setup

```swift
// Ensure view is layer-backed for performance
UnifiedDrawingCoordinator.ensureLayerBacked(view)

// Set layer background color
UnifiedDrawingCoordinator.setLayerBackgroundColor(
    .systemBackground,
    for: view
)
```

## Platform-Specific Features

### Focus Ring (macOS Only)

```swift
// Draw focus ring on macOS
UnifiedDrawingCoordinator.drawFocusRing(
    around: CGRect(x: 10, y: 10, width: 200, height: 30)
)
// No-op on iOS
```

### Clipping

```swift
// Clip drawing to rectangle
UnifiedDrawingCoordinator.clipToRect(visibleRect)
// All subsequent drawing is clipped
```

## Drawing Context Wrapper

For more complex drawing operations:

```swift
// Create unified drawing context
if let context = UnifiedDrawingContext(for: view) {
    // Access Core Graphics context
    let cgContext = context.cgContext
    
    // Convert coordinates automatically
    let drawPoint = context.convertPoint(viewPoint)
    let drawRect = context.convertRect(viewRect)
    
    // Check if coordinates are flipped
    if context.isFlipped {
        // Handle flipped coordinates if needed
    }
}
```

## Practical Examples

### Line Number Gutter

```swift
class LineNumberGutter: PlatformView {
    override func draw(_ rect: CGRect) {
        // Background
        UnifiedDrawingCoordinator.fillRect(
            bounds,
            with: .secondarySystemBackground
        )
        
        // Line numbers
        for (index, lineRect) in visibleLineRects.enumerated() {
            UnifiedDrawingCoordinator.drawLineNumber(
                index + 1,
                at: lineRect.origin,
                font: lineNumberFont,
                color: .secondaryLabel,
                alignment: .right,
                maxWidth: bounds.width - 5
            )
        }
        
        // Separator line
        UnifiedDrawingCoordinator.drawLine(
            from: CGPoint(x: bounds.maxX - 0.5, y: 0),
            to: CGPoint(x: bounds.maxX - 0.5, y: bounds.maxY),
            color: .separator,
            lineWidth: 0.5
        )
    }
}
```

### Minimap View

```swift
class MinimapView: PlatformView {
    override func draw(_ rect: CGRect) {
        // Calculate scale
        let scale = bounds.height / documentHeight
        
        // Draw miniaturized lines
        for (index, line) in visibleLines.enumerated() {
            let y = CGFloat(index) * lineHeight * scale
            
            UnifiedDrawingCoordinator.drawMinimapLine(
                line.text,
                at: CGPoint(x: 2, y: y),
                font: minimapFont,
                color: line.syntaxColor,
                maxWidth: bounds.width - 4
            )
        }
        
        // Draw viewport indicator
        let viewportRect = CGRect(
            x: 0,
            y: visibleRange.location * scale,
            width: bounds.width,
            height: visibleRange.length * scale
        )
        
        UnifiedDrawingCoordinator.drawViewportIndicator(
            in: viewportRect,
            backgroundColor: .systemBlue.withAlphaComponent(0.1),
            borderColor: .systemBlue
        )
    }
}
```

## Performance Best Practices

1. **Batch Operations**: Group drawing operations to minimize state changes
2. **Partial Redraws**: Use `setNeedsDisplay(in:)` for specific regions
3. **Layer Backing**: Enable on macOS for better performance
4. **Text Caching**: Cache attributed strings for repeated drawing
5. **Coordinate Conversion**: Convert coordinates once, reuse results

## Common Patterns

### Double-Buffering Pattern

```swift
// Save current state
UnifiedDrawingCoordinator.saveGraphicsState()

// Clip to dirty region
UnifiedDrawingCoordinator.clipToRect(dirtyRect)

// Perform drawing
drawContent()

// Restore state
UnifiedDrawingCoordinator.restoreGraphicsState()
```

### Responsive Drawing

```swift
override func draw(_ rect: CGRect) {
    // Only draw what's needed
    let visibleRect = UnifiedDrawingCoordinator.calculateVisibleTextRect(for: self)
    
    // Draw only visible content
    drawVisibleContent(in: visibleRect)
}
```

## See Also

- ``GutterView``
- ``MinimapView``
- ``PlatformColor``
- ``PlatformFont``
- ``CodeEditorView``