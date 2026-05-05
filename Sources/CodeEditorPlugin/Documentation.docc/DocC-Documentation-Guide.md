# DocC Documentation Guide

Learn how to generate, view, and contribute to CodeEditorPlugin's documentation.

## Overview

CodeEditorPlugin uses Apple's DocC (Documentation Compiler) to provide comprehensive API documentation with 100% coverage. This guide explains how to work with the documentation system.

## Generating Documentation

### Using Xcode

The easiest way to view documentation:

1. Open CodeEditorPlugin in Xcode
2. Select **Product → Build Documentation** (⌃⇧⌘D)
3. Documentation opens in Xcode's viewer

### Command Line Generation

Generate documentation archives and static websites:

```bash
# Generate documentation archive
swift package generate-documentation

# Generate static website
swift package generate-documentation \
    --target CodeEditorPlugin \
    --output-path ./docs \
    --transform-for-static-hosting \
    --hosting-base-path /CodeEditorPlugin
```

### Hosting Documentation

Deploy the static site to GitHub Pages:

```bash
# Generate docs
swift package generate-documentation \
    --transform-for-static-hosting \
    --output-path ./docs

# Commit and push
git add docs/
git commit -m "Update documentation"
git push

# Enable GitHub Pages for the /docs folder
```

## Documentation Structure

### Topic Organization

The documentation is organized into logical groups:

#### Essentials
- **Getting Started** - Quick integration guide
- **CodeEditorView** - Main editor component
- **CodeEditor** - SwiftUI wrapper
- **EditorConfiguration** - Configuration system

#### Core Components
- **Text Editing** - Editor API and operations
- **Syntax Highlighting** - Language support
- **Code Completion** - Intelligence features
- **Annotations** - TODO/FIXME detection

#### Advanced Features
- **Language Server Protocol** - LSP integration
- **Performance** - Monitoring and optimization
- **Platform Support** - Cross-platform capabilities
- **Error Handling** - Comprehensive error system

### Documentation Coverage

Current metrics:
- **Public APIs Documented**: 100%
- **Documentation Comments**: 500+
- **Code Examples**: 100+
- **Cross-References**: 200+
- **Platform Notes**: 50+

## Writing Documentation

### DocC Comment Format

Follow this structure for comprehensive documentation:

```swift
/// Brief one-line description of the type or method.
///
/// Detailed explanation providing context and usage information.
/// Can span multiple paragraphs as needed.
///
/// ## Overview
///
/// Additional context, important notes, or architectural details.
///
/// ## Example
///
/// ```swift
/// let editor = CodeEditorView()
/// editor.text = "Hello, World!"
/// ```
///
/// - Parameters:
///   - parameter1: Description of first parameter
///   - parameter2: Description of second parameter
/// - Returns: Description of return value
/// - Throws: `ErrorType` when specific conditions occur
///
/// - Note: Important information to highlight
/// - Warning: Potential issues to be aware of
/// - Important: Critical information
///
/// - SeeAlso: ``RelatedType``, ``relatedMethod()``
public func exampleMethod(parameter1: String, parameter2: Int) throws -> Bool
```

### Best Practices

#### 1. Be Comprehensive
- Document all public APIs
- Include parameter descriptions
- Explain return values and errors
- Add usage examples

#### 2. Use Cross-References
```swift
/// Uses ``TokenType`` to categorize syntax elements.
/// - SeeAlso: ``Language``, ``SyntaxHighlighter``
```

#### 3. Platform-Specific Notes
```swift
/// - Note: On iOS, this requires `UITextView` configuration.
/// - Important: Mac Catalyst uses hybrid behavior.
@available(iOS 26.3, macOS 26.3, *)
```

#### 4. Code Examples
```swift
/// ## Example
/// 
/// Basic usage:
/// ```swift
/// let config = EditorConfiguration()
/// config.display.isLineNumbersEnabled = true
/// ```
/// 
/// Advanced configuration:
/// ```swift
/// var config = EditorConfiguration()
/// config.display.fontSize = 16
/// config.display.theme = .dark
/// ```
```

#### 5. Error Documentation
```swift
/// - Throws: ``CodeEditorError/invalidRange(_:textLength:)`` if the range exceeds text bounds
/// - Throws: ``CodeEditorError/encodingError`` if text encoding fails
```

## DocC Features

### Extension Files

Add extended documentation without modifying source:

```markdown
# ``CodeEditorPlugin/CodeEditorView``

Extended documentation for CodeEditorView with additional examples and use cases.

## Topics

### Creating an Editor
- ``init()``
- ``init(frame:)``

### Configuring Display
- ``showsLineNumbers``
- ``highlightSelectedLine``
```

### Tutorials

Create step-by-step guides:

```markdown
@Tutorial(time: 15) {
    @Intro(title: "Building a Code Editor") {
        Learn to create a fully-featured code editor.
        
        @Image(source: editor-intro.png, alt: "Code editor preview")
    }
    
    @Section(title: "Basic Setup") {
        @Steps {
            @Step {
                Import CodeEditorPlugin.
                @Code(name: "ContentView.swift", file: setup-01.swift)
            }
        }
    }
}
```

### Articles

Provide conceptual documentation:

```markdown
# Architecture Overview

@Metadata {
    @PageKind(article)
    @PageImage(purpose: card, source: architecture-card.png)
}

Deep dive into CodeEditorPlugin's architecture...
```

## Viewing Documentation

### In Xcode

- **Quick Help**: Option-click any API
- **Documentation Window**: ⇧⌘0
- **Jump to Documentation**: ⌃⌘?

### Documentation Browser

After building documentation:
1. Navigate by topic
2. Search for specific APIs
3. View linked code examples
4. Follow cross-references

### Online Hosting

When hosted as static site:
- Full search functionality
- Syntax highlighted code
- Responsive design
- Direct linking to topics

## Contributing Documentation

### Guidelines

1. **Document New APIs**: Every public API needs documentation
2. **Update Examples**: Ensure examples compile and work
3. **Add Cross-References**: Link related APIs
4. **Include Platform Notes**: Document platform differences
5. **Test Documentation**: Build and review before submitting

### Documentation Review Checklist

- [ ] All public APIs have summaries
- [ ] Parameters and return values documented
- [ ] At least one code example provided
- [ ] Cross-references to related APIs
- [ ] Platform availability noted
- [ ] Errors/throws documented
- [ ] Grammar and spelling checked

### Common Documentation Patterns

#### Async Methods
```swift
/// Asynchronously processes the document.
///
/// - Note: This method performs work on a background queue.
/// - Parameter document: The document to process
/// - Returns: Processed result
/// - Throws: ``ProcessingError`` if processing fails
public func process(_ document: Document) async throws -> Result
```

#### Delegate Methods
```swift
/// Notifies the delegate that editing began.
///
/// Implement this method to respond to the start of editing.
/// 
/// - Parameter editor: The editor that began editing
/// - SeeAlso: ``codeEditorViewDidEndEditing(_:)``
func codeEditorViewDidBeginEditing(_ editor: CodeEditorView)
```

#### Configuration Properties
```swift
/// Controls whether line numbers are displayed.
///
/// Default is `true`. When enabled, shows line numbers in the gutter.
///
/// ## Example
/// ```swift
/// editor.showsLineNumbers = false  // Hide line numbers
/// ```
///
/// - Note: On iOS, requires ``CodeEditorContainerView`` for proper display.
public var showsLineNumbers: Bool
```

## Troubleshooting Documentation

### Build Failures

If documentation fails to build:

1. Check for syntax errors in doc comments
2. Verify all type references use double backticks
3. Ensure code examples are valid Swift
4. Check that referenced images exist

### Missing Cross-References

If type reference links don't work:

1. Verify the type is public
2. Check spelling and capitalization
3. Use full type paths if needed: `CodeEditorPlugin/TypeName`
4. Ensure the target module is imported

### Preview Issues

If examples don't preview correctly:

1. Make examples self-contained
2. Import necessary modules
3. Use complete, compilable code
4. Avoid referencing private APIs

## Future Enhancements

Planned documentation improvements:

1. **Video Tutorials** - Screen recordings for common tasks
2. **Interactive Examples** - Live code playgrounds
3. **API Diffs** - Migration guides between versions
4. **Localization** - Multi-language documentation
5. **Search Enhancement** - Better full-text search

## See Also

- <doc:GettingStarted>
- <doc:Architecture-Overview>
- [Apple's DocC Documentation](https://www.swift.org/documentation/docc/)
