# `CodeEditorPlugin/SmartEditingEngine`

Provides intelligent editing features including auto-brackets, multi-cursor support, smart indentation, and selection expansion.

## Overview

`SmartEditingEngine` enhances the editing experience with intelligent features that boost productivity. It automatically inserts matching brackets and quotes, manages multiple cursors for simultaneous edits, provides context-aware auto-indentation, and offers smart selection expansion. The engine works by intercepting text changes through the text view delegate pattern.

## Key Features

- **Auto-Bracket Insertion**: Automatically inserts closing brackets, parentheses, and quotes
- **Multi-Cursor Editing**: Edit multiple locations simultaneously
- **Smart Indentation**: Context-aware indentation based on language rules
- **Selection Expansion**: Expand selection to logical boundaries (word, line, brackets)
- **Quote Handling**: Smart quote pairing with word boundary detection

## Basic Setup

### Attaching to a Text View

```swift
let smartEngine = SmartEditingEngine()
smartEngine.attach(to: codeEditorView)

// Configure features
smartEngine.configuration.autoInsertBrackets = true
smartEngine.configuration.isAutoIndentEnabled = true
smartEngine.configuration.enableMultiCursor = true
```

## Auto-Bracket Insertion

### Default Bracket Pairs

The engine handles these bracket pairs by default:
- Parentheses: `(` `)`
- Square brackets: `[` `]`
- Curly braces: `{` `}`
- Double quotes: `"` `"`
- Single quotes: `'` `'`
- Backticks: \` \`

### Bracket Behavior

```swift
// When typing an opening bracket:
// Input: (
// Result: (|)  // Cursor positioned between brackets

// When typing a closing bracket with cursor before it:
// Before: (|)
// Input: )
// Result: ()|  // Cursor moves past the bracket

// Quote behavior is context-aware:
// Won't auto-pair inside words
// Input: word|  then "
// Result: word"|  // No auto-pairing
```

## Multi-Cursor Support

### Adding Cursors

```swift
// Add cursor at specific location
smartEngine.addCursor(at: 100)

// Add cursors at all occurrences of selected text
codeEditorView.selectedRange = NSRange(location: 50, length: 8)
smartEngine.addCursorsAtOccurrences()

// Clear all extra cursors
smartEngine.clearMultiCursors()
```

### Multi-Cursor Editing

```swift
// When multiple cursors are active:
// - Text typed appears at all cursor locations
// - Deletions happen at all cursors
// - Each cursor maintains its own position

// Monitor cursor state
smartEngine.$isMultiCursorMode
    .sink { isMulti in
        CrossPlatformLogger.logger().info("Multi-cursor mode: \(isMulti)")
    }

smartEngine.$cursors
    .sink { cursors in
        CrossPlatformLogger.logger().info("Active cursors: \(cursors.count)")
    }
```

## Smart Indentation

### Configuration

```swift
// Configure indentation behavior
smartEngine.configuration.isAutoIndentEnabled = true
smartEngine.configuration.insertSpacesForTabs = true
smartEngine.configuration.tabWidth = 4
smartEngine.configuration.detectIndentation = true
```

### Auto-Indent Rules

The engine includes language-aware indentation rules:

```swift
// Opening brace increases indent:
// if condition {
//     | <- cursor indented

// Closing brace decreases indent:
// }| <- cursor dedented

// Python colon increases next line indent:
// def function():
//     | <- cursor indented

// Switch case statements:
// case value:
//     | <- cursor indented
```

### Custom Indent Rules

```swift
// Add custom indentation rules
let customRule = AutoIndentRule(
    trigger: "begin",
    action: .increaseIndent
)

// The engine will detect these triggers and adjust indentation
```

## Smart Selection

### Expand Selection

```swift
// Expand selection to logical boundaries
smartEngine.expandSelection()

// Expansion follows this hierarchy:
// 1. Word boundaries
// 2. Line boundaries  
// 3. Enclosing brackets
// 4. Entire document
```

### Selection Stops

```swift
// Configure expansion stops
smartEngine.configuration.expandSelectionStops = [
    .word,    // Select current word
    .line,    // Select current line
    .scope,   // Select enclosing scope
    .all      // Select all
]
```

### Bracket-Aware Selection

```swift
// With cursor inside brackets:
// func example(param1, |param2, param3)

// First expansion: selects "param2"
// Second expansion: selects line
// Third expansion: selects "(param1, param2, param3)"
```

## Platform-Specific Features

### macOS Modifier Keys

```swift
#if canImport(AppKit)
// Configure multi-cursor modifier
smartEngine.configuration.multiCursorModifierKey = .option
// Option+Click to add cursor
#endif
```

### iOS Touch Support

```swift
#if canImport(UIKit)
// Configure for touch
smartEngine.configuration.multiCursorModifierKey = .alternate
// Long press + drag for multi-cursor
#endif
```

## Advanced Configuration

### Complete Configuration Example

```swift
var config = SmartEditingConfiguration()

// Auto-brackets
config.autoInsertBrackets = true
config.autoInsertQuotes = true
config.wrapSelection = true  // Wrap selected text with brackets

// Multi-cursor
config.enableMultiCursor = true

// Auto-indentation
config.isAutoIndentEnabled = true
config.insertSpacesForTabs = true
config.tabWidth = 4
config.detectIndentation = true  // Detect from file

// Smart selection
config.enableSmartSelection = true
config.expandSelectionStops = [.word, .line, .scope, .all]

smartEngine.configuration = config
```

## Delegate Integration

SmartEditingEngine works by implementing the text view delegate:

```swift
// The engine intercepts these delegate methods:
// - textView(_:shouldChangeTextIn:replacementString:)
// - textViewDidChangeSelection(_:)

// Your existing delegates will be replaced
// Consider this when integrating with other features
```

## Common Patterns

### Wrap Selection with Brackets

```swift
// When text is selected and opening bracket typed:
// Selected: "text"
// Type: (
// Result: (text)
```

### Skip Over Quotes

```swift
// When cursor is before a quote:
// Position: "|"
// Type: "
// Result: "| // Cursor moves past instead of inserting
```

### Indentation Detection

```swift
// The engine can detect indentation from existing code:
if config.detectIndentation {
    // Analyzes current file to determine:
    // - Tabs vs spaces
    // - Indentation width
}
```

## Performance Considerations

1. **Multi-Cursor Limits**: Limit cursors for performance
2. **Indentation Rules**: Keep rules simple and fast
3. **Selection Expansion**: Uses efficient algorithms for bracket matching
4. **Delegate Overhead**: Minimal overhead on text changes

## Troubleshooting

### Brackets Not Auto-Pairing

```swift
// Check configuration
assert(smartEngine.configuration.autoInsertBrackets)

// Verify attachment
assert(codeEditorView.delegate === smartEngine)
```

### Indentation Not Working

```swift
// Ensure auto-indent is enabled
assert(smartEngine.configuration.isAutoIndentEnabled)

// Check for conflicting delegate
// SmartEditingEngine must be the text view delegate
```

## Best Practices

1. **Single Engine**: Use one SmartEditingEngine per text view
2. **Early Attachment**: Attach before user interaction begins
3. **Configuration**: Configure before attaching
4. **Delegate Conflicts**: Be aware of delegate replacement
5. **Platform Testing**: Test features on all target platforms

## See Also

- `SmartEditingConfiguration`
- `TextCursor`
- `AutoIndentRule`
- `SmartEditingBracketPair`
- `CodeEditorView`
