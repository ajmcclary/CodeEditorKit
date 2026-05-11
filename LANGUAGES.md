# Language System Analysis & Integration Blueprint

Date: 2026-05-11
Source material: NOTES.md (audit of `CodeEditLanguages`), deep inspection of `CodeEditorPlugin` source.
Baseline: Swift 6.3, strict concurrency, macOS + iOS.

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Current Architecture Map](#current-architecture-map)
3. [Language Coverage Comparison](#language-coverage-comparison)
4. [Integration Point Analysis](#integration-point-analysis)
   - 4.1 [Language Detection](#41-language-detection)
   - 4.2 [Language Metadata & Identity](#42-language-metadata--identity)
   - 4.3 [Syntax Highlighting](#43-syntax-highlighting)
   - 4.4 [Range-Based Highlighting Insertion Point](#44-range-based-highlighting-insertion-point)
   - 4.5 [Code Folding](#45-code-folding)
   - 4.6 [Document Symbols](#46-document-symbols)
   - 4.7 [Code Completion](#47-code-completion)
   - 4.8 [LSP Integration](#48-lsp-integration)
   - 4.9 [Embedded Languages & Injections](#49-embedded-languages--injections)
5. [Bugs & Gaps Found](#5-bugs--gaps-found)
6. [Phased Migration Plan](#6-phased-migration-plan)
7. [Asset Architecture Design](#7-asset-architecture-design)
8. [Performance Benchmarks Required](#8-performance-benchmarks-required)
9. [Risks & Mitigations](#9-risks--mitigations)

---

## Executive Summary

`CodeEditLanguages` (the reference repo) is a narrow language-asset package: 5 Swift files, a prebuilt 33 MB XCFramework of Tree-sitter grammar binaries, and 178 `.scm` query files covering 41 language entries. Its architectural lesson is the **boundary**: keep grammar binaries, language metadata, and query assets separate from rendering and editor state.

`CodeEditorPlugin` (our repo) is a full editor stack with SwiftSyntax-based highlighting for Swift, regex for 17 other languages, a fast JSON tokenizer, TextKit2 rendering, code folding, document symbols, completions, LSP scaffolding, and performance instrumentation. It already has the protocol (`RangeHighlightProviding`) and pipeline (`RangeBasedHighlightingController`) to receive a Tree-sitter provider behind a feature flag.

The strongest recommendation from this analysis: **do not import CodeEditLanguages wholesale**. Instead, adopt its data-model patterns (centralized asset descriptors, typed query bundles, robust language detection) into our existing Swift 6.3 strict-concurrency architecture, then build a Tree-sitter provider behind our `RangeHighlightProviding` protocol.

**Architecture decisions**:
- **Swift stays on SwiftSyntax.** SwiftSyntax remains authoritative for Swift highlighting, document symbols, and parser-derived features. Tree-sitter is for non-Swift languages only.
- **Tree-sitter is an optional companion package** (`CodeEditorTreeSitterLanguages`), not part of the core editor package. Core stays SwiftSyntax + regex + fast JSON. Consumers opt in.

---

## Current Architecture Map

### Language Identity & Detection

| Component | File | Role | Issue |
|-----------|------|------|-------|
| `Language` enum | `SyntaxHighlightingCoordinator.swift` (line ~510) | 20-case enum with `name`, `fileExtensions`, `lspIdentifier`, `init?(fileExtension:)` | Solid foundation. Missing many languages vs. CodeEdit's 41. |
| `LanguageDetectionService` | `Core/LanguageDetectionService.swift` | Extension cache, filename table, shebang substring match, content heuristics | Shebang is simple `contains()` — misses `/usr/bin/env`, script aliases (`node`, `deno`). No modeline scanning. Dockerfile → `.shell` (wrong). |
| `LanguageStaticMetadata` | `Languages/LanguageStaticMetadata.swift` | Centralized keywords, types, functions, literals, trigger characters, highlighting strategy per language | Good direction. Only covers the 20 `Language` cases. |
| `LanguageMetadataRegistry` | `Languages/LanguageMetadataRegistry.swift` | Separate registry with `ExtendedLanguageMetadata` (snippets, modules, member completions) | Duplicates `LanguageStaticMetadata`. Only populated for Swift, TypeScript, Go. Redundant. |
| `LanguageProviderFactory` | `Languages/LanguageProviderFactory.swift` | Creates `UniversalCompletionProvider` from static metadata | Uses `LanguageStaticMetadata` — correct data flow. |

### Syntax Highlighting

| Component | File | Role | Issue |
|-----------|------|------|-------|
| `SyntaxHighlightingCoordinator` | `SyntaxHighlighting/SyntaxHighlightingCoordinator.swift` | Top-level coordinator with async/cancel support | Solid. Uses `HighlightingStrategyExecutor`. |
| `HighlightingStrategyExecutor` | `SyntaxHighlighting/HighlightingStrategyExecutor.swift` | Dispatches `.swiftSyntax` / `.fastJSON` / `.regex` / `.noHighlighting` | Clean dispatch. |
| `SwiftSyntaxHighlighter` | `Languages/SwiftSyntaxHighlighter.swift` | AST-based Swift highlighting | Correct choice for Swift. |
| `FastJSONTokenizer` | (tokenizer path) | Specialized JSON tokenizer | Good tradeoff for JSON. |
| `RegexSyntaxHighlighter` | `SyntaxHighlighting/RegexSyntaxHighlighter.swift` | Core regex engine with `LanguageDefinition` and `HighlightedToken` | Solid engine. |
| `RegexSyntaxHighlighter+LanguagesExtensions` | `SyntaxHighlighting/RegexSyntaxHighlighter+LanguagesExtensions.swift` | Language definitions for all 18 non-plainText languages | Good coverage. Builder pattern is clean. |
| `LanguageRegistry` (highlighting) | `SyntaxHighlighting/LanguageRegistry.swift` | **Separate** registry with inline rule definitions for 10 languages | **Duplicates** the regex extension definitions. Only covers 10 languages. Used by `RangeBasedHighlightingController`. |

### Range-Based Highlighting Pipeline

| Component | File | Role | Issue |
|-----------|------|------|-------|
| `RangeHighlightProviding` | `SyntaxHighlighting/RangeHighlightProviding.swift` | Protocol: `setUp`, `willApplyEdit`, `applyEdit`, `queryHighlights` | Perfect insertion point for Tree-sitter. |
| `SyntaxHighlighterRangeAdapter` | `SyntaxHighlighting/SyntaxHighlighterRangeAdapter.swift` | Wraps legacy `SyntaxHighlighter` → `RangeHighlightProviding` | Works. |
| `RangeBasedHighlightingController` | `SyntaxHighlighting/RangeBasedHighlightingController.swift` | Wires range provider into `StyledRangeContainer` + minimap | Uses `LanguageRegistry` (10 languages). |
| `StyledRangeContainer` | `SyntaxHighlighting/StyledRangeContainer.swift` | Merges tokens from multiple providers by priority | Correct for multi-provider strategy. |

### Code Folding

| Component | File | Role |
|-----------|------|------|
| `CodeFoldingProvider` protocol | `Models/FoldableRegion.swift` | `detectFoldableRegions(in:) async -> [FoldableRegion]` |
| `FoldingProviderRegistry` | `Features/FoldingProviderRegistry.swift` | Maps `Language` → `CodeFoldingProvider`. Covers all 19 active languages. |
| `BraceFoldingProvider` | `Languages/BraceFoldingProvider.swift` | Brace matching for 11 C-style languages |
| `IndentationFoldingProvider` | `Languages/IndentationFoldingProvider.swift` | Indentation for Python, YAML |
| `MarkdownFoldingProvider` | `Languages/MarkdownFoldingProvider.swift` | Heading-based sections |
| `XMLFoldingProvider` | `Languages/XMLFoldingProvider.swift` | Tag matching for HTML, XML |
| `ShellFoldingProvider` | `Languages/ShellFoldingProvider.swift` | Function/if/fi detection |
| `SQLFoldingProvider` | `Languages/SQLFoldingProvider.swift` | CREATE/block detection |
| `RubyFoldingProvider` | `Languages/RubyFoldingProvider.swift` | Class/module/def/do-end |

### Document Symbols

| Component | File | Role |
|-----------|------|------|
| `DocumentSymbolProvider` protocol | `Features/SymbolNavigationTypes.swift` | `detectSymbols(in:) async -> [DocumentSymbol]` |
| `SymbolNavigator` | `Features/SymbolNavigator.swift` | Manages providers, builds symbol tree, breadcrumbs |
| `CStyleSymbolProvider` | `Languages/CStyleSymbolProvider.swift` | Line-based function/class detection for C, C++, Java, Go, Rust |
| Language-specific providers | `Languages/*SymbolProvider.swift` | Line/regex heuristics per language |

### Completion & LSP

| Component | File | Role |
|-----------|------|------|
| `LanguageProviderFactory` | `Languages/LanguageProviderFactory.swift` | Creates `UniversalCompletionProvider` from `LanguageStaticMetadata` |
| `UniversalCompletionProvider` | `Languages/LanguageProviderFactory.swift` | Context-analyzing completion for all languages |
| `LSPLanguageFeatures` | `LSP/LSPLanguageFeatures.swift` | LSP request builders for completion, hover, definition, symbols |
| Language LSP identifiers | `SyntaxHighlightingCoordinator.swift` (Language enum) | Maps 20 languages to LSP IDs |

---

## Language Coverage Comparison

### Our 20 vs. CodeEdit's 41

Our current `Language` enum (`SyntaxHighlightingCoordinator.swift`):

```
swift, javascript, typescript, python, go, rust, c, cpp, java,
html, css, json, markdown, yaml, xml, sql, ruby, php, shell, plainText
```

CodeEditLanguages has these **additional** entries (21 more, for 41 total):

| Language | Priority | Rationale |
|----------|----------|-----------|
| **Dockerfile** | High | Currently mapped to `.shell` — incorrect. Common in dev workflows. |
| **TOML** | High | Rust ecosystem, config files. No representation today. |
| **Lua** | High | Game dev, Neovim config, embedded scripting. |
| **Kotlin** | Medium | Android ecosystem. |
| **Dart** | Medium | Flutter ecosystem. |
| **Haskell** | Medium | Functional programming. |
| **Scala** | Medium | JVM language with unique syntax. |
| **Objective-C** | Medium | Apple legacy, still in many codebases. |
| **JSX** (as parse mode) | High | React. Currently JSX files map to `.javascript`. |
| **TSX** (as parse mode) | High | React+TypeScript. Currently TSX files map to `.typescript`. |
| **JSDoc** (as parse mode) | Medium | Documentation injection. |
| **Markdown inline** (as parse mode) | Low | Inline markup differentiation. |
| **Regex** (as parse mode) | Low | Regex literal highlighting within host languages. |
| C# | Medium | .NET ecosystem. |
| Elixir | Low | Niche but growing. |
| Julia | Low | Scientific computing. |
| OCaml / OCaml interface | Low | Academic/industrial FP. |
| Perl | Low | Legacy scripting. |
| Verilog | Low | Hardware description. |
| Zig | Low | Systems programming. |
| Go module | Low | Go-specific. |
| Bash (separate from shell) | Medium | Shell currently lumps bash/sh/zsh/fish together. |
| Agda | Low | Academic. |

**Immediate additions** (low effort, high impact): Dockerfile, TOML, Lua, Kotlin, Dart, C#.
**Parse mode differentiation** (medium effort): JSX from JS, TSX from TS.

---

## Integration Point Analysis

### 4.1 Language Detection

**Current state**: `LanguageDetectionService` uses:
- Extension cache → `Language(fileExtension:)` initializer.
- Special filename table (Dockerfile→shell, Makefile→shell, etc.).
- Shebang: simple `contains("python")`, `contains("bash")`, etc.
- Content heuristics: first 1000 chars, keyword detection.

**Gaps vs. CodeEditLanguages**:

1. **Shebang parsing is naive.** CodeEdit's `detectLanguageFrom(url:prefixBuffer:suffixBuffer:)` handles:
   - `/usr/bin/env python3` → resolves to Python.
   - `/usr/bin/env -S python3 -u` → parses env flags.
   - Script aliases: `node`, `deno`, `python2`, `python3`.
   
   Our implementation (`detectLanguageFromShebang`) uses substring matching:
   ```swift
   if shebang.contains("python") { return .python }
   // ...
   ```
   Because it uses `contains()`, it *does* match `/usr/bin/env python3` (the substring "python" appears). The real problems are:
   - **Imprecision**: substring matching can produce accidental matches (e.g., a shebang containing "python" in a path like `/opt/nopython/bin/node`).
   - **Incompleteness**: it cannot structurally parse `env -S` flags, cannot distinguish `python2` from `python3` for targeted handling, and cannot resolve script aliases like `deno` (which has no substring match to any current check).
   - **Missing aliases**: `#!/usr/bin/env node` is not detected because "node" has no substring check — only "javascript" and "node" are not the same substring. Similarly, `deno` is not checked.

2. **No modeline scanning.** CodeEdit scans prefix/suffix buffers for:
   - Vim modelines: `vim: set filetype=python:`
   - Emacs modelines: `-*- mode: python -*-`
   
   Our `LanguageDetectionService` has no equivalent. These are common in scripts and configuration files.

3. **Dockerfile maps to shell.** Should be its own `Language` case (`.dockerfile`). Do not map to `.plainText` as a fallback — Dockerfile has real syntax that deserves highlighting. Add the case to the enum and provide a regex definition.

4. **No script-embedding detection.** Shebangs with `node` should detect JavaScript, `deno` should detect TypeScript, `python2`/`python3` should detect Python. Our shebang logic only matches the substring "javascript" — `#!/usr/bin/env node` would not be detected.

**Concrete improvements**:

```
LanguageDetectionService additions:
├── parseShebang(_:) → resolves env + flags → Language
│   e.g. "#!/usr/bin/env -S python3 -u" → .python
│   e.g. "#!/usr/bin/env node" → .javascript
│   e.g. "#!/usr/bin/env deno" → .typescript
├── scanModelines(prefix: String, suffix: String) → Language?
│   Matches: "vim:.*filetype=(\\w+)", "-*- mode: (\\w+) -*-"
├── resolveScriptAlias(_:) → Language?
│   "node" → .javascript, "deno" → .typescript,
│   "python2"/"python3" → .python, "rb" → .ruby
└── specialFilename table: add "Dockerfile" → .dockerfile (once added)
```

### 4.2 Language Metadata & Identity

**Current state**: Two overlapping metadata systems.

1. `LanguageStaticMetadata` (in `Languages/LanguageStaticMetadata.swift`):
   - Dictionary `[Language: Self]` with name, extensions, LSP ID, strategy, comment syntax, identifier pattern, string delimiters, keywords, types, functions, literals, trigger characters.
   - Covers all 20 languages.
   - Used by `LanguageProviderFactory` for completions.

2. `LanguageMetadataRegistry` (in `Languages/LanguageMetadataRegistry.swift`):
   - `ExtendedLanguageMetadata` adds snippets, `LanguageMemberCompletions`, `commonModules`.
   - Only populated for Swift, TypeScript, Go.
   - Contains `createProvider(for:)` — which creates a `UniversalCompletionProvider` (duplicating `LanguageProviderFactory`).

**Problem**: These two systems are redundant. `LanguageStaticMetadata` is the right single source of truth. `LanguageMetadataRegistry` should either be folded into it or the extended fields should move into `LanguageStaticMetadata`.

**CodeEditLanguages pattern**: `CodeLanguage` struct holds identity, Tree-sitter name, file extensions, comment types, parent query URL, extra query files, shebang identifiers — **one struct, one source of truth per language entry**.

**Recommendation**: Merge into a single `LanguageDescriptor`:

```swift
struct LanguageDescriptor: Sendable {
    let language: Language
    let displayName: String
    let treeSitterName: String?   // e.g. "javascript", "python"
    let fileExtensions: Set<String>
    let lspIdentifier: String
    let highlightingStrategy: HighlightingStrategy
    let lineComment: String?
    let blockComment: (start: String, end: String)?
    let docComments: [String]
    let identifierPattern: String
    let stringDelimiters: [Character]
    let shebangIdentifiers: Set<String>
    let scriptAliases: Set<String>
    let queryNames: Set<QueryPurpose>   // highlights, folds, indents, injections, locals, tags
    let keywords: [String]
    let types: [String]
    let functions: [String]
    let literals: [String]
    let triggerCharacters: [String]
}
```

### 4.3 Syntax Highlighting

**Current state**: Three strategies (`SwiftSyntax`, `FastJSON`, `regex`) dispatched through `HighlightingStrategyExecutor`. Regex definitions live in `RegexSyntaxHighlighter+LanguagesExtensions.swift` using a builder pattern. All 18 non-plainText languages have regex definitions.

**Strengths**:
- SwiftSyntax for Swift is correct and performant.
- Regex builder pattern (`LanguageDefinitionBuilder`) is clean, reduces boilerplate.
- `createLanguageMap(from:)` efficiently maps `Language` enum to definitions.
- Token type mapping is O(1) via lookup table.

**Weaknesses**:
- Regex cannot parse nested grammar (JS template literals with `${}`, HTML-in-JS, CSS-in-HTML).
- Regex definitions are hand-maintained per-language (no query-file-based highlighting).
- The `LanguageRegistry` in `LanguageRegistry.swift` duplicates regex rules inline for 10 languages — this second copy is out of sync with the canonical definitions.

**The duplicate LanguageRegistry problem in detail**:

`LanguageRegistry.registerBuiltInLanguages()` (line ~125 of `LanguageRegistry.swift`) creates `PythonLanguageProvider`, `JavaScriptLanguageProvider`, etc. — each with inline regex rules. These rules are a **subset** of the canonical rules in `RegexSyntaxHighlighter+LanguagesExtensions.swift` and are **missing languages** like Go, Rust, C, C++, Java, Ruby, PHP, Shell, SQL.

This matters because `RangeBasedHighlightingController.makeHighlighter(for:)` uses `LanguageRegistry` — so the range-backed (minimap) path produces no tokens for Go, Rust, C, C++, Java, Ruby, PHP, Shell, or SQL.

**Recommendation**: `RangeBasedHighlightingController` should use the canonical `RegexSyntaxHighlighter` definitions (from `RegexSyntaxHighlighter+LanguagesExtensions.swift`) directly, bypassing `LanguageRegistry` for built-in languages. `LanguageRegistry` should be retained only for public/custom language provider registration (its `LanguageProvider` protocol surface). Maintaining two internal registries that duplicate regex rules is unsustainable — every language addition or rule change must be made in both places.

**Tree-sitter opportunity**: Tree-sitter `highlights.scm` files are the canonical, community-maintained source of truth for syntax coloring. For non-Swift languages, using them eliminates the hand-maintenance burden. The 178 `.scm` files in CodeEditLanguages cover all major languages.

### 4.4 Range-Based Highlighting Insertion Point

**This is Phase 1 work — the only immediate code change.**

**Current state**: `RangeHighlightProviding` protocol is already the right abstraction:

```swift
@MainActor
protocol RangeHighlightProviding: AnyObject {
    func setUp(textView: CodeEditorView, language: Language)
    func willApplyEdit(textView: CodeEditorView, range: NSRange)
    func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet
    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken]
}
```

`RangeBasedHighlightingController` wires a provider into `StyledRangeContainer`, visible range tracking, edit invalidation, and minimap style data. Multiple providers can coexist (syntax + LSP + spellcheck) and their results are merged by priority.

**The RegexSyntaxHighlighter bug (critical)**:

In `LanguageRegistry.swift` (lines ~360-370):

```swift
extension RegexSyntaxHighlighter: SyntaxHighlighter {
    public convenience init(customLanguage _: LanguageDefinition) {
        self.init()  // Discards customLanguage!
    }

    public func highlight(source: String) -> [HighlightedToken] {
        let plainTextDef = LanguageDefinition(name: "Plain", fileExtensions: [], rules: [])
        return highlight(source: source, language: plainTextDef)
    }
}
```

This means the range-backed path (`RangeBasedHighlightingController` → `LanguageRegistry` → provider's `createHighlighter()` → `RegexSyntaxHighlighter(customLanguage:)` → `SyntaxHighlighterRangeAdapter`) **always produces zero tokens** because it creates a plain-text definition regardless of language.

This must be fixed before any Tree-sitter work, otherwise the baseline is broken.

**Fix**: Add an immutable stored property to `RegexSyntaxHighlighter` itself — do **not** use Objective-C associated objects. Under Swift 6.3 strict concurrency, an immutable `let` property initialized at construction time is safe, auditable, and free of runtime association hazards:

```swift
public final class RegexSyntaxHighlighter: Sendable {
    // Existing properties...
    public let supportedLanguages: [String: RegexLanguageDefinition]
    private let languageMap: [Language: RegexLanguageDefinition]

    /// Optional default language — stored immutably at init for use when
    /// `highlight(source:)` is called without an explicit definition.
    private let defaultLanguage: RegexLanguageDefinition?

    public init(defaultLanguage: RegexLanguageDefinition? = nil) {
        self.supportedLanguages = Self.createLanguageDefinitions()
        self.languageMap = Self.createLanguageMap(from: supportedLanguages)
        self.defaultLanguage = defaultLanguage
    }

    // Conforms to SyntaxHighlighter.highlight(source:)
    public func highlight(source: String) -> [HighlightedToken] {
        guard let language = defaultLanguage else {
            // No language defined — return empty (plain text, no tokens).
            return []
        }
        return highlight(source: source, language: language)
    }
}
```

### 4.5 Code Folding

**Current state**: 7 folding providers registered for all 19 active languages in `FoldingProviderRegistry`. Providers are heuristic:

- **Brace**: Character-by-character scan. Works for simple cases, fails with strings containing braces, comments containing braces, nested template literals.
- **Indentation**: Whitespace-counting. Fragile for mixed tabs/spaces, inconsistent indentation.
- **Markdown**: Heading level detection. Works well for its limited scope.
- **XML/HTML**: Tag matching regex. Works for well-formed documents.
- **Shell/Ruby/SQL**: Custom keyword-based detection.

**Tree-sitter opportunity**: `folds.scm` query files provide exact fold regions based on actual parse trees. They handle:
- Braces inside strings correctly (parser knows it's a string, not a structural brace).
- Nested folds with proper hierarchy.
- Language-specific fold boundaries (e.g., Python `def`/`class`, Ruby `do`/`end`, Markdown sections).
- Zero false positives from comments/strings.

CodeEditLanguages ships `folds.scm` for most grammars. This is the single biggest correctness improvement we could make to folding — more impactful than highlighting because wrong folds are more disruptive to the user than wrong colors.

**Migration path**: Add a `TreeSitterFoldProvider` that conforms to `CodeFoldingProvider` and uses `folds.scm` queries. Register it for languages with available queries, fall back to heuristic providers for others.

### 4.6 Document Symbols

**Current state**: 12 symbol providers registered in `SymbolNavigator.setupDefaultProviders()`. Most are line-based or simple regex heuristics:

- `CStyleSymbolProvider`: Scans for `(` followed by `)` on a line → function. Scans for `class`/`struct` prefix → class/struct. **Fragile**: matches function calls, misses multi-line signatures, false-positives on string contents.
- `PythonSymbolProvider`: Indentation + `def`/`class` detection.
- `JavaScriptSymbolProvider`: Similar line-based approach.
- `MarkdownSymbolProvider`: Heading detection (works well).
- Various language-specific providers: similar heuristic approaches.

**Tree-sitter opportunity**: `tags.scm` query files provide structured document symbols with:
- Exact symbol boundaries (not line-based guesses).
- Symbol kind (function, class, method, variable, constant, etc.).
- Nested symbol hierarchy (class → method → inner function).
- Selection range (the symbol name, not the full range).
- Zero false positives from comments/strings.

CodeEditLanguages ships `tags.scm` for several grammars. This would make the symbol navigator/breadcrumbs dramatically more accurate for JS, TS, Python, Ruby, PHP, and others.

**Migration path**: Add a `TreeSitterSymbolProvider` conforming to `DocumentSymbolProvider`. Register for languages with `tags.scm`, fall back to heuristic providers.

### 4.7 Code Completion

**Current state**: `LanguageProviderFactory` creates `UniversalCompletionProvider` from `LanguageStaticMetadata`. The provider uses `SharedContextAnalyzer` and `SharedCompletionBuilder` — well-factored, avoids per-language switch statements.

Coverage: All 20 languages have keyword/type/function/literal completions via `LanguageStaticMetadata`. Member completions exist for Swift, JavaScript, TypeScript, Python, Rust, Go, Java, C, C++.

**CodeEditLanguages contribution**: CodeEditLanguages has no completion system — it's purely a parse/query resource package. Our completion system is already more advanced.

**Recommendation**: No changes needed for the completion system in the context of language asset integration. Continue using `LanguageStaticMetadata` as the source of truth. The Tree-sitter integration will not directly affect completions (LSP handles semantic completions; Tree-sitter provides parse trees for scope analysis, which is a separate feature).

### 4.8 LSP Integration

**Current state**: `LSPLanguageFeatures` provides request builders for completion, hover, definition, document symbols, references, rename, formatting, code action, code lens, signature help. Language LSP identifiers are in the `Language` enum.

**Coverage**: All 20 languages have correct LSP identifiers. New languages added to the enum will need LSP identifiers.

**CodeEditLanguages contribution**: CodeEdit's `CodeLanguage` doesn't have LSP identifiers — it's focused on parse/query resources. Our LSP scaffolding is independent.

**Recommendation**: When adding new `Language` cases, add the corresponding LSP identifier. No architectural changes needed.

### 4.9 Embedded Languages & Injections

**Current state**: No injection system exists. The regex highlighter treats the entire document as a single language. This means:

- Markdown fenced code blocks (```` ```javascript ````) are not highlighted as JavaScript.
- HTML `<script>` and `<style>` tags are not highlighted as JavaScript/CSS.
- PHP blocks within HTML are not handled.
- JS template literals (`` `hello ${name}` ``) are not syntax-colored inside.

**Tree-sitter opportunity**: `injections.scm` query files define language nesting rules. Tree-sitter can recursively parse injected languages, producing proper tokens for embedded code. This is a headline feature that regex cannot match.

**Implementation note**: Injections require the Tree-sitter provider (or a compatible parser) and add complexity — recursive parsing, parse scheduling, range management for nested languages. This should be Phase 6b after basic Tree-sitter highlighting (Phase 5/6a) is stable.

---

## Bugs & Gaps Found

### Critical Bugs

1. **`RegexSyntaxHighlighter` convenience init discards custom language** (BLOCKING)
   - File: `SyntaxHighlighting/LanguageRegistry.swift`, line ~360
   - Effect: Range-based highlighting path produces zero tokens for all regex-backed languages.
   - Fix: Add `private let defaultLanguage: RegexLanguageDefinition?` to `RegexSyntaxHighlighter` itself, initialize it in a new `init(defaultLanguage:)` and use it in `highlight(source:)`. No associated objects.

2. **`LanguageRegistry.registerBuiltInLanguages()` only registers 10 languages** (BLOCKING)
   - File: `SyntaxHighlighting/LanguageRegistry.swift`, line ~125
   - Effect: `RangeBasedHighlightingController` has no highlighting for Go, Rust, C, C++, Java, Ruby, PHP, Shell, SQL.
   - Fix: Switch `RangeBasedHighlightingController` to use the canonical `RegexSyntaxHighlighter` definitions directly. Retain `LanguageRegistry` only for public/custom language providers.

3. **Dockerfile maps to `.shell`** (HIGH)
   - Files: `Core/LanguageDetectionService.swift` (line ~70), `Language` enum fileExtensions
   - Effect: Dockerfile content gets shell highlighting, which is semantically wrong.
   - Fix: Add `.dockerfile` as a real `Language` case with its own regex definition. Do not fall back to `.plainText`.

4. **`LanguageMetadataRegistry` duplicates `LanguageStaticMetadata`** (MEDIUM)
   - Files: `Languages/LanguageMetadataRegistry.swift`, `Languages/LanguageStaticMetadata.swift`
   - Effect: Two sources of truth for language metadata. Only 3 of 20 languages in the registry.
   - Fix: Merge into one or deprecate `LanguageMetadataRegistry`.

### Gaps (Non-Critical)

5. **Shebang parsing is substring-based, not structural.** It matches `/usr/bin/env python3` by coincidence (substring "python"), but cannot resolve `env -S` flags, misses `deno`/`node` aliases, and can produce accidental matches. Replace with structural parser.
6. **No modeline scanning** — Vim/Emacs modelines are common in scripts and config files.
7. **No injection support** — embedded languages (Markdown code blocks, HTML script/style, JS template literals) get no highlighting.
8. **Folding providers are heuristic** — brace-matching can't distinguish string braces from structural braces.
9. **Symbol providers are heuristic** — line-based function detection has false positives.

---

## Phased Migration Plan

### Phase 1: Baseline Correctness (immediate — only code work now)

**Goal**: Make the existing range-based pipeline work correctly. No new features, no Tree-sitter.

1. Fix `RegexSyntaxHighlighter` custom language init → add `private let defaultLanguage: RegexLanguageDefinition?` and use it in `highlight(source:)`.
2. Switch `RangeBasedHighlightingController` to use canonical `RegexSyntaxHighlighter` definitions directly instead of `LanguageRegistry` for built-in languages.
3. Add regression tests proving `RangeBasedHighlightingController` produces tokens for JS, Python, Go, Rust, SQL, Shell, Markdown, JSON, and CSS.
4. Add `.dockerfile` as a real `Language` case with its own regex definition.

**Files touched**: `RegexSyntaxHighlighter.swift`, `RangeBasedHighlightingController.swift`, `LanguageRegistry.swift`, `LanguageDetectionService.swift`, `Language` enum.

### Phase 2: Descriptor Consolidation

**Goal**: Merge all language metadata into a single `LanguageDescriptor` source of truth **before** adding languages or new detection logic.

1. Merge `LanguageMetadataRegistry` into `LanguageStaticMetadata` (or deprecate the former).
2. Add `LanguageDescriptor` struct with all fields: identity (extensions, LSP ID, Tree-sitter name, shebang identifiers, script aliases), syntax (comments, strategy), completion data (keywords, types, functions, literals, triggers), and query purposes.
3. Ensure `Language` enum properties (`name`, `fileExtensions`, `lspIdentifier`) delegate to `LanguageDescriptor.all[language]` rather than containing their own switch statements.
4. Ensure `RegexSyntaxHighlighter.createLanguageMap(from:)`, `LanguageProviderFactory`, `SymbolNavigator`, `FoldingProviderRegistry`, and `LanguageDetectionService` all read from the descriptor.

**Why before language additions**: Adding a new language today touches the `Language` enum switch (name, extensions, LSP ID), `LanguageStaticMetadata.all` dictionary, `RegexSyntaxHighlighter+LanguagesExtensions` definitions, `FoldingProviderRegistry` registrations, `SymbolNavigator` registrations, `LanguageDetectionService` filename table, and optionally `LanguageRegistry` inline rules. After consolidation, a new language is one descriptor entry plus a regex definition.

**Files touched**: `LanguageStaticMetadata.swift`, `LanguageMetadataRegistry.swift`, `LanguageProviderFactory.swift`, `SyntaxHighlightingCoordinator.swift` (Language enum).

### Phase 3: Language Detection

**Goal**: Replace substring-based shebang matching with structural parsing. Add modeline scanning.

1. Add `parseShebang(_:)` — resolves `/usr/bin/env` indirection, handles `-S` flags, extracts the script name, looks it up in the descriptor's `shebangIdentifiers` and `scriptAliases` sets.
2. Add `scanModelines(prefix:suffix:)` — detects Vim (`vim:.*filetype=`) and Emacs (`-*- mode: ... -*-`) modelines, resolves filetype to `Language` via descriptor.
3. Remove the old substring-based `detectLanguageFromShebang`. The new parser uses the descriptor alias table, so `deno` → TypeScript, `node` → JavaScript, `python2`/`python3` → Python, etc.
4. Add coverage tests for shebang variants: `/usr/bin/env python3`, `/usr/bin/env -S python3 -u`, `/usr/bin/env node`, `/usr/bin/env deno`, `/bin/bash`, `/usr/bin/ruby`.

**Files touched**: `LanguageDetectionService.swift`.

### Phase 4: Add Small Languages

**Goal**: Add Dockerfile, TOML, Lua, C#, Kotlin, Dart. Do this after descriptor consolidation so each language is one descriptor entry + one regex definition.

1. Add `.dockerfile`, `.toml`, `.lua`, `.csharp`, `.kotlin`, `.dart` to `Language` enum.
2. Add `LanguageDescriptor` entries for each.
3. Add regex definitions in `RegexSyntaxHighlighter+LanguagesExtensions`.
4. Register folding / symbol providers (start with `BraceFoldingProvider` for brace-based languages, `IndentationFoldingProvider` for TOML/Lua/Dockerfile).
5. Map file extensions, shebangs, and LSP identifiers.

**Files touched**: `Language` enum, `LanguageStaticMetadata.swift`, `RegexSyntaxHighlighter+LanguagesExtensions.swift`, `FoldingProviderRegistry.swift`, `SymbolNavigator.swift`.

### Phase 5: Tree-sitter Spike (JavaScript only, feature-flagged)

**Goal**: Prove Tree-sitter highlighting works behind a feature flag. Swift stays on SwiftSyntax throughout.

1. Resolve SwiftTreeSitter Swift 6.3 compatibility (verify 0.25.x compiles with `StrictConcurrency`). If it does not, fork or write a minimal wrapper.
2. Build a `TreeSitterRangeHighlightProvider` conforming to `RangeHighlightProviding`.
3. Load JavaScript grammar + `highlights.scm` queries.
4. Implement parse → query → `[HighlightedToken]` pipeline.
5. Support incremental editing: apply edits to tree, re-query only invalidated ranges.
6. Run on macOS first, JavaScript only.
7. Benchmark against current regex highlighting: parse time, query time, memory for 10K/100K-line JS files.

**Files touched**: New `TreeSitter/` directory or `SyntaxHighlighting/TreeSitter/`.

### Phase 6: Tree-sitter Expansion

**Goal**: Expand Tree-sitter to all non-Swift languages with available grammars. Highlighting first, then injections, then folds/symbols.

**Sub-phase 6a — Highlighting**:
1. Add grammars for high-impact languages: TypeScript, Python, JSON, HTML, CSS, Markdown, Ruby, PHP, Shell, SQL, Go, Rust, C, C++, Java, YAML, XML.
2. Map Tree-sitter capture names to our `TokenType` enum.
3. Implement capture-to-token mapping table per language.
4. Add feature flag: `EditorConfiguration.behavior.useTreeSitterHighlighting`.
5. Benchmark all supported languages.

**Sub-phase 6b — Injections**:
1. Implement `injections.scm` support.
2. Recursive parse scheduling for nested languages.
3. Markdown fenced code blocks, HTML `<script>`/`<style>`, JS template literals first.
4. PHP-in-HTML, JSX, TSX as injection modes.

**Sub-phase 6c — Folding & Symbols**:
1. Build `TreeSitterFoldProvider` using `folds.scm`.
2. Build `TreeSitterSymbolProvider` using `tags.scm`.
3. Register alongside existing heuristic providers with priority fallback.

### Phase 7: Packaging

**Goal**: Extract Tree-sitter grammars and query assets into an optional companion package.

1. Extract grammar binaries + query resources into `CodeEditorTreeSitterLanguages` package.
2. Core editor stays lean (pure Swift + SwiftSyntax + regex fallback).
3. Consumers opt in via package dependency or feature flag.
4. Build automation for grammar updates (CI pipeline, not manual XCFramework builds).

---

## Asset Architecture Design

### Language Descriptor (single source of truth)

```swift
/// The canonical descriptor for a single supported language.
/// One instance per `Language` case, stored in a static dictionary.
struct LanguageDescriptor: Sendable {
    let language: Language
    let displayName: String

    // Identity
    let treeSitterName: String?          // e.g. "javascript"
    let fileExtensions: Set<String>
    let lspIdentifier: String
    let shebangIdentifiers: Set<String>  // e.g. {"python", "python3"}
    let scriptAliases: Set<String>       // e.g. {"node"}

    // Syntax
    let highlightingStrategy: HighlightingStrategy
    let lineComment: String?
    let blockComment: (start: String, end: String)?
    let docComments: [String]

    // Tree-sitter queries available for this language
    let queryPurposes: Set<QueryPurpose>

    // Completion data
    let keywords: [String]
    let types: [String]
    let functions: [String]
    let literals: [String]
    let triggerCharacters: [String]
}

enum QueryPurpose: String, Sendable, CaseIterable {
    case highlights
    case folds
    case indents
    case injections
    case locals
    case tags
}
```

### Tree-sitter Provider Interface

```swift
/// Tree-sitter-backed range highlight provider.
/// Implements RangeHighlightProviding for integration with
/// RangeBasedHighlightingController.
@MainActor
final class TreeSitterRangeHighlightProvider: RangeHighlightProviding {
    func setUp(textView: CodeEditorView, language: Language)
    func willApplyEdit(textView: CodeEditorView, range: NSRange)
    func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet
    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken]
}
```

Internal design:
- One parser + syntax tree per document, stored in a `DocumentParseState` actor.
- Edits applied to tree before reparsing (O(log n) per edit, not O(n)).
- Queries cached by document version + range.
- Parse/query work off the main actor; results delivered to main actor for TextKit updates.
- Cancellation on rapid edits (debounce + cancel stale tasks).

### Typed Query Cache

```swift
/// Typed query bundles per language, lazily loaded.
actor TreeSitterQueryCache {
    func highlightQuery(for language: Language) -> Query?
    func foldQuery(for language: Language) -> Query?
    func tagQuery(for language: Language) -> Query?
    func injectionQuery(for language: Language) -> Query?
}
```

Separate query purposes so that:
- The highlighter only loads `highlights.scm`.
- The folding provider only loads `folds.scm`.
- The symbol provider only loads `tags.scm`.
- Injection handling only loads `injections.scm`.

This avoids CodeEditLanguages' pattern of combining all query files into one query.

---

## Performance Benchmarks Required

Before shipping Tree-sitter highlighting, measure against current regex path:

| Metric | Fixture | Target |
|--------|---------|--------|
| Initial parse time | 10K-line JS, Python, Markdown | < 50 ms per file |
| Initial parse time | 100K-line JS | < 500 ms |
| Incremental edit time | 10K-line JS, mid-edit | < 5 ms |
| Viewport query time | Visible 80-line window | < 2 ms |
| Memory after open | 10K-line JS | < 50 MB (parser + tree + queries) |
| Memory after scroll | 100K-line JS | < 200 MB |
| Memory after close | — | 0 MB (no leaks) |
| Startup latency | Cold launch, 20 languages available | < 100 ms (lazy query loading) |

Compare each metric against current regex path. Tree-sitter will be slower for initial parse (it builds an actual AST) but should win on:
- Incremental edits (tree edit vs. full re-regex).
- Correctness (no false positives from strings/comments).
- Folding and symbol quality (structured vs. heuristic).

---

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| SwiftTreeSitter doesn't compile under Swift 6.3 | High | Verify before starting Phase 5. Fall back to fork or wrapper if needed. |
| Tree-sitter binary size (grammars) | Medium | Keep in optional companion package. Core editor stays lean. |
| iOS build complexity (C library) | Medium | Validate ARM64 slices early. Consider embedded grammar bundles. |
| Query capture names don't match our `TokenType` | Low | Build explicit mapping table per language. Test with snapshot tests. |
| Parser state per document → memory pressure | Medium | Limit concurrent parsers. Invalidate idle parsers under memory pressure. |
| Incremental query complexity | Medium | Start with viewport-only queries. Cache by version+range. |
| Maintenance burden of grammar updates | Low | Automate via CI. Community-maintained grammars update on their own cadence. |

---

## Verification Checklist

- [ ] Phase 1: `RegexSyntaxHighlighter` stores default language as immutable `let` property.
- [ ] Phase 1: `RangeBasedHighlightingController` uses canonical regex definitions (not `LanguageRegistry`) for all 18 non-plainText languages.
- [ ] Phase 1: Regression tests prove range-backed minimap tokens for JS, Python, Go, Rust, SQL, Shell, Markdown, JSON, CSS.
- [ ] Phase 1: `.dockerfile` added as real `Language` case, not mapped to `.shell`.
- [ ] Phase 2: Single `LanguageDescriptor` replaces dual metadata systems.
- [ ] Phase 2: `Language` enum properties delegate to `LanguageDescriptor` (no inline switch statements).
- [ ] Phase 3: Shebang parser resolves `/usr/bin/env node` → JavaScript, `/usr/bin/env deno` → TypeScript.
- [ ] Phase 3: Modeline scanner detects `vim: set filetype=python:`.
- [ ] Phase 4: Dockerfile, TOML, Lua, C#, Kotlin, Dart each added as one descriptor + one regex definition.
- [ ] Phase 5: JavaScript Tree-sitter spike compiles under Swift 6.3.
- [ ] Phase 5: 10K-line JS file parses in < 50 ms.
- [ ] Phase 6a: All 18 non-Swift languages have Tree-sitter highlighting behind feature flag.
- [ ] Phase 6b: Markdown fenced code blocks get injected highlighting.
- [ ] Phase 6c: Tree-sitter folding and symbols available alongside heuristic fallbacks.

---

## References

- `NOTES.md` — Audit of CodeEditLanguages repository (2026-05-11).
- `docs/Architecture/TreeSitterDecision.md` — Gate B decision to defer Tree-sitter until after Phase 3.
- `Sources/CodeEditorPlugin/Core/LanguageDetectionService.swift` — Current language detection.
- `Sources/CodeEditorPlugin/Languages/LanguageStaticMetadata.swift` — Centralized language metadata.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift` — Language enum, TokenType, HighlightedToken.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightingStrategyExecutor.swift` — Strategy dispatch.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeHighlightProviding.swift` — Provider protocol.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeBasedHighlightingController.swift` — Range pipeline.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/LanguageRegistry.swift` — Duplicate registry (10 languages).
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter.swift` — Core regex engine.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RegexSyntaxHighlighter+LanguagesExtensions.swift` — Language definitions.
- `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlighterRangeAdapter.swift` — Adapter for range pipeline.
- `Sources/CodeEditorPlugin/Features/CodeFoldingEngine.swift` — Folding engine.
- `Sources/CodeEditorPlugin/Features/FoldingProviderRegistry.swift` — Folding provider registry.
- `Sources/CodeEditorPlugin/Features/SymbolNavigator.swift` — Symbol navigation.
