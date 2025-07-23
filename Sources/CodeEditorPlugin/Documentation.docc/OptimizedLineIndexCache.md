# ``CodeEditorPlugin/OptimizedLineIndexCache``

@Metadata {
    @PageColor(green)
}

High-performance line index cache using a balanced red-black tree for O(log n) line lookups and updates in large documents.

## Overview

`OptimizedLineIndexCache` provides extremely fast line number calculations for large text documents by maintaining a self-balancing red-black tree of line information. Unlike traditional approaches that scan through text linearly (O(n)), this cache provides O(log n) performance for all operations including lookups, insertions, and updates. This makes it ideal for multi-megabyte documents where line number calculations are frequent.

## Architecture

The cache uses a red-black tree where each node stores:
- Line start position
- Line length
- Subtree line count (for fast line index calculations)
- Subtree character count (for fast offset calculations)

This structure enables efficient:
- Character offset to line/column conversion
- Line number to character offset conversion
- Incremental updates when text changes

## Basic Usage

### Building the Index

```swift
let cache = OptimizedLineIndexCache()

// Build index from text
let text = "line 1\nline 2\nline 3"
await cache.buildIndex(from: text)

// Get total line count - O(1)
let lineCount = await cache.count  // 3
```

### Line and Column Lookups

```swift
// Get line and column for character offset - O(log n)
let (line, column) = await cache.lineAndColumn(for: 15)
// line: 2, column: 2 (for "line 2" at position 15)

// Get character offset for line - O(log n)
let offset = await cache.characterOffset(for: 1)  // 7
```

### Incremental Updates

```swift
// Update cache for text change - O(log n)
let range = NSRange(location: 7, length: 6)  // "line 2"
let replacementLength = 10  // "long line 2"
await cache.updateForTextChange(at: range, replacementLength: replacementLength)

// Cache remains valid and efficient after update
```

## Performance Characteristics

### Time Complexity

| Operation | Traditional | OptimizedLineIndexCache |
|-----------|-------------|------------------------|
| Line lookup | O(n) | O(log n) |
| Character offset | O(n) | O(log n) |
| Text change update | O(n) | O(log n) |
| Build index | O(n) | O(n log n) |

### Space Complexity

- Memory usage: O(n) where n is the number of lines
- Each node stores minimal data for efficiency
- Lookup cache provides additional performance boost

## Advanced Features

### Lookup Cache

The cache includes an LRU cache for recent lookups:

```swift
// First lookup calculates and caches
let result1 = await cache.lineAndColumn(for: 1000)  // O(log n)

// Subsequent lookup is O(1) from cache
let result2 = await cache.lineAndColumn(for: 1000)  // O(1)

// Cache automatically evicts old entries
```

### Line Information

```swift
// Get detailed line information - O(log n)
if let info = await cache.lineInfo(at: lineIndex) {
    print("Line starts at: \(info.start)")
    print("Line length: \(info.length)")
}
```

## Red-Black Tree Properties

The implementation maintains red-black tree invariants:

1. **Root is black**: Ensures balanced height
2. **No red-red parent-child**: Prevents long chains
3. **Equal black height**: All paths have same black nodes
4. **Self-balancing**: Rotations maintain O(log n) height

### Tree Validation (Debug)

```swift
#if DEBUG
// Validate tree structure
let isValid = await cache.validateTree()
assert(isValid, "Tree structure is invalid")
#endif
```

## Integration with Text Editors

### With CodeEditorView

```swift
// Create optimized cache
let lineCache = OptimizedLineIndexCache()

// Build initial index
await lineCache.buildIndex(from: textView.text)

// Update on text changes
func textDidChange(in range: NSRange, replacementLength: Int) {
    Task {
        await lineCache.updateForTextChange(
            at: range,
            replacementLength: replacementLength
        )
    }
}

// Use for line number display
func lineNumber(at point: CGPoint) async -> Int {
    let charIndex = textView.characterIndex(at: point)
    let (line, _) = await lineCache.lineAndColumn(for: charIndex)
    return line + 1  // Convert to 1-based
}
```

### Performance Monitoring

```swift
// Monitor cache performance
let start = CFAbsoluteTimeGetCurrent()
let (line, column) = await cache.lineAndColumn(for: offset)
let elapsed = CFAbsoluteTimeGetCurrent() - start

print("Lookup took: \(elapsed * 1000)ms")
```

## Handling Text Changes

### Single Line Changes

```swift
// Change within a line
let range = NSRange(location: 10, length: 5)
let newLength = 8
await cache.updateForTextChange(
    at: range,
    replacementLength: newLength
)
// Efficiently updates just the affected node
```

### Multi-Line Changes

```swift
// Change spanning multiple lines
let range = NSRange(location: 10, length: 50)
let newLength = 30
await cache.updateForTextChange(
    at: range,
    replacementLength: newLength
)
// Complex update handled efficiently
```

## Memory Management

### Cache Eviction

```swift
// Lookup cache has size limit
// Default: 100 entries
// Automatically clears when full

// Manual cache clear if needed
await cache.invalidateLookupCache(from: offset)
```

### Tree Rebalancing

The red-black tree automatically rebalances:
- During insertions to maintain height
- No manual rebalancing needed
- Guarantees O(log n) operations

## Use Cases

### Line Number Gutter

```swift
actor LineNumberGutter {
    let cache = OptimizedLineIndexCache()
    
    func visibleLineNumbers(in rect: CGRect) async -> [Int] {
        let startOffset = textView.characterIndex(at: rect.origin)
        let endOffset = textView.characterIndex(at: CGPoint(x: rect.maxX, y: rect.maxY))
        
        let startLine = await cache.lineAndColumn(for: startOffset).line
        let endLine = await cache.lineAndColumn(for: endOffset).line
        
        return Array(startLine...endLine)
    }
}
```

### Jump to Line

```swift
func jumpToLine(_ lineNumber: Int) async {
    let offset = await cache.characterOffset(for: lineNumber - 1)
    textView.selectedRange = NSRange(location: offset, length: 0)
    textView.scrollRangeToVisible(textView.selectedRange)
}
```

### Status Bar

```swift
func updateStatusBar() async {
    let (line, column) = await cache.lineAndColumn(
        for: textView.selectedRange.location
    )
    statusLabel.text = "Line \(line + 1), Column \(column + 1)"
}
```

## Performance Tips

1. **Build Once**: Build the full index once rather than incrementally
2. **Batch Updates**: Group multiple text changes when possible
3. **Actor Isolation**: The cache is an actor, batch async calls
4. **Lookup Cache**: Hot paths benefit from the internal cache

## Comparison with Alternatives

### vs Linear Scan
- ✅ O(log n) vs O(n) for lookups
- ✅ Efficient incremental updates
- ❌ Higher memory usage
- ❌ More complex implementation

### vs Line Start Array
- ✅ Better for frequent updates
- ✅ No full rebuild needed
- ❌ Slightly slower for sequential access
- ✅ Better worst-case performance

## See Also

- ``TextMetricsCalculator``
- ``TextKitLineNumberHelper``
- ``CodeEditorView``