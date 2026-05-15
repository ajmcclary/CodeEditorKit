# Workspace Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a macOS left-rail Files/Search workspace surface to the sample, backed by the framework's `WorkspaceFileTree`/`WorkspaceFileWatching`/`ProjectSearchProvider` APIs; migrate the inline `SettingsSidebar` to the already-wired `Settings { SettingsScene(...) }`.

**Architecture:** Two feature-scoped `@Observable` models in the sample (`WorkspaceModel`, `ProjectSearchModel`). One new `EditorSidebarShell` host (`WorkspaceSidebar`) that segments between `FilePanelView` and `ProjectSearchPanelView`. Two small framework additions: public-promote the workspace types so the sample can consume them, and add `EditorController.selectRange(_:scroll:)` to expose the select+scroll primitive `gotoSymbol` already uses.

**Tech Stack:** Swift 6.3 with `StrictConcurrency`, SwiftUI, `@Observable`, `AsyncStream`, `NSOpenPanel`, `EditorSidebarShell` (from `CodeEditorUI`), `PortableProjectSearchAdapter`, `MacOSWorkspaceFileManager`, `swift-snapshot-testing` for visual regression.

**Spec:** `docs/superpowers/specs/2026-05-14-workspace-surface-design.md` (commit `9ff71ce`).

**Pipeline reminders:**
- `swift build && swiftlint --fix && swiftlint && swift test --parallel` after each significant change.
- Sample app is a target, not a directory — `swift build --target CodeEditorSample`, never `cd CodeEditorSample`.
- SwiftLint strict mode is on — warnings fail the build. Always `swiftlint --fix` first.
- No `print()`; use `CrossPlatformLogger.logger()`. No force-unwraps. Use `canImport(AppKit)`, never `os(macOS)`.
- Snapshot tests record with `isRecording: true`, then commit the PNGs.

---

## Task 1: Framework — Public-promote workspace types

**Files:**
- Modify: `Sources/CodeEditorPlugin/Workspace/WorkspaceFileProtocols.swift`
- Modify: `Sources/CodeEditorPlugin/Workspace/MacOSWorkspaceFileManager.swift`

**Why:** The sample target (a separate SPM target) needs to import `WorkspaceFileNode`, `WorkspaceFileEvent`, `WorkspaceFileTree`, `WorkspaceFileWatching`, and `MacOSWorkspaceFileManager`. They are currently `internal`. Promotion is a pure access-modifier change; no shape changes.

- [ ] **Step 1: Verify the current build is green**

Run: `swift build && swiftlint`
Expected: Build succeeds; no lint violations.

- [ ] **Step 2: Promote types in WorkspaceFileProtocols.swift**

Replace `Sources/CodeEditorPlugin/Workspace/WorkspaceFileProtocols.swift` body with:

```swift
import Foundation

// MARK: - Workspace File Protocols

/// A node in the workspace file tree. Represents a file or directory.
public struct WorkspaceFileNode: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let isDirectory: Bool
    /// Cached children file names for directories. Empty for files.
    public var children: [String]

    public init(
        name: String,
        url: URL,
        isDirectory: Bool,
        children: [String] = [],
        id: String? = nil
    ) {
        self.id = id ?? url.absoluteString
        self.name = name
        self.url = url
        self.isDirectory = isDirectory
        self.children = children
    }
}

/// Events emitted by workspace file watching.
public enum WorkspaceFileEvent: Sendable {
    case created(url: URL)
    case modified(url: URL)
    case deleted(url: URL)
    case renamed(oldURL: URL, newURL: URL)
}

// MARK: - WorkspaceFileTree

/// Protocol for lazily materializing a workspace file tree.
///
/// Only root children are loaded initially; deeper nodes are
/// loaded on demand via `children(of:)`.
@MainActor
public protocol WorkspaceFileTree: AnyObject {
    /// The root node of the file tree (the workspace directory itself).
    var root: WorkspaceFileNode { get }

    /// Returns the children of a directory node. Files return `[]`.
    func children(of node: WorkspaceFileNode) -> [WorkspaceFileNode]

    /// Returns `true` if the node represents a directory.
    func isDirectory(_ node: WorkspaceFileNode) -> Bool

    /// Returns the file URL for a node.
    func fileURL(for node: WorkspaceFileNode) -> URL

    /// Refresh the cached children of a directory node.
    func refresh(node: WorkspaceFileNode) async throws
}

// MARK: - WorkspaceFileWatching

/// Protocol for watching file-system changes in a workspace.
@MainActor
public protocol WorkspaceFileWatching: AnyObject {
    /// Start watching a root directory.
    func startWatching(root: URL) async throws

    /// Stop watching.
    func stopWatching()

    /// An async stream of file events.
    var events: AsyncStream<WorkspaceFileEvent> { get }
}
```

- [ ] **Step 3: Promote types in MacOSWorkspaceFileManager.swift**

Edit `Sources/CodeEditorPlugin/Workspace/MacOSWorkspaceFileManager.swift`:

Replace the class declaration line:

```swift
final class MacOSWorkspaceFileManager: WorkspaceFileTree, WorkspaceFileWatching {
```

With:

```swift
public final class MacOSWorkspaceFileManager: WorkspaceFileTree, WorkspaceFileWatching {
```

Promote the `init`:

```swift
public init(rootURL: URL) {
```

Promote `root`:

```swift
public let root: WorkspaceFileNode
```

Promote the four `WorkspaceFileTree` conformance methods (`children(of:)`, `isDirectory(_:)`, `fileURL(for:)`, `refresh(node:)`) and the three `WorkspaceFileWatching` members (`startWatching(root:)`, `stopWatching()`, `events`) by adding `public` to each declaration.

- [ ] **Step 4: Verify the framework still builds**

Run: `swift build --target CodeEditorPlugin && swiftlint --fix && swiftlint`
Expected: Builds clean; no lint violations.

- [ ] **Step 5: Verify existing tests still pass**

Run: `swift test --filter Workspace --parallel`
Expected: Any existing tests touching these types still pass. If there are none (likely), the filter returns 0 tests — proceed.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Workspace/WorkspaceFileProtocols.swift \
        Sources/CodeEditorPlugin/Workspace/MacOSWorkspaceFileManager.swift
git commit -m "$(cat <<'EOF'
Workspace types: public-promote WorkspaceFileNode/Event/Tree/Watching

So the sample target can consume them. Pure access-modifier change;
no signatures move.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Framework — `EditorController.selectRange(_:scroll:)`

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`
- Test: `Tests/CodeEditorPluginTests/EditorControllerSelectRangeTests.swift` (new)

**Why:** Sample-side `selectMatch(_:)` needs to select an arbitrary `NSRange` and scroll it into view. `gotoSymbol(_:)` already does select+scroll internally but requires a `DocumentSymbol`. Expose the primitive.

- [ ] **Step 1: Write the failing test**

Create `Tests/CodeEditorPluginTests/EditorControllerSelectRangeTests.swift`:

```swift
#if canImport(AppKit)
import AppKit
import Testing
@testable import CodeEditorPlugin

@MainActor
@Suite("EditorController.selectRange")
struct EditorControllerSelectRangeTests {
    @Test("selectRange is a no-op when no view is attached")
    func noViewAttached() {
        let controller = EditorController()
        // Should not crash; nothing observable to assert beyond non-crash.
        controller.selectRange(NSRange(location: 0, length: 4))
    }

    @Test("selectRange updates the attached view's selection")
    func selectsRangeInAttachedView() {
        let controller = EditorController()
        let view = CodeEditorView(frame: .zero)
        view.string = "Hello, world"
        controller.attach(to: view)

        controller.selectRange(NSRange(location: 7, length: 5), scroll: false)

        #expect(view.selectedRange() == NSRange(location: 7, length: 5))
    }
}
#endif
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter EditorControllerSelectRangeTests`
Expected: FAIL — `selectRange` is not a member of `EditorController`.

- [ ] **Step 3: Implement `selectRange(_:scroll:)`**

In `Sources/CodeEditorPlugin/SwiftUI/EditorController.swift`, after the existing `gotoSymbol(_:)` method (around line 295), add:

```swift
/// Selects `range` in the attached view and (optionally) scrolls it
/// into visible. No-op when no view is attached. Mirrors the
/// select+scroll primitive used internally by `gotoSymbol(_:)`.
public func selectRange(_ range: NSRange, scroll: Bool = true) {
    guard let view = codeEditorView else { return }
    view.setSelectedRangeWithoutScrolling(range)
    if scroll {
        view.scrollToVisible(range)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `swift test --filter EditorControllerSelectRangeTests`
Expected: PASS (both cases).

- [ ] **Step 5: Lint + final framework check**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorPlugin`
Expected: Clean.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/EditorController.swift \
        Tests/CodeEditorPluginTests/EditorControllerSelectRangeTests.swift
git commit -m "$(cat <<'EOF'
EditorController: public selectRange(_:scroll:) for arbitrary NSRange

Exposes the select+scroll primitive gotoSymbol(_:) already uses,
without requiring a DocumentSymbol. Sample-side selectMatch builds on it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Sample — `WorkspaceIgnoreRules`

**Files:**
- Create: `Sources/CodeEditorSample/Workspace/WorkspaceIgnoreRules.swift`
- Test: `Tests/CodeEditorSampleTests/WorkspaceIgnoreRulesTests.swift` (new)

**Why:** Both the file tree and project-search indexing need to skip the same set of names. Centralized constant + tiny pure function.

- [ ] **Step 1: Create the Workspace directory** (it doesn't exist yet)

Run: `mkdir -p Sources/CodeEditorSample/Workspace`
Expected: Directory exists.

- [ ] **Step 2: Write the failing test**

Create `Tests/CodeEditorSampleTests/WorkspaceIgnoreRulesTests.swift`:

```swift
#if canImport(AppKit)
import Foundation
import Testing
@testable import CodeEditorSample

@Suite("WorkspaceIgnoreRules")
struct WorkspaceIgnoreRulesTests {
    @Test("hides dotfiles")
    func hidesDotfiles() {
        #expect(WorkspaceIgnoreRules.shouldHide(name: ".git"))
        #expect(WorkspaceIgnoreRules.shouldHide(name: ".DS_Store"))
        #expect(WorkspaceIgnoreRules.shouldHide(name: ".env"))
    }

    @Test("hides common build directories")
    func hidesBuildDirs() {
        for name in [".build", ".swiftpm", "node_modules", "DerivedData", "__Snapshots__"] {
            #expect(WorkspaceIgnoreRules.shouldHide(name: name), "expected \(name) hidden")
        }
    }

    @Test("does not hide ordinary file names")
    func keepsOrdinaryFiles() {
        for name in ["Package.swift", "README.md", "Sources", "Tests"] {
            #expect(!WorkspaceIgnoreRules.shouldHide(name: name), "expected \(name) visible")
        }
    }

    @Test("recognizes binary extensions for search indexing")
    func skipsBinaryExtensions() {
        #expect(WorkspaceIgnoreRules.isBinaryExtension("png"))
        #expect(WorkspaceIgnoreRules.isBinaryExtension("PNG"))
        #expect(WorkspaceIgnoreRules.isBinaryExtension("jpg"))
        #expect(!WorkspaceIgnoreRules.isBinaryExtension("swift"))
        #expect(!WorkspaceIgnoreRules.isBinaryExtension(""))
    }
}
#endif
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter WorkspaceIgnoreRulesTests`
Expected: FAIL — `WorkspaceIgnoreRules` is not defined.

- [ ] **Step 4: Implement `WorkspaceIgnoreRules`**

Create `Sources/CodeEditorSample/Workspace/WorkspaceIgnoreRules.swift`:

```swift
import Foundation

/// Centralized name-based filters for the workspace surface. Used by
/// `WorkspaceModel` (file tree) and `ProjectSearchModel` (indexing).
///
/// These rules are intentionally static. The sample doesn't parse
/// `.gitignore` or expose user configuration; if you need that, fork.
enum WorkspaceIgnoreRules {
    /// Names hidden from the file tree and excluded from search indexing.
    /// Covers dotfiles plus a small set of well-known build / vendor dirs.
    static let hiddenNames: Set<String> = [
        ".build",
        ".swiftpm",
        "node_modules",
        "DerivedData",
        "__Snapshots__"
    ]

    /// File extensions excluded from project-search indexing because the
    /// portable adapter can't usefully match against their bytes.
    static let binaryExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp", "heic", "heif",
        "pdf", "zip", "tar", "gz", "bz2", "xz", "7z",
        "mov", "mp4", "m4v", "mp3", "wav", "aiff",
        "ttf", "otf", "woff", "woff2",
        "dylib", "a", "so", "framework", "bundle"
    ]

    /// `true` when this file or directory name should be hidden from
    /// the workspace surface.
    static func shouldHide(name: String) -> Bool {
        if name.hasPrefix(".") { return true }
        return hiddenNames.contains(name)
    }

    /// `true` when this extension is in the binary deny-list. Case-insensitive.
    static func isBinaryExtension(_ ext: String) -> Bool {
        binaryExtensions.contains(ext.lowercased())
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `swift test --filter WorkspaceIgnoreRulesTests`
Expected: PASS (4 cases).

- [ ] **Step 6: Lint + commit**

```bash
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/Workspace/WorkspaceIgnoreRules.swift \
        Tests/CodeEditorSampleTests/WorkspaceIgnoreRulesTests.swift
git commit -m "$(cat <<'EOF'
Sample: WorkspaceIgnoreRules (dotfiles + build dirs + binary exts)

Centralized name-based filter shared by WorkspaceModel (file tree) and
ProjectSearchModel (indexing). Static; no .gitignore parsing.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Sample — `WorkspacePicker` helper

**Files:**
- Create: `Sources/CodeEditorSample/Workspace/WorkspacePicker.swift`
- Modify: `Sources/CodeEditorSample/KnobPanels/WorkspaceKnobsSection.swift`

**Why:** The NSOpenPanel logic in `WorkspaceKnobsSection.presentOpenPanel` is needed in three new places (empty-state button, footer button, menu command). Extract once, reuse everywhere.

- [ ] **Step 1: Create `WorkspacePicker`**

Create `Sources/CodeEditorSample/Workspace/WorkspacePicker.swift`:

```swift
#if canImport(AppKit)
import AppKit
import Foundation

/// macOS-only NSOpenPanel wrapper used by the workspace surface
/// (empty-state button, footer button) and the "Open Folder…"
/// command. Modal; returns synchronously via the completion handler.
enum WorkspacePicker {
    /// Presents an `NSOpenPanel` configured for a single directory choice.
    /// Invokes `onChoose` with the picked URL when the user confirms;
    /// invokes nothing on cancel.
    ///
    /// - Parameters:
    ///   - currentRoot: Optional URL to preselect.
    ///   - onChoose: Callback invoked on confirm with the picked URL.
    @MainActor
    static func choose(currentRoot: URL? = nil, onChoose: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Workspace"
        if let currentRoot {
            panel.directoryURL = currentRoot
        }
        if panel.runModal() == .OK, let url = panel.url {
            onChoose(url)
        }
    }
}
#endif
```

- [ ] **Step 2: Update `WorkspaceKnobsSection` to call the picker**

In `Sources/CodeEditorSample/KnobPanels/WorkspaceKnobsSection.swift`, replace the private `presentOpenPanel()` method (around lines 84–99) with a single call site:

In `actionRow` (around lines 57–65), change the button action body from `presentOpenPanel()` to:

```swift
Button {
    WorkspacePicker.choose(currentRoot: workspaceRoot) { workspaceRoot = $0 }
} label: {
    Label("Choose…", systemImage: "folder.badge.plus")
        .labelStyle(.titleAndIcon)
}
.controlSize(.small)
```

Delete the entire `#if canImport(AppKit) / private func presentOpenPanel() / #endif` block at the bottom of the file (lines 84–99).

- [ ] **Step 3: Build to verify the refactor compiles**

Run: `swift build --target CodeEditorSample && swiftlint --fix && swiftlint`
Expected: Clean build, no lint violations.

- [ ] **Step 4: Smoke-run the existing workspace knobs path**

Run: `swift test --filter WorkspaceKnobs --parallel`
Expected: If there are tests, they pass. If not, the filter returns 0; OK.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorSample/Workspace/WorkspacePicker.swift \
        Sources/CodeEditorSample/KnobPanels/WorkspaceKnobsSection.swift
git commit -m "$(cat <<'EOF'
Sample: WorkspacePicker helper; reuse from WorkspaceKnobsSection

Single home for the NSOpenPanel folder-picker logic. The new workspace
surface (empty state, footer, menu command) will all call into this.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Sample — `WorkspaceModel` (TDD)

**Files:**
- Create: `Sources/CodeEditorSample/Workspace/WorkspaceModel.swift`
- Create: `Tests/CodeEditorSampleTests/Support/StubWorkspaceFileTree.swift` (test double)
- Create: `Tests/CodeEditorSampleTests/WorkspaceModelTests.swift`

**Why:** Owns the file-tree state + the `WorkspaceFileWatching` subscription. Independently testable through an injected protocol-conforming stub.

- [ ] **Step 1: Create the test double**

Create `Tests/CodeEditorSampleTests/Support/StubWorkspaceFileTree.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

@MainActor
final class StubWorkspaceFileTree: WorkspaceFileTree, WorkspaceFileWatching {
    var rootNode: WorkspaceFileNode
    var childrenByID: [String: [WorkspaceFileNode]]
    var startCount = 0
    var stopCount = 0
    private var continuation: AsyncStream<WorkspaceFileEvent>.Continuation?
    private(set) var eventStream: AsyncStream<WorkspaceFileEvent>

    init(
        root: WorkspaceFileNode,
        childrenByID: [String: [WorkspaceFileNode]] = [:]
    ) {
        self.rootNode = root
        self.childrenByID = childrenByID
        var localContinuation: AsyncStream<WorkspaceFileEvent>.Continuation!
        self.eventStream = AsyncStream { continuation in
            localContinuation = continuation
        }
        self.continuation = localContinuation
    }

    var root: WorkspaceFileNode { rootNode }

    func children(of node: WorkspaceFileNode) -> [WorkspaceFileNode] {
        childrenByID[node.id] ?? []
    }

    func isDirectory(_ node: WorkspaceFileNode) -> Bool { node.isDirectory }
    func fileURL(for node: WorkspaceFileNode) -> URL { node.url }
    func refresh(node: WorkspaceFileNode) async throws { /* no-op */ }

    func startWatching(root: URL) async throws { startCount += 1 }
    func stopWatching() { stopCount += 1 }
    var events: AsyncStream<WorkspaceFileEvent> { eventStream }

    func send(_ event: WorkspaceFileEvent) {
        continuation?.yield(event)
    }

    func finish() {
        continuation?.finish()
    }
}
#endif
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/CodeEditorSampleTests/WorkspaceModelTests.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation
import Testing
@testable import CodeEditorSample

@MainActor
@Suite("WorkspaceModel")
struct WorkspaceModelTests {
    private func makeRoot(at path: String = "/tmp/ws") -> WorkspaceFileNode {
        WorkspaceFileNode(name: "ws", url: URL(fileURLWithPath: path), isDirectory: true)
    }

    private func makeChild(_ name: String, in rootPath: String = "/tmp/ws", isDirectory: Bool = false) -> WorkspaceFileNode {
        WorkspaceFileNode(
            name: name,
            url: URL(fileURLWithPath: rootPath).appendingPathComponent(name),
            isDirectory: isDirectory
        )
    }

    @Test("setRoot(nil) clears state without invoking the factory")
    func setRootNilClearsState() {
        var factoryCalls = 0
        let model = WorkspaceModel(factory: { _ in
            factoryCalls += 1
            return StubWorkspaceFileTree(root: WorkspaceFileNode(name: "", url: URL(fileURLWithPath: "/"), isDirectory: true))
        })

        model.setRoot(nil)

        #expect(factoryCalls == 0)
        #expect(model.rootURL == nil)
        #expect(model.rootNode == nil)
    }

    @Test("setRoot loads the root and applies ignore rules to filtered children")
    func setRootLoadsRoot() async {
        let root = makeRoot()
        let visible = makeChild("Sources", isDirectory: true)
        let hidden = makeChild(".git", isDirectory: true)
        let stub = StubWorkspaceFileTree(
            root: root,
            childrenByID: [root.id: [visible, hidden]]
        )

        let model = WorkspaceModel(factory: { _ in stub })
        model.setRoot(root.url)

        // Drain a tick so any synchronous follow-ups settle.
        await Task.yield()

        #expect(model.rootURL == root.url)
        #expect(model.rootNode?.id == root.id)
        let filtered = model.filteredChildren(of: root.url)
        #expect(filtered.map(\.name) == ["Sources"])
    }

    @Test("setRoot starts watching and a subsequent setRoot(nil) stops")
    func setRootStartsAndStopsWatching() async {
        let root = makeRoot()
        let stub = StubWorkspaceFileTree(root: root)
        let model = WorkspaceModel(factory: { _ in stub })

        model.setRoot(root.url)
        await Task.yield()
        #expect(stub.startCount == 1)

        model.setRoot(nil)
        #expect(stub.stopCount == 1)
    }

    @Test("created event inserts a child into the parent's cached list")
    func createdEventInserts() async {
        let root = makeRoot()
        let stub = StubWorkspaceFileTree(root: root)
        let model = WorkspaceModel(factory: { _ in stub })
        model.setRoot(root.url)
        await Task.yield()

        let newChild = makeChild("NewFile.swift")
        stub.send(.created(url: newChild.url))
        try? await Task.sleep(nanoseconds: 50_000_000)

        let children = model.filteredChildren(of: root.url)
        #expect(children.contains(where: { $0.name == "NewFile.swift" }))
    }

    @Test("deleted event removes the child from the parent's cached list")
    func deletedEventRemoves() async {
        let root = makeRoot()
        let existing = makeChild("Existing.swift")
        let stub = StubWorkspaceFileTree(root: root, childrenByID: [root.id: [existing]])
        let model = WorkspaceModel(factory: { _ in stub })
        model.setRoot(root.url)
        await Task.yield()

        stub.send(.deleted(url: existing.url))
        try? await Task.sleep(nanoseconds: 50_000_000)

        let children = model.filteredChildren(of: root.url)
        #expect(!children.contains(where: { $0.name == "Existing.swift" }))
    }
}
#endif
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter WorkspaceModelTests`
Expected: FAIL — `WorkspaceModel` not defined.

- [ ] **Step 4: Implement `WorkspaceModel`**

Create `Sources/CodeEditorSample/Workspace/WorkspaceModel.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

/// File-tree state + WorkspaceFileWatching subscription for the
/// sample's workspace surface. macOS-only.
///
/// The model owns:
/// - the current root and root node
/// - a lazy cache of children keyed by directory URL
/// - the set of expanded directory URLs (drives disclosure)
/// - the file-watching task that mutates the cache incrementally
@MainActor
@Observable
final class WorkspaceModel {
    typealias TreeProvider = WorkspaceFileTree & WorkspaceFileWatching

    private(set) var rootURL: URL?
    private(set) var rootNode: WorkspaceFileNode?
    private(set) var childrenByURL: [URL: [WorkspaceFileNode]] = [:]
    var expandedDirectoryURLs: Set<URL> = []
    var selectedFileURL: URL?
    private(set) var loadError: Error?

    private var provider: TreeProvider?
    private var watchTask: Task<Void, Never>?
    private let factory: @MainActor (URL) -> TreeProvider

    init(
        factory: @escaping @MainActor (URL) -> TreeProvider = { url in
            MacOSWorkspaceFileManager(rootURL: url)
        }
    ) {
        self.factory = factory
    }

    /// Sets a new root. Tears down the previous watcher and replaces
    /// the file provider. Passing `nil` clears all state.
    func setRoot(_ url: URL?) {
        watchTask?.cancel()
        watchTask = nil
        provider?.stopWatching()
        provider = nil
        childrenByURL = [:]
        expandedDirectoryURLs = []
        loadError = nil

        guard let url else {
            rootURL = nil
            rootNode = nil
            return
        }

        let newProvider = factory(url)
        provider = newProvider
        rootURL = url
        rootNode = newProvider.root
        expandedDirectoryURLs.insert(url)

        let rootChildren = newProvider.children(of: newProvider.root)
        childrenByURL[url] = rootChildren

        watchTask = Task { [weak self] in
            do {
                try await newProvider.startWatching(root: url)
            } catch {
                await MainActor.run { self?.loadError = error }
                return
            }
            for await event in newProvider.events {
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.apply(event: event) }
            }
        }
    }

    /// Toggle a directory's expansion. Loads children on first expand.
    func toggleExpanded(_ url: URL) async {
        if expandedDirectoryURLs.contains(url) {
            expandedDirectoryURLs.remove(url)
            return
        }
        expandedDirectoryURLs.insert(url)
        if childrenByURL[url] == nil {
            await loadChildren(for: url)
        }
    }

    /// Re-fetch a directory's children from the provider.
    func refresh(directory url: URL) async {
        await loadChildren(for: url)
    }

    /// Cached children, filtered through `WorkspaceIgnoreRules`,
    /// sorted directories-first then alpha by name.
    func filteredChildren(of url: URL) -> [WorkspaceFileNode] {
        let cached = childrenByURL[url] ?? []
        return cached
            .filter { !WorkspaceIgnoreRules.shouldHide(name: $0.name) }
            .sorted { lhs, rhs in
                if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }

    // MARK: - Private

    private func loadChildren(for url: URL) async {
        guard let provider, let parentNode = nodeForURL(url) else { return }
        do {
            try await provider.refresh(node: parentNode)
        } catch {
            loadError = error
        }
        childrenByURL[url] = provider.children(of: parentNode)
    }

    private func nodeForURL(_ url: URL) -> WorkspaceFileNode? {
        if url == rootURL { return rootNode }
        for (_, nodes) in childrenByURL {
            if let match = nodes.first(where: { $0.url == url }) {
                return match
            }
        }
        return nil
    }

    private func apply(event: WorkspaceFileEvent) {
        switch event {
        case .created(let url):
            insert(url: url)
        case .deleted(let url):
            remove(url: url)
        case .renamed(let oldURL, let newURL):
            remove(url: oldURL)
            insert(url: newURL)
        case .modified:
            // Modifications don't change tree structure; ignored for tree.
            break
        }
    }

    private func insert(url: URL) {
        let parentURL = url.deletingLastPathComponent()
        guard childrenByURL[parentURL] != nil else { return }
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let node = WorkspaceFileNode(
            name: url.lastPathComponent,
            url: url,
            isDirectory: isDir
        )
        var siblings = childrenByURL[parentURL] ?? []
        guard !siblings.contains(where: { $0.url == url }) else { return }
        siblings.append(node)
        childrenByURL[parentURL] = siblings
    }

    private func remove(url: URL) {
        let parentURL = url.deletingLastPathComponent()
        guard var siblings = childrenByURL[parentURL] else { return }
        siblings.removeAll { $0.url == url }
        childrenByURL[parentURL] = siblings
        childrenByURL.removeValue(forKey: url)
        expandedDirectoryURLs.remove(url)
    }
}
#endif
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter WorkspaceModelTests`
Expected: PASS (5 cases).

- [ ] **Step 6: Lint and commit**

```bash
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/Workspace/WorkspaceModel.swift \
        Tests/CodeEditorSampleTests/Support/StubWorkspaceFileTree.swift \
        Tests/CodeEditorSampleTests/WorkspaceModelTests.swift
git commit -m "$(cat <<'EOF'
Sample: WorkspaceModel (@Observable tree + watching subscription)

Owns the lazy children cache + expanded set; mutates incrementally
on WorkspaceFileWatching events. Tests use a StubWorkspaceFileTree
double that hand-feeds an AsyncStream.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Sample — `ProjectSearchModel` (TDD)

**Files:**
- Create: `Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift`
- Create: `Tests/CodeEditorSampleTests/Support/StubProjectSearchProvider.swift`
- Create: `Tests/CodeEditorSampleTests/ProjectSearchModelTests.swift`

**Why:** Owns query / toggles / results / indexing state. Independently testable through an injected `ProjectSearchProvider` stub.

- [ ] **Step 1: Create the test double**

Create `Tests/CodeEditorSampleTests/Support/StubProjectSearchProvider.swift`:

```swift
import CodeEditorPlugin
import Foundation

/// Test double for ProjectSearchProvider. Records calls, returns
/// pre-canned results, and can be configured to throw.
final class StubProjectSearchProvider: ProjectSearchProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _indexedURLs: [URL] = []
    private var _cancelCount = 0
    private var _clearCount = 0
    private var _searchCalls: [(query: String, options: ProjectSearchOptions)] = []
    private var _resultsToReturn: [ProjectSearchResult] = []
    private var _errorToThrow: Error?

    var indexedURLs: [URL] { lock.withLock { _indexedURLs } }
    var cancelCount: Int { lock.withLock { _cancelCount } }
    var clearCount: Int { lock.withLock { _clearCount } }
    var searchCalls: [(query: String, options: ProjectSearchOptions)] { lock.withLock { _searchCalls } }

    func setResults(_ results: [ProjectSearchResult]) {
        lock.withLock { _resultsToReturn = results }
    }

    func setError(_ error: Error?) {
        lock.withLock { _errorToThrow = error }
    }

    func indexFiles(urls: [URL]) async throws {
        lock.withLock { _indexedURLs = urls }
    }

    func search(query: String, options: ProjectSearchOptions) async throws -> [ProjectSearchResult] {
        let snapshot = lock.withLock {
            _searchCalls.append((query, options))
            return (_resultsToReturn, _errorToThrow)
        }
        if let err = snapshot.1 { throw err }
        return snapshot.0
    }

    func cancelSearch() {
        lock.withLock { _cancelCount += 1 }
    }

    func clearIndex() {
        lock.withLock {
            _indexedURLs = []
            _clearCount += 1
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
```

- [ ] **Step 2: Write the failing tests**

Create `Tests/CodeEditorSampleTests/ProjectSearchModelTests.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation
import Testing
@testable import CodeEditorSample

@MainActor
@Suite("ProjectSearchModel")
struct ProjectSearchModelTests {
    @Test("empty query clears results without calling search")
    func emptyQueryClears() async {
        let stub = StubProjectSearchProvider()
        let model = ProjectSearchModel(adapter: stub)

        model.query = ""
        await model.runSearch()

        #expect(stub.searchCalls.isEmpty)
        #expect(model.results.isEmpty)
    }

    @Test("non-empty query invokes the adapter and stores results")
    func nonEmptyQuerySearches() async {
        let stub = StubProjectSearchProvider()
        let result = ProjectSearchResult(
            fileURL: URL(fileURLWithPath: "/tmp/x.swift"),
            lineNumber: 3,
            column: 5,
            matchedText: "foo",
            contextLine: "let foo = 1"
        )
        stub.setResults([result])
        let model = ProjectSearchModel(adapter: stub)

        model.query = "foo"
        await model.runSearch()

        #expect(stub.searchCalls.map(\.query) == ["foo"])
        #expect(model.results.count == 1)
    }

    @Test("toggle changes trigger runSearch from the host")
    func toggleTriggersSearch() async {
        let stub = StubProjectSearchProvider()
        let model = ProjectSearchModel(adapter: stub)
        model.query = "foo"
        await model.runSearch()
        let baseline = stub.searchCalls.count

        model.caseSensitive = true
        await model.runSearch()

        #expect(stub.searchCalls.count == baseline + 1)
        #expect(stub.searchCalls.last?.options.caseSensitive == true)
    }

    @Test("adapter error sets the error status")
    func adapterErrorStored() async {
        let stub = StubProjectSearchProvider()
        struct Boom: Error, LocalizedError {
            var errorDescription: String? { "regex bad" }
        }
        stub.setError(Boom())
        let model = ProjectSearchModel(adapter: stub)

        model.query = "foo"
        await model.runSearch()

        if case .error(let message) = model.status {
            #expect(message == "regex bad")
        } else {
            Issue.record("expected .error status, got \(model.status)")
        }
    }

    @Test("extensionFilter parsing splits on comma/whitespace and lowercases")
    func extensionFilterParsing() async {
        let stub = StubProjectSearchProvider()
        let model = ProjectSearchModel(adapter: stub)
        model.query = "foo"
        model.extensionFilter = "Swift, MD .toml"
        await model.runSearch()

        let exts = stub.searchCalls.last?.options.fileExtensions ?? []
        #expect(Set(exts) == ["swift", "md", "toml"])
    }

    @Test("setRoot(nil) cancels and clears the index")
    func setRootNilClears() async {
        let stub = StubProjectSearchProvider()
        let model = ProjectSearchModel(adapter: stub)
        await model.setRoot(nil)

        #expect(model.results.isEmpty)
        #expect(model.status == .idle)
    }
}
#endif
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter ProjectSearchModelTests`
Expected: FAIL — `ProjectSearchModel` not defined.

- [ ] **Step 4: Implement `ProjectSearchModel`**

Create `Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

/// Project-wide search state + ProjectSearchProvider adapter for the
/// sample's workspace surface. Independent of WorkspaceModel.
@MainActor
@Observable
final class ProjectSearchModel {
    enum Status: Equatable, Sendable {
        case idle
        case indexing
        case searching
        case ready
        case results(matchCount: Int, fileCount: Int)
        case noMatches
        case error(message: String)
    }

    var query: String = ""
    var caseSensitive: Bool = false
    var useRegex: Bool = false
    var extensionFilter: String = ""
    private(set) var results: [ProjectSearchResult] = []
    private(set) var status: Status = .idle
    private(set) var indexedFileCount: Int = 0

    private let adapter: ProjectSearchProvider
    private var indexTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private(set) var indexedRoot: URL?

    init(adapter: ProjectSearchProvider = PortableProjectSearchAdapter()) {
        self.adapter = adapter
    }

    /// Sets a new root. Cancels any in-flight work, then walks the
    /// directory and feeds the index. `nil` clears state.
    func setRoot(_ url: URL?) async {
        indexTask?.cancel()
        searchTask?.cancel()
        adapter.cancelSearch()
        adapter.clearIndex()
        results = []
        indexedFileCount = 0
        indexedRoot = nil

        guard let url else {
            status = .idle
            return
        }

        status = .indexing
        let urls = await enumerateFiles(at: url)
        indexedFileCount = urls.count
        do {
            try await adapter.indexFiles(urls: urls)
            indexedRoot = url
            status = .ready
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }

    /// Run the current query with the current options. Cancels any
    /// in-flight search.
    func runSearch() async {
        searchTask?.cancel()
        adapter.cancelSearch()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clear()
            return
        }
        status = .searching
        let options = ProjectSearchOptions(
            caseSensitive: caseSensitive,
            useRegex: useRegex,
            maxResults: 200,
            fileExtensions: parsedExtensionFilter()
        )
        do {
            let found = try await adapter.search(query: trimmed, options: options)
            results = found
            if found.isEmpty {
                status = .noMatches
            } else {
                let fileCount = Set(found.map(\.fileURL)).count
                status = .results(matchCount: found.count, fileCount: fileCount)
            }
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }

    /// Cancel any in-flight search; preserve existing results.
    func cancel() {
        searchTask?.cancel()
        adapter.cancelSearch()
        if !results.isEmpty {
            let fileCount = Set(results.map(\.fileURL)).count
            status = .results(matchCount: results.count, fileCount: fileCount)
        } else {
            status = indexedRoot == nil ? .idle : .ready
        }
    }

    /// Reset query + results. Index is retained.
    func clear() {
        searchTask?.cancel()
        adapter.cancelSearch()
        query = ""
        results = []
        status = indexedRoot == nil ? .idle : .ready
    }

    /// Re-walk the indexed root and re-feed the index.
    func reindex() async {
        guard let indexedRoot else { return }
        await setRoot(indexedRoot)
    }

    // MARK: - Private

    func parsedExtensionFilter() -> [String] {
        let raw = extensionFilter
        let separators = CharacterSet(charactersIn: ", \t")
        let pieces = raw
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return pieces.map { piece -> String in
            var trimmed = piece
            if trimmed.hasPrefix(".") { trimmed.removeFirst() }
            return trimmed.lowercased()
        }
    }

    private func enumerateFiles(at root: URL) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            var results: [URL] = []
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                return results
            }
            while let url = enumerator.nextObject() as? URL {
                let name = url.lastPathComponent
                if WorkspaceIgnoreRules.shouldHide(name: name) {
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                    if isDir { enumerator.skipDescendants() }
                    continue
                }
                let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
                guard isRegular else { continue }
                if WorkspaceIgnoreRules.isBinaryExtension(url.pathExtension) { continue }
                results.append(url)
            }
            return results
        }.value
    }
}
#endif
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter ProjectSearchModelTests`
Expected: PASS (6 cases).

- [ ] **Step 6: Lint and commit**

```bash
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/Workspace/ProjectSearchModel.swift \
        Tests/CodeEditorSampleTests/Support/StubProjectSearchProvider.swift \
        Tests/CodeEditorSampleTests/ProjectSearchModelTests.swift
git commit -m "$(cat <<'EOF'
Sample: ProjectSearchModel (@Observable adapter-backed search)

Owns query/toggles/results/indexing state and routes through
PortableProjectSearchAdapter. Status enum has six explicit cases so
the view can render every state without ad-hoc booleans.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Sample — `EditorController+SelectMatch` helper

**Files:**
- Create: `Sources/CodeEditorSample/Workspace/EditorController+SelectMatch.swift`
- Create: `Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift`

**Why:** Sample-side glue. Converts a `ProjectSearchResult` (1-based line/column + matchedText) into the NSRange selection that `EditorController.selectRange(_:scroll:)` (from Task 2) wants.

- [ ] **Step 1: Write the failing tests**

Create `Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift`:

```swift
#if canImport(AppKit)
import AppKit
import CodeEditorPlugin
import Foundation
import Testing
@testable import CodeEditorSample

@MainActor
@Suite("EditorController.selectMatch")
struct EditorControllerSelectMatchTests {
    private func makeAttached(text: String) -> (EditorController, CodeEditorView) {
        let view = CodeEditorView(frame: .zero)
        view.string = text
        let controller = EditorController()
        controller.attach(to: view)
        return (controller, view)
    }

    @Test("selects the matched substring on the indexed line")
    func selectsMatchedSubstring() {
        let text = "line one\nlet foo = 1\nlast line"
        let (controller, view) = makeAttached(text: text)
        let result = ProjectSearchResult(
            fileURL: URL(fileURLWithPath: "/tmp/x.swift"),
            lineNumber: 2,
            column: 5,
            matchedText: "foo",
            contextLine: "let foo = 1"
        )

        let ok = controller.selectMatch(result)

        #expect(ok)
        let expectedRange = (text as NSString).range(of: "foo")
        #expect(view.selectedRange() == expectedRange)
    }

    @Test("returns false when the line is out of range")
    func outOfRangeReturnsFalse() {
        let text = "single line"
        let (controller, _) = makeAttached(text: text)
        let result = ProjectSearchResult(
            fileURL: URL(fileURLWithPath: "/tmp/x.swift"),
            lineNumber: 99,
            column: 1,
            matchedText: "x",
            contextLine: ""
        )

        let ok = controller.selectMatch(result)

        #expect(!ok)
    }
}
#endif
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter EditorControllerSelectMatchTests`
Expected: FAIL — `selectMatch` not defined.

- [ ] **Step 3: Implement the helper**

Create `Sources/CodeEditorSample/Workspace/EditorController+SelectMatch.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation

extension EditorController {
    /// Routes a project-search hit into the editor: computes the NSRange
    /// from `(lineNumber, column, matchedText)`, selects it, and scrolls
    /// it into view. Returns `false` when `lineNumber`/`column` falls
    /// outside the attached document (e.g. file changed since indexing).
    @discardableResult
    public func selectMatch(_ result: ProjectSearchResult) -> Bool {
        // ProjectSearchResult line/column are 1-based; LSP positions are 0-based.
        let lspLine = result.lineNumber - 1
        let lspChar = result.column - 1
        guard lspLine >= 0, lspChar >= 0,
              let start = nsLocation(forLSPLine: lspLine, character: lspChar) else {
            return false
        }
        let length = (result.matchedText as NSString).length
        let range = NSRange(location: start, length: length)
        selectRange(range, scroll: true)
        return true
    }
}
#endif
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter EditorControllerSelectMatchTests`
Expected: PASS (2 cases).

- [ ] **Step 5: Lint and commit**

```bash
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/Workspace/EditorController+SelectMatch.swift \
        Tests/CodeEditorSampleTests/EditorControllerSelectMatchTests.swift
git commit -m "$(cat <<'EOF'
Sample: EditorController+SelectMatch helper for ProjectSearchResult

Bridges 1-based search hits to the framework's 0-based LSP-position
helpers and the new selectRange(_:scroll:) API.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: Sample — `WorkspaceSidebar` host

**Files:**
- Create: `Sources/CodeEditorSample/Workspace/WorkspaceSidebar.swift`

**Why:** Owns the segmented tab state and renders the appropriate panel inside `EditorSidebarShell`. Pure view container; no model logic.

- [ ] **Step 1: Implement `WorkspaceSidebar`**

Create `Sources/CodeEditorSample/Workspace/WorkspaceSidebar.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import CodeEditorUI
import SwiftUI

/// macOS left-rail workspace surface. Segmented switcher between a
/// file tree (`FilePanelView`) and project search
/// (`ProjectSearchPanelView`). Owns no model state — both panels
/// are driven by AppState's WorkspaceModel and ProjectSearchModel.
struct WorkspaceSidebar: View {
    @Bindable var workspace: WorkspaceModel
    @Bindable var search: ProjectSearchModel
    @Bindable var appState: AppState
    @State private var tab: Tab = .files

    enum Tab: String, CaseIterable, Hashable, Identifiable {
        case files = "Files"
        case search = "Search"
        var id: String { rawValue }
    }

    var body: some View {
        EditorSidebarShell(sectionTitle: tab.rawValue) {
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)

                switch tab {
                case .files:
                    FilePanelView(model: workspace, appState: appState)
                case .search:
                    ProjectSearchPanelView(model: search, workspace: workspace, appState: appState)
                }
            }
        }
        .frame(minWidth: 240, idealWidth: 280, maxWidth: 360)
    }
}
#endif
```

- [ ] **Step 2: Verify the file compiles** (it will error until panels exist, but commit-then-build is fine; we add panels next)

Run: `swift build --target CodeEditorSample 2>&1 | head -20`
Expected: Errors referencing `FilePanelView` and `ProjectSearchPanelView` — expected; we add them in Tasks 9 and 10.

- [ ] **Step 3: Move on**

No commit yet; commit after the panels compile.

---

## Task 9: Sample — `FilePanelView`

**Files:**
- Create: `Sources/CodeEditorSample/Workspace/FilePanelView.swift`

**Why:** Renders the file tree with three states (no-root, loaded, error). Pure view; all state comes from `WorkspaceModel`.

- [ ] **Step 1: Implement `FilePanelView`**

Create `Sources/CodeEditorSample/Workspace/FilePanelView.swift`:

```swift
#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

/// File-tree panel content. Three states:
/// - no root: ContentUnavailableView + Open Folder… button
/// - loaded: OutlineGroup-style lazy tree
/// - error overlay: inline row above the tree
struct FilePanelView: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var model: WorkspaceModel
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if let error = model.loadError {
                errorBanner(error)
            }
            content
            footer
        }
    }

    @ViewBuilder
    private var content: some View {
        if let root = model.rootNode {
            List {
                rowsForChildren(of: root.url, depth: 0)
            }
            .listStyle(.sidebar)
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No folder open", systemImage: "folder.badge.questionmark")
        } description: {
            Text("Open a folder to browse and search its files.")
        } actions: {
            Button("Open Folder…") {
                WorkspacePicker.choose(currentRoot: model.rootURL) {
                    appState.workspaceRoot = $0
                }
            }
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func rowsForChildren(of url: URL, depth: Int) -> some View {
        let children = model.filteredChildren(of: url)
        ForEach(children) { node in
            row(for: node, depth: depth)
            if node.isDirectory, model.expandedDirectoryURLs.contains(node.url) {
                rowsForChildren(of: node.url, depth: depth + 1)
            }
        }
    }

    private func row(for node: WorkspaceFileNode, depth: Int) -> some View {
        Button {
            handleTap(on: node)
        } label: {
            HStack(spacing: 6) {
                Spacer().frame(width: CGFloat(depth) * 12)
                if node.isDirectory {
                    Image(systemName: model.expandedDirectoryURLs.contains(node.url) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color(tokens: theme.style.icon.muted))
                        .frame(width: 10)
                    Image(systemName: "folder.fill")
                        .foregroundStyle(Color(tokens: theme.style.icon.muted))
                } else {
                    Spacer().frame(width: 10)
                    Image(systemName: "doc.text")
                        .foregroundStyle(Color(tokens: theme.style.icon.muted))
                }
                Text(node.name)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
        .background(
            (model.selectedFileURL == node.url)
                ? Color(tokens: theme.style.backgrounds.activeRow)
                : Color.clear
        )
    }

    private func handleTap(on node: WorkspaceFileNode) {
        if node.isDirectory {
            Task { await model.toggleExpanded(node.url) }
        } else {
            model.selectedFileURL = node.url
            appState.documents.openFile(url: node.url)
        }
    }

    private func errorBanner(_ error: Error) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color(tokens: theme.style.text.warning))
            Text(error.localizedDescription)
                .font(.system(size: 11))
                .foregroundStyle(Color(tokens: theme.style.text.base))
                .lineLimit(2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(tokens: theme.style.backgrounds.subtle))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(model.rootURL?.path ?? "No folder")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if let url = model.rootURL {
                    Task { await model.refresh(directory: url) }
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Reload")
            .disabled(model.rootURL == nil)

            Button {
                WorkspacePicker.choose(currentRoot: model.rootURL) {
                    appState.workspaceRoot = $0
                }
            } label: {
                Image(systemName: "folder.badge.plus")
            }
            .buttonStyle(.plain)
            .help("Open Folder…")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .overlay(
            Rectangle()
                .fill(Color(tokens: theme.style.borders.variant))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}
#endif
```

> **Note:** This file references `theme.style.text.warning`, `theme.style.backgrounds.activeRow`, and `theme.style.backgrounds.subtle`. If any of those tokens don't exist, fall back to `theme.style.text.muted` / `theme.style.backgrounds.panel` respectively. Run the build in Step 2 to find out.

- [ ] **Step 2: Build to surface token name mismatches**

Run: `swift build --target CodeEditorSample 2>&1 | head -40`
Expected: Likely some "value of type 'X' has no member 'warning'/'activeRow'/'subtle'" errors.

- [ ] **Step 3: Fix any token references that don't compile**

Search the design tokens to find the right names:

Run: `grep -rn "var warning\|var subtle\|var activeRow\|var emphasis" Sources/CodeEditorDesignTokens Sources/CodeEditorPlugin/Theming | head -30`

Pick the closest equivalents and update the file. If no warning color exists, use `theme.style.text.error` or `Color.orange`. If no `activeRow` exists, use a low-alpha derivation of `theme.style.text.accent`.

- [ ] **Step 4: Build clean**

Run: `swift build --target CodeEditorSample && swiftlint --fix && swiftlint`
Expected: Clean build (still errors for `ProjectSearchPanelView` — expected; commit happens after Task 10).

---

## Task 10: Sample — `ProjectSearchPanelView`

**Files:**
- Create: `Sources/CodeEditorSample/Workspace/ProjectSearchPanelView.swift`

**Why:** Renders the search header (query field + three controls), the results list grouped by file, and the inline state-line. Pure view; all state from `ProjectSearchModel`.

- [ ] **Step 1: Implement `ProjectSearchPanelView`**

Create `Sources/CodeEditorSample/Workspace/ProjectSearchPanelView.swift`:

```swift
#if canImport(AppKit)
import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

struct ProjectSearchPanelView: View {
    @Environment(\.codeEditorTheme) private var theme
    @Bindable var model: ProjectSearchModel
    @Bindable var workspace: WorkspaceModel
    @Bindable var appState: AppState
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            header
            statusLine
            resultsList
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            TextField("Search workspace…", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onChange(of: model.query) { _, _ in scheduleDebouncedSearch() }

            HStack(spacing: 6) {
                Toggle(isOn: $model.caseSensitive) { Text("Aa") }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .onChange(of: model.caseSensitive) { _, _ in runImmediately() }

                Toggle(isOn: $model.useRegex) { Text(".*") }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .onChange(of: model.useRegex) { _, _ in runImmediately() }

                TextField("ext: swift, md", text: $model.extensionFilter)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onChange(of: model.extensionFilter) { _, _ in scheduleDebouncedSearch() }
            }

            HStack(spacing: 8) {
                Button {
                    Task { await model.reindex() }
                } label: {
                    Label("Reindex", systemImage: "arrow.triangle.2.circlepath")
                }
                .controlSize(.small)
                .disabled(workspace.rootURL == nil)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var statusLine: some View {
        Text(statusText)
            .font(.system(size: 10))
            .foregroundStyle(Color(tokens: theme.style.text.muted))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusText: String {
        switch model.status {
        case .idle: return "Open a folder to enable project search"
        case .indexing: return "Indexing \(model.indexedFileCount) files…"
        case .ready: return "Ready · \(model.indexedFileCount) files indexed"
        case .searching: return "Searching…"
        case .results(let matches, let files): return "\(matches) matches in \(files) files"
        case .noMatches: return "No matches"
        case .error(let message): return message
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if model.results.isEmpty {
            Spacer()
        } else {
            List {
                ForEach(groupedResults, id: \.0) { (fileURL, hits) in
                    Section {
                        ForEach(Array(hits.enumerated()), id: \.offset) { _, hit in
                            resultRow(for: hit)
                        }
                    } header: {
                        Text(relativePath(for: fileURL))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(tokens: theme.style.text.muted))
                    }
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var groupedResults: [(URL, [ProjectSearchResult])] {
        var seen: [URL] = []
        var buckets: [URL: [ProjectSearchResult]] = [:]
        for result in model.results {
            if buckets[result.fileURL] == nil { seen.append(result.fileURL) }
            buckets[result.fileURL, default: []].append(result)
        }
        return seen.map { ($0, buckets[$0] ?? []) }
    }

    private func relativePath(for fileURL: URL) -> String {
        guard let root = workspace.rootURL else { return fileURL.path }
        let rootPath = root.path
        let filePath = fileURL.path
        if filePath.hasPrefix(rootPath) {
            let stripped = String(filePath.dropFirst(rootPath.count))
            return stripped.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return fileURL.path
    }

    private func resultRow(for hit: ProjectSearchResult) -> some View {
        Button {
            openResult(hit)
        } label: {
            HStack(alignment: .top, spacing: 8) {
                Text("\(hit.lineNumber)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
                    .frame(width: 36, alignment: .trailing)
                Text(hit.contextLine)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    private func openResult(_ hit: ProjectSearchResult) {
        appState.documents.openFile(url: hit.fileURL)
        appState.editorController.selectMatch(hit)
    }

    // MARK: - Debounce

    private func scheduleDebouncedSearch() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await model.runSearch()
        }
    }

    private func runImmediately() {
        debounceTask?.cancel()
        Task { await model.runSearch() }
    }
}
#endif
```

- [ ] **Step 2: Build to verify both views compile together**

Run: `swift build --target CodeEditorSample && swiftlint --fix && swiftlint`
Expected: Clean build.

- [ ] **Step 3: Commit all three views together**

```bash
git add Sources/CodeEditorSample/Workspace/WorkspaceSidebar.swift \
        Sources/CodeEditorSample/Workspace/FilePanelView.swift \
        Sources/CodeEditorSample/Workspace/ProjectSearchPanelView.swift
git commit -m "$(cat <<'EOF'
Sample: WorkspaceSidebar + FilePanelView + ProjectSearchPanelView

Three new views: a segmented EditorSidebarShell host and two panel
content views. All pure views; state lives in WorkspaceModel and
ProjectSearchModel from prior tasks.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Sample — `AppState` wiring

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift`

**Why:** Make `workspaceModel` and `projectSearchModel` available to the views; ensure they observe `workspaceRoot`. The first observation happens at init time so a startup `workspaceRoot` is picked up.

- [ ] **Step 1: Read the current AppState to know where to insert**

Run: `head -60 Sources/CodeEditorSample/App/AppState.swift`
Expected: See the existing `@Observable final class AppState { ... var workspaceRoot: URL? ... }` declaration and `init()`.

- [ ] **Step 2: Add the two new stored properties + init wiring**

After the existing `var workspaceRoot: URL?` declaration, add:

```swift
let workspaceModel = WorkspaceModel()
let projectSearchModel = ProjectSearchModel()
```

These properties live alongside the other top-level observable handles. They are `let` because the models themselves are `@Observable` and own their internal state.

In `AppState.init()` (find the existing init body), after the existing initialization but before the closing brace, add:

```swift
#if canImport(AppKit)
workspaceModel.setRoot(workspaceRoot)
let initialRoot = workspaceRoot
Task { @MainActor in
    await projectSearchModel.setRoot(initialRoot)
}
#endif
```

- [ ] **Step 3: Build + lint**

Run: `swift build --target CodeEditorSample && swiftlint --fix && swiftlint`
Expected: Clean.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/App/AppState.swift
git commit -m "$(cat <<'EOF'
Sample AppState: own WorkspaceModel + ProjectSearchModel

Both are observable handles wired to the existing workspaceRoot at
init. The sidebar host adds an .onChange to keep them in sync after
launch.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Sample — Add the "Open Folder…" command

**Files:**
- Modify: `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift`

**Why:** Menu + keyboard entry point so users can change the folder without diving into Settings.

- [ ] **Step 1: Add the button to the existing `CommandGroup(after: .newItem)`**

In `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift`, locate the `CommandGroup(after: .newItem) { ... }` block (currently containing "New Tab", "Close Tab", "Save"). After the "New Tab" button (or wherever fits), add:

```swift
Button("Open Folder…") {
    WorkspacePicker.choose(currentRoot: appState.workspaceRoot) {
        appState.workspaceRoot = $0
    }
}
.keyboardShortcut("o", modifiers: .command)
```

`⌘O` is currently a no-op in the sample per NEXT.md A.1; we claim it for Open Folder. `⇧⌘O` continues to belong to the existing "Go to Symbol…" command.

- [ ] **Step 2: Build + lint**

Run: `swift build --target CodeEditorSample && swiftlint --fix && swiftlint`
Expected: Clean.

- [ ] **Step 3: Smoke-run the sample**

Run: `swift run CodeEditorSample` (in a separate terminal if you can — the build watches; otherwise build then run).

Click **File ▸ Open Folder…**, pick a directory, confirm — `AppState.workspaceRoot` should update and (after Task 13) the sidebar should populate.

Stop the sample (`⌘Q`).

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/App/CodeEditorSampleApp.swift
git commit -m "$(cat <<'EOF'
Sample: File ▸ Open Folder… command (⌘O)

Routes through the shared WorkspacePicker helper. ⌘O was unused per
NEXT.md A.1; ⇧⌘O stays with Go to Symbol.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Sample — Swap `WindowBody` left rail

**Files:**
- Modify: `Sources/CodeEditorSample/App/WindowBody.swift`
- Modify: `Sources/CodeEditorSample/App/RootWindow.swift`
- Modify: `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift` (rename binding)
- Delete: `Sources/CodeEditorSample/Sidebars/SettingsSidebar.swift`

**Why:** Replace the inline `SettingsSidebar` with the new `WorkspaceSidebar`. Rename `settingsVisible` → `workspaceVisible` throughout.

- [ ] **Step 1: Find every reference to `settingsVisible`**

Run: `grep -rn "settingsVisible" Sources/CodeEditorSample/`
Expected: Hits in `WindowBody.swift`, `RootWindow.swift`, and likely `CommandPaletteCatalog.swift`. Record the file:line list before editing.

- [ ] **Step 2: Rename `settingsVisible` → `workspaceVisible` in `RootWindow.swift`**

In `Sources/CodeEditorSample/App/RootWindow.swift`, change:

```swift
@State private var settingsVisible: Bool = true
```

to:

```swift
@State private var workspaceVisible: Bool = true
```

Update the two pass-through sites (`CommandPaletteCatalog.build(... settingsVisible: $settingsVisible ...)` and `WindowBody(... settingsVisible: $settingsVisible ...)`) to pass `workspaceVisible: $workspaceVisible`.

- [ ] **Step 3: Update `CommandPaletteCatalog`**

In `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift`, rename the `settingsVisible: Binding<Bool>` parameter to `workspaceVisible: Binding<Bool>` and update any internal use (command title can change from "Toggle Settings" to "Toggle Workspace").

- [ ] **Step 4: Replace the left rail in `WindowBody.swift`**

In `Sources/CodeEditorSample/App/WindowBody.swift`:

Change the property declaration:

```swift
@Binding var settingsVisible: Bool
```

to:

```swift
@Binding var workspaceVisible: Bool
```

Replace the `SettingsSidebar(appState: appState)` invocation:

```swift
if workspaceVisible {
    WorkspaceSidebar(
        workspace: appState.workspaceModel,
        search: appState.projectSearchModel,
        appState: appState
    )
    .onChange(of: appState.workspaceRoot) { _, newValue in
        appState.workspaceModel.setRoot(newValue)
        Task { await appState.projectSearchModel.setRoot(newValue) }
    }
    columnSeparator
}
```

- [ ] **Step 5: Delete `SettingsSidebar.swift`**

```bash
git rm Sources/CodeEditorSample/Sidebars/SettingsSidebar.swift
```

- [ ] **Step 6: Build to find any missed references**

Run: `swift build --target CodeEditorSample`
Expected: Either clean, or one or two remaining `settingsVisible` references — fix and rebuild until clean.

- [ ] **Step 7: Run tests + lint**

Run: `swift test --filter SampleTests --parallel; swiftlint --fix && swiftlint`
Expected: Existing sample tests still pass; lint clean.

- [ ] **Step 8: Smoke-run the sample again**

Run: `swift run CodeEditorSample`

Verify:
- The left rail shows the new Files/Search switcher (not the old SettingsSidebar).
- File ▸ Open Folder… picks a folder; the tree populates.
- Searching with a non-empty query yields results that, when clicked, open the file and highlight the match.
- ⌘, opens the existing `SettingsScene` window with the same knobs.

Stop the sample (`⌘Q`).

- [ ] **Step 9: Commit**

```bash
git add Sources/CodeEditorSample/App/WindowBody.swift \
        Sources/CodeEditorSample/App/RootWindow.swift \
        Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift
git commit -m "$(cat <<'EOF'
Sample: replace inline SettingsSidebar with WorkspaceSidebar on the left rail

settingsVisible renamed to workspaceVisible throughout RootWindow,
WindowBody, and CommandPaletteCatalog. The old SettingsSidebar is
gone; global settings live in ⌘, → SettingsScene (already wired in
CodeEditorSampleApp).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Sample — iOS Inspectors copy update

**Files:**
- Modify: `Sources/CodeEditorSample/iOS/IOSRootView.swift`

**Why:** iOS doesn't get the workspace surface in this spec. Update the existing Inspectors detail copy so iOS users know workspace browsing and project search are macOS-only here.

- [ ] **Step 1: Locate the Inspectors detail copy**

Run: `grep -n "ContentUnavailable\|Inspectors\|workspace" Sources/CodeEditorSample/iOS/IOSRootView.swift`
Expected: One or two hits pointing at the Inspectors detail's `ContentUnavailableView` description text.

- [ ] **Step 2: Update the copy**

Find the existing `description:` or similar text on the Inspectors detail's `ContentUnavailableView`. If the current copy mentions specific framework systems, append:

```
File-tree browsing and project search are macOS-only in the current sample.
```

If no `ContentUnavailableView` exists yet in the Inspectors detail, add a brief footer note in the existing detail body. Keep it under two sentences.

- [ ] **Step 3: Build the iOS target**

Run: `swift build --target CodeEditorSample` (the sample builds for the host platform; iOS-specific code is checked via `#if canImport(UIKit)` paths).
Expected: Clean.

- [ ] **Step 4: Lint + commit**

```bash
swiftlint --fix && swiftlint
git add Sources/CodeEditorSample/iOS/IOSRootView.swift
git commit -m "$(cat <<'EOF'
Sample iOS: note workspace surface is macOS-only in current sample

The new file tree and project search sit in WindowBody's left rail
(AppKit). Tracked as a future iOS spec.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Snapshot tests for the workspace surface

**Files:**
- Create: `Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift`

**Why:** Visual regression guard, mirroring the existing `EditorSidebarShellSnapshots` / `EventLogPanelSnapshotTests` pattern.

- [ ] **Step 1: Find the existing snapshot conventions**

Run: `ls Tests/CodeEditorSampleTests/__Snapshots__/ 2>/dev/null && head -40 Tests/CodeEditorSampleTests/EventLogPanelSnapshotTests.swift`
Expected: A list of existing snapshot directories and the conventional header / setup. Mirror it.

- [ ] **Step 2: Add the snapshot test file**

Create `Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
import Foundation
import SnapshotTesting
import SwiftUI
import XCTest
@testable import CodeEditorSample

@MainActor
final class WorkspaceSidebarSnapshotTests: XCTestCase {
    private func makeAppState() -> AppState { AppState() }

    private func makeWorkspaceModel(loaded: Bool = false) -> WorkspaceModel {
        let model = WorkspaceModel(factory: { url in
            let root = WorkspaceFileNode(name: url.lastPathComponent, url: url, isDirectory: true)
            let children: [WorkspaceFileNode] = loaded ? [
                WorkspaceFileNode(
                    name: "Sources",
                    url: url.appendingPathComponent("Sources"),
                    isDirectory: true
                ),
                WorkspaceFileNode(
                    name: "Tests",
                    url: url.appendingPathComponent("Tests"),
                    isDirectory: true
                ),
                WorkspaceFileNode(
                    name: "Package.swift",
                    url: url.appendingPathComponent("Package.swift"),
                    isDirectory: false
                ),
                WorkspaceFileNode(
                    name: "README.md",
                    url: url.appendingPathComponent("README.md"),
                    isDirectory: false
                )
            ] : []
            return StubWorkspaceFileTreeForSnapshots(root: root, children: children)
        })
        if loaded {
            model.setRoot(URL(fileURLWithPath: "/tmp/SampleWorkspace"))
        }
        return model
    }

    func testFilesEmptyState() {
        let view = WorkspaceSidebar(
            workspace: WorkspaceModel(),
            search: ProjectSearchModel(adapter: StubProjectSearchProvider()),
            appState: makeAppState()
        )
        .frame(width: 280, height: 480)
        assertSnapshot(of: view, as: .image)
    }

    func testFilesLoaded() {
        let view = WorkspaceSidebar(
            workspace: makeWorkspaceModel(loaded: true),
            search: ProjectSearchModel(adapter: StubProjectSearchProvider()),
            appState: makeAppState()
        )
        .frame(width: 280, height: 480)
        assertSnapshot(of: view, as: .image)
    }

    func testSearchReady() {
        let search = ProjectSearchModel(adapter: StubProjectSearchProvider())
        Task { @MainActor in search.query = "" }
        let view = WorkspaceSidebar(
            workspace: WorkspaceModel(),
            search: search,
            appState: makeAppState()
        )
        .frame(width: 280, height: 480)
        assertSnapshot(of: view, as: .image)
    }

    func testSearchResultsPopulated() async {
        let stub = StubProjectSearchProvider()
        stub.setResults([
            ProjectSearchResult(
                fileURL: URL(fileURLWithPath: "/tmp/SampleWorkspace/Sources/Foo.swift"),
                lineNumber: 14,
                column: 9,
                matchedText: "TODO",
                contextLine: "// TODO: Implement feature"
            ),
            ProjectSearchResult(
                fileURL: URL(fileURLWithPath: "/tmp/SampleWorkspace/Tests/Bar.swift"),
                lineNumber: 7,
                column: 5,
                matchedText: "TODO",
                contextLine: "    TODO: assert behavior"
            )
        ])
        let search = ProjectSearchModel(adapter: stub)
        search.query = "TODO"
        await search.runSearch()

        let view = WorkspaceSidebar(
            workspace: WorkspaceModel(),
            search: search,
            appState: makeAppState()
        )
        .frame(width: 280, height: 480)
        assertSnapshot(of: view, as: .image)
    }

    func testSearchRegexError() async {
        let stub = StubProjectSearchProvider()
        struct Boom: Error, LocalizedError { var errorDescription: String? { "invalid regex" } }
        stub.setError(Boom())
        let search = ProjectSearchModel(adapter: stub)
        search.query = "[invalid"
        search.useRegex = true
        await search.runSearch()

        let view = WorkspaceSidebar(
            workspace: WorkspaceModel(),
            search: search,
            appState: makeAppState()
        )
        .frame(width: 280, height: 480)
        assertSnapshot(of: view, as: .image)
    }
}

@MainActor
private final class StubWorkspaceFileTreeForSnapshots: WorkspaceFileTree, WorkspaceFileWatching {
    let root: WorkspaceFileNode
    private let children: [WorkspaceFileNode]
    private let (_stream, _continuation) = AsyncStream<WorkspaceFileEvent>.makeStream()

    init(root: WorkspaceFileNode, children: [WorkspaceFileNode]) {
        self.root = root
        self.children = children
    }

    func children(of node: WorkspaceFileNode) -> [WorkspaceFileNode] {
        node.id == root.id ? children : []
    }

    func isDirectory(_ node: WorkspaceFileNode) -> Bool { node.isDirectory }
    func fileURL(for node: WorkspaceFileNode) -> URL { node.url }
    func refresh(node: WorkspaceFileNode) async throws {}

    func startWatching(root: URL) async throws {}
    func stopWatching() {}
    var events: AsyncStream<WorkspaceFileEvent> { _stream }
}
#endif
```

- [ ] **Step 3: Record the baselines**

Temporarily change the test file: replace each `assertSnapshot(of: view, as: .image)` with `assertSnapshot(of: view, as: .image, record: true)`.

Run: `swift test --filter WorkspaceSidebarSnapshotTests`
Expected: All five tests "fail" but write PNGs into `Tests/CodeEditorSampleTests/__Snapshots__/WorkspaceSidebarSnapshotTests/`.

Inspect the PNGs visually (open in Finder). They should show:
1. The empty Files state with "Open Folder…" button.
2. The loaded Files state with two folders and two files.
3. The Search ready state.
4. Search results populated, grouped by file.
5. Search regex-error state.

If a baseline looks wrong, adjust the view source or the test inputs before un-recording.

- [ ] **Step 4: Switch off recording mode**

Revert each `record: true` argument back to plain `assertSnapshot(of: view, as: .image)`.

- [ ] **Step 5: Run tests again to confirm they pass against the recorded baselines**

Run: `swift test --filter WorkspaceSidebarSnapshotTests`
Expected: PASS (5 cases).

- [ ] **Step 6: Lint + commit baselines and tests**

```bash
swiftlint --fix && swiftlint
git add Tests/CodeEditorSampleTests/WorkspaceSidebarSnapshotTests.swift \
        Tests/CodeEditorSampleTests/__Snapshots__/WorkspaceSidebarSnapshotTests/
git commit -m "$(cat <<'EOF'
Test: WorkspaceSidebar snapshot baselines

Five baselines: Files empty, Files loaded, Search ready, Search
results populated, Search regex error.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Final pipeline pass

**Files:** None (verification only)

**Why:** Catch anything the per-task pipelines missed and confirm the spec's full surface lands green.

- [ ] **Step 1: Full pipeline**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`
Expected: Clean build, no lint, all tests pass.

If any test fails:
- Check `NEXT.md D` for known flakes — `LineGeometryStoreBenchmarkTests.testFuzzIncrementalEditCorrectness`, `EditorStatusBarSnapshots/*`, `PerformanceObservationTests.restartAfterStopResumesRefreshTicks`, etc. are pre-existing.
- If a test that *this* work touched fails, fix it before continuing.

- [ ] **Step 2: Smoke-run once more**

Run: `swift run CodeEditorSample`

Verify end-to-end:
- ⌘O → folder picker → folder loads
- Tree click → file opens in a new tab; clicking the same file again focuses the existing tab (de-dupe).
- Search → results populate; clicking a result opens (or focuses) the file and selects the matched substring.
- Regex toggle → invalid regex produces a visible inline error.
- ⌘, → SettingsScene window opens with all the existing knob sections.

Stop the sample (`⌘Q`).

- [ ] **Step 3: Update `NEXT.md`**

In `NEXT.md`:

- In A.1 — strike through "Workspace search" with `~~...~~` and add a short note pointing at this spec + plan.
- In A.1 — strike through "File tree / workspace browser" similarly.
- In A.1 — note that `EditorSidebarShell` is now consumed for the third time (`WorkspaceSidebar`).
- In A.3 #8 — mark complete (SettingsSidebar removed; SettingsScene is the only home).

- [ ] **Step 4: Commit the NEXT.md update**

```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
NEXT.md: mark A.1 workspace search/tree and A.3 #8 SettingsScene done

Spec: docs/superpowers/specs/2026-05-14-workspace-surface-design.md
Plan: docs/superpowers/plans/2026-05-14-workspace-surface.md

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review

**Spec coverage:**

| Spec requirement | Task |
|---|---|
| Public-promote workspace types | Task 1 |
| `EditorController.selectRange(_:scroll:)` | Task 2 |
| `WorkspaceIgnoreRules` (built-in defaults) | Task 3 |
| `WorkspacePicker` helper | Task 4 |
| `WorkspaceModel` (`@Observable` tree + watching) | Task 5 |
| `ProjectSearchModel` (`@Observable` adapter + index) | Task 6 |
| `selectMatch(_:)` sample helper | Task 7 |
| `WorkspaceSidebar` host | Task 8 |
| `FilePanelView` | Task 9 |
| `ProjectSearchPanelView` (incl. status, debounce, three controls) | Task 10 |
| `AppState` wiring | Task 11 |
| Open Folder… command (⌘O) | Task 12 |
| `WindowBody` left-rail swap + `settingsVisible` rename | Task 13 |
| Delete `SettingsSidebar.swift` | Task 13 |
| iOS Inspectors copy update | Task 14 |
| Five `WorkspaceSidebar` snapshot baselines | Task 15 |
| Final pipeline + NEXT.md update | Task 16 |

**Placeholder scan:** None found — every step has either runnable commands or complete source.

**Type consistency:**

- `WorkspaceFileNode` / `WorkspaceFileEvent` / `WorkspaceFileTree` / `WorkspaceFileWatching` — same names across Tasks 1, 5, 9, 15.
- `MacOSWorkspaceFileManager(rootURL: URL)` — same init signature in Task 1 and Task 5's factory default.
- `ProjectSearchResult.lineNumber/column` are 1-based, `nsLocation(forLSPLine:character:)` is 0-based — Task 7 documents the subtraction explicitly.
- `EditorController.selectRange(_:scroll:)` defined in Task 2 and consumed in Task 7; signatures match.
- `WorkspaceModel.factory: @MainActor (URL) -> TreeProvider` — same in Task 5 spec and Task 15 snapshot stubs.
- `ProjectSearchModel.Status` cases — same 7 cases referenced by Tasks 6 (model), 10 (panel), and 15 (snapshots).

**Scope check:** Single-PR scope. Two small framework changes; ~7 new sample files; one deletion; three modifications. Pipeline verifiable end-to-end. Snapshot tests provide visual regression guard.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-14-workspace-surface.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
