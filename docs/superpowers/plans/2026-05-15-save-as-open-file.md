# Save-As, Save As…, and Open File… Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship sample-side Save-As (auto-prompt on `⌘S` Untitled), explicit Save As… (`⇧⌘S`), and Open File… (`⇧⌘O`) commands on macOS and iOS, all backed by a shared `DocumentPicker` helper and a new `EditorDocuments.saveAs(to:)` extension.

**Architecture:** All changes land in the `CodeEditorSample` target. No framework changes. A new `DocumentPicker` enum mirrors the existing `WorkspacePicker` pattern (macOS `NSSavePanel` / `NSOpenPanel`; iOS `UIDocumentPickerViewController` via `UIViewControllerRepresentable` shims). `EditorDocuments+SampleExtras.swift` gains a `saveAs(to:)` method with rebind semantics and private security-scoped I/O helpers. `AppState` orchestrates the picker-to-document-to-feedback chain via `requestSave` / `requestSaveAs` / `requestOpenFile`. Spec: `docs/superpowers/specs/2026-05-15-save-as-open-file-design.md`.

**Tech Stack:** Swift 6.3, SwiftUI, AppKit (macOS), UIKit (iOS), Swift Testing.

---

## Task 1: Extract security-scope I/O helpers (pure refactor)

Wraps existing `save(_:)` and `openFile(url:)` writes/reads in private static helpers so iOS's security-scoped URL lifecycle has a single home. Behavior unchanged on macOS; existing tests must still pass.

**Files:**
- Modify: `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift` (current lines 24–61)

- [ ] **Step 1: Open `EditorDocuments+SampleExtras.swift` and add two private static helpers above the `// MARK: - Untitled naming` line**

Add these immediately before line 63 (`// MARK: - Untitled naming`):

```swift
// MARK: - Security-scoped I/O helpers

/// Writes `text` to `url`. On iOS, brackets the write in
/// `startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`
/// so URLs returned by `UIDocumentPickerViewController` (or sandbox URLs from
/// any other picker) are written correctly. macOS compiles the bracket out.
private static func writeWithSecurityScope(text: String, to url: URL) throws {
    #if !canImport(AppKit)
    let acquired = url.startAccessingSecurityScopedResource()
    defer { if acquired { url.stopAccessingSecurityScopedResource() } }
    #endif
    try text.write(to: url, atomically: true, encoding: .utf8)
}

/// Reads UTF-8 text from `url`. iOS bracket-pairs the read with
/// security-scope access; macOS compiles the bracket out.
private static func readWithSecurityScope(_ url: URL) throws -> String {
    #if !canImport(AppKit)
    let acquired = url.startAccessingSecurityScopedResource()
    defer { if acquired { url.stopAccessingSecurityScopedResource() } }
    #endif
    return try String(contentsOf: url, encoding: .utf8)
}
```

- [ ] **Step 2: Replace the inline `String(contentsOf:)` read in `openFile(url:)` with the helper**

In the existing `openFile(url:)` (around line 29), change:

```swift
guard let text = try? String(contentsOf: url, encoding: .utf8) else {
    return nil
}
```

to:

```swift
guard let text = try? Self.readWithSecurityScope(url) else {
    return nil
}
```

- [ ] **Step 3: Replace the inline write in `save(_:)` with the helper**

In the existing `save(_:)` (around line 54), change:

```swift
do {
    try document.text.write(to: url, atomically: true, encoding: .utf8)
    markClean(target)
    return .saved(url: url)
} catch {
    return .failed(error: error)
}
```

to:

```swift
do {
    try Self.writeWithSecurityScope(text: document.text, to: url)
    markClean(target)
    return .saved(url: url)
} catch {
    return .failed(error: error)
}
```

- [ ] **Step 4: Build and run the existing tests to confirm the refactor is behavior-preserving**

Run: `swift build --target CodeEditorSample && swift test --filter EditorDocumentsOpenFileTests`
Expected: All 5 tests in `EditorDocumentsOpenFileTests` pass — `testOpenFileCreatesDocumentAndInfersLanguage`, `testOpenFileForExistingURLReactivates`, `testSaveWritesBytesAndClearsDirty`, `testSaveUntitledTabReturnsUntitled`, `testNewTabIncrementsUntitledCounter`.

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift
git commit -m "$(cat <<'EOF'
Sample: extract writeWithSecurityScope / readWithSecurityScope helpers

Pure refactor of EditorDocuments+SampleExtras I/O. macOS behavior
unchanged. iOS now bracket-pairs picker-returned URLs with
startAccessingSecurityScopedResource / stopAccessingSecurityScopedResource
at a single site so saveAs(to:) (next task) gets the same handling for
free.
EOF
)"
```

---

## Task 2: TDD `EditorDocuments.saveAs(to:)`

Adds the rebind-semantics Save-As primitive: write content, update `url` / `name` / `language` / `isDirty`. Tests written first; implementation added after they fail for the right reason.

**Files:**
- Create: `Tests/CodeEditorSampleTests/EditorDocumentsSaveAsTests.swift`
- Modify: `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift` (add method)

- [ ] **Step 1: Create the failing test file**

Create `Tests/CodeEditorSampleTests/EditorDocumentsSaveAsTests.swift`:

```swift
#if canImport(AppKit)
import CodeEditorPlugin
@testable import CodeEditorSample
import Foundation
import Testing

/// Coverage for the sample-only `EditorDocuments.saveAs(to:)` Save-As
/// primitive. Picker presentation and AppState orchestration are covered
/// by manual smoke; this suite verifies the rebind / write logic.
@MainActor
@Suite("EditorDocuments saveAs")
struct EditorDocumentsSaveAsTests {
    @Test("saveAs writes the document text to the chosen URL")
    func saveAsWritesContent() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()                    // Untitled-1.swift, .swift
        documents.textBinding(for: id).wrappedValue = "let saved = true\n"

        let destination = uniqueTempURL(extension: "swift")
        defer { try? FileManager.default.removeItem(at: destination) }

        let outcome = documents.saveAs(to: destination, id)

        guard case .saved(let url) = outcome else {
            Issue.record("expected .saved, got \(outcome)")
            return
        }
        #expect(url == destination)
        let onDisk = try String(contentsOf: destination, encoding: .utf8)
        #expect(onDisk == "let saved = true\n")
    }

    @Test("saveAs rebinds url, name, language, and clears isDirty")
    func saveAsRebindsDocument() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        documents.textBinding(for: id).wrappedValue = "dirty\n"
        #expect(documents.documents.first { $0.id == id }?.isDirty == true)

        let destination = uniqueTempURL(extension: "py")
        defer { try? FileManager.default.removeItem(at: destination) }

        _ = documents.saveAs(to: destination, id)

        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.url == destination)
        #expect(document.name == destination.lastPathComponent)
        #expect(document.language == .python)
        #expect(document.isDirty == false)
    }

    @Test("saveAs detects language from extension — swift")
    func saveAsDetectsSwiftFromExtension() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        let destination = uniqueTempURL(extension: "swift")
        defer { try? FileManager.default.removeItem(at: destination) }

        _ = documents.saveAs(to: destination, id)
        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.language == .swift)
    }

    @Test("saveAs detects language from extension — python")
    func saveAsDetectsPythonFromExtension() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        let destination = uniqueTempURL(extension: "py")
        defer { try? FileManager.default.removeItem(at: destination) }

        _ = documents.saveAs(to: destination, id)
        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.language == .python)
    }

    @Test("saveAs falls back to plainText for unknown extensions")
    func saveAsFallsBackToPlainText() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        let destination = uniqueTempURL(extension: "zzznotalang")
        defer { try? FileManager.default.removeItem(at: destination) }

        _ = documents.saveAs(to: destination, id)
        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.language == .plainText)
    }

    @Test("saveAs returns .noTab when there's no active tab and no explicit id")
    func saveAsWithNoActiveTabReturnsNoTab() {
        let documents = EditorDocuments()
        let destination = uniqueTempURL(extension: "swift")
        defer { try? FileManager.default.removeItem(at: destination) }

        let outcome = documents.saveAs(to: destination)
        if case .noTab = outcome {
            // expected
        } else {
            Issue.record("expected .noTab, got \(outcome)")
        }
    }

    @Test("saveAs returns .failed and preserves the document on write failure")
    func saveAsFailedWritePreservesDocument() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        let originalName = try #require(documents.documents.first { $0.id == id }?.name)
        let originalLanguage = try #require(documents.documents.first { $0.id == id }?.language)

        // Directory that does not and cannot exist — write must fail.
        let destination = URL(fileURLWithPath: "/this/path/does/not/exist/\(UUID().uuidString).swift")

        let outcome = documents.saveAs(to: destination, id)

        guard case .failed = outcome else {
            Issue.record("expected .failed, got \(outcome)")
            return
        }
        let document = try #require(documents.documents.first { $0.id == id })
        #expect(document.url == nil)
        #expect(document.name == originalName)
        #expect(document.language == originalLanguage)
    }

    @Test("saveAs overwrites an existing file at the destination")
    func saveAsOverwritesExistingFile() throws {
        let documents = EditorDocuments()
        let id = documents.newTab()
        documents.textBinding(for: id).wrappedValue = "new\n"

        let destination = uniqueTempURL(extension: "swift")
        try "old\n".write(to: destination, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: destination) }

        _ = documents.saveAs(to: destination, id)
        let onDisk = try String(contentsOf: destination, encoding: .utf8)
        #expect(onDisk == "new\n")
    }

    // MARK: - Helpers

    private func uniqueTempURL(extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString).\(ext)")
    }
}
#endif
```

- [ ] **Step 2: Run the failing tests**

Run: `swift test --filter EditorDocumentsSaveAsTests`
Expected: Build failure with errors like `value of type 'EditorDocuments' has no member 'saveAs'` — confirms the test is wired correctly and we're about to add the missing method.

- [ ] **Step 3: Implement `saveAs(to:)` in `EditorDocuments+SampleExtras.swift`**

Insert this method immediately after the existing `save(_:)` method (around line 61), inside the `// MARK: - Open / save` section:

```swift
/// Write the document's contents to `url` and rebind the tab to it:
/// updates `url`, renames the tab to the URL's last path component,
/// switches `language` to whatever the new extension implies, and
/// clears `isDirty`. The previous on-disk file (if any) is left
/// untouched. Returns `.noTab` if there is no active document (and
/// no explicit `id` was passed); `.failed(error:)` on write failure.
@discardableResult
func saveAs(to url: URL, _ id: EditorDocument.ID? = nil) -> SaveOutcome {
    let target = id ?? activeID
    guard let target,
          let document = documents.first(where: { $0.id == target }) else {
        return .noTab
    }
    do {
        try Self.writeWithSecurityScope(text: document.text, to: url)
        let detected = LanguageDetectionService().detectLanguage(fromExtension: url.pathExtension)
        update(target) { doc in
            doc.tab.url = url
            doc.tab.name = url.lastPathComponent
            doc.tab.language = detected
            doc.tab.isDirty = false
        }
        return .saved(url: url)
    } catch {
        return .failed(error: error)
    }
}
```

- [ ] **Step 4: Run the tests to verify they all pass**

Run: `swift test --filter EditorDocumentsSaveAsTests`
Expected: All 8 tests pass:
- `saveAsWritesContent`
- `saveAsRebindsDocument`
- `saveAsDetectsSwiftFromExtension`
- `saveAsDetectsPythonFromExtension`
- `saveAsFallsBackToPlainText`
- `saveAsWithNoActiveTabReturnsNoTab`
- `saveAsFailedWritePreservesDocument`
- `saveAsOverwritesExistingFile`

- [ ] **Step 5: Run lint**

Run: `swiftlint --fix && swiftlint`
Expected: No violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift Tests/CodeEditorSampleTests/EditorDocumentsSaveAsTests.swift
git commit -m "$(cat <<'EOF'
Sample: EditorDocuments.saveAs(to:) with rebind semantics

Adds the Save-As primitive: writes the active (or specified) document's
text to the given URL, then rebinds the tab — url, name, language, and
isDirty all update. Language is re-detected from the new extension;
unknown extensions fall back to .plainText. Failure returns .failed and
leaves the document untouched.

Backed by the writeWithSecurityScope helper from the previous commit so
iOS picker URLs work without further wiring.
EOF
)"
```

---

## Task 3: `DocumentPicker` (macOS branch — NSSavePanel / NSOpenPanel)

Mirrors the existing `WorkspacePicker` pattern: synchronous modal wrappers with completion-handler callbacks.

**Files:**
- Create: `Sources/CodeEditorSample/Documents/DocumentPicker.swift`

- [ ] **Step 1: Create the macOS branch of the file**

Create `Sources/CodeEditorSample/Documents/DocumentPicker.swift` with **only** the macOS branch for now — the iOS branch lands in Task 4:

```swift
#if canImport(AppKit)
import AppKit
import Foundation

/// macOS NSSavePanel / NSOpenPanel wrappers used by the sample's
/// Save-As, Save As…, and Open File… commands. Mirrors the existing
/// `WorkspacePicker` shape (synchronous modal, completion-handler
/// callback). iOS branch lives in the same file behind `#if !canImport(AppKit)`.
enum DocumentPicker {
    /// Presents `NSSavePanel` configured for a single-file save. Invokes
    /// `onChoose` with the picked URL on confirm; invokes nothing on cancel.
    @MainActor
    static func save(
        suggestedName: String,
        defaultDirectory: URL? = nil,
        onChoose: @escaping (URL) -> Void
    ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        if let defaultDirectory {
            panel.directoryURL = defaultDirectory
        }
        if panel.runModal() == .OK, let url = panel.url {
            onChoose(url)
        }
    }

    /// Presents `NSOpenPanel` configured to pick exactly one file (no
    /// directories, no multi-select). Allowed content types are not
    /// restricted — a code editor accepts any extension.
    @MainActor
    static func openFile(
        defaultDirectory: URL? = nil,
        onChoose: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let defaultDirectory {
            panel.directoryURL = defaultDirectory
        }
        if panel.runModal() == .OK, let url = panel.url {
            onChoose(url)
        }
    }
}
#endif
```

- [ ] **Step 2: Build to confirm compilation**

Run: `swift build --target CodeEditorSample`
Expected: Builds cleanly. Lint should also pass — run `swiftlint --fix && swiftlint` if you like.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorSample/Documents/DocumentPicker.swift
git commit -m "$(cat <<'EOF'
Sample: DocumentPicker macOS branch (NSSavePanel / NSOpenPanel)

Mirrors WorkspacePicker. Two static @MainActor methods: save(...) for
Save-As and openFile(...) for Open File…. Synchronous modal, completion-
handler callback on confirm, silent on cancel. No content-type
restriction — a code editor accepts any extension. iOS branch lands in
the next commit.
EOF
)"
```

---

## Task 4: `DocumentPicker` iOS branch — `SaveSheetState`, `ExportDocumentSheet`, `ImportDocumentSheet`

Adds the `UIViewControllerRepresentable` shims around `UIDocumentPickerViewController` plus the `SaveSheetState` payload that drives the export sheet's `.sheet(item:)` binding.

**Files:**
- Modify: `Sources/CodeEditorSample/Documents/DocumentPicker.swift` (append iOS branch)

- [ ] **Step 1: Append the iOS branch to `DocumentPicker.swift`**

After the closing `#endif` of the macOS branch, append:

```swift

#if !canImport(AppKit)
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// State payload that drives the iOS Save-As sheet from `IOSRootView`.
/// `Identifiable` so it can power `.sheet(item:)`; nil dismisses.
struct SaveSheetState: Identifiable {
    let id = UUID()
    let temporaryURL: URL
    let suggestedName: String
}

/// SwiftUI wrapper around `UIDocumentPickerViewController(forExporting:asCopy:)`
/// for Save-As on iOS. The picker moves the temp file to the user's chosen
/// destination (asCopy: false) and returns the destination URL via delegate.
struct ExportDocumentSheet: UIViewControllerRepresentable {
    let temporaryURL: URL
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forExporting: [temporaryURL],
            asCopy: false
        )
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

/// SwiftUI wrapper around `UIDocumentPickerViewController(forOpeningContentTypes:)`
/// for Open File… on iOS. Accepts plain text, source code, and a `.data`
/// fallback so the user can pick any extension.
struct ImportDocumentSheet: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.plainText, .sourceCode, .data]
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }

        func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}
#endif
```

- [ ] **Step 2: Build for iOS Simulator to confirm the iOS branch compiles**

Run: `xcrun simctl list devices | head` to find an available simulator (note one, e.g. "iPhone 15"), then:

`swift build --target CodeEditorSample -Xswiftc "-sdk" -Xswiftc "$(xcrun --sdk iphonesimulator --show-sdk-path)" -Xswiftc "-target" -Xswiftc "arm64-apple-ios18.0-simulator"`

If that compound `swift build` recipe doesn't apply in this checkout (the package may not be configured for direct iOS SPM builds), fall back to: open the package in Xcode (`open Package.swift`) and switch the active scheme to an iOS Simulator destination. Verify `Sources/CodeEditorSample/Documents/DocumentPicker.swift` compiles in that destination — the iOS branch is `#if !canImport(AppKit)` so it only compiles for non-AppKit targets.

Expected: Clean compile on iOS. macOS build (default `swift build`) skips the iOS branch entirely.

- [ ] **Step 3: Run lint**

Run: `swiftlint --fix && swiftlint`
Expected: No violations.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/Documents/DocumentPicker.swift
git commit -m "$(cat <<'EOF'
Sample: DocumentPicker iOS branch (UIDocumentPickerViewController shims)

SaveSheetState (Identifiable payload for .sheet(item:)),
ExportDocumentSheet (forExporting:asCopy: false — moves temp file to
destination), and ImportDocumentSheet (forOpeningContentTypes:
[.plainText, .sourceCode, .data]). Both shims forward delegate
callbacks to onPick / onCancel closures supplied by the host view.
EOF
)"
```

---

## Task 5: `AppState` request helpers (macOS branch)

Adds `requestSave`, `requestSaveAs`, `requestOpenFile` orchestration helpers. macOS branch wires straight into `DocumentPicker`; the iOS branch follows in Task 6.

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift` (append after `handleSaveOutcome` around line 218)

- [ ] **Step 1: Add the helpers to `AppState`**

Insert this block immediately after the closing brace of `handleSaveOutcome` (current line 218) and **before** the final closing brace of the `AppState` class (line 219):

```swift
// MARK: - Save / Open command orchestration

/// `⌘S` command handler. Tries `documents.save()`; if the active tab
/// has no URL, transparently chains to `requestSaveAs()` so the user
/// gets the save panel instead of a silent log entry. All other
/// outcomes route to `handleSaveOutcome`.
@MainActor
func requestSave() {
    let outcome = documents.save()
    if case .untitled = outcome {
        requestSaveAs()
    } else {
        handleSaveOutcome(outcome)
    }
}

/// `⇧⌘S` command handler. Presents the platform save panel, then
/// rebinds the active document to the chosen URL via
/// `EditorDocuments.saveAs(to:)`.
@MainActor
func requestSaveAs() {
    guard let active = documents.active else {
        handleSaveOutcome(.noTab)
        return
    }
    #if canImport(AppKit)
    DocumentPicker.save(
        suggestedName: active.name,
        defaultDirectory: workspaceRoot ?? active.url?.deletingLastPathComponent()
    ) { [self] url in
        let outcome = documents.saveAs(to: url)
        handleSaveOutcome(outcome)
    }
    #else
    pendingSaveAs = prepareSaveAsTemporaryFile(for: active)
    #endif
}

/// `⇧⌘O` command handler. Presents the platform open panel and feeds
/// the picked URL into `EditorDocuments.openFile(url:)`. If the URL is
/// already open, the existing tab is activated.
@MainActor
func requestOpenFile() {
    #if canImport(AppKit)
    DocumentPicker.openFile(defaultDirectory: workspaceRoot) { [self] url in
        documents.openFile(url: url)
    }
    #else
    pendingOpenFile = true
    #endif
}
```

The `#else` branches reference `pendingSaveAs`, `pendingOpenFile`, and `prepareSaveAsTemporaryFile(for:)` — those iOS-only members are added in Task 6.

- [ ] **Step 2: Build macOS to confirm the AppKit branch compiles**

Run: `swift build --target CodeEditorSample`
Expected: Clean build. (iOS won't build yet — the `#else` branch references symbols added in Task 6. Don't build for iOS until Task 6 lands.)

- [ ] **Step 3: Run lint**

Run: `swiftlint --fix && swiftlint`
Expected: No violations.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/App/AppState.swift
git commit -m "$(cat <<'EOF'
Sample: AppState.requestSave / requestSaveAs / requestOpenFile (macOS)

Orchestration helpers used by ⌘S, ⇧⌘S, and ⇧⌘O command buttons.
requestSave chains to requestSaveAs on .untitled so Untitled tabs get
the save panel instead of a silent warning. macOS branch wires
DocumentPicker straight through; iOS branch references pendingSaveAs /
pendingOpenFile / prepareSaveAsTemporaryFile which land in the next
commit.
EOF
)"
```

---

## Task 6: `AppState` iOS sheet state + `prepareSaveAsTemporaryFile` + `finalizeSaveAs`

Adds the iOS-only state and helpers the `#else` branches of Task 5 depend on. After this task, both platforms build.

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift` (append a new iOS-only block)

- [ ] **Step 1: Append the iOS-only block at the end of the `AppState` class body**

Add this block immediately after the closing brace of `requestOpenFile` (added in Task 5) and **before** the final closing brace of the `AppState` class:

```swift
// MARK: - iOS save/open sheet state

#if !canImport(AppKit)
/// State driving the iOS Save-As sheet. `IOSRootView` binds
/// `.sheet(item: $appState.pendingSaveAs)`; setting nil dismisses.
var pendingSaveAs: SaveSheetState?

/// State driving the iOS Open File… sheet. `IOSRootView` binds
/// `.sheet(isPresented: $appState.pendingOpenFile)`.
var pendingOpenFile: Bool = false

/// Writes the active document's text to `NSTemporaryDirectory()/<name>`
/// so `UIDocumentPickerViewController(forExporting:asCopy: false)` has
/// a file to move to the user's chosen destination. Returns the
/// `SaveSheetState` that drives the export sheet, or nil if the temp
/// write fails (failure is reported through `handleSaveOutcome`).
@MainActor
private func prepareSaveAsTemporaryFile(for active: EditorDocument) -> SaveSheetState? {
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(active.name)
    do {
        try active.text.write(to: tempURL, atomically: true, encoding: .utf8)
        return SaveSheetState(temporaryURL: tempURL, suggestedName: active.name)
    } catch {
        handleSaveOutcome(.failed(error: error))
        return nil
    }
}

/// Invoked by `ExportDocumentSheet.onPick` after the user confirms the
/// iOS document picker. Performs the rebind via `EditorDocuments.saveAs`
/// and routes the outcome through the standard feedback channel.
@MainActor
func finalizeSaveAs(to url: URL) {
    let outcome = documents.saveAs(to: url)
    handleSaveOutcome(outcome)
}
#endif
```

- [ ] **Step 2: Build for iOS Simulator destination**

If your environment supports it: open the package in Xcode (`open Package.swift`) and build the `CodeEditorSample` scheme against an iOS Simulator destination. Confirm the iOS branch (everything inside `#if !canImport(AppKit)`) compiles.

If you can't open Xcode here, at minimum re-run `swift build --target CodeEditorSample` (macOS) and trust the `#if`-gating — the iOS code referenced by `requestSaveAs` / `requestOpenFile` `#else` branches now exists in the file.

Expected: Clean compile on both platforms.

- [ ] **Step 3: Run lint**

Run: `swiftlint --fix && swiftlint`
Expected: No violations.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorSample/App/AppState.swift
git commit -m "$(cat <<'EOF'
Sample: AppState iOS sheet state + finalizeSaveAs

Adds pendingSaveAs (SaveSheetState? for .sheet(item:)),
pendingOpenFile (Bool for .sheet(isPresented:)),
prepareSaveAsTemporaryFile(for:) (writes a temp copy that
UIDocumentPickerViewController(forExporting:asCopy: false) moves to
the destination), and finalizeSaveAs(to:) (rebinds via
EditorDocuments.saveAs and reports through handleSaveOutcome).

Closes the iOS branch of the Save-As/Open-File flows. Both platforms
now compile.
EOF
)"
```

---

## Task 7: Wire macOS commands in `CodeEditorSampleApp.swift`

Updates the existing `CommandGroup(after: .newItem)` and `CommandGroup(after: .textEditing)` blocks: Save now calls `requestSave`, Save As… / Open File… are added, and Go to Symbol… moves from `⇧⌘O` to `⌃⌘O` to free `⇧⌘O` for Open File….

**Files:**
- Modify: `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift` (lines 24–81)

- [ ] **Step 1: Replace the Save button block (current lines 49–56) with the new Save + Save As… block**

Find:

```swift
// ⌘S — save the active tab back to its on-disk URL.
// `Untitled-*` tabs have no URL and currently fall through to
// a logger message (Save-As is out of scope for the demo).
Button("Save") {
    let outcome = appState.documents.save()
    appState.handleSaveOutcome(outcome)
}
.keyboardShortcut("s", modifiers: .command)
```

Replace with:

```swift
// ⌘S — save the active tab back to its on-disk URL. On Untitled
// tabs (no URL), requestSave transparently chains to requestSaveAs
// so the user sees the NSSavePanel instead of a silent log entry.
Button("Save") {
    appState.requestSave()
}
.keyboardShortcut("s", modifiers: .command)

// ⇧⌘S — explicit Save As…. Always presents NSSavePanel; on confirm
// the active document rebinds (url, name, language, isDirty all
// update). The previous on-disk file (if any) is left untouched.
Button("Save As…") {
    appState.requestSaveAs()
}
.keyboardShortcut("s", modifiers: [.command, .shift])
```

- [ ] **Step 2: Add the Open File… button after Open Folder…**

Find the existing Open Folder… block (current lines 35–40):

```swift
Button("Open Folder…") {
    WorkspacePicker.choose(currentRoot: appState.workspaceRoot) {
        appState.workspaceRoot = $0
    }
}
.keyboardShortcut("o", modifiers: .command)
```

Immediately after it (and before "Close Tab"), add:

```swift
Button("Open File…") {
    appState.requestOpenFile()
}
.keyboardShortcut("o", modifiers: [.command, .shift])
```

- [ ] **Step 3: Move Go to Symbol… from `⇧⌘O` to `⌃⌘O`**

Find (current lines 70–74):

```swift
Button("Go to Symbol…") {
    appState.editorController.refreshSymbols()
    appState.gotoSymbolSheetVisible = true
}
.keyboardShortcut("o", modifiers: [.command, .shift])
```

Replace the modifiers with `[.command, .control]`:

```swift
Button("Go to Symbol…") {
    appState.editorController.refreshSymbols()
    appState.gotoSymbolSheetVisible = true
}
.keyboardShortcut("o", modifiers: [.command, .control])
```

- [ ] **Step 4: Build to confirm the command block compiles**

Run: `swift build --target CodeEditorSample`
Expected: Clean build.

- [ ] **Step 5: Run lint**

Run: `swiftlint --fix && swiftlint`
Expected: No violations.

- [ ] **Step 6: Run the sample and smoke-test the new shortcuts**

Run: `swift run CodeEditorSample`

Verify in the running app:
- `⌘S` on a dirty Untitled tab → `NSSavePanel` appears with the tab's name suggested.
- `⌘S` on a tab opened from disk → writes silently (no panel).
- `⇧⌘S` on any tab → `NSSavePanel` appears.
- `⇧⌘O` → `NSOpenPanel` for files appears. Picking a file opens it as a new tab.
- `⌃⌘O` → Go to Symbol… sheet appears.
- `⌘O` → still Open Folder… (workspace picker).

Quit the sample. If any of the above fail, fix before committing.

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorSample/App/CodeEditorSampleApp.swift
git commit -m "$(cat <<'EOF'
Sample: wire ⌘S / ⇧⌘S / ⇧⌘O commands on macOS

Save button now calls requestSave (chains to Save-As on Untitled).
Save As… (⇧⌘S) and Open File… (⇧⌘O) added. Go to Symbol… moves from
⇧⌘O to ⌃⌘O to free the chord for Open File….
EOF
)"
```

---

## Task 8: Wire iOS toolbar Menu + sheet bindings in `IOSRootView.swift`

Replaces the toolbar's single `+ New Tab` button with a `Menu` containing Save, Save As…, New Tab, and Open File…. Adds `.sheet(item:)` and `.sheet(isPresented:)` bindings driven by `AppState.pendingSaveAs` / `AppState.pendingOpenFile`.

**Files:**
- Modify: `Sources/CodeEditorSample/iOS/IOSRootView.swift`

- [ ] **Step 1: Add sheet bindings to the root `NavigationSplitView`**

Find the `var body: some View {` block (current lines 17–27):

```swift
var body: some View {
    NavigationSplitView {
        sidebar
    } detail: {
        detail(for: selectedSection)
            .navigationTitle(title(for: selectedSection))
            .toolbar { toolbar(documents: appState.documents) }
    }
    .codeTheme(appState.theme)
    .preferredColorScheme(appState.theme.appearance == .dark ? .dark : .light)
}
```

Replace with:

```swift
var body: some View {
    NavigationSplitView {
        sidebar
    } detail: {
        detail(for: selectedSection)
            .navigationTitle(title(for: selectedSection))
            .toolbar { toolbar(documents: appState.documents) }
    }
    .codeTheme(appState.theme)
    .preferredColorScheme(appState.theme.appearance == .dark ? .dark : .light)
    .sheet(item: $appState.pendingSaveAs) { state in
        ExportDocumentSheet(
            temporaryURL: state.temporaryURL,
            onPick: { url in
                appState.finalizeSaveAs(to: url)
                appState.pendingSaveAs = nil
            },
            onCancel: { appState.pendingSaveAs = nil }
        )
    }
    .sheet(isPresented: $appState.pendingOpenFile) {
        ImportDocumentSheet(
            onPick: { url in
                appState.documents.openFile(url: url)
                appState.pendingOpenFile = false
            },
            onCancel: { appState.pendingOpenFile = false }
        )
    }
}
```

`$appState.pendingSaveAs` and `$appState.pendingOpenFile` work because `AppState` is already `@Observable` and `IOSRootView` declares `@Bindable var appState: AppState`.

- [ ] **Step 2: Replace the toolbar function body with a `Menu`**

Find the existing `toolbar(documents:)` (current lines 208–217):

```swift
@ToolbarContentBuilder
private func toolbar(documents: EditorDocuments) -> some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
        Button {
            documents.newTab()
        } label: {
            Label("New Tab", systemImage: "plus")
        }
    }
}
```

Replace with:

```swift
@ToolbarContentBuilder
private func toolbar(documents: EditorDocuments) -> some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button("Save", action: appState.requestSave)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.documents.active == nil)
            Button("Save As…", action: appState.requestSaveAs)
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.documents.active == nil)
            Divider()
            Button("New Tab") { documents.newTab() }
                .keyboardShortcut("t", modifiers: .command)
            Button("Open File…", action: appState.requestOpenFile)
                .keyboardShortcut("o", modifiers: [.command, .shift])
        } label: {
            Label("File", systemImage: "doc")
        }
    }
}
```

- [ ] **Step 3: Build for iOS to confirm everything compiles**

If your environment supports Xcode: open the package and build for an iOS Simulator destination.

If not, at minimum verify the macOS build is still clean: `swift build --target CodeEditorSample` (the changes in `IOSRootView.swift` are inside `#if !canImport(AppKit)` and won't affect macOS, but a clean build is a sanity check).

Expected: Clean compile.

- [ ] **Step 4: Run lint**

Run: `swiftlint --fix && swiftlint`
Expected: No violations.

- [ ] **Step 5: iOS smoke test (if a simulator is available)**

Launch the sample on an iOS Simulator. Verify:
- Toolbar shows a "File" menu (doc icon) instead of a bare `+` button.
- Tapping the menu reveals: Save, Save As…, New Tab, Open File…
- "Save As…" presents the system Files picker; choosing a destination rebinds the tab (name updates in the title bar).
- "Open File…" presents the Files picker; choosing a file opens it as a new tab.
- With an iPad + hardware keyboard: `⌘S`, `⇧⌘S`, `⌘T`, `⇧⌘O` all fire the corresponding actions.

If no simulator is available, mark Step 5 with a note in the commit body that iOS smoke is pending.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample/iOS/IOSRootView.swift
git commit -m "$(cat <<'EOF'
Sample iOS: File toolbar menu + Save-As / Open File sheets

Replaces the bare + New Tab toolbar button with a File menu containing
Save, Save As…, New Tab, and Open File…. Adds .sheet(item:) and
.sheet(isPresented:) bindings driven by AppState.pendingSaveAs /
AppState.pendingOpenFile so the export and import document pickers
present from a single site. Hardware-keyboard shortcuts on iPad reach
the same chords as macOS.
EOF
)"
```

---

## Task 9: Full quality pipeline + NEXT.md update

Final verification: lint clean, test suite green, manual smoke checklist run, NEXT.md marked done for the closed items.

**Files:**
- Modify: `NEXT.md` (lines 21 and 90–91)

- [ ] **Step 1: Run the full quality pipeline**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`

Expected:
- Build succeeds.
- Lint reports no violations.
- Test suite passes. New `EditorDocumentsSaveAsTests` shows 8 passing tests. The pre-existing flakes called out in NEXT.md section D (`LineGeometryStoreBenchmarkTests.testFuzzIncrementalEditCorrectness`, `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`, `SyntaxHighlightingTests.testRegexHighlighterLanguageEnumMapping`, `SyntaxHighlightingTests.testRegexHighlighterCustomLanguageProducesTokens`, `EditorStatusBarSnapshots/*`, `PerformanceObservationTests.restartAfterStopResumesRefreshTicks`, `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor`) may still fail — they are pre-existing and not introduced by this work. Re-run any flake in isolation to confirm: `swift test --filter <name>`.

If anything new fails (anything not on the NEXT.md section D list), fix it before continuing.

- [ ] **Step 2: Manual smoke checklist (macOS)**

Launch: `swift run CodeEditorSample`

Walk through:
- [ ] `⌘S` on a dirty Untitled tab → `NSSavePanel` appears, default name = tab name (e.g. `Untitled-1.swift`).
- [ ] `⌘S` on a tab opened from disk (use `⇧⌘O` first) → writes silently, no panel.
- [ ] `⇧⌘S` on any tab → `NSSavePanel` appears; on confirm the tab renames and language updates from the new extension.
- [ ] `⇧⌘O` → `NSOpenPanel` for files → opens file as a new tab; opening the same URL twice reactivates the first tab (no duplicate).
- [ ] `⌃⌘O` → Go to Symbol… sheet appears.
- [ ] `⌘O` → still Open Folder… (workspace picker).
- [ ] Cancel each panel — no log spam, no crashes, tab state preserved.

- [ ] **Step 3: Manual smoke checklist (iOS, if simulator available)**

Launch the sample on an iOS Simulator (or iPad with hardware keyboard for shortcut verification).

- [ ] Toolbar shows "File" menu, not a bare `+`.
- [ ] Save As… presents the Files picker.
- [ ] Open File… presents the Files picker.
- [ ] iPad hardware keyboard: `⌘S`, `⇧⌘S`, `⌘T`, `⇧⌘O` fire correctly.
- [ ] Saving to iCloud Drive, then re-saving with `⌘S` succeeds (security scope re-acquired per write).

If no iOS simulator is available, note this in the final commit.

- [ ] **Step 4: Update `NEXT.md`**

Two edits.

Edit 1 — strike through the Save-As item under A.1 (around line 21). Find:

```markdown
**Save-As for `Untitled-*` tabs.** `⌘S` writes through `EditorDocuments.save(_:)` with `SaveOutcome` routing, but Save-As for untitled tabs was deliberately deferred. Needs an `NSSavePanel` flow on macOS and an iOS document-picker variant. `⌘O` is still a no-op.
```

Replace with:

```markdown
~~**Save-As for `Untitled-*` tabs.**~~ — done. `⌘S` on Untitled tabs now chains through `AppState.requestSave` → `requestSaveAs` → `DocumentPicker.save` (macOS `NSSavePanel`; iOS `UIDocumentPickerViewController` in export mode). Explicit Save As… (`⇧⌘S`) and Open File… (`⇧⌘O`) added; Go to Symbol… moved to `⌃⌘O`. `EditorDocuments.saveAs(to:)` rebinds the tab (url, name, language, isDirty). Spec: `docs/superpowers/specs/2026-05-15-save-as-open-file-design.md`; plan: `docs/superpowers/plans/2026-05-15-save-as-open-file.md`.
```

Edit 2 — strike through B.6 (around lines 90–91). Find:

```markdown
### B.6 Save-As path
Sample-side. `EditorDocuments.save(_:)` covers tabs that already have URLs. Save-As for `Untitled-*` tabs needs an `NSSavePanel` flow on macOS and an iOS document-picker variant. Tracked under A.1 above for the sample side; framework changes (if any) are minimal — `EditorDocuments` already exposes the storage and dirty tracking.
```

Replace with:

```markdown
### B.6 ~~Save-As path~~ — done
Sample-side. Closed alongside the A.1 entry above. Zero framework changes; all I/O lives in `EditorDocuments+SampleExtras.swift` via the new `saveAs(to:)` plus security-scoped read/write helpers.
```

- [ ] **Step 5: Commit the NEXT.md update**

```bash
git add NEXT.md
git commit -m "$(cat <<'EOF'
NEXT.md: mark Save-As / Open File (A.1, B.6) done

Strikes through the A.1 Save-As bullet and B.6 entry. Links to the
spec + plan that landed the feature.
EOF
)"
```

- [ ] **Step 6: Verify the working tree is clean**

Run: `git status`
Expected: `nothing to commit, working tree clean`. The branch is now ahead of `origin/main` by 9 commits (Tasks 1–9, one commit each).

- [ ] **Step 7: Hand back to the user**

Report the commit list (`git log --oneline -10`) and the smoke-checklist outcomes. If iOS smoke was skipped because no simulator was available, say so explicitly so the user can run it themselves before merging.

---

## Self-review summary (filled in during plan authoring)

**Spec coverage check:**
- Goals → Tasks: ⌘S Untitled auto-prompt (Task 5 requestSave, Task 7 wiring); explicit Save As… (Tasks 5, 7); Open File… (Tasks 5, 7); iOS toolbar/menu (Task 8); iOS sheet bindings (Tasks 6, 8); security-scope handling (Task 1); Go to Symbol… relocation (Task 7).
- Non-goals: respected — no framework changes, no bookmark persistence, no banner UI, no recents.
- File layout matches spec.
- `EditorDocuments` API additions: `saveAs(to:)` (Task 2), `writeWithSecurityScope` / `readWithSecurityScope` (Task 1). `SaveOutcome` unchanged.
- UX details: default directory, file-exists, cancel, language rebind, isDirty — all covered.
- Testing: Swift Testing `@Suite` with 8 tests (Task 2). Manual smoke checklist (Task 9).

**Placeholder scan:** No "TBD", "TODO", "implement later", or vague "appropriate error handling" remain.

**Type consistency check:**
- `SaveOutcome.saved(url:)`, `.untitled`, `.noTab`, `.failed(error:)` — consistent throughout.
- `EditorDocuments.saveAs(to:_:)` signature consistent across Task 2 (implementation), Task 5 (AppState helper call site), and Task 6 (`finalizeSaveAs` call site).
- `DocumentPicker.save(suggestedName:defaultDirectory:onChoose:)` and `DocumentPicker.openFile(defaultDirectory:onChoose:)` signatures consistent between Task 3 (definition) and Task 5 (call sites).
- `pendingSaveAs: SaveSheetState?` and `pendingOpenFile: Bool` consistent between Task 6 (definition) and Task 8 (binding) and Task 5 (`#else` writes).
- `prepareSaveAsTemporaryFile(for:)` returns `SaveSheetState?` consistent between Task 6 (definition) and Task 5 (call site).
- `ExportDocumentSheet(temporaryURL:onPick:onCancel:)` and `ImportDocumentSheet(onPick:onCancel:)` consistent between Task 4 (definition) and Task 8 (construction).
