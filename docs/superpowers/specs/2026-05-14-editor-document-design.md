# `EditorDocument` + `EditorDocuments` — Design

**Status.** Draft, 2026-05-14.
**Tracks.** REVIEW.md "Sample-driven API gaps", item #3 (no first-class "document" recipe).

## Problem

Every host that opens more than one file at a time re-derives the same data model on top of `TabModel`. The sample shows it concretely: `Sources/CodeEditorSample/Documents/DocumentStore.swift` is 228 lines and invents:

1. Tab CRUD over `[TabModel]` — `newTab` / `close` / `closeAll` / `setActive`.
2. A per-tab text dictionary `[TabModel.ID: String]` plus `textBinding(for:)`.
3. A per-tab `EditorInteractionState` dictionary plus `interactionBinding(for:)` so cursor positions survive tab switches.
4. Dirty tracking via `.onTextChange { markDirty(_:newText:) }`, with a quirky "ignore the first character in an empty Untitled tab" rule.
5. UTF-8 `openFile(url:)` / `save(_:)` with a `SaveOutcome` enum + `LanguageDetectionService` on open.
6. Untitled-N naming + extension-follows-language renames.

Pieces 1–4 + 6 are pure in-memory bookkeeping that has nothing to do with the sample's UX. They're the same across every multi-tab host. The framework already ships `TabModel` (`Sources/CodeEditorPlugin/Core/TabModel.swift`) and `EditorInteractionState` (`Sources/CodeEditorPlugin/Core/EditorInteractionState.swift`) and the SwiftUI binding API on `CodeEditor` to consume both — but it stops short of the type that *owns* a document. REVIEW.md framing: "ship an `EditorDocument` value type."

The downstream cost shows up at the modifier chain in `Sources/CodeEditorSample/App/WindowBody.swift:46-67`: 14 lines wiring `appState.documents.textBinding(for: activeID)`, `.onTextChange { markDirty + LSP }`, `.codeLanguage(appState.documents.activeLanguage ?? .plainText)`, `.editorInteractionState(appState.documents.interactionBinding(for: activeID))`, etc. `Sources/CodeEditorSample/iOS/IOSRootView.swift:106-119` reproduces the same chain. Every host gets the same 6+ modifier ceremony.

## Goals & non-goals

**Goal.** Ship a first-class document type and an observable collection so the host writes one CRUD + bindings + dirty-tracking method per concern, and a single SwiftUI modifier wires the active document into a `CodeEditor`. The sample's `DocumentStore` reduces to a small sample-only extension covering file I/O and naming policy.

**Non-goals.**
- File I/O. Reading and writing bytes is host concern (sandboxing, security-scoped URLs, NSSavePanel, UIDocumentPicker — all vary by host). The framework's `EditorDocuments` does not call `String(contentsOf:)`, `Data.write(to:)`, or `FileManager`.
- Untitled-N naming, "Save As…", or any opinion about how new documents get their names. Naming is host policy.
- `NSDocument` / `FileDocument`-shaped autosave architecture.
- `EditorState.tabs` auto-mirroring. `EditorDocuments` doesn't touch `EditorState`; the recipe for mirroring is documented (one `.onChange` line).
- Deprecating or renaming `TabModel`. The new types compose with it; nothing in the existing chrome API changes.
- Replacing the sample's `SampleCodeCatalog` / `resetToSample` flow. That's sample UX.

## Design

### `EditorDocument` (struct)

```swift
public struct EditorDocument: Hashable, Identifiable, Sendable, Codable {
    public var tab: TabModel
    public var text: String
    public var interactionState: EditorInteractionState

    public var id: TabModel.ID { tab.id }

    public var name: String { get { tab.name } set { tab.name = newValue } }
    public var url: URL? { get { tab.url } set { tab.url = newValue } }
    public var language: Language? { get { tab.language } set { tab.language = newValue } }
    public var isDirty: Bool { get { tab.isDirty } set { tab.isDirty = newValue } }

    public init(
        name: String,
        text: String = "",
        url: URL? = nil,
        language: Language? = nil,
        interactionState: EditorInteractionState = EditorInteractionState(),
        isDirty: Bool = false,
        id: TabModel.ID = UUID()
    )
}
```

**Three things to call out.**

1. **`tab.id` is the only identity.** No separate document-level id field; `id` is a computed forward. A document and its tab share identity exactly. Equivalent: `EditorDocument` *contains* a `TabModel`; the tab is not a snapshot, it's the canonical chrome projection.
2. **Forwarding accessors.** `doc.name`, `doc.url`, `doc.language`, `doc.isDirty` read and write through `tab`. Call sites stay terse (`doc.language` rather than `doc.tab.language`). Chrome that needs the full `TabModel` (e.g., `EditorTabStrip(tabs:)`) reads `doc.tab`.
3. **`Codable` is auto-synthesized.** All three stored properties — `TabModel`, `String`, `EditorInteractionState` — are already `Codable`. Hosts get free workspace snapshot/restore (`JSONEncoder().encode(documents)`) without any hand-rolled `CodingKeys`.

File: `Sources/CodeEditorPlugin/Documents/EditorDocument.swift` (new).

### `EditorDocuments` (observable manager)

```swift
@MainActor
@Observable
public final class EditorDocuments {
    public private(set) var documents: [EditorDocument]
    public var activeID: EditorDocument.ID?

    public var active: EditorDocument? { documents.first { $0.id == activeID } }
    public var tabs: [TabModel] { documents.map(\.tab) }

    /// Mutable Binding<[TabModel]> for chrome (EditorTabStrip). Getter
    /// returns `tabs`; setter diffs by id and dispatches `close(_:)` for
    /// removed ids, reorders `documents` for moved ids, and ignores ids
    /// that weren't already present.
    public var tabsBinding: Binding<[TabModel]>

    public init(documents: [EditorDocument] = [], activeID: EditorDocument.ID? = nil)

    // CRUD
    @discardableResult
    public func open(_ document: EditorDocument) -> EditorDocument.ID
    public func close(_ id: EditorDocument.ID)
    public func closeAll()
    public func setActive(_ id: EditorDocument.ID)

    // Bindings
    public func textBinding(for id: EditorDocument.ID) -> Binding<String>
    public func interactionBinding(for id: EditorDocument.ID) -> Binding<EditorInteractionState>

    // Dirty
    public func markClean(_ id: EditorDocument.ID)

    // Per-document mutation
    public func setLanguage(_ language: Language, of id: EditorDocument.ID)
}
```

**Five design points.**

1. **`documents` is `private(set)`.** External reassignment is blocked. Mutation goes through CRUD methods, which keeps `activeID` consistent on `close` (falls back to the previous tab, then to nil when the list empties). Reading the array directly (for iteration, count, etc.) stays public.
2. **`activeID` is read/write.** Hosts can flip it directly (e.g., on tab-strip click). `setActive(_:)` is the safe variant that no-ops when the id isn't in the list.
3. **Dirty-flip is in the binding setter.** `textBinding(for:)` returns a `Binding<String>` whose setter:
   - Writes the new value into the per-id text storage.
   - If the new value differs from the prior stored value, flips `documents[i].tab.isDirty = true`.
   - Otherwise leaves `isDirty` alone (so writing the same value through the binding is a no-op).
   - Reading from the binding returns `""` for an unknown id (defensive default; matches today's sample).

   `markClean(_:)` is the explicit reset after a successful save. Hosts that want to bypass dirty tracking (e.g., a programmatic text replacement that shouldn't count as a user edit) mutate `documents[i].text` directly through a helper — out of scope for this design; the binding-setter path is the documented one.
4. **No file I/O.** `open(_:)` takes an already-constructed `EditorDocument`. Hosts that read from disk own the read. The sample retains a thin `openFile(url:) -> EditorDocument.ID?` helper that does `String(contentsOf:)` + `LanguageDetectionService` + `documents.open(EditorDocument(...))`. The helper lives in `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift` (or equivalent name during implementation).
5. **No `EditorState` mirroring.** The manager doesn't reach into `EditorState.tabs`. Hosts that want both wire `.onChange(of: documents.tabs) { editorState.tabs = $0 }` — one line, documented in the migration recipe.

File: `Sources/CodeEditorPlugin/Documents/EditorDocuments.swift` (new).

### `.activeDocument(in:)` modifier

```swift
extension View {
    /// Wires the active EditorDocument's text, language, and interaction
    /// state into the CodeEditor below this modifier.
    public func activeDocument(in documents: EditorDocuments) -> some View
}
```

Internally, the modifier wraps the receiver in a private SwiftUI view that:

1. Reads `documents.activeID` (observable). If nil, renders `EmptyView()` — host handles the empty-state case separately (the sample already does, see `WindowBody.emptyState`).
2. When `activeID` is non-nil, renders the underlying receiver with `text: documents.textBinding(for: activeID)` flowing through the existing internal Binding plumbing, and applies `.codeLanguage(documents.active?.language ?? .plainText)` + `.editorInteractionState(documents.interactionBinding(for: activeID))` to the receiver.
3. Switching `activeID` triggers SwiftUI to re-read the bindings; the manager's per-id storage means the previously active document's text and interaction state are preserved (already in the manager) and surface again when the host re-activates that id.

**`extension View`, not `extension CodeEditor`.** Same precedent as `.performanceObserver(_:)` (see `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+ModifiersExtensions.swift` after the 2026-05-14 perf-observer batch). Composes after other view-typed modifiers (e.g., `.frame(maxWidth:maxHeight:)`, `.onAppear`).

**Requires a no-arg `CodeEditor()` initializer.** The framework currently has `CodeEditor(text: Binding<String>)` and the `withConfiguration` / `withLanguage` factories. The modifier needs to be able to inject a text Binding into a receiver that doesn't carry one. Add `CodeEditor()` that defaults its internal text Binding to `.constant("")` — the modifier overrides via the same mechanism the existing internal helpers use (`Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift:167`-style internal var assignment). Documented as "use with `.activeDocument(in:)`; standalone usage renders an empty editor."

**Alternative considered and rejected.** A `CodeEditor(documents:)` initializer. Rejected because constructors don't compose cleanly with the existing modifier chain — `.editorController` / `.performanceObserver` / `.onTextChange` etc. are modifier-shaped; a constructor variant would force hosts to pick between document-factory and the existing factories.

Files: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+DocumentsExtensions.swift` (new). Touches `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` and `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift` for the no-arg initializer.

## Migration plan & sample impact

**Sample-side files that change:**

| File | Change |
|---|---|
| `Sources/CodeEditorSample/Documents/DocumentStore.swift` | Deleted. The CRUD / bindings / dirty tracking / `activeLanguage` move to `EditorDocuments`. `save(_:)`, `openFile(url:)`, `newTab()` (with Untitled-N + extension-rename helper), `resetToSample(_:of:)` move to a new `EditorDocuments+SampleExtras.swift` extension. `SaveOutcome` enum moves to the extension. |
| `Sources/CodeEditorSample/App/AppState.swift` | `let documents = DocumentStore()` → `let documents = EditorDocuments()`. Save-outcome handler signature switches to the extension's `SaveOutcome`. |
| `Sources/CodeEditorSample/App/WindowBody.swift` | 14-line modifier chain in `editorPane` collapses by ~6 lines (text binding, `.codeLanguage`, `.editorInteractionState`, the `markDirty` call inside `.onTextChange` all disappear; `.activeDocument(in:)` replaces them). |
| `Sources/CodeEditorSample/iOS/IOSRootView.swift` | Same collapse as `WindowBody.editorPane`. |
| `Sources/CodeEditorSample/App/RootWindow.swift` | `EditorTabStrip` needs a `Binding<[TabModel]>` that it can mutate to close tabs. `EditorDocuments.tabs` is now a computed projection (read-only). `EditorDocuments` exposes a `tabsBinding: Binding<[TabModel]>` whose getter returns the projection and whose setter diffs the incoming array against the current one by id: any id missing in the new array dispatches `close(_:)`; index reorderings re-sort `documents` to match; previously-unseen ids in the setter are ignored (the strip can only remove or reorder, never invent). Chrome stays unchanged: `EditorTabStrip(tabs: $appState.documents.tabsBinding, activeTabID: $appState.documents.activeID)`. The strip's `onClose` closure parameter is left for sample-side LSP teardown hooks. |
| `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift` | `appState.documents.activeTabID` → `activeID`; `documents.newTab()` / `close(_:)` / `closeAll()` / `resetToSample` keep their names. |
| `Sources/CodeEditorSample/Switchers/SwitcherSection.swift` | `documents.activeTabID` → `activeID`; `documents.activeLanguage` → `documents.active?.language`. |
| `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` | Same renames as above; the LSP "open all Swift tabs" iteration switches from `for tab in documents.tabs where tab.language == .swift` to `for doc in documents.documents where doc.language == .swift`. `documents.textBinding(for: tab.id).wrappedValue` → `doc.text`. |
| `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift` | `documents.newTab()` / `close(_:)` / `save()` calls update to the new types (the `Untitled-N`-generating `newTab()` lives on the extension; `close`/`closeAll`/`setActive` live on the framework class). |
| `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift` | `documents.activeTabID` → `activeID`; the `onRequestOpen` closure calls the extension's `openFile(url:)`. |

**Test file movement:** `Tests/CodeEditorSampleTests/DocumentStoreOpenFileTests.swift` (53 lines) retargets to the new `openFile(url:)` extension and renames to `EditorDocumentsOpenFileTests.swift` (or stays under the original name pointed at the extension — implementation choice).

## Public API impact

Strictly additive on the framework:

- New `Sources/CodeEditorPlugin/Documents/EditorDocument.swift` struct.
- New `Sources/CodeEditorPlugin/Documents/EditorDocuments.swift` `@Observable` class.
- New `extension View { func activeDocument(in:) }` modifier in `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+DocumentsExtensions.swift`.
- New no-arg `CodeEditor()` initializer alongside the existing `CodeEditor(text:)`.

No existing public API is renamed, deprecated, or behavior-changed. `TabModel`, `EditorInteractionState`, `EditorState`, `EditorTabStrip`, `LanguageDetectionService`, `CodeEditor(text:)`, `.codeLanguage(_:)`, `.editorInteractionState(_:)` all stay exactly as they are.

Source-breaking inside the sample only: `DocumentStore` is deleted and replaced. No external consumers exist (sample is in-tree).

## Testing

**Framework tests (new, under `Tests/CodeEditorPluginTests/Documents/`):**

| File | Coverage |
|---|---|
| `EditorDocumentTests.swift` | Struct invariants — `id` forwards to `tab.id`; forwarding accessors (`name`/`url`/`language`/`isDirty`) read and write through `tab`; `Codable` round-trip preserves all three stored fields including non-empty `interactionState`; `Hashable` keyed by id only. |
| `EditorDocumentsTests.swift` | CRUD — `open` appends and activates; `close` of active picks the previous tab as new active; `close` of last tab nils `activeID`; `closeAll` empties everything; `setActive` no-ops for unknown id. `documents.tabs.map(\.id) == documents.documents.map(\.id)`. |
| `EditorDocumentsBindingTests.swift` | Binding semantics — `textBinding(for:)` getter returns `""` for unknown id; setter writes through; dirty flips on first different write but stays clean when value equals stored; `markClean(_:)` resets; interaction binding writes/reads round-trip through manager storage. `tabsBinding` setter: id removal dispatches `close(_:)`; index reorder reorders `documents`; ids not previously present are ignored. |
| `ActiveDocumentModifierTests.swift` (Swift Testing) | Modifier reads `documents.activeID`; threads the right Bindings into the underlying `CodeEditor`; hot-swap on `activeID` change preserves prior doc's text + interaction state in the manager's storage. Uses the existing `EditorTestHarness` to avoid full SwiftUI rendering. |

**Sample test (renamed and retargeted):** `Tests/CodeEditorSampleTests/DocumentStoreOpenFileTests.swift` → `Tests/CodeEditorSampleTests/EditorDocumentsOpenFileTests.swift`, driving the new `openFile(url:)` extension. Coverage unchanged.

**No snapshot tests** — `EditorDocuments` is data, not visual.

**No mocks** — `EditorDocuments` has no dependencies beyond `Foundation`. Tests construct `EditorDocument(name:text:language:)` directly.

## Files added / modified

**Added (framework):**
- `Sources/CodeEditorPlugin/Documents/EditorDocument.swift`
- `Sources/CodeEditorPlugin/Documents/EditorDocuments.swift`
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+DocumentsExtensions.swift`

**Added (tests):**
- `Tests/CodeEditorPluginTests/Documents/EditorDocumentTests.swift`
- `Tests/CodeEditorPluginTests/Documents/EditorDocumentsTests.swift`
- `Tests/CodeEditorPluginTests/Documents/EditorDocumentsBindingTests.swift`
- `Tests/CodeEditorPluginTests/Documents/ActiveDocumentModifierTests.swift`

**Modified (framework):**
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditor.swift` — add no-arg `CodeEditor()` initializer.
- `Sources/CodeEditorPlugin/SwiftUI/CodeEditorRepresentableHelper.swift` — default text Binding plumbing supports no-arg init.

**Added (sample):**
- `Sources/CodeEditorSample/Documents/EditorDocuments+SampleExtras.swift` — `openFile(url:)`, `save(_:)`, `SaveOutcome`, `newTab()` (Untitled-N counter + extension-rename helper), `resetToSample(_:of:)`.

**Modified (sample, surface renames only):**
- `Sources/CodeEditorSample/App/AppState.swift`
- `Sources/CodeEditorSample/App/WindowBody.swift`
- `Sources/CodeEditorSample/App/RootWindow.swift`
- `Sources/CodeEditorSample/App/CodeEditorSampleApp.swift`
- `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift`
- `Sources/CodeEditorSample/iOS/IOSRootView.swift`
- `Sources/CodeEditorSample/CommandPalette/CommandPaletteCatalog.swift`
- `Sources/CodeEditorSample/Switchers/SwitcherSection.swift`
- `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`

**Modified (test, surface renames only):**
- `Tests/CodeEditorSampleTests/DocumentStoreOpenFileTests.swift`

**Deleted:**
- `Sources/CodeEditorSample/Documents/DocumentStore.swift`

## What's NOT in scope

Tracked here so the implementation plan and future review passes don't accidentally pull them in:

- **File I/O on `EditorDocuments`.** Stays as a sample-side extension.
- **Save-As panel** for `Untitled-*` tabs. Reviewer deliberately deferred in the Sample coverage gaps batch; still deferred.
- **Untitled-N naming** in the framework. Sample owns the policy.
- **`EditorDocuments` ↔ `EditorState.tabs` auto-mirroring.** Sample wires it explicitly; framework documents the recipe.
- **Persistence to disk** (workspace snapshot). `EditorDocument` is `Codable` so hosts can do this themselves; the framework doesn't ship a writer.
- **iOS document picker integration**. Sample concern.
- **`NSDocument` / `FileDocument` shape.** Different architecture; out of scope.
