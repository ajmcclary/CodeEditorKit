# `CodeEditorView/SearchReplaceEngine`

Provides comprehensive search and replace functionality with support for regular expressions, highlighting, and batch operations.

## Overview

`SearchReplaceEngine` lives in `Sources/CodeEditorView/Search/` and offers a full-featured in-document search and replace system for the code editor. It supports plain text and regular expression searches, case-sensitive and whole-word matching, search result highlighting, current-match highlighting, and efficient batch replacements. The engine maintains search statistics and provides navigation through results with wraparound support.

## Key Features

- **Multiple Search Modes**: Plain text and regular expressions
- **Search Options**: Case sensitivity, whole word, wraparound
- **Visual Feedback**: Result highlighting and flashing
- **Batch Operations**: Replace all with optimized performance
- **Search Statistics**: Track matches, lines, and timing
- **Navigation**: Find next/previous with wraparound

## Basic Usage

### Setting Up the Engine

```swift
let searchEngine = SearchReplaceEngine()
searchEngine.attach(to: codeEditorView)

// Or use the convenience accessor
let searchEngine = codeEditorView.searchEngine
```

### Simple Search

```swift
// Find all occurrences
let results = await searchEngine.findAll(pattern: "TODO")

// Check results
CrossPlatformLogger.logger().info("Found \(results.count) matches")
for result in results {
    CrossPlatformLogger.logger().info("Line \(result.lineNumber): \(result.context)")
}
```

### Search Navigation

```swift
// Find next from current position
if let next = searchEngine.findNext() {
    CrossPlatformLogger.logger().info("Found at line \(next.lineNumber)")
}

// Find previous
if let previous = searchEngine.findPrevious() {
    CrossPlatformLogger.logger().info("Found at line \(previous.lineNumber)")
}

// Find from specific location
let range = NSRange(location: 100, length: 0)
if let next = searchEngine.findNext(from: range) {
    CrossPlatformLogger.logger().info("Found after position 100")
}
```

## Search Options

Configure search behavior with `SearchOptions`:

```swift
// Configure options
searchEngine.searchOptions.caseSensitive = true
searchEngine.searchOptions.wholeWord = true
searchEngine.searchOptions.useRegularExpression = false
searchEngine.searchOptions.wrapAround = true
searchEngine.searchOptions.highlightResults = true

// Or provide options per search
let options = SearchOptions()
options.caseSensitive = false
options.useRegularExpression = true

let results = await searchEngine.findAll(
    pattern: "func\\s+\\w+",
    options: options
)
```

## Regular Expression Search

```swift
// Enable regex mode
let options = SearchOptions()
options.useRegularExpression = true

// Find function definitions
let results = await searchEngine.findAll(
    pattern: "func\\s+(\\w+)\\s*\\([^)]*\\)",
    options: options
)

// Find email addresses
let emails = await searchEngine.findAll(
    pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}",
    options: options
)
```

## Replace Operations

### Single Replacement

```swift
// Replace a specific occurrence
let results = await searchEngine.findAll(pattern: "oldValue")
if results.count > 0 {
    // Replace first occurrence
    searchEngine.replace(at: 0, with: "newValue")
}
```

### Replace All

```swift
// Replace all occurrences
let count = await searchEngine.replaceAll(
    pattern: "TODO:",
    with: "DONE:"
)
CrossPlatformLogger.logger().info("Replaced \(count) occurrences")

// With options
let options = SearchOptions()
options.caseSensitive = false
options.wholeWord = true

let count = await searchEngine.replaceAll(
    pattern: "color",
    with: "colour",
    options: options
)
```

## Visual Highlighting

### Highlight Configuration

```swift
// Configure highlight appearance
searchEngine.searchOptions.highlightResults = true
searchEngine.searchOptions.highlightColor = .yellow.withAlphaComponent(0.3)

// Configure flash animation
searchEngine.searchOptions.flashResult = true
searchEngine.searchOptions.flashColor = .systemBlue.withAlphaComponent(0.5)
```

### Manual Highlight Control

Results are automatically highlighted when `highlightResults` is true. The highlighting updates as you navigate through results.

## Search Statistics

Access detailed search statistics:

```swift
let stats = searchEngine.searchStatistics

CrossPlatformLogger.logger().info("Total matches: \(stats.totalMatches)")
CrossPlatformLogger.logger().info("Lines with matches: \(stats.linesWithMatches)")
CrossPlatformLogger.logger().info("First match line: \(stats.firstMatchLine)")
CrossPlatformLogger.logger().info("Last match line: \(stats.lastMatchLine)")
CrossPlatformLogger.logger().info("Search completed at: \(stats.searchTime)")
```

## Advanced Usage

### Async Search with Progress

```swift
// Monitor search progress
searchEngine.$isSearching
    .sink { isSearching in
        if isSearching {
            // Show progress indicator
        } else {
            // Hide progress indicator
        }
    }
    .store(in: &cancellables)
```

### Search Result Details

```swift
struct SearchResult {
    let index: Int              // Result index
    let range: NSRange         // Character range in text
    let matchedText: String    // The matched text
    let lineNumber: Int        // Line number (1-based)
    let context: String        // Surrounding context with ellipsis
}
```

### Context Extraction

Each result includes context (40 characters before and after):

```swift
let result = searchResults[0]
CrossPlatformLogger.logger().info(result.context)
// Output: "...surrounding text [matched text] more surrounding..."
```

## Platform Considerations

SearchReplaceEngine works across all platforms with proper abstractions:

### macOS
```swift
// Uses NSTextView methods
textView.replaceCharacters(in: range, with: replacement)
```

### iOS
```swift
// Uses UITextView's text storage
textStorage.replaceCharacters(in: range, with: replacement)
```

## Performance Optimization

### Batch Operations

Replace operations are optimized for performance:
- Results are sorted in reverse order to maintain correct ranges
- Text storage editing is wrapped in begin/endEditing
- Single undo group for all replacements

### Search Caching

The engine maintains internal state for efficient navigation:
- Current results are cached
- Navigation doesn't re-search
- Results update only when pattern changes

## Integration Examples

### Search Bar Implementation

```swift
struct SearchBar: View {
    @StateObject private var searchEngine = SearchReplaceEngine()
    @State private var searchText = ""
    @State private var replaceText = ""
    
    var body: some View {
        HStack {
            TextField("Search", text: $searchText)
                .onSubmit {
                    Task {
                        await searchEngine.findAll(pattern: searchText)
                    }
                }
            
            Text("\(searchEngine.currentSearchIndex + 1) of \(searchEngine.currentSearchResults.count)")
            
            Button("Previous") {
                searchEngine.findPrevious()
            }
            
            Button("Next") {
                searchEngine.findNext()
            }
            
            TextField("Replace", text: $replaceText)
            
            Button("Replace All") {
                Task {
                    await searchEngine.replaceAll(
                        pattern: searchText,
                        with: replaceText
                    )
                }
            }
        }
    }
}
```

## Best Practices

1. **Attach Once**: Attach the engine to a text view once and reuse
2. **Async Operations**: Use async/await for search operations
3. **Options Reuse**: Configure default options on the engine
4. **Memory**: Clear results when no longer needed
5. **UI Updates**: Use published properties for reactive UI

## See Also

- `SearchOptions`
- `SearchResult`
- `SearchStatistics`
- `CodeEditorView`
