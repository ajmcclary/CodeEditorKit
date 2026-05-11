# CodeEditLanguages Audit Notes

Date: 2026-05-11

Compared repository:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditLanguages`

Current repository:

- `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin`

Important framing: this project is Swift 6.3 with strict concurrency enabled, and that should remain the baseline. The useful lessons from `CodeEditLanguages` are architectural and data-model lessons, not a compatibility target. We should not lower language mode or accept Swift 5.7-era constraints.

## Executive Summary

`CodeEditLanguages` is not an editor framework. It is a compact language asset package around Tree-sitter:

- 5 Swift source files.
- A prebuilt `CodeLanguagesContainer.xcframework.zip`.
- 178 Tree-sitter `.scm` query files.
- Metadata for 41 grammar entries.
- SwiftTreeSitter as the runtime wrapper.

Our repo is a full editor stack: TextKit2, SwiftUI/AppKit/UIKit bridging, syntax highlighting, folding, completion, symbols, minimap, LSP, theming, performance systems, and tests. The main thing to learn from `CodeEditLanguages` is the boundary: keep grammar binaries, language metadata, query assets, and language detection separate from rendering and editor state.

The strongest recommendation is to copy the language-asset architecture, not import `CodeEditLanguages` wholesale. Build a Swift 6.3 strict-concurrency-compatible Tree-sitter provider behind our existing range-based highlighting protocol.

## Repository Shape

### CodeEditLanguages

The package is small and intentionally narrow:

- `Package.swift` declares one library target, one binary target, one test target.
- The source target depends on `CodeLanguagesContainer` and `SwiftTreeSitter`.
- The source target copies `Resources`.
- It links C++ because some Tree-sitter grammars use C++ scanners.
- It supports macOS only in its manifest.

Useful source files:

- `Sources/CodeEditLanguages/CodeLanguage.swift`
- `Sources/CodeEditLanguages/CodeLanguage+Definitions.swift`
- `Sources/CodeEditLanguages/CodeLanguage+DetectLanguage.swift`
- `Sources/CodeEditLanguages/TreeSitterLanguage.swift`
- `Sources/CodeEditLanguages/TreeSitterModel.swift`

Key measured facts from local inspection:

- `CodeLanguagesContainer.xcframework.zip`: about 33 MB compressed.
- Unzipped framework binary listed by `unzip -l`: about 392 MB.
- `Sources/CodeEditLanguages/Resources`: about 780 KB.
- `.scm` query files: 178 files, about 12,015 total lines.
- Runtime Swift source plus tests: about 2,319 lines.

### CodeEditorPlugin

Our package is broader and already has infrastructure that can host parser-backed language services:

- Swift 6.3.
- Strict concurrency.
- macOS and iOS targets.
- SwiftSyntax for Swift.
- Regex and fast tokenizer strategies for other languages.
- Async highlighting, token caching, streaming fallback, range stores, minimap style data.
- Folding, symbols, completions, LSP, annotations, UI, and platform abstraction.

Key files in our repo:

- `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/HighlightingStrategyExecutor.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeHighlightProviding.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/RangeBasedHighlightingController.swift`
- `Sources/CodeEditorPlugin/SyntaxHighlighting/StyledRangeContainer.swift`
- `Sources/CodeEditorPlugin/Text/RangeStore/RangeStore.swift`
- `Sources/CodeEditorPlugin/Core/LanguageDetectionService.swift`
- `docs/Architecture/TreeSitterDecision.md`

## What CodeEditLanguages Does Well

### 1. Language Metadata Is Centralized

`CodeLanguage` holds language identity, Tree-sitter name, file extensions, line comments, range comments, documentation comments, parent query URL, additional query files, and shebang identifiers.

This is cleaner than spreading the same metadata across:

- language enum cases,
- completion providers,
- folding providers,
- symbol providers,
- syntax highlighter definitions,
- LSP identifier logic,
- language detection services.

Our repo has made progress with `LanguageStaticMetadata`, but there is still duplication across detection, highlighting, completion, folding, symbols, and LSP. A data-backed registry should become the source of truth.

### 2. Grammar Coverage Is Broad

`CodeEditLanguages` defines these grammar entries:

- Agda
- Bash
- C
- C++
- C#
- CSS
- Dart
- Dockerfile
- Elixir
- Go
- Go module
- Haskell
- HTML
- Java
- JavaScript
- JSDoc
- JSON
- JSX
- Julia
- Kotlin
- Lua
- Markdown
- Markdown inline
- Objective-C
- OCaml
- OCaml interface
- Perl
- PHP
- Python
- Regex
- Ruby
- Rust
- Scala
- SQL
- Swift
- TOML
- TSX
- TypeScript
- Verilog
- YAML
- Zig
- Plain text

Our public language enum currently covers 20 entries. The most immediately useful CodeEdit gaps for us are:

- C#
- Dockerfile as its own language, not shell
- Lua
- TOML
- Kotlin
- Dart
- Haskell
- Scala
- Objective-C
- Regex
- Markdown inline
- JSDoc
- JSX/TSX as distinct parse modes

### 3. Query Assets Cover More Than Highlighting

The `Resources/tree-sitter-*` folders include:

- `highlights.scm`
- `folds.scm`
- `indents.scm`
- `injections.scm`
- `locals.scm`
- `tags.scm`
- `structure.scm` for Go-related grammars

This is the biggest lesson. Tree-sitter is not just a syntax coloring engine. Query assets can become one substrate for:

- syntax highlighting,
- fold discovery,
- indentation,
- embedded-language injections,
- local scopes,
- document symbols,
- semantic-ish tagging.

Our current implementations are more fragmented:

- highlighting is SwiftSyntax, regex, or fast JSON;
- folding is brace, indentation, XML, Markdown, SQL, shell, Ruby providers;
- symbols are line-based or custom providers;
- embedded language handling is minimal and mostly regex-bound.

Tree-sitter queries could unify those features for non-Swift languages.

### 4. Query Composition Is Simple

`TreeSitterModel` lazily creates and caches queries. It supports:

- parent query inheritance, such as C plus C++;
- additional query files, such as folds, injections, locals, tags;
- lazy query construction per language.

This is a useful model, but we should adapt it:

- Keep query purpose separate instead of always combining all extra query files.
- Cache typed query bundles, for example `highlightQuery`, `foldQuery`, `tagQuery`, `injectionQuery`.
- Make cache ownership actor-safe or main-actor-confined under Swift 6.3 strict concurrency.

### 5. Language Detection Handles Real Editor Conventions

`CodeLanguage.detectLanguageFrom(url:prefixBuffer:suffixBuffer:)` detects:

- URL extension or special filename.
- Shebangs.
- `/usr/bin/env` with flags and env parameters.
- Vim modelines.
- Emacs modelines.

Our `LanguageDetectionService` detects extensions, a few special filenames, simple shebang substring matches, and simple content heuristics. We should adopt the modeline and better shebang parsing ideas.

Concrete improvement:

- Replace the substring shebang logic with parser-style logic that resolves script identifiers.
- Add prefix and suffix modeline scanning.
- Add aliases like `node`, `deno`, `python2`, `python3`.
- Stop mapping `Dockerfile` to shell once Dockerfile exists as its own language.

## Weaknesses And Risks In CodeEditLanguages

### 1. The Binary Container Is Large

The compressed artifact is convenient for consumers and avoids SPM resolving dozens of grammar packages. The tradeoff is a large binary:

- about 33 MB compressed locally;
- about 392 MB uncompressed according to archive listing.

For our repo, this argues for an optional product or separate companion package:

- `CodeEditorPlugin` stays lean.
- `CodeEditorTreeSitterLanguages` or similar carries grammar binaries and queries.
- Consumers opt in when they want broad parser-backed language support.

### 2. It Is macOS-Only As Packaged

`CodeEditLanguages` currently declares only macOS in its `Package.swift`. Our project supports macOS and iOS. A direct adoption would need:

- iOS device and simulator slices;
- C/C++ scanner build validation;
- SPM binary target validation;
- strict-concurrency review of wrappers and shared state.

Since we are Swift 6.3 strict concurrency, compatibility work should mean raising the language package to us, not lowering us to it.

### 3. Resource Lookup Fails Locally Under SwiftPM Tests

Running `swift test --parallel` in `CodeEditLanguages` built successfully, then failed many query-resource tests because the code looked for:

```text
...bundle/Resources/Resources/tree-sitter-*/highlights.scm
```

But the bundle layout contains:

```text
...bundle/Resources/tree-sitter-*/highlights.scm
```

The likely issue is `CodeLanguage.queryURL(for:)` appending `"Resources/tree-sitter-\(tsName)/..."` to `Bundle.module.resourceURL`, while SwiftPM has already placed copied resources under the bundle resource root.

This matters if we copy the design:

- Add resource path tests under SwiftPM.
- Avoid hard-coding an extra `Resources` component unless packaging layout requires it.
- Consider a small `LanguageResourceLocator` abstraction with test fixtures.

### 4. The Update Pipeline Is Heavy

`build_framework.sh`:

- builds an Xcode framework project;
- creates an XCFramework;
- zips it;
- deletes and repopulates resource queries;
- reads target paths through `swift package dump-package`;
- depends on `jq`;
- clones `nvim-treesitter` and copies missing queries with license headers.

This is effective but not lightweight. If we adopt this pattern, it should live in a companion language package with clear release automation, not in the editor core.

### 5. Query Composition Is Too Coarse For Our Use

`TreeSitterModel.queryFor(_:)` may combine parent and additional query files into a single query. That is acceptable for a narrow highlighting package, but not ideal for us because different subsystems need different capture sets:

- highlighter wants highlight captures;
- folding wants `@fold`;
- symbols want `@definition.*` and `@name`;
- injections need recursive parse scheduling;
- locals need scope information.

Typed query bundles will be easier to reason about and test.

## Our Current Architecture Compared

### Parsing And Highlighting

Current high-level strategy:

- Swift uses SwiftSyntax.
- JSON uses a custom fast tokenizer.
- Most non-Swift languages use regex rules.
- Plain text uses no highlighting.

This is dispatched in `HighlightingStrategyExecutor`.

Strengths:

- Pure Swift for most paths.
- Easy to build on iOS.
- Strict-concurrency-compatible baseline.
- SwiftSyntax is likely the right choice for Swift.
- Regex is simple and predictable for basic highlighting.

Weaknesses:

- Regex cannot parse nested grammar reliably.
- Embedded languages are hard.
- Folding and symbols duplicate language knowledge.
- JS/TS/HTML/Markdown/PHP correctness will lag query-backed parsers.

### Range-Based Highlighting Is The Right Insertion Point

Our `RangeHighlightProviding` protocol is already the right abstraction for a Tree-sitter provider:

- `setUp(textView:language:)`
- `willApplyEdit`
- `applyEdit`
- `queryHighlights(textView:range:)`

`RangeBasedHighlightingController` already wires a provider into:

- `StyledRangeContainer`
- visible range tracking
- text edit invalidation
- minimap style data

This means Tree-sitter can be introduced behind a feature flag without replacing the legacy attributed-string path immediately.

### Important Current Bug Or Gap In Our Range Path

`RangeBasedHighlightingController.makeHighlighter(for:)` creates a `LanguageRegistry` and asks for a provider. But `LanguageRegistry.registerBuiltInLanguages()` only registers:

- Swift
- Python
- JavaScript
- JSON
- HTML
- CSS
- Markdown
- XML
- YAML
- Plain text

It omits many languages that `Language.allCases` supports.

More importantly, `RegexSyntaxHighlighter(customLanguage:)` discards the passed language definition, and `RegexSyntaxHighlighter.highlight(source:)` uses an empty plain-text definition. That likely means the range-backed path produces no regex tokens for non-Swift languages even though the legacy coordinator path works.

Before introducing Tree-sitter, fix this baseline:

- Make `RegexSyntaxHighlighter` store the custom language definition for protocol conformance.
- Or make `SyntaxHighlighterRangeAdapter` wrap `SyntaxHighlightingCoordinator` directly.
- Ensure all supported `Language` cases can participate in range-based highlighting.

### Folding

Our folding providers are pragmatic:

- brace-based for C-style languages;
- indentation for Python/YAML;
- Markdown section folding;
- XML/HTML tag folding;
- shell, SQL, Ruby custom providers.

This works, but Tree-sitter `folds.scm` gives a more correct and maintainable path for languages with mature queries. We should eventually back folding with Tree-sitter queries where available.

### Symbols

Our symbol providers are mostly line-based or regex-ish. For Swift, a Tree-sitter `tags.scm` is available in CodeEdit, but SwiftSyntax remains the stronger Swift-native option for us. For JS/TS/Python/Ruby/PHP/HTML/CSS/SQL/etc., `tags.scm` can produce better document symbols than our line heuristics.

### Rendering

`CodeEditLanguages` has no rendering strategy. It provides parse/query resources only.

Our rendering system is much more advanced:

- TextKit2 bridge and helper layers.
- Async highlighter with debounce and cancellation.
- Token cache.
- Streaming/highlight fallback paths.
- Range stores.
- Minimap style data.
- Unified drawing and platform abstraction.

There is no direct rendering pattern to copy from `CodeEditLanguages`. The lesson is to keep language parsing independent from rendering so it can feed multiple surfaces: editor text, minimap, folding gutter, breadcrumbs, and completion.

## Performance Lessons

### What CodeEditLanguages Optimizes

It optimizes package resolution and query loading:

- Prebuilt grammar container avoids resolving many grammar packages on consumer install.
- Lazy query properties avoid parsing all queries at startup.
- Query files are copied once and shipped as resources.

It does not implement:

- incremental parsing;
- edit application to Tree-sitter trees;
- viewport query execution;
- background parser scheduling;
- rendering invalidation;
- memory pressure behavior.

### What We Already Optimize

Our repo already has more runtime performance infrastructure:

- async highlighting with debounce and cancellation;
- `SmartTokenCache`;
- large-file thresholds;
- streaming fallback;
- `StyledRangeContainer`;
- `RangeStore`;
- memory pressure cleanup;
- performance metrics and budgets;
- viewport/range invalidation scaffolding.

### What We Should Add

For Tree-sitter, add performance work at the provider layer:

- one parser/tree per document and language mode;
- apply edits to the existing tree instead of reparsing full text;
- query only visible or invalidated ranges;
- cache query results by document version and range;
- keep parser work off the main actor where possible;
- return to the main actor only to update TextKit or range stores;
- cancel stale parse/query tasks on rapid edits;
- measure parse time, query time, memory, and range update time.

Benchmark requirements before shipping:

- 10K-line JS/TS/Python/Markdown fixtures.
- 100K-line stress fixtures.
- Initial parse time.
- Incremental edit time near top, middle, and bottom.
- Query time for visible viewport.
- Memory after open, scroll, edit, and close.
- Comparison against current regex path.

## Recommended Architecture For Us

### Phase 1: Fix Our Existing Range Highlighting Baseline

Before adding Tree-sitter:

- Fix `RegexSyntaxHighlighter(customLanguage:)`.
- Ensure `RangeBasedHighlightingController` can produce real tokens for all non-Swift supported languages.
- Add tests proving range-backed minimap/style data has tokens for JavaScript, Python, JSON, Markdown, and CSS.

This prevents Tree-sitter from hiding an existing broken path.

### Phase 2: Add A Tree-sitter Language Asset Boundary

Create a strict-concurrency-compatible internal abstraction:

```swift
struct LanguageAssetDescriptor: Sendable {
    var id: Language
    var treeSitterName: String
    var fileExtensions: Set<String>
    var lineComment: String?
    var blockComment: (start: String, end: String)?
    var documentationComments: [DocumentationComment]
    var aliases: Set<String>
    var queryNames: Set<QueryPurpose>
}

enum QueryPurpose: String, Sendable {
    case highlights
    case folds
    case indents
    case injections
    case locals
    case tags
}
```

Back it with a resource locator and typed query cache.

### Phase 3: Tree-sitter Range Highlight Provider

Add a feature-flagged provider:

```swift
@MainActor
final class TreeSitterRangeHighlightProvider: RangeHighlightProviding {
    func setUp(textView: CodeEditorView, language: Language)
    func willApplyEdit(textView: CodeEditorView, range: NSRange)
    func applyEdit(textView: CodeEditorView, range: NSRange, delta: Int) async -> IndexSet
    func queryHighlights(textView: CodeEditorView, range: NSRange) async throws -> [HighlightedToken]
}
```

Implementation details:

- Maintain parser and syntax tree in a document-scoped state object.
- Apply edits to the tree before reparsing.
- Use query captures to build `HighlightedToken`.
- Map captures like `keyword.function`, `function.call`, `variable.builtin`, `punctuation.bracket` into our coarser `TokenType`.
- Preserve SwiftSyntax as default for Swift.

### Phase 4: Injections

Implement injection support after plain highlighting works:

- Markdown fenced code blocks.
- HTML `<script>` and `<style>`.
- JavaScript template literal injections.
- Regex literals.
- JSDoc comments.

This is where Tree-sitter starts to beat regex visibly.

### Phase 5: Folding And Symbols

Use `folds.scm` and `tags.scm` to improve:

- `CodeFoldingProvider`
- `DocumentSymbolProvider`
- breadcrumbs
- minimap markers

Do this after highlight provider performance is proven.

### Phase 6: Packaging

Avoid forcing all users to download grammar binaries by default.

Prefer:

- core editor package remains pure Swift plus SwiftSyntax;
- optional language grammar package contains Tree-sitter binaries and query resources;
- feature flag or dependency injection selects Tree-sitter provider when available.

## Specific Ideas To Pull Into Our Codebase

### Language Detection

Adopt:

- prefix and suffix modeline scanning;
- robust shebang parser;
- script aliases;
- file-name-as-extension behavior for files like `Dockerfile`.

Do not copy:

- macOS-only assumptions;
- lower Swift tools version;
- non-concurrency-aware singleton model.

### Query Resources

Adopt:

- `highlights.scm` for non-Swift syntax highlighting;
- `injections.scm` for embedded languages;
- `folds.scm` for folding;
- `tags.scm` for symbols;
- parent query inheritance, such as C to C++ and JS to TS;
- extra query files for JSX/TSX-style modes.

Adapt:

- separate query purpose caches;
- strict resource path tests;
- Sendable or actor-safe wrappers;
- iOS-compatible binary packaging.

### Performance

Adopt:

- lazy query creation;
- optional binary grammar bundle to avoid repeated SPM grammar resolution.

Build ourselves:

- incremental edit application;
- viewport query ranges;
- cancellation;
- memory pressure cleanup;
- benchmarks.

## Risks If We Adopt Too Much Directly

- Large binary artifact in the core package.
- No iOS packaging out of the box.
- Swift 6.3 strict concurrency audit needed.
- Resource path assumptions may fail under SwiftPM.
- Query capture names do not match our `TokenType` exactly.
- Combining query files may produce captures we do not want in a given subsystem.
- Parser state must be document-scoped, not a global singleton.

## Concrete Next Steps

1. Fix our current range-based regex highlighter path.
2. Add better language detection with shebang/modeline support.
3. Create a small Tree-sitter spike for JavaScript only, behind a feature flag.
4. Run the spike on macOS first, then validate iOS slices.
5. Benchmark against current regex highlighting.
6. If the spike is good, extract language assets into an optional package.
7. Add Markdown/HTML injections next.
8. Add `folds.scm` and `tags.scm` integration after highlighting is stable.

## Verification Notes

Commands run during audit:

```bash
rg --files
sed -n ...
find Sources/CodeEditLanguages/Resources -name '*.scm'
du -h CodeLanguagesContainer.xcframework.zip
unzip -l CodeLanguagesContainer.xcframework.zip
swift test --parallel
```

`swift test --parallel` in `CodeEditLanguages`:

- dependencies resolved and build completed;
- tests then failed due resource lookup using `Resources/Resources/...`;
- this appears to be a package resource path issue, not a parser compile failure.

No tracked files were modified during the audit itself. This `NOTES.md` file is the first saved artifact from the research.
