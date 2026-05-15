# Save-As, Save As…, and Open File… — Design

**Status:** Approved, ready for implementation plan.
**Date:** 2026-05-15
**Closes (partial):** NEXT.md A.1 ("Save-As for `Untitled-*` tabs"), B.6 ("Save-As path").

## Problem

`EditorDocuments.save(_:)` writes through to a tab's backing URL and returns a `SaveOutcome`, but tabs minted by `EditorDocuments.newTab()` ("Untitled-N") have no URL. Today, `⌘S` on an Untitled tab falls through to a warning log (`AppState.handleSaveOutcome(.untitled)`) and no UI affordance fires. There is no explicit `Save As…` command on any platform and no `Open File…` command (the sample has only `Open Folder…` on `⌘O`, which selects a workspace root). iOS exposes neither save nor open beyond the toolbar's `+ New Tab`.

A consumer reading the sample sees the framework's I/O primitives (`EditorDocuments.save`, `EditorDocuments.openFile`, `markClean`, `isDirty`) but cannot see how a host wires the user-facing flows that actually exercise them — the most common reason a developer would adopt a code editor framework.

This spec adds three sample-side commands — Save-As (auto-triggered when `⌘S` fires on an Untitled tab), explicit Save As… (`⇧⌘S` on macOS / menu on iOS), and Open File… (`⇧⌘O` on macOS / menu on iOS) — backed by a shared `DocumentPicker` helper. No framework changes.

## Goals

- `⌘S` on an Untitled tab pops a save panel (macOS `NSSavePanel`, iOS `UIDocumentPickerViewController` in export mode) with `active.name` as the suggested filename. On confirm, the document rebinds to the new URL: `url`, `name`, and `language` are updated; `isDirty` clears.
- Explicit Save As… command on any tab. Rebinds in the same way. Standard Mac doc-app behavior.
- Open File… command. macOS `NSOpenPanel`, iOS `UIDocumentPickerViewController` in import mode. Calls `EditorDocuments.openFile(url:)`, which already activates an existing tab if one is open for the URL.
- iOS toolbar/menu surfaces all three commands, with hardware-keyboard shortcuts so iPad with a Magic Keyboard reaches them at the same chords as macOS.
- iOS security-scoped URL lifecycle (`startAccessingSecurityScopedResource` / `stopAccessingSecurityScopedResource`) wrapped at the I/O layer in `EditorDocuments+SampleExtras` so callers don't think about it.
- Go to Symbol… moves from `⇧⌘O` to `⌃⌘O` to free `⇧⌘O` for Open File….

## Non-goals

- Framework changes. `EditorDocuments` stays I/O-free; all save/open helpers remain in `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift` exactly as the existing pattern.
- Cross-launch persistence of iOS-picked URLs. Security-scoped bookmark data (`URL.bookmarkData(options: .minimalBookmark)`) is out of scope. If the user relaunches the app, the rebound Untitled tab is gone and the file can be re-opened via Open File….
- Restricting macOS save/open content types. A code editor accepts any extension. `NSSavePanel.allowedContentTypes` is not set; `NSOpenPanel` is also unrestricted.
- Custom "Replace existing file?" confirmation. `NSSavePanel` and the iOS export picker both show system-provided conflict UI; we do not add our own.
- Merge-stale-buffer flow when Save-As targets a URL already open in another tab. The rebind succeeds; the other tab keeps its (now stale) in-memory text. Documented as a known limitation.
- Banner / toast UI for save errors. `handleSaveOutcome(.failed(error))` keeps its existing `CrossPlatformLogger.error(...)` behavior. A future UI pass can hook a banner at this site without changes to the save/open logic.
- iOS `Open Folder…`. Workspace browsing remains macOS-only per the prior workspace-surface spec.
- Recent files / `NSDocumentController` integration.
- Auto-save / restore.

## Approach

All file I/O remains in the sample's `EditorDocuments+SampleExtras.swift` (`save`, `openFile`, new `saveAs(to:)`). A new sample-only `DocumentPicker` enum mirrors the shape of the existing `WorkspacePicker`:

- macOS: `NSSavePanel.runModal()` / `NSOpenPanel.runModal()`, synchronous, completion-handler style.
- iOS: presents `UIDocumentPickerViewController` via two `UIViewControllerRepresentable` shims (`ExportDocumentSheet`, `ImportDocumentSheet`) hosted by SwiftUI `.sheet` flags on `IOSRootView`.

`AppState` gains three `@MainActor` request helpers — `requestSave()`, `requestSaveAs()`, `requestOpenFile()` — that orchestrate the picker → `EditorDocuments` → `handleSaveOutcome` chain. macOS commands and iOS toolbar buttons both invoke these helpers; the picker presentation differs per platform but the orchestration is identical.

Security-scope handling is folded into the sample's `EditorDocuments` extension via a private `writeWithSecurityScope(text:to:)` (and a matching read helper used by `openFile`). On macOS the helper is a thin wrapper around `String.write(to:)`; on iOS it brackets the call in `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()` so any URL — whether sandbox-local or returned by the document picker — is handled uniformly.

## File layout

```
Sources/CodeEditorSample/Documents/
├── DocumentPicker.swift                              NEW. Static enum: save / openFile.
│                                                     macOS: NSSavePanel / NSOpenPanel.
│                                                     iOS: ExportDocumentSheet, ImportDocumentSheet
│                                                     (UIViewControllerRepresentable wrappers).
└── EditorDocuments+SampleExtras.swift                EXTEND: saveAs(to:); refactor save/openFile to use
                                                      writeWithSecurityScope / readWithSecurityScope.

Sources/CodeEditorSample/App/
├── AppState.swift                                    + requestSave / requestSaveAs / requestOpenFile;
│                                                     + (iOS) @State holders for sheet presentation can
│                                                       live on IOSRootView instead — see iOS surface.
└── CodeEditorSampleApp.swift                         Save button → appState.requestSave;
                                                      + Save As… (⇧⌘S);
                                                      + Open File… (⇧⌘O);
                                                      Go to Symbol… moves from ⇧⌘O to ⌃⌘O.

Sources/CodeEditorSample/iOS/
└── IOSRootView.swift                                 Toolbar Menu with Save, Save As…, Open File…,
                                                      New Tab. @State for SaveSheetState? and
                                                      openSheetVisible. .sheet presents the
                                                      ExportDocumentSheet / ImportDocumentSheet.
                                                      Hardware-keyboard shortcuts on each Button.

Tests/CodeEditorSampleTests/
└── EditorDocumentsSaveAsTests.swift                  NEW. Swift Testing @Suite.
```

## Architecture

### Shortcut map (final state, macOS)

| Shortcut | Command | Status |
|---|---|---|
| `⌘N` | New (default) | unchanged |
| `⌘T` | New Tab | unchanged |
| `⌘O` | Open Folder… (workspace) | unchanged |
| `⇧⌘O` | **Open File…** | **NEW** |
| `⌘W` | Close Tab | unchanged |
| `⌘S` | Save (auto Save-As on Untitled) | **behavior extended** |
| `⇧⌘S` | **Save As…** | **NEW** |
| `⌃⌘O` | Go to Symbol… | **moved from `⇧⌘O`** |
| `⌘F` | Find / Replace… | unchanged |
| `⌘L` | Go to Line… | unchanged |
| `⇧⌘P` | Command Palette… | unchanged |

### Data flow (Save-As on Untitled, macOS)

```
⌘S menu action
  → AppState.requestSave()
    → EditorDocuments.save() → SaveOutcome
    → if .untitled → AppState.requestSaveAs()
      → DocumentPicker.save(suggestedName: active.name,
                            defaultDirectory: workspaceRoot ?? active.url?.deletingLastPathComponent())
        → NSSavePanel.runModal() → URL? (nil on cancel)
        → on confirm:
          → EditorDocuments.saveAs(to: url) → SaveOutcome
            → writeWithSecurityScope(text:, to: url)
            → update(id) { doc in doc.url = url; doc.name = url.lastPathComponent;
                                  doc.language = detect(url.pathExtension); doc.isDirty = false }
          → AppState.handleSaveOutcome(outcome)
    → else → AppState.handleSaveOutcome(outcome)
```

### Data flow (Save-As on Untitled, iOS)

```
Toolbar Save menu item (⌘S via hardware keyboard)
  → AppState.requestSave()
    → EditorDocuments.save() → SaveOutcome
    → if .untitled → AppState.requestSaveAs()
      → AppState.prepareSaveAsTemporaryFile(for: active)
        → write active.text to NSTemporaryDirectory()/active.name → tempURL
        → AppState.pendingSaveAs = SaveSheetState(temporaryURL:, suggestedName:)
      → IOSRootView .sheet(item: $appState.pendingSaveAs) presents
        ExportDocumentSheet(temporaryURL:, onPick:, onCancel:)
        → UIDocumentPickerViewController(forExporting: [tempURL], asCopy: false)
        → coordinator didPickDocumentsAt urls → onPick(urls.first)
          → AppState.finalizeSaveAs(to: pickedURL)
            → EditorDocuments.saveAs(to: pickedURL) → SaveOutcome
            → AppState.handleSaveOutcome(outcome)
          → AppState.pendingSaveAs = nil  (dismisses sheet)
```

### `EditorDocuments` extension additions

```swift
// EditorDocuments+SampleExtras.swift

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
            doc.url = url
            doc.tab.name = url.lastPathComponent
            doc.tab.language = detected
            doc.tab.isDirty = false
        }
        return .saved(url: url)
    } catch {
        return .failed(error: error)
    }
}

private static func writeWithSecurityScope(text: String, to url: URL) throws {
    #if !canImport(AppKit)
    let acquired = url.startAccessingSecurityScopedResource()
    defer { if acquired { url.stopAccessingSecurityScopedResource() } }
    #endif
    try text.write(to: url, atomically: true, encoding: .utf8)
}

private static func readWithSecurityScope(_ url: URL) throws -> String {
    #if !canImport(AppKit)
    let acquired = url.startAccessingSecurityScopedResource()
    defer { if acquired { url.stopAccessingSecurityScopedResource() } }
    #endif
    return try String(contentsOf: url, encoding: .utf8)
}
```

`save(_:)` and `openFile(url:)` are refactored to call `writeWithSecurityScope` / `readWithSecurityScope` so all I/O on user-picked URLs is uniformly scope-aware. macOS behavior is unchanged.

`SaveOutcome` is **unchanged**. `.untitled` is now logically unreachable from `requestSave()` (which chains to Save-As) but remains valid: direct callers of `documents.save()` still get it, and `handleSaveOutcome(.untitled)` keeps its warning-log branch as a safety net.

### `DocumentPicker` (sample, macOS branch)

```swift
#if canImport(AppKit)
import AppKit

enum DocumentPicker {
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
        if let defaultDirectory { panel.directoryURL = defaultDirectory }
        if panel.runModal() == .OK, let url = panel.url {
            onChoose(url)
        }
    }

    @MainActor
    static func openFile(
        defaultDirectory: URL? = nil,
        onChoose: @escaping (URL) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if let defaultDirectory { panel.directoryURL = defaultDirectory }
        if panel.runModal() == .OK, let url = panel.url {
            onChoose(url)
        }
    }
}
#endif
```

### `DocumentPicker` (sample, iOS branch)

```swift
#if !canImport(AppKit)
import SwiftUI
import UniformTypeIdentifiers

/// State payload that drives the Save-As sheet from IOSRootView.
struct SaveSheetState: Identifiable {
    let id = UUID()
    let temporaryURL: URL
    let suggestedName: String
}

/// UIDocumentPickerViewController wrapper for Save-As.
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

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void
        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
        func documentPickerWasCancelled(_: UIDocumentPickerViewController) { onCancel() }
    }
}

/// UIDocumentPickerViewController wrapper for Open File….
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

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        let onCancel: () -> Void
        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }
        func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
        func documentPickerWasCancelled(_: UIDocumentPickerViewController) { onCancel() }
    }
}
#endif
```

### `AppState` request helpers

```swift
@MainActor
func requestSave() {
    let outcome = documents.save()
    if case .untitled = outcome {
        requestSaveAs()
    } else {
        handleSaveOutcome(outcome)
    }
}

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
    // Write a temp copy then publish the sheet state. IOSRootView
    // binds .sheet(item: $appState.pendingSaveAs) directly.
    pendingSaveAs = prepareSaveAsTemporaryFile(for: active)
    #endif
}

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

#if !canImport(AppKit)
/// Observable state driving the iOS export sheet. IOSRootView binds
/// .sheet(item: $appState.pendingSaveAs); setting this to nil dismisses.
@MainActor var pendingSaveAs: SaveSheetState?

/// Observable flag driving the iOS import sheet. IOSRootView binds
/// .sheet(isPresented: $appState.pendingOpenFile).
@MainActor var pendingOpenFile: Bool = false

/// Writes the active document's text to NSTemporaryDirectory()/<name> and
/// returns a SaveSheetState pointing at the temp URL. Returns nil if the
/// temp write fails (logged via handleSaveOutcome(.failed)). The temp file
/// is moved (not copied) to the user's chosen destination by
/// UIDocumentPickerViewController(forExporting:asCopy: false), so no
/// explicit cleanup is required on the happy path; on cancel the temp
/// file is left in NSTemporaryDirectory(), which the system purges.
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

@MainActor
func finalizeSaveAs(to url: URL) {
    let outcome = documents.saveAs(to: url)
    handleSaveOutcome(outcome)
}
#endif
```

iOS sheet presentation lives on `IOSRootView` because SwiftUI `.sheet` is view-bound; `AppState` exposes the prepare/finalize hooks so `IOSRootView` doesn't reach into `EditorDocuments` directly.

### iOS toolbar / sheet wiring

```swift
var body: some View {
    NavigationSplitView { sidebar }
        detail: { detail(for: selectedSection) }  // unchanged from today
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

## UX details and edge cases

**Default directory:**

| Case | macOS Save-As / Save As… | macOS Open File… | iOS |
|---|---|---|---|
| Workspace root set | workspace root | workspace root | n/a (Files picker has own state) |
| No workspace, tab has URL | parent of tab's URL | (no fallback; system default) | n/a |
| No workspace, no URL | system default (~/Documents) | system default | n/a |

**File-exists conflict on Save-As:** Handled by `NSSavePanel` / iOS Files picker. No custom UI.

**Save-As to a URL already open in another tab:** Rebind succeeds; the other tab keeps its stale in-memory text. Known limitation, called out here in lieu of a merge flow.

**Open File on a URL already open:** Existing `EditorDocuments.openFile(url:)` activates the existing tab. No change.

**Cancel behavior:** Silent. No log entry, no `handleSaveOutcome` call.

**Error surfaces:** `handleSaveOutcome(.failed(error))` keeps its `CrossPlatformLogger.error(...)` behavior. Banner/toast UI is out of scope.

**Language rebind on Save-As:** `LanguageDetectionService().detectLanguage(fromExtension:)` runs against the new URL's extension. Unknown extensions return `.plainText`. The highlighter swaps live, matching the existing `setLanguageRenaming` behavior.

**Untitled default filename:** The tab's name (`Untitled-1.swift`) is passed verbatim as the panel's suggested filename. Users can edit it freely.

## Testing

Sample target only. New file: `Tests/CodeEditorSampleTests/EditorDocumentsSaveAsTests.swift` (Swift Testing `@Suite`).

```
@Suite("EditorDocuments saveAs")
- saveAs_writesContentToURL                       Asserts on-disk bytes match document.text.
- saveAs_rebindsURLNameLanguageIsDirty            url, name, language updated; isDirty cleared.
- saveAs_languageDetectsFromExtension             .py → .python; .swift → .swift; verify both.
- saveAs_unknownExtensionFallsBackToPlainText
- saveAs_noActiveTab_returnsNoTab
- saveAs_failedWrite_returnsFailedAndPreservesDocument
                                                  Point at unwritable URL; expect .failed;
                                                  document fields untouched.
- saveAs_overwritingExistingFile                  Pre-create file at URL; saveAs overwrites cleanly.
```

All tests use a per-test scratch directory under `FileManager.default.temporaryDirectory` and clean up via `defer`. macOS and iOS-simulator run the suite identically (security-scope branches compile out on macOS and no-op on app-sandbox URLs on iOS).

**Not covered by automated tests:**
- `AppState.requestSave` → `requestSaveAs` chaining (would require stubbing `DocumentPicker` modal). The branch is thin glue over `save()` and `saveAs(to:)`, both of which have unit coverage.
- Picker UI itself (system-provided).
- iOS sheet presentation and `UIViewControllerRepresentable` wiring (manual smoke).

**Manual smoke checklist** (carried into the implementation plan, not automated):
- macOS `⌘S` on dirty Untitled → `NSSavePanel` appears, default name = tab name.
- macOS `⌘S` on dirty named tab → no panel; file written.
- macOS `⇧⌘S` on any tab → `NSSavePanel`; rebind on confirm.
- macOS `⇧⌘O` → `NSOpenPanel` → opens file as new tab; opening an already-open URL activates the existing tab.
- macOS `⌃⌘O` → Go to Symbol… (moved).
- iOS: toolbar Menu reveals Save / Save As… / Open File… / New Tab; hardware keyboard shortcuts on iPad fire the same commands.
- iOS Save-As to iCloud Drive: rebind succeeds; subsequent `⌘S` re-saves successfully (security scope re-acquired per write).
- iOS Open File from iCloud Drive: tab opens, text is readable; subsequent `⌘S` saves back to the same URL.

## Risks and tradeoffs

**`⇧⌘O` collision.** Moving Go to Symbol… is a small breaking change to existing demo muscle memory. Mitigation: the command is also reachable via the Command Palette (`⇧⌘P`). The new home (`⌃⌘O`) keeps the "O for symbol" association.

**iOS in-session URL handling without bookmark persistence.** A user who saves an Untitled tab to iCloud Drive, closes the app, and relaunches will not see that tab restored — they'd Open File… to recover it. This matches the sample's existing "no persistence" stance for documents and is called out here so the limitation is explicit.

**`writeWithSecurityScope` refactor of existing `save()` and `openFile()`.** The refactor is mechanical (wrap existing call site) but touches code with existing test coverage (`EditorDocumentsOpenFileTests`). The implementation plan should re-run those tests after the refactor lands.

**`SaveOutcome.untitled` becomes logically dead from `requestSave()`.** Kept for direct-call compatibility; the `handleSaveOutcome(.untitled)` log branch remains a safety net.

## Open questions

None — all scope, semantics, shortcut, and platform questions are settled.

## Out of scope (revisit later)

- Sandboxed macOS distribution. The sample is not sandboxed today; if a future packaging pass enables the App Sandbox, security-scoped URL handling will need to extend to the macOS save/open paths as well. `writeWithSecurityScope` is already structured to handle this; the `#if !canImport(AppKit)` guard would simply be removed.
- Cross-launch URL persistence via security-scoped bookmarks.
- Recent files menu / `NSDocumentController`.
- Banner-style save/error feedback to replace logger-only output.
- A formal "stale buffer in another tab after Save-As-overwrites-open-file" merge UX.
- `Open Folder…` on iOS.
