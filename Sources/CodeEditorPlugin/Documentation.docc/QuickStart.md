# Quick Start

@Metadata {
    @PageKind(article)
    @PageColor(blue)
}

Get a minimal code editor running in your app in under 1 minute.

## Overview

This is the absolute quickest way to add a code editor to your app. For more comprehensive setup and features, see <doc:GettingStarted>.

## Minimal SwiftUI Example

```swift
import CodeEditorPlugin
import SwiftUI

struct ContentView: View {
    @State private var code = "print(\"Hello, World!\")"
    
    var body: some View {
        CodeEditor(text: $code)
            .codeLanguage(.swift)
    }
}
```

That's it! You now have a functional code editor with Swift syntax highlighting.

## Next Steps

- <doc:GettingStarted> - Full setup guide with all options
- <doc:Configuration-System> - Customize the editor
- <doc:Syntax-Highlighting> - Support for 20 languages

## See Also

- <doc:SwiftUI-Integration>
- <doc:UIKit-AppKit-Integration>