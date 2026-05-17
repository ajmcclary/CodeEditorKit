# CodeEditorLanguages Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract `Sources/CodeEditorPlugin/Languages/` into a new SPM target `CodeEditorLanguages` (phase 3 per NEXT.md §6.2.6). Pull the `Language` enum out of `SyntaxHighlighting/`, relocate the Completion data-model layer + `CompletionProvider` protocol, and push the folding/symbol interface types down from `Features/` into Languages.

**Architecture:** Six sequential commits, each independently buildable. Five preparatory commits leave the umbrella single-target but with all interface relocations done; the sixth commit splits the target in `Package.swift`. Then final validation + NEXT.md status update. No new tests written — this is a refactor; the existing test suite is the regression net.

**Tech Stack:** Swift 6.3, SPM, SwiftLint (strict), Swift Testing + XCTest hybrid.

**Source spec:** `docs/superpowers/specs/2026-05-17-codeeditor-languages-extraction-design.md` (commit `24d55d7`).

---

## Pre-flight context (read before Task 1)

Six new SPM targets currently exist alongside the umbrella `CodeEditorPlugin` target: `CodeEditorCommon`, `CodeEditorTextModel`, `CodeEditorPlatform`, `CodeEditorConfiguration`, `CodeEditorTheming`, and the historical `CodeEditorDesignTokens`. Phase A (commit `8bac96cb`) promoted 116 symbols to `package` access; `package` is sufficient across same-package target boundaries. Promote to `public` **only** if an external consumer of `CodeEditorPlugin` needs the symbol.

Working directory is `/Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin`. Working branch is `main`. The user works directly on `main` per stored feedback.

Each task ends with `git commit` and `swift build` + targeted `swift test --filter <Name>` green. Full `swift test --parallel` + `swiftlint` runs once at the end (Task 6). Do not skip the targeted runs.

If any task fails mid-way, rollback is `git restore .` (uncommitted work) or `git reset --hard HEAD~1` (last commit). Tasks never depend on each other's uncommitted state — every task starts from a clean working tree.

---

## Task 1: Access promotion (Folding internals + DocumentSymbolKind members)

**Files:**
- Modify: `Sources/CodeEditorPlugin/Features/FoldableRegion.swift` (lines 7, 11, 26, 40, 58 — the four `internal` declarations + the `FoldingType` enum + the `CodeFoldingConfiguration` struct)
- Modify: `Sources/CodeEditorPlugin/Features/SymbolNavigationTypes.swift` (lines 59, 90 — the two `internal` computed properties on `DocumentSymbolKind`)
- Test: existing `Tests/CodeEditorPluginTests/Features/`, `Tests/CodeEditorPluginTests/Languages/`

**Context:** `FoldableRegion`, `FoldingType`, and `CodeFoldingProvider` are all `internal` today. When `Languages/` becomes its own target, the Languages-side providers (e.g. `BraceFoldingProvider`) need these declarations cross-target — so they must move to Languages. Promoting to `public` first is the safe pre-flight: the build stays single-target through Task 4. `CodeFoldingConfiguration` does **not** move (its consumers are split between Configuration and the future Folding engine — that's NEXT.md §6.0 question 2, out of scope here). It stays in Features/ but must also become `public` because the file declares it inline with the moving types and the easiest split path is to lift the whole access bar uniformly; we'll separate it in Task 3.

`DocumentSymbolKind.icon` and `.canContainSymbols` have no access modifier (default `internal`). One umbrella consumer (`Features/SymbolNavigator.swift:141`) references `canContainSymbols`; promoting both to `package` is sufficient (same-package cross-target).

- [ ] **Step 1.1: Promote FoldableRegion declarations to public**

Open `Sources/CodeEditorPlugin/Features/FoldableRegion.swift`. Replace the file with:

```swift
import CodeEditorPlatform
import Foundation

// MARK: - Foldable Region

/// Represents a foldable region in the text
public struct FoldableRegion: Identifiable {
    public let id = UUID()
    public var range: NSRange
    public var title: String
    public var type: FoldingType
    public var level: Int = 0
    public var parentId: UUID?
    public var foldedText: String?

    public init(range: NSRange, title: String, type: FoldingType) {
        self.range = range
        self.title = title
        self.type = type
    }
}

// MARK: - Folding Type

/// Types of foldable regions
public enum FoldingType: Equatable {
    case function
    case `class`
    case method
    case block
    case comment
    case imports
    case region
    case custom(String)
}

// MARK: - Code Folding Configuration

/// Configuration for code folding behavior
public struct CodeFoldingConfiguration {
    public var enabled = true
    public var showGutterControls = true
    public var hidesFoldedContent = true
    public var minimumLineCount = 3
    public var foldedIndicator = " ⋯ "

    public var indicatorColor = PlatformColors.secondaryLabel

    public var animatesFolding = true
    public var saveFoldState = true
    public var enableIncrementalUpdates = true

    public init() {}
}

// MARK: - Code Folding Provider Protocol

/// Protocol for language-specific folding providers
@MainActor
public protocol CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion]
}
```

Note: `public struct CodeFoldingConfiguration` now needs an explicit `public init()` because the synthesized default is `internal`.

- [ ] **Step 1.2: Promote DocumentSymbolKind members to package**

Open `Sources/CodeEditorPlugin/Features/SymbolNavigationTypes.swift`. Find:

```swift
    var icon: String {
```

at line 59. Change to:

```swift
    package var icon: String {
```

Find:

```swift
    var canContainSymbols: Bool {
```

at line 90. Change to:

```swift
    package var canContainSymbols: Bool {
```

- [ ] **Step 1.3: Build and targeted test**

Run:

```bash
swift build
```

Expected: build succeeds.

Run:

```bash
swift test --filter Folding
```

Expected: tests pass (folding test count varies; verify zero failures).

Run:

```bash
swift test --filter Symbol
```

Expected: tests pass.

- [ ] **Step 1.4: Commit**

```bash
git add Sources/CodeEditorPlugin/Features/FoldableRegion.swift Sources/CodeEditorPlugin/Features/SymbolNavigationTypes.swift
git commit -m "$(cat <<'EOF'
Promote CodeFoldingProvider/FoldableRegion to public for Languages extraction

Promotes FoldableRegion, FoldingType, CodeFoldingConfiguration, and
CodeFoldingProvider from internal to public so they can move to the
forthcoming CodeEditorLanguages target. Also promotes
DocumentSymbolKind.icon and .canContainSymbols from internal (default)
to package access.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Rollback:** `git reset --hard HEAD~1` (restores Features/ originals).

---

## Task 2: Extract `Language` enum into Languages/Language.swift

**Files:**
- Modify: `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift` (delete lines 179–341)
- Create: `Sources/CodeEditorPlugin/Languages/Language.swift`
- Test: existing `Tests/CodeEditorPluginTests/SyntaxHighlighting/`, `Tests/CodeEditorPluginTests/Languages/`

**Context:** The `Language` enum currently lives at lines 239–326 of `SyntaxHighlightingCoordinator.swift`, preceded by a doc-comment block (lines 181–238) and a `// MARK: - Language` divider (line 179), and followed by an `extension Language { ... }` at lines 330–340 (provides `identifier` property + `init?(identifier:)`). All of that moves to one new file at the canonical home. The file's `SyntaxHighlightingCoordinator` class (lines 66–177), `TokenType`-related code (line 342+), and `HighlightedToken` (line 518+) stay untouched.

A pre-check earlier confirmed zero call sites use the qualified form `SyntaxHighlightingCoordinator.Language`, so no rewrite is needed elsewhere — this is a pure relocation.

- [ ] **Step 2.1: Create the new Language.swift file**

Create `Sources/CodeEditorPlugin/Languages/Language.swift` with this content (copied verbatim from `SyntaxHighlightingCoordinator.swift:179–341`):

```swift
// MARK: - Language

/// Represents the programming languages supported by the code editor.
///
/// The Language enum defines all supported languages for syntax highlighting,
/// code completion, and other language-specific features. Each language has
/// associated file extensions and display names.
///
/// ## Supported Languages
///
/// The editor supports 25 programming languages plus plain text, grouped by category:
///
/// ### Web Development
/// - `.html` - HTML markup
/// - `.css` - CSS stylesheets  
/// - `.javascript` - JavaScript (.js, .mjs, .cjs)
/// - `.typescript` - TypeScript (.ts, .tsx)
///
/// ### Systems Programming
/// - `.swift` - Swift (with AST-based highlighting)
/// - `.rust` - Rust (.rs)
/// - `.c` - C language (.c, .h)
/// - `.cpp` - C++ (.cpp, .cc, .cxx, .hpp)
/// - `.go` - Go (.go)
///
/// ### Scripting Languages
/// - `.python` - Python (.py, .pyw)
/// - `.ruby` - Ruby (.rb)
/// - `.php` - PHP (.php)
/// - `.shell` - Shell scripts (.sh, .bash, .zsh)
///
/// ### Data & Configuration
/// - `.json` - JSON (.json)
/// - `.yaml` - YAML (.yml, .yaml)
/// - `.xml` - XML (.xml)
/// - `.sql` - SQL (.sql)
///
/// ### Documentation
/// - `.markdown` - Markdown (.md, .markdown)
/// - `.plainText` - Plain text (no highlighting)
///
/// ## Example
///
/// ```swift
/// // Set language directly
/// editor.language = .swift
///
/// // Get display name
/// let name = Language.python.name  // "Python"
///
/// // Check file extensions
/// let extensions = Language.javascript.fileExtensions  // ["js", "mjs", "cjs"]
///
/// // Detect from file extension
/// if let language = Language(fileExtension: "py") {
///     editor.language = language  // .python
/// }
/// ```
///
/// - SeeAlso: `CodeEditorView.language`, `CodeEditorView.setLanguage(fileExtension:)`
public enum Language: String, CaseIterable, Equatable, Hashable, Sendable, Codable {
    case swift
    case javascript
    case typescript
    case python
    case go
    case rust
    case c // swiftlint:disable:this identifier_name
    case cpp
    case java
    case html
    case css
    case json
    case markdown
    case yaml
    case xml
    case sql
    case ruby
    case php
    case shell
    case dockerfile
    case toml
    case lua
    case csharp
    case kotlin
    case dart
    case plainText = "plaintext"

    /// The human-readable display name for the language.
    ///
    /// Use this property to show language names in UI elements like
    /// language selectors or status bars.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let languages = Language.allCases.map { $0.name }
    /// // ["Swift", "JavaScript", "TypeScript", ...]
    /// ```
    public var name: String {
        LanguageDescriptor.descriptor(for: self)?.displayName ?? rawValue.capitalized
    }

    /// The file extensions associated with this language.
    ///
    /// Returns an array of common file extensions (without dots) that are
    /// typically used for files of this language type.
    ///
    /// ## Example
    ///
    /// ```swift
    /// Language.python.fileExtensions    // ["py", "pyw"]
    /// Language.cpp.fileExtensions       // ["cpp", "cc", "cxx", "hpp", "h", "hh"]
    /// ```
    public var fileExtensions: [String] {
        LanguageDescriptor.descriptor(for: self)?.fileExtensions ?? []
    }
}

// MARK: - Language Extensions

extension Language {
    /// Unique identifier for the language (used by plugin system)
    public var identifier: String {
        rawValue
    }

    /// Get language from identifier
    public init?(identifier: String) {
        self.init(rawValue: identifier)
    }
}
```

Add `import Foundation` at the very top if your existing project convention requires it. Check whether `LanguageDescriptor` (referenced by the `name` and `fileExtensions` computed properties) is in the same target — it is (`Sources/CodeEditorPlugin/Languages/LanguageDescriptor.swift`), so no import needed yet (still single-target through Task 4).

Also verify the file does **not** include `Language(fileExtension:)` — that initializer is referenced in the doc comment but defined elsewhere. Grep before assuming:

```bash
grep -rn "init?(fileExtension:" Sources/CodeEditorPlugin/
```

Expected: one or more hits in `Sources/CodeEditorPlugin/Languages/` (e.g., `LanguageDescriptor.swift`). If it shows up in `SyntaxHighlightingCoordinator.swift`, expand the cut range in Step 2.2.

- [ ] **Step 2.2: Delete the original lines from SyntaxHighlightingCoordinator.swift**

Open `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift`. Delete lines 179 through 341 inclusive (the `// MARK: - Language` divider, the doc-comment block, the `public enum Language` body, the blank line, the `// MARK: - Language Extensions` divider, the `extension Language { ... }` body, and one trailing blank line). The file should pick up immediately at the next remaining `// MARK: - TokenType` divider.

- [ ] **Step 2.3: Build and targeted test**

Run:

```bash
swift build
```

Expected: success.

Run:

```bash
swift test --filter SyntaxHighlighting
swift test --filter Languages
```

Expected: both green.

- [ ] **Step 2.4: Commit**

```bash
git add Sources/CodeEditorPlugin/Languages/Language.swift Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift
git commit -m "$(cat <<'EOF'
Relocate Language enum to Languages/ (pre-target-split)

Moves the public Language enum + its extension out of
SyntaxHighlighting/SyntaxHighlightingCoordinator.swift into a dedicated
Languages/Language.swift. Pure file relocation; no API or behavior
change. Prepares for the CodeEditorLanguages target extraction.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Rollback:** `git reset --hard HEAD~1`.

---

## Task 3: Split Folding & Symbol interface types into Languages/

**Files:**
- Modify: `Sources/CodeEditorPlugin/Features/FoldableRegion.swift` (delete most declarations; keep `CodeFoldingConfiguration` only)
- Modify: `Sources/CodeEditorPlugin/Features/SymbolNavigationTypes.swift` (delete `DocumentSymbol` + `DocumentSymbolKind` + `DocumentSymbolProvider`; keep `BreadcrumbItem` + `SymbolNavigationConfiguration`)
- Create: `Sources/CodeEditorPlugin/Languages/CodeFoldingInterfaces.swift`
- Create: `Sources/CodeEditorPlugin/Languages/DocumentSymbolInterfaces.swift`
- Test: existing `Tests/CodeEditorPluginTests/Features/`, `Tests/CodeEditorPluginTests/Languages/`

**Context:** Languages/-side providers conform to `CodeFoldingProvider`, `DocumentSymbolProvider`, `LineBasedSymbolProvider`, and `StatefulLineBasedSymbolProvider`. The first two protocols currently live in Features/, but Languages depends on them at compile time. Pushing them down so Languages can be a leaf target.

`CodeFoldingConfiguration` is intentionally left in Features/ — its consumers straddle the Configuration target and the future Folding engine; resolving that is NEXT.md §6.0 question 2, out of this spec's scope.

- [ ] **Step 3.1: Create CodeFoldingInterfaces.swift**

Create `Sources/CodeEditorPlugin/Languages/CodeFoldingInterfaces.swift` with:

```swift
import Foundation

// MARK: - Foldable Region

/// Represents a foldable region in the text
public struct FoldableRegion: Identifiable {
    public let id = UUID()
    public var range: NSRange
    public var title: String
    public var type: FoldingType
    public var level: Int = 0
    public var parentId: UUID?
    public var foldedText: String?

    public init(range: NSRange, title: String, type: FoldingType) {
        self.range = range
        self.title = title
        self.type = type
    }
}

// MARK: - Folding Type

/// Types of foldable regions
public enum FoldingType: Equatable {
    case function
    case `class`
    case method
    case block
    case comment
    case imports
    case region
    case custom(String)
}

// MARK: - Code Folding Provider Protocol

/// Protocol for language-specific folding providers
@MainActor
public protocol CodeFoldingProvider {
    func detectFoldableRegions(in text: String) async -> [FoldableRegion]
}
```

- [ ] **Step 3.2: Reduce FoldableRegion.swift to CodeFoldingConfiguration only**

Replace the contents of `Sources/CodeEditorPlugin/Features/FoldableRegion.swift` with:

```swift
import CodeEditorPlatform
import Foundation

// MARK: - Code Folding Configuration

/// Configuration for code folding behavior
public struct CodeFoldingConfiguration {
    public var enabled = true
    public var showGutterControls = true
    public var hidesFoldedContent = true
    public var minimumLineCount = 3
    public var foldedIndicator = " ⋯ "

    public var indicatorColor = PlatformColors.secondaryLabel

    public var animatesFolding = true
    public var saveFoldState = true
    public var enableIncrementalUpdates = true

    public init() {}
}
```

Note: The filename `FoldableRegion.swift` is now misleading — it only contains `CodeFoldingConfiguration`. Resist the temptation to rename in this PR; that's drift from the spec. NEXT.md §6.0 question 2 will resolve where `CodeFoldingConfiguration` ultimately lives in §6.2.8.

- [ ] **Step 3.3: Create DocumentSymbolInterfaces.swift**

Create `Sources/CodeEditorPlugin/Languages/DocumentSymbolInterfaces.swift` with:

```swift
import Foundation

// MARK: - Supporting Types

/// Document symbol representation
public struct DocumentSymbol: Identifiable, Sendable {
    public let id = UUID()
    public var name: String
    public var kind: DocumentSymbolKind
    public var range: NSRange
    public var selectionRange: NSRange
    public var detail: String?
    public var children: [Self] = []

    public init(
        name: String,
        kind: DocumentSymbolKind,
        range: NSRange,
        selectionRange: NSRange? = nil,
        detail: String? = nil
    ) {
        self.name = name
        self.kind = kind
        self.range = range
        self.selectionRange = selectionRange ?? range
        self.detail = detail
    }
}

/// Document symbol kinds for navigation
public enum DocumentSymbolKind: String, CaseIterable, Sendable {
    case file
    case module
    case namespace
    case package
    case `class`
    case method
    case property
    case field
    case constructor
    case `enum`
    case interface
    case function
    case variable
    case constant
    case string
    case number
    case boolean
    case array
    case object
    case key
    case null
    case enumMember
    case `struct`
    case event
    case `operator`
    case typeParameter

    package var icon: String {
        switch self {
        case .file: return "📄"
        case .module: return "📦"
        case .namespace: return "🗂"
        case .package: return "📦"
        case .class: return "🏛"
        case .method: return "⚡️"
        case .property: return "🔧"
        case .field: return "📝"
        case .constructor: return "🏗"
        case .enum: return "🔢"
        case .interface: return "🔌"
        case .function: return "ƒ"
        case .variable: return "𝑥"
        case .constant: return "𝐶"
        case .string: return "\"\""
        case .number: return "#"
        case .boolean: return "◉"
        case .array: return "[]"
        case .object: return "{}"
        case .key: return "🔑"
        case .null: return "∅"
        case .enumMember: return "•"
        case .struct: return "◼︎"
        case .event: return "⚡"
        case .operator: return "±"
        case .typeParameter: return "𝑇"
        }
    }

    package var canContainSymbols: Bool {
        switch self {
        case .file, .module, .namespace, .package, .class,
             .interface, .struct, .object, .enum:
            return true

        default:
            return false
        }
    }
}

// MARK: - Document Symbol Provider Protocol

/// Protocol for language-specific symbol providers
public protocol DocumentSymbolProvider: Sendable {
    /// Detects and returns symbols found in the given text
    /// - Parameter text: The source code text to analyze
    /// - Returns: An array of detected document symbols
    func detectSymbols(in text: String) async -> [DocumentSymbol]
}
```

- [ ] **Step 3.4: Reduce SymbolNavigationTypes.swift to engine-only types**

Replace `Sources/CodeEditorPlugin/Features/SymbolNavigationTypes.swift` with:

```swift
import Foundation

// MARK: - Breadcrumb

/// Breadcrumb item
public struct BreadcrumbItem: Identifiable, Sendable {
    public let id = UUID()
    public let symbol: DocumentSymbol
    public let level: Int
}

// MARK: - Symbol Navigation Configuration

/// Symbol navigation configuration
public struct SymbolNavigationConfiguration: Sendable {
    /// Whether symbol navigation is enabled
    public var enabled = true
    /// Whether to show symbol markers in the gutter
    public var showInGutter = true
    /// Whether to show breadcrumb navigation at the top
    public var showBreadcrumbs = true
    /// Maximum number of items to show in breadcrumbs
    public var maxBreadcrumbItems = 5
    /// Delay before updating symbols after text changes
    public var updateDelay: TimeInterval = 0.3
    /// Whether to include anonymous symbols in navigation
    public var includeAnonymousSymbols = false
}
```

- [ ] **Step 3.5: Build and targeted test**

Run:

```bash
swift build
```

Expected: success. If errors mention "duplicate declaration of `FoldableRegion`" or similar, Steps 3.1/3.3 left both old and new copies — revisit 3.2/3.4 to ensure the deletions landed.

Run:

```bash
swift test --filter Folding
swift test --filter Symbol
swift test --filter Languages
```

Expected: all green.

- [ ] **Step 3.6: Commit**

```bash
git add Sources/CodeEditorPlugin/Languages/CodeFoldingInterfaces.swift Sources/CodeEditorPlugin/Languages/DocumentSymbolInterfaces.swift Sources/CodeEditorPlugin/Features/FoldableRegion.swift Sources/CodeEditorPlugin/Features/SymbolNavigationTypes.swift
git commit -m "$(cat <<'EOF'
Move Languages-facing interfaces (Folding/Symbol) into Languages/

Splits FoldableRegion/FoldingType/CodeFoldingProvider out of
Features/FoldableRegion.swift into Languages/CodeFoldingInterfaces.swift.
Splits DocumentSymbol/DocumentSymbolKind/DocumentSymbolProvider out of
Features/SymbolNavigationTypes.swift into Languages/DocumentSymbolInterfaces.swift.
CodeFoldingConfiguration remains in Features/ pending the §6.2.8
Folding engine extraction. BreadcrumbItem and SymbolNavigationConfiguration
remain in Features/ (engine territory).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Rollback:** `git reset --hard HEAD~1`.

---

## Task 4: Move Completion model layer into Languages/

**Files:**
- Move: `Sources/CodeEditorPlugin/Completion/CompletionModels.swift` → `Sources/CodeEditorPlugin/Languages/CompletionModels.swift`
- Move: `Sources/CodeEditorPlugin/Completion/CompletionProtocols+Extensions.swift` → `Sources/CodeEditorPlugin/Languages/CompletionProtocols+Extensions.swift`
- Test: existing `Tests/CodeEditorPluginTests/Completion/`, `Tests/CodeEditorPluginTests/Languages/`

**Context:** `CompletionModels.swift` (330 lines) holds the data layer (`CompletionItemModel`, `CompletionItemKind`, `CompletionTextEdit`, `CompletionContextModel`, `CompletionTriggerKind`, `CompletionResult`, `CompletionRequestError`). `CompletionProtocols+Extensions.swift` (67 lines) holds the `CompletionProvider` protocol + default-impl extension. Both files reference `Language`, which now lives in Languages/. Both are self-contained — no umbrella code depends on internals not already `public`.

This is a `git mv` — no content edits. Still single-target until Task 5.

- [ ] **Step 4.1: Move the two files**

```bash
git mv Sources/CodeEditorPlugin/Completion/CompletionModels.swift Sources/CodeEditorPlugin/Languages/CompletionModels.swift
git mv Sources/CodeEditorPlugin/Completion/CompletionProtocols+Extensions.swift Sources/CodeEditorPlugin/Languages/CompletionProtocols+Extensions.swift
```

- [ ] **Step 4.2: Build and targeted test**

Run:

```bash
swift build
```

Expected: success. The build sees the same files at new paths; symbol resolution doesn't change while everything is still in one target.

Run:

```bash
swift test --filter Completion
swift test --filter Languages
```

Expected: green.

- [ ] **Step 4.3: Commit**

```bash
git commit -m "$(cat <<'EOF'
Relocate Completion model layer into Languages/

git mv CompletionModels.swift and CompletionProtocols+Extensions.swift
from Completion/ to Languages/. No content changes; the Completion data
types (CompletionItemModel, CompletionContextModel, etc.) and the
CompletionProvider protocol semantically belong with the Language enum
they reference. The Completion engine (CompletionManager, ranking, view
controllers, etc.) remains in Completion/ for future §6.2.8 extraction.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Rollback:** `git reset --hard HEAD~1` (restores the moves).

---

## Task 5: Create the CodeEditorLanguages SPM target

**Files:**
- Modify: `Package.swift` (lines 90–138 — the `targets:` array; specifically the umbrella `CodeEditorPlugin` target and the new target's insertion point)
- No source moves — `Sources/CodeEditorPlugin/Languages/` is already populated from Tasks 1–4 and becomes the new target's `path:`
- Test: existing test target via filter runs

**Context:** This is the splitting commit. The new target gets its own `.target(...)` entry; the umbrella's `dependencies:` list adds `"CodeEditorLanguages"` and drops the two `SwiftSyntax`/`SwiftParser` `.product(...)` entries (they move to the new target). After this commit, attempts to `import SwiftSyntax` from anywhere outside `Languages/` will fail at build time — that's the correct boundary.

The umbrella target's `path:` is implicit (`Sources/CodeEditorPlugin/`). With `Languages/` now belonging to a separate target, SwiftPM needs `exclude: ["Languages"]` added to the umbrella so files don't double-count. **No** — SwiftPM auto-discovers `path:` only when omitted; the umbrella declares no explicit `path:`, so it auto-uses `Sources/CodeEditorPlugin/`. When another target's `path:` is `Sources/CodeEditorPlugin/Languages`, SwiftPM treats that as a separate source root and excludes it from the umbrella automatically. Confirm by inspecting how `CodeEditorTextModel` was set up — it used `path: "Sources/CodeEditorTextModel"`, a *sibling* directory. For Languages we use a *nested* path `Sources/CodeEditorPlugin/Languages`, which is unusual but supported. If the build complains about file overlap, add `exclude: ["Languages"]` to the umbrella's existing exclude list.

- [ ] **Step 5.1: Inspect current Package.swift structure**

Read `Package.swift` and locate:
- The `CodeEditorTheming` target declaration (around line 113) — this is where the new target's declaration goes immediately after.
- The umbrella `CodeEditorPlugin` target declaration (lines 119–138) — this is where we edit `dependencies:` and possibly `exclude:`.

Run:

```bash
grep -n "CodeEditorTheming\|CodeEditorPlugin\"\|exclude:" Package.swift | head -20
```

Confirm line numbers match the spec's expectations.

- [ ] **Step 5.2: Add CodeEditorLanguages target**

In `Package.swift`, find the existing `CodeEditorTheming` target block:

```swift
        .target(
            name: "CodeEditorTheming",
            ...
        ),
```

Immediately after it (before the `CodeEditorPlugin` umbrella target), insert:

```swift
        .target(
            name: "CodeEditorLanguages",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax")
            ],
            path: "Sources/CodeEditorPlugin/Languages",
            swiftSettings: swiftSettings
        ),
```

- [ ] **Step 5.3: Update umbrella CodeEditorPlugin target**

In the umbrella `CodeEditorPlugin` target's `dependencies:` array:

1. Add `"CodeEditorLanguages"` to the list (insert alphabetically between `"CodeEditorConfiguration"` and `"CodeEditorPlatform"`).
2. Remove these two lines:
   ```swift
   .product(name: "SwiftSyntax", package: "swift-syntax"),
   .product(name: "SwiftParser", package: "swift-syntax")
   ```

The resulting block should read:

```swift
        .target(
            name: "CodeEditorPlugin",
            dependencies: [
                "CodeEditorCommon",
                "CodeEditorConfiguration",
                "CodeEditorDesignTokens",
                "CodeEditorLanguages",
                "CodeEditorPlatform",
                "CodeEditorTextModel",
                "CodeEditorTheming",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "IssueReporting", package: "xctest-dynamic-overlay")
            ],
            exclude: [
                "Info.plist"
            ],
            swiftSettings: swiftSettings
        ),
```

- [ ] **Step 5.4: First build attempt — surface boundary issues**

Run:

```bash
swift build 2>&1 | tee /tmp/build-task5.log
```

Possible outcomes:

**A. Build succeeds.** Best case. Proceed to Step 5.5.

**B. "Overlapping sources" / "Multiple targets reference the same path" error.** Add `"Languages"` to the umbrella target's existing exclude list:

```swift
            exclude: [
                "Info.plist",
                "Languages"
            ],
```

Re-run `swift build`. Should succeed.

**C. "Cannot find type X in scope" or "X is inaccessible due to 'internal' protection level" from umbrella files referencing Languages symbols.** This is the F3 / access-promotion path. For each error:

  - If the named symbol lives in `Sources/CodeEditorPlugin/Languages/` and is currently `internal`: promote to `package`. (Same-package cross-target — sufficient.)
  - If the named symbol is in some umbrella file that semantically should be in Languages but the umbrella also needs it: leave it where it is and inspect why. Likely an F3 candidate — relocate the umbrella file to `Sources/CodeEditorPlugin/Core/Languages/` only if all its callers are in the umbrella *and* it imports Languages.
  - If the error is `Use of unresolved identifier 'SwiftSyntax'` in an umbrella file: that file uses SwiftSyntax but isn't in Languages/. Either move it into Languages or add `import CodeEditorLanguages` if the symbol it needs is re-exported. (None expected; verify with `grep -rn "import SwiftSyntax" Sources/CodeEditorPlugin/ | grep -v Languages/`.)
  - If the error is `Cannot find 'CompletionItemModel'` from an umbrella file: add `import CodeEditorLanguages` to that file. Same for `Language`, `FoldableRegion`, `FoldingType`, `CodeFoldingProvider`, `DocumentSymbol`, `DocumentSymbolKind`, `DocumentSymbolProvider`, `CompletionContextModel`, `CompletionResult`, `CompletionTriggerKind`, `CompletionRequestError`, `CompletionItemKind`, `CompletionTextEdit`, `CompletionProvider`.

Document every promotion and relocation made in this step; you'll list them in Task 6's NEXT.md update.

**D. Concurrency / sendability errors.** Risk #2 from the spec. Most likely on `CompletionProvider`'s `@MainActor func completions(...)`. If a conformance in the umbrella now fails strict-concurrency checks, examine the specific conformance — usually adds `@MainActor` to the conforming type's relevant method or to the type itself. Note these as deviations.

- [ ] **Step 5.5: Add umbrella imports for Languages**

Many umbrella files now need `import CodeEditorLanguages` at the top. Predicted needs (verify with the build error messages from Step 5.4):

- Most files in `Sources/CodeEditorPlugin/Completion/` (engine references `CompletionContextModel`, `CompletionResult`, `CompletionItemModel`, etc.)
- `Sources/CodeEditorPlugin/Core/CodeEditorView+CompletionExtensions.swift`
- `Sources/CodeEditorPlugin/Core/CodeEditorView+CodeFoldingExtensions.swift` (uses `FoldingType`)
- `Sources/CodeEditorPlugin/Features/FoldStoreElement.swift` (uses `FoldingType`)
- `Sources/CodeEditorPlugin/Features/LineFoldStorage.swift` (uses `FoldingType`)
- `Sources/CodeEditorPlugin/Features/SymbolNavigator.swift` (uses `DocumentSymbol`, `.canContainSymbols`)
- `Sources/CodeEditorPlugin/Features/SymbolNavigationTypes.swift` (now uses `DocumentSymbol` for `BreadcrumbItem`)
- `Sources/CodeEditorPlugin/SyntaxHighlighting/SyntaxHighlightingCoordinator.swift` (uses `Language`)
- LSP files using completion model
- SwiftUI integration files
- Anywhere `Language` is named

Run this grep to find files that need it (post-Task 4):

```bash
grep -rLE "^import CodeEditorLanguages" Sources/CodeEditorPlugin/ \
  | xargs grep -lE "\bLanguage\b|\bCompletionItemModel\b|\bCompletionContextModel\b|\bCompletionResult\b|\bFoldableRegion\b|\bFoldingType\b|\bCodeFoldingProvider\b|\bDocumentSymbol\b|\bDocumentSymbolKind\b|\bDocumentSymbolProvider\b|\bCompletionProvider\b" \
  2>/dev/null
```

For each file printed, add `import CodeEditorLanguages` near the other imports.

- [ ] **Step 5.6: Iterate build until green**

Repeat `swift build` after each batch of import additions or access promotions. Stop adding when the build is fully green.

- [ ] **Step 5.7: Run targeted test suites**

```bash
swift test --filter Languages
swift test --filter Completion
swift test --filter Folding
swift test --filter Symbol
swift test --filter SyntaxHighlighting
```

Each should be green. If a snapshot test under `Tests/CodeEditorPluginTests/Languages/__Snapshots__/` exists (none currently, per spec), it would need re-recording — but no such tests are in the inventory.

- [ ] **Step 5.8: Quick lint check (non-final)**

Run:

```bash
swiftlint --fix
swiftlint
```

Expected: zero violations. If `swiftlint --fix` modifies anything (likely just import ordering after Step 5.5), include those changes in this commit.

- [ ] **Step 5.9: Commit**

```bash
git add Package.swift Sources/CodeEditorPlugin/
git commit -m "$(cat <<'EOF'
Extract CodeEditorLanguages target (phase 3)

Creates the CodeEditorLanguages SPM target at
Sources/CodeEditorPlugin/Languages/, depending on CodeEditorCommon,
CodeEditorPlatform, CodeEditorTextModel, SwiftSyntax, and SwiftParser.
The umbrella CodeEditorPlugin target gains a dependency on
CodeEditorLanguages and drops its direct SwiftSyntax/SwiftParser
dependencies (now transitive via Languages). Umbrella files using
Languages-domain types (Language, CompletionItemModel, FoldableRegion,
DocumentSymbol, etc.) gain explicit `import CodeEditorLanguages`.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

**Rollback:** `git reset --hard HEAD~1` (restores `Package.swift` and the umbrella imports).

---

## Task 6: Full validation + NEXT.md status update

**Files:**
- Modify: `NEXT.md`
- Test: full suite

**Context:** Final validation pass and documentation update. The full `swift test --parallel` runs only here; earlier tasks intentionally avoided it.

- [ ] **Step 6.1: Run the full quality pipeline**

Run, in order:

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: clean build, zero SwiftLint violations, all tests green. If anything fails, do NOT amend Task 5's commit — fix forward as part of this task or with a separate fix commit.

- [ ] **Step 6.2: Inspect the new target's file count**

```bash
find Sources/CodeEditorPlugin/Languages -name '*.swift' | wc -l
```

Record the actual number for the NEXT.md update. Should be approximately 71 (66 original + 1 Language.swift + 2 Completion model files + 2 interface files).

```bash
git log --oneline -6
```

Capture the commit hash of Task 5 ("Extract CodeEditorLanguages target (phase 3)") — you'll cite it in NEXT.md.

- [ ] **Step 6.3: Update NEXT.md §6.0 status table**

Open `NEXT.md`. Find the status table in §6.0 (begins with `| Target | Commit | What landed | Direct deps |`). Add a row beneath the `CodeEditorTheming` row:

```markdown
| `CodeEditorLanguages` | `<task-5-hash>` | 71 of 71 `Languages/` files (66 originals + `Language` enum from SyntaxHighlighting + 2 Completion model files + 2 interface files from Features/) | Common, Platform, TextModel, SwiftSyntax, SwiftParser |
```

Replace `<task-5-hash>` with the short hash from Step 6.2.

- [ ] **Step 6.4: Update NEXT.md §6.0 status sentence**

The introductory sentence currently reads "**Phases 0–2 complete.**" — update to:

```markdown
**Phases 0–3 complete (Languages partial; SyntaxHighlighting deferred).** Six new SPM targets exist alongside ...
```

Update the file/test counts in that sentence to match the actual count from `find` (Step 6.2) and `swift test --parallel` output count (Step 6.1).

- [ ] **Step 6.5: Add the §6.0 "Deviations from the original plan" bullets**

In §6.0's "Deviations" list, add bullets describing:

1. **Deferred §6.2.7 SyntaxHighlighting.** Six SH files hard-reference `MemoryMonitor` (ObservableObject) and `ProductionPerformanceMetrics` (actor) from `Performance/`, plus `CodeEditorDependencies` from `Core/`. Deferral keeps phase ordering honest until either `CodeEditorDiagnostics` (§6.2.10) extracts or these types are type-erased via Common marker protocols (mirroring `UnifiedPerformanceTracking`). Tracked separately.
2. **`CodeFoldingConfiguration` stayed in Features/.** Promoted to `public` so the future Folding engine target (§6.2.8) can move it cleanly. Its consumer in `CodeEditorConfiguration` (`createCodeFoldingConfiguration()`) still works through umbrella re-export.
3. **`DocumentSymbolKind.icon` and `.canContainSymbols` promoted internal → package.** Required because `Features/SymbolNavigator.swift` (umbrella) calls `.canContainSymbols` across the new target boundary.
4. **Any access promotions or F3 relocations done in Task 5.** List them from your notes during Step 5.4–5.6.

- [ ] **Step 6.6: Update NEXT.md §10 remaining-work list**

Find §10. Strike (or remove) the "6.2.6 `CodeEditorLanguages`" bullet. Add a new bullet at the top:

```markdown
- **6.2.7 `CodeEditorSyntaxHighlighting`** — 43 files. Blocked on Performance/Core back-refs (`MemoryMonitor`, `ProductionPerformanceMetrics`, `CodeEditorDependencies`). Needs its own spec choosing: (a) type-erase via Common markers, (b) extract Diagnostics first then SH, or (c) reorder.
```

Adjust file counts for §10's other bullets if Step 6.2 surfaced different numbers.

- [ ] **Step 6.7: Final commit**

```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
Update NEXT.md for phase 3 (Languages) extraction

Records the CodeEditorLanguages extraction landing, lists the
SyntaxHighlighting deferral with reasoning, and updates §10's
remaining-work list. Adds bullets for the access-promotion deviations
made during the extraction.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 6.8: Verify final state**

```bash
git log --oneline -7
swift build
swiftlint
swift test --parallel
```

Expected:
- Six new commits on top of `57b3b193 Update NEXT.md`, in this order (oldest first):
  1. Promote CodeFoldingProvider/FoldableRegion to public for Languages extraction
  2. Relocate Language enum to Languages/ (pre-target-split)
  3. Move Languages-facing interfaces (Folding/Symbol) into Languages/
  4. Relocate Completion model layer into Languages/
  5. Extract CodeEditorLanguages target (phase 3)
  6. Update NEXT.md for phase 3 (Languages) extraction
- Build green.
- Lint clean.
- Tests green.

**Rollback (full):** `git reset --hard 57b3b193` returns to pre-Task-1 state. Tasks 1–4 are individually rollback-safe via `git reset --hard HEAD~1`. After Task 5, rolling back requires reverting Package.swift's target split, so prefer "fix forward" once Task 5 is committed.

---

## Out-of-scope (carried forward to future plans)

1. **§6.2.7 `CodeEditorSyntaxHighlighting` extraction** — requires a follow-up spec resolving the Performance/Core back-references.
2. **Productizing `CodeEditorLanguages`** — no `.library` product added; mirrors phases 0–2.
3. **Per-target test extraction** — `CodeEditorLanguagesTests` lands in §6.2.15 alongside `CodeEditorTestSupport`.
4. **Resolving `CodeFoldingConfiguration`'s home** — NEXT.md §6.0 question 2; out of scope here.
5. **`ToolbarItem` typealias placement** — NEXT.md §6.0 question 3; unrelated to Languages.

---

## Self-Review notes

**Spec coverage (§2.a–§2.e of the design doc):**
- (a) 66 Languages/ files → handled by Task 5's `path:` declaration; no per-file move needed.
- (b) `Language` enum → Task 2.
- (c) Completion model layer → Task 4.
- (d) Folding/Symbol interfaces → Task 3.
- (e) F3 spill → Step 5.4–5.6 handle and Step 6.5 documents.

**Migration steps (§3):**
- §3 Step 1 (access promotion) → Task 1.
- §3 Step 2 (Language enum) → Task 2.
- §3 Step 3 (Features/ split) → Task 3.
- §3 Step 4 (Completion model move) → Task 4.
- §3 Step 5 (target creation) → Task 5.
- §3 Step 6 (validation + NEXT.md) → Task 6.

**Risks (§4):**
- Risk 1 (Language qualified refs) → Step 2.1 grep check.
- Risk 2 (`@MainActor` concurrency) → Step 5.4 outcome D.
- Risk 3 (F3 spill) → Step 5.4 outcome C + Step 6.5 documentation.
- Risk 4 (LineBasedSymbolProvider noted as already public) → no action needed; informational.
- Risk 5 (LSP conformance impact) → Step 5.4 outcome C handles.
- Risk 6 (legacy `CompletionItem`) → noted; not moved.
- Risks 7–8 (DocC, tree-sitter) → no action.

**Type/method consistency:**
- `FoldableRegion`, `FoldingType`, `CodeFoldingProvider`, `CodeFoldingConfiguration`, `DocumentSymbol`, `DocumentSymbolKind`, `DocumentSymbolProvider`, `Language`, `CompletionItemModel`, `CompletionContextModel`, `CompletionResult`, `CompletionTriggerKind`, `CompletionRequestError`, `CompletionTextEdit`, `CompletionItemKind`, `CompletionProvider` — all referenced consistently across Tasks 1, 3, 4, 5.
- `BreadcrumbItem` and `SymbolNavigationConfiguration` stay in Features/; Task 3 verifies their preserved import of `DocumentSymbol`.

No placeholders, no "similar to Task N" references — every code block is the actual content the engineer pastes.
