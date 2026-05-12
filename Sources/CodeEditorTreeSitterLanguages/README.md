# CodeEditorTreeSitterLanguages

> Optional companion package for Tree-sitter grammar support.
> **Status**: Extraction target — currently lives inside `CodeEditorPlugin/SyntaxHighlighting/TreeSitter/`.

## Purpose

This package will contain:

- **Grammar binaries**: Prebuilt `.dylib`/`.framework` files for each supported Tree-sitter grammar (JavaScript, TypeScript, Python, Go, Rust, C, C++, Java, HTML, CSS, JSON, Markdown, YAML, XML, SQL, Ruby, PHP, Shell, etc.)
- **Query files**: `highlights.scm`, `folds.scm`, `tags.scm`, `injections.scm` per language
- **Swift wrappers**: Thin Swift types that load grammars and queries, conforming to `TreeSitterParserProtocol`

## Extraction Plan (Phase 7)

### Current state

All Tree-sitter code lives in `Sources/CodeEditorPlugin/SyntaxHighlighting/TreeSitter/`:

```
TreeSitter/
├── TreeSitterRangeHighlightProvider.swift   # Provider + ParserProtocol + RegexBackedParser
├── TreeSitterCaptureMap.swift               # Capture name → TokenType mapping
├── TreeSitterInjectionLayer.swift           # Injection rules
├── TreeSitterFoldProvider.swift             # folds.scm-backed folding
└── TreeSitterSymbolProvider.swift           # tags.scm-backed symbols
```

### Extraction steps

1. **Create `Sources/CodeEditorTreeSitterLanguages/`** as a new SPM target in `Package.swift`:
   ```swift
   .target(
       name: "CodeEditorTreeSitterLanguages",
       dependencies: ["CodeEditorPlugin"],
       resources: [.process("Grammars"), .process("Queries")],
       swiftSettings: swiftSettings
   )
   ```

2. **Move Tree-sitter files** from `CodeEditorPlugin/SyntaxHighlighting/TreeSitter/` to the new target.

3. **Swap `RegexBackedTreeSitterParser`** for a real C Tree-sitter parser that loads grammar binaries and runs `highlights.scm` queries.

4. **Add as optional dependency** in consumer `Package.swift`:
   ```swift
   dependencies: [
       .package(url: "https://github.com/ajmcclary/CodeEditorPlugin.git", from: "0.2.0"),
       .package(url: "https://github.com/ajmcclary/CodeEditorTreeSitterLanguages.git", from: "0.1.0")
   ],
   targets: [
       .target(
           name: "MyApp",
           dependencies: [
               .product(name: "CodeEditorPlugin", package: "CodeEditorPlugin"),
               .product(name: "CodeEditorTreeSitterLanguages", package: "CodeEditorTreeSitterLanguages")
           ]
       )
   ]
   ```

5. **Consumer code** will wire the provider explicitly once the companion
   package exists:
   ```swift
   import CodeEditorPlugin
   import CodeEditorTreeSitterLanguages

   var config = EditorConfiguration()
   config.performance.usesRangeBasedHighlighting = true
   // Future companion package API will register its provider explicitly.
   ```

### Why separate?

- **Binary size**: Grammar binaries are large (33 MB+ as an XCFramework). The core editor stays lean at ~2 MB.
- **Build time**: Tree-sitter grammars are C code that must be compiled per architecture. Separating them avoids slowing down core editor builds.
- **Optional**: Not every consumer needs Tree-sitter. Regex highlighting covers all 26 languages with correct token production.
- **Update cadence**: Grammar updates happen on the Tree-sitter community schedule, not the editor's release cadence.

## Public integration status

The core editor does not define a Tree-sitter build flag by default and does not expose a runtime `EditorConfiguration` switch. Until real grammar binaries and queries ship in this companion package, the consumer-facing highlighting path remains SwiftSyntax for Swift and regex definitions for other languages.
