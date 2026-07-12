# Reuse Kernels and Platform State Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the high-value algorithmic and policy duplication identified by D1–D4 and make platform differences explicit rather than repetitive.

**Architecture:** `LinkedLRU` becomes the sole linked-list cache kernel; one typed debounce actor owns task replacement; LSP unions and syntax capture maps derive from canonical definitions. Shared UI semantic state and command catalogs are extracted while AppKit/UIKit view construction remains native.

**Tech Stack:** Swift 6.3, Swift Testing, XCTest, AppKit, UIKit, CodeEditorDesignTokens.

## Global Constraints

- Preserve semantic public types even when their codec/storage kernel is shared.
- Preserve native platform subclasses and drawing APIs.
- Cancellation must surface as `CancellationError`.
- Shared helpers contain policy; platform branches contain only platform API calls.
- Re-run the normalized eight-line clone scan after every task.

---

### Task 1: Consolidate LRU Storage

**Files:**
- Modify: `Sources/CodeEditorCommon/LinkedLRU.swift`
- Modify: `Sources/CodeEditorDiagnostics/LRUCache.swift`
- Modify: `Tests/CodeEditorPluginTests/LinkedLRUTests.swift`
- Create: `Tests/CodeEditorPluginTests/Diagnostics/MonitoredLRUCacheTests.swift`

**Interfaces:**
- Produces: one node/list implementation in `LinkedLRU`; monitored `LRUCache` wraps it.

- [ ] **Step 1: Add failing compatibility and cleanup tests**

```swift
@MainActor
@Test("monitored cache uses linked storage semantics")
func monitoredCacheSemantics() {
    let cache = LRUCache<String, Int>(capacity: 2, memoryMonitor: MemoryMonitor())
    cache.set(1, forKey: "a")
    cache.set(2, forKey: "b")
    #expect(cache.get("a") == 1)
    cache.set(3, forKey: "c")
    #expect(cache.get("b") == nil)
    #expect(cache.allKeys == ["c", "a"])
}
```

Add a test requiring identical invalid-capacity behavior for both public initializers.

The required behavior is clamping `capacity <= 0` to one entry in both wrappers, matching the existing monitored-cache behavior.

- [ ] **Step 2: Run RED**

Run: `swift test --filter MonitoredLRUCacheTests`

Expected: the invalid-capacity expectation fails until semantics are unified.

- [ ] **Step 3: Wrap `LinkedLRU`**

Add `keysMostRecentFirst` and `removeLeastRecent()` to `LinkedLRU`. Replace `LRUCache.Node`, dictionary, head, tail, and list methods with `private let storage: LinkedLRU<Key, Value>`. Keep monitoring/statistics in the wrapper.

- [ ] **Step 4: Verify one kernel remains**

Run:

```bash
swift test --filter LinkedLRUTests
swift test --filter MonitoredLRUCacheTests
rg -n "private final class Node" Sources/CodeEditorCommon/LinkedLRU.swift Sources/CodeEditorDiagnostics/LRUCache.swift
```

Expected: tests pass and search returns exactly one `Node`, in `LinkedLRU.swift`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorCommon/LinkedLRU.swift Sources/CodeEditorDiagnostics/LRUCache.swift Tests
git commit -m "refactor(cache): unify linked LRU storage"
```

### Task 2: Replace Duplicate Debounce Implementations

**Files:**
- Create: `Sources/CodeEditorCommon/Utilities/KeyedDebouncer.swift`
- Create: `Tests/CodeEditorPluginTests/Common/KeyedDebouncerTests.swift`
- Modify: `Sources/CodeEditorCommon/Utilities/AsyncOperationManager.swift`
- Modify: `Sources/CodeEditorCommon/Utilities/AsyncOperationManager+DebouncingExtensions.swift`
- Delete: `Sources/CodeEditorCommon/Utilities/AsyncOperationManager+OptimizedDebouncing.swift`

**Interfaces:**
- Produces: `KeyedDebouncer<Key, Value>.run(key:delay:operation:)`, a `Value == Void` fire-and-forget wrapper, and a deprecated `debounceOptimized` forwarder only if public compatibility requires it.

- [ ] **Step 1: Add failing result/cancellation tests**

```swift
@Test("replaced keyed operation throws cancellation")
func replacementCancellation() async {
    let debouncer = KeyedDebouncer<String, Int>()
    let first = Task { try await debouncer.run(key: "search", delay: .seconds(1)) { 1 } }
    await Task.yield()
    let second = Task { try await debouncer.run(key: "search", delay: .zero) { 2 } }
    await #expect(throws: CancellationError.self) { try await first.value }
    #expect(try await second.value == 2)
}
```

- [ ] **Step 2: Run RED**

Run: `swift test --filter KeyedDebouncerTests`

Expected: missing-type failure.

- [ ] **Step 3: Implement typed task replacement**

```swift
public actor KeyedDebouncer<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry {
        let token: UUID
        let task: Task<Value, Error>
    }
    private var tasks: [Key: Entry] = [:]

    public func run(
        key: Key,
        delay: Duration,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        tasks[key]?.task.cancel()
        let token = UUID()
        let task = Task<Value, Error> {
            try await Task.sleep(for: delay)
            try Task.checkCancellation()
            return try await operation()
        }
        tasks[key] = Entry(token: token, task: task)
        defer { if tasks[key]?.token == token { tasks[key] = nil } }
        return try await task.value
    }
}
```

- [ ] **Step 4: Rewire manager and verify obsolete storage is gone**

Run:

```bash
swift test --filter KeyedDebouncerTests
swift test --filter PerformanceRegressionTests
rg -n "debounceResults|debounceErrors|debounceOptimized" Sources
```

Expected: tests pass; no result/error dictionaries remain; `debounceOptimized` is absent or a one-line deprecated forwarder.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorCommon Tests/CodeEditorPluginTests/Common Tests/CodeEditorPluginTests/PerformanceRegressionTests.swift
git commit -m "refactor(concurrency): unify keyed debounce behavior"
```

### Task 3: Share LSP String-or-Integer Coding

**Files:**
- Create: `Sources/CodeEditorLSP/StringOrInteger.swift`
- Create: `Tests/CodeEditorPluginTests/LSP/StringOrIntegerTests.swift`
- Modify: `Sources/CodeEditorLSP/LSPTypes.swift:41-79,556-588`

**Interfaces:**
- Produces: package `StringOrInteger`; semantic `RequestId` and `DiagnosticCode` retain public cases.

- [ ] **Step 1: Add failing round-trip matrix**

Test integer/string encode/decode for the kernel and both public wrappers, plus boolean/null/object type-mismatch failures.

- [ ] **Step 2: Run RED**

Run: `swift test --filter StringOrIntegerTests`

Expected: missing-type failure.

- [ ] **Step 3: Implement shared codec**

```swift
package enum StringOrInteger: Codable, Hashable, Sendable {
    case string(String)
    case integer(Int)

    package init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) { self = .integer(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        throw DecodingError.typeMismatch(Self.self, .init(
            codingPath: decoder.codingPath,
            debugDescription: "Expected string or integer"
        ))
    }
}
```

Implement one shared `encode(to:)`. Public wrappers convert cases to/from the kernel in small private helpers.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter StringOrIntegerTests
swift test --filter LSP
git add Sources/CodeEditorLSP Tests/CodeEditorPluginTests/LSP
git commit -m "refactor(lsp): share string-or-integer wire codec"
```

### Task 4: Derive TypeScript Capture Mappings From JavaScript

**Files:**
- Modify: `Sources/CodeEditorSyntaxHighlighting/RegexQuery/QueryCaptureMap.swift:66-106`
- Create: `Tests/CodeEditorPluginTests/SyntaxHighlighting/QueryCaptureMapReuseTests.swift`

**Interfaces:**
- Produces: `QueryCaptureMap.merging(_:)`; TypeScript derives from JavaScript.

- [ ] **Step 1: Add failing equality/override tests**

```swift
@Test("TypeScript includes JavaScript mappings plus explicit overrides")
func typescriptDerivation() {
    #expect(QueryCaptureMap.typescript.tokenType(for: "function") == .function)
    #expect(QueryCaptureMap.typescript.tokenType(for: "interface") == .type)
}
```

The second expectation must fail before adding the explicit TypeScript override.

- [ ] **Step 2: Implement derivation**

```swift
package func merging(_ overrides: [String: TokenType]) -> Self {
    Self(mappings: map.merging(overrides) { _, replacement in replacement })
}

package static let typescript = javascript.merging([
    "interface": .type,
    "type.alias": .type
])
```

- [ ] **Step 3: Run and commit**

```bash
swift test --filter QueryCaptureMapReuseTests
swift test --filter RangeBasedHighlighting
git add Sources/CodeEditorSyntaxHighlighting Tests/CodeEditorPluginTests/SyntaxHighlighting
git commit -m "refactor(syntax): derive TypeScript capture mappings"
```

### Task 5: Share Completion Cell Theme State

**Files:**
- Create: `Sources/CodeEditorLayout/CompletionCellThemeState.swift`
- Create: `Tests/CodeEditorPluginTests/Layout/CompletionCellThemeStateTests.swift`
- Modify: `Sources/CodeEditorLayout/CompletionCellComponents.swift:269-486`

**Interfaces:**
- Produces: `CompletionCellThemeState.apply(theme:) -> Bool` used by both native cell types.

- [ ] **Step 1: Add failing equality-gate test**

```swift
@MainActor
@Test("theme state reports only effective changes")
func equalityGate() {
    var state = CompletionCellThemeState(fallback: .default)
    #expect(state.apply(theme: .default))
    #expect(state.apply(theme: .default) == false)
}
```

- [ ] **Step 2: Run RED**

Run: `swift test --filter CompletionCellThemeStateTests`

Expected: missing-type failure.

- [ ] **Step 3: Extract state and common configuration model**

The state owns applied theme, primary/secondary colors, border color/width, and corner radius. AppKit/UIKit cells expose computed public properties and apply colors to native labels after a successful state transition. Keep label construction native.

- [ ] **Step 4: Run snapshots and commit**

```bash
swift test --filter CompletionCellThemeStateTests
swift test --filter CompletionCell
git add Sources/CodeEditorLayout Tests/CodeEditorPluginTests/Layout
git commit -m "refactor(layout): share completion cell theme state"
```

### Task 6: Centralize Toolbar Command Descriptors

**Files:**
- Create: `Sources/CodeEditorView/Platform/ToolbarCatalog.swift`
- Create: `Tests/CodeEditorPluginTests/Platform/ToolbarCatalogTests.swift`
- Modify: `Sources/CodeEditorView/Platform/ToolbarCoordinator.swift:250-350`

**Interfaces:**
- Produces: canonical `find`, `editing`, `macOnly`, and `phoneOnly` descriptor collections.

- [ ] **Step 1: Add failing platform-selection tests**

Assert macOS identifiers equal `find + editing + macOnly`, iPad equals `find + editing`, and iPhone equals `find + phoneOnly`, with no duplicate identifiers.

- [ ] **Step 2: Run RED**

Run: `swift test --filter ToolbarCatalogTests`

Expected: missing-type failure.

- [ ] **Step 3: Implement catalog and selection**

```swift
package enum ToolbarCatalog {
    static let find = ToolbarItem(title: "Find", icon: "magnifyingglass", action: .find, id: "find")
    static let editing = [
        ToolbarItem(title: "Replace", icon: "arrow.left.arrow.right", action: .replace, id: "replace"),
        ToolbarItem(title: "Symbols", icon: "list.bullet.indent", action: .showSymbols, id: "symbol"),
        ToolbarItem(title: "Format", icon: "text.alignleft", action: .format, id: "format")
    ]
}
```

Platform builders concatenate catalogs and contain no repeated item literal.

- [ ] **Step 4: Run and commit**

```bash
swift test --filter ToolbarCatalogTests
swift test --filter ToolbarCoordinator
git add Sources/CodeEditorView/Platform Tests/CodeEditorPluginTests/Platform
git commit -m "refactor(toolbar): centralize command catalog"
```

### Task 7: Centralize UIKit Scroll Preservation and Responsibility Files

**Files:**
- Create: `Sources/CodeEditorView/CodeEditorView+EditingActions.swift`
- Create: `Sources/CodeEditorView/CodeEditorView+SelectionScrolling.swift`
- Rename: `Sources/CodeEditorView/CodeEditorView+Configuration.swift` to `Sources/CodeEditorView/CodeEditorView+ConfigurationApplication.swift`
- Modify: `Sources/CodeEditorView/CodeEditorView+Extensions.swift`
- Create: `Tests/CodeEditorPluginTests/Core/SelectionScrollPreservationTests.swift`

**Interfaces:**
- Produces: UIKit `preservingScrollPosition(_:)`; responsibility-named extension files; platform-neutral edit commands outside conditional branches.

- [ ] **Step 1: Add failing scroll restoration tests**

On UIKit, set a non-zero content offset, mutate both `selectedRange` and `selectedTextRange` with auto-scroll disabled, and assert offset and prior `isScrollEnabled` are restored. On AppKit, retain the current visible-rect assertion.

- [ ] **Step 2: Run RED**

Run: `swift test --filter SelectionScrollPreservationTests`

Expected: at least one assertion exposes duplicated-path drift or the new helper inspection seam is missing.

- [ ] **Step 3: Extract one helper and split files**

```swift
#if canImport(UIKit)
private func preservingScrollPosition(_ operation: () -> Void) {
    let offset = contentOffset
    let scrolling = isScrollEnabled
    isScrollEnabled = false
    operation()
    isScrollEnabled = scrolling
    if contentOffset != offset { setContentOffset(offset, animated: false) }
}
#endif
```

Call it from both selection setters and the no-scroll helper. Move editing commands to `+EditingActions`; remove identical `canImport` branches. Move selection behavior to `+SelectionScrolling`. Delete the now-empty catch-all file.

- [ ] **Step 4: Run platform/view tests and Wave 3 gate**

```bash
swift test --filter SelectionScrollPreservationTests
swift test --filter CodeEditorViewTests
swift build
swiftlint --fix
swiftlint
swift test --parallel
```

Expected: all commands pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorView Tests/CodeEditorPluginTests/Core
git commit -m "refactor(view): centralize selection scroll preservation"
```
