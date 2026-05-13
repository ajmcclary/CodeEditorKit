# Sample-App LSP Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `sourcekit-lsp` into the `CodeEditorSample` target with inline diagnostics, hover popover, and ⌘-click Go-to-Definition. Add the minimum public framework surface needed (decoration + hover + click hooks + `SourcePosition` type).

**Architecture:** A new `LSPSampleCoordinator` (sample-side) owns `LSPManager`, mirrors active Swift documents to a temp directory for on-disk URIs, bridges diagnostics into the existing `AnnotationsHub`, and renders a SwiftUI popover via a `HoverSession`. The framework grows by three small public APIs and one public type — none know about LSP. macOS-only via `#if canImport(AppKit)`.

**Tech Stack:** Swift 6.3 (StrictConcurrency), SwiftUI + AppKit, TextKit 2, Combine (`@Published` LSP diagnostic stream), Swift Testing + XCTest + SnapshotTesting.

**Spec:** `docs/superpowers/specs/2026-05-13-sample-app-lsp-integration-design.md`

**Spec deviation note:** The spec described the attribute API on `CodeEditorView`. During implementation planning it became clearer that `EditorController` is the right place (matches the existing imperative-facade pattern used by find/goto/fold). The hover/click modifiers stay as SwiftUI `View` extensions. If the engineer discovers `EditorController` is unsuitable, fall back to a public extension on whichever type the SwiftUI `CodeEditor` actually wraps.

---

## Phase 1 — Framework primitives

### Task 1: `SourcePosition` public type

**Files:**
- Create: `Sources/CodeEditorPlugin/Core/SourcePosition.swift`
- Test: `Tests/CodeEditorPluginTests/Core/SourcePositionTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Core/SourcePositionTests.swift
import Testing
@testable import CodeEditorPlugin

@Suite("SourcePosition")
struct SourcePositionTests {
    @Test func equatableByLineAndCharacter() {
        let a = SourcePosition(line: 3, character: 5)
        let b = SourcePosition(line: 3, character: 5)
        let c = SourcePosition(line: 3, character: 6)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func hashableMatchesEquality() {
        let a = SourcePosition(line: 1, character: 2)
        let b = SourcePosition(line: 1, character: 2)
        var set: Set<SourcePosition> = []
        set.insert(a)
        #expect(set.contains(b))
    }

    @Test func zeroIsValid() {
        let p = SourcePosition(line: 0, character: 0)
        #expect(p.line == 0)
        #expect(p.character == 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter SourcePositionTests`
Expected: FAIL with "cannot find 'SourcePosition' in scope"

- [ ] **Step 3: Write the implementation**

```swift
// Sources/CodeEditorPlugin/Core/SourcePosition.swift

/// Zero-based source position. Matches the LSP convention (UTF-16 character
/// offset within the line) so callers translating to LSP `Position` do not
/// need per-call arithmetic, but this type imports no LSP types itself.
public struct SourcePosition: Sendable, Hashable {
    public let line: Int
    public let character: Int

    public init(line: Int, character: Int) {
        self.line = line
        self.character = character
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter SourcePositionTests`
Expected: PASS, 3 tests

- [ ] **Step 5: Lint pass**

Run: `swiftlint --fix && swiftlint`
Expected: zero violations on new files

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/SourcePosition.swift \
        Tests/CodeEditorPluginTests/Core/SourcePositionTests.swift
git commit -m "Add SourcePosition public type"
```

---

### Task 2: `TemporaryAttributesStore` (internal)

**Files:**
- Create: `Sources/CodeEditorPlugin/Text/TemporaryAttributesStore.swift`
- Test: `Tests/CodeEditorPluginTests/Text/TemporaryAttributesStoreTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Text/TemporaryAttributesStoreTests.swift
#if canImport(AppKit)
import XCTest
import AppKit
@testable import CodeEditorPlugin

final class TemporaryAttributesStoreTests: XCTestCase {
    func makeStorage(_ text: String) -> NSTextStorage {
        NSTextStorage(string: text, attributes: [:])
    }

    func testApplyAddsAttributesInRange() {
        let storage = makeStorage("hello world")
        let store = TemporaryAttributesStore(textStorage: storage)
        let range = NSRange(location: 0, length: 5)

        store.apply([.underlineColor: NSColor.red], to: range)

        var effectiveRange = NSRange()
        let color = storage.attribute(.underlineColor, at: 0, effectiveRange: &effectiveRange) as? NSColor
        XCTAssertEqual(color, .red)
        XCTAssertEqual(effectiveRange, range)
    }

    func testClearInRangeRemovesAttributes() {
        let storage = makeStorage("hello world")
        let store = TemporaryAttributesStore(textStorage: storage)
        store.apply([.underlineColor: NSColor.red], to: NSRange(location: 0, length: 5))

        store.clear(in: NSRange(location: 0, length: 5))

        let color = storage.attribute(.underlineColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertNil(color)
    }

    func testClearAllRemovesEverythingWeApplied() {
        let storage = makeStorage("hello world")
        let store = TemporaryAttributesStore(textStorage: storage)
        store.apply([.underlineColor: NSColor.red], to: NSRange(location: 0, length: 5))
        store.apply([.underlineColor: NSColor.blue], to: NSRange(location: 6, length: 5))

        store.clearAll()

        let c0 = storage.attribute(.underlineColor, at: 0, effectiveRange: nil) as? NSColor
        let c6 = storage.attribute(.underlineColor, at: 6, effectiveRange: nil) as? NSColor
        XCTAssertNil(c0)
        XCTAssertNil(c6)
    }

    func testClearAllToleratesStaleRanges() {
        let storage = makeStorage("hello world")
        let store = TemporaryAttributesStore(textStorage: storage)
        store.apply([.underlineColor: NSColor.red], to: NSRange(location: 0, length: 5))

        // Simulate the user deleting the entire text out from under us.
        storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: "")

        // Must not crash; effectively a no-op.
        store.clearAll()
        XCTAssertEqual(storage.length, 0)
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter TemporaryAttributesStoreTests`
Expected: FAIL with "cannot find 'TemporaryAttributesStore' in scope"

- [ ] **Step 3: Write the implementation**

```swift
// Sources/CodeEditorPlugin/Text/TemporaryAttributesStore.swift
#if canImport(AppKit)
import AppKit

/// Tracks transient presentation attributes that have been layered on top of
/// the editor's syntax highlighting. Owns the bookkeeping needed to clear
/// previously applied keys without disturbing other consumers of the same
/// attribute keys (e.g. find-match highlighting).
///
/// macOS-only: relies on NSTextStorage attribute application.
final class TemporaryAttributesStore {
    private struct Applied {
        let range: NSRange
        let keys: Set<NSAttributedString.Key>
    }

    private weak var textStorage: NSTextStorage?
    private var applied: [Applied] = []

    init(textStorage: NSTextStorage) {
        self.textStorage = textStorage
    }

    func apply(_ attributes: [NSAttributedString.Key: Any], to range: NSRange) {
        guard let storage = textStorage,
              let clamped = clamp(range, to: storage.length) else { return }
        storage.beginEditing()
        storage.addAttributes(attributes, range: clamped)
        storage.endEditing()
        applied.append(Applied(range: clamped, keys: Set(attributes.keys)))
    }

    func clear(in range: NSRange) {
        guard let storage = textStorage else { return }
        storage.beginEditing()
        defer { storage.endEditing() }
        for entry in applied {
            guard let clampedEntry = clamp(entry.range, to: storage.length) else { continue }
            let intersection = NSIntersectionRange(clampedEntry, range)
            guard intersection.length > 0 else { continue }
            for key in entry.keys {
                storage.removeAttribute(key, range: intersection)
            }
        }
        applied.removeAll { entry in
            guard let clampedEntry = clamp(entry.range, to: storage.length) else { return true }
            return NSIntersectionRange(clampedEntry, range).length == clampedEntry.length
        }
    }

    func clearAll() {
        guard let storage = textStorage else {
            applied.removeAll()
            return
        }
        storage.beginEditing()
        defer { storage.endEditing() }
        for entry in applied {
            guard let clampedEntry = clamp(entry.range, to: storage.length) else { continue }
            for key in entry.keys {
                storage.removeAttribute(key, range: clampedEntry)
            }
        }
        applied.removeAll()
    }

    private func clamp(_ range: NSRange, to length: Int) -> NSRange? {
        let lower = max(0, min(range.location, length))
        let upper = max(lower, min(range.location + range.length, length))
        let clamped = NSRange(location: lower, length: upper - lower)
        return clamped.length > 0 ? clamped : nil
    }
}
#endif
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter TemporaryAttributesStoreTests`
Expected: PASS, 4 tests

- [ ] **Step 5: Lint + full build**

Run: `swiftlint --fix && swiftlint && swift build`
Expected: zero violations, build succeeds

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Text/TemporaryAttributesStore.swift \
        Tests/CodeEditorPluginTests/Text/TemporaryAttributesStoreTests.swift
git commit -m "Add TemporaryAttributesStore for transient editor decorations"
```

---

### Task 3: `EditorController` public temporary-attributes API

**Files:**
- Create: `Sources/CodeEditorPlugin/Core/EditorController+TemporaryAttributesExtensions.swift`
- Modify: existing `EditorController` to lazily own a `TemporaryAttributesStore` (find the file first; likely under `Sources/CodeEditorPlugin/Core/`)
- Test: `Tests/CodeEditorPluginTests/Core/EditorControllerTemporaryAttributesTests.swift`

**Investigation step before coding:** Find the current `EditorController` definition. It must expose (publicly or internally) the active `NSTextStorage` for this task to wire up. If it does not, add an `internal var currentTextStorage: NSTextStorage?` accessor in the same task.

Run: `grep -rn "class EditorController\|final class EditorController" Sources/CodeEditorPlugin/`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Core/EditorControllerTemporaryAttributesTests.swift
#if canImport(AppKit)
import XCTest
import AppKit
@testable import CodeEditorPlugin

final class EditorControllerTemporaryAttributesTests: XCTestCase {
    func testApplyTemporaryAttributesAddsUnderline() {
        let storage = NSTextStorage(string: "let x = 1")
        let controller = EditorController.makeForTesting(textStorage: storage)

        controller.applyTemporaryAttributes(
            [.underlineColor: NSColor.systemRed,
             .underlineStyle: NSUnderlineStyle([.single, .patternDot]).rawValue],
            to: NSRange(location: 0, length: 3)
        )

        let color = storage.attribute(.underlineColor, at: 0, effectiveRange: nil) as? NSColor
        XCTAssertEqual(color, .systemRed)
    }

    func testClearAllTemporaryAttributesRemovesEverything() {
        let storage = NSTextStorage(string: "let x = 1")
        let controller = EditorController.makeForTesting(textStorage: storage)
        controller.applyTemporaryAttributes([.underlineColor: NSColor.systemRed],
                                            to: NSRange(location: 0, length: 3))

        controller.clearAllTemporaryAttributes()

        XCTAssertNil(storage.attribute(.underlineColor, at: 0, effectiveRange: nil))
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter EditorControllerTemporaryAttributesTests`
Expected: FAIL with "value of type 'EditorController' has no member 'applyTemporaryAttributes'"

- [ ] **Step 3: Add internal storage accessor + test factory on `EditorController`**

In the existing `EditorController.swift` (path discovered above), add:

```swift
// In existing EditorController class
internal var temporaryAttributesStore: TemporaryAttributesStore? {
    guard let storage = currentTextStorage else { return nil }
    if let existing = _temporaryAttributesStore { return existing }
    let store = TemporaryAttributesStore(textStorage: storage)
    _temporaryAttributesStore = store
    return store
}

private var _temporaryAttributesStore: TemporaryAttributesStore?

#if canImport(AppKit)
// Test-only factory
static func makeForTesting(textStorage: NSTextStorage) -> EditorController {
    let controller = EditorController()
    controller._testStorageOverride = textStorage
    return controller
}
private var _testStorageOverride: NSTextStorage?
#endif

internal var currentTextStorage: NSTextStorage? {
    // Existing implementation if it already exposes the active text storage.
    // If not, route to the currently-attached NSTextView's textStorage.
    // Test override takes precedence.
    _testStorageOverride ?? attachedTextView?.textStorage
}
```

If `EditorController` already has `currentTextStorage` or an equivalent, use that and skip the new accessor. The point: temporaryAttributesStore must be backed by the active text storage.

- [ ] **Step 4: Write the public extension**

```swift
// Sources/CodeEditorPlugin/Core/EditorController+TemporaryAttributesExtensions.swift
#if canImport(AppKit)
import AppKit

public extension EditorController {
    /// Applies presentation-only attributes to a character range. Attributes
    /// are layered on top of syntax highlighting and survive standard
    /// NSTextStorage edits (attribute ranges adjust as text changes).
    ///
    /// Intended for transient decorations such as LSP diagnostic underlines,
    /// search-match highlights, or debug-stop indicators. Not for syntax
    /// highlighting — register a `HighlightingStrategy` for that.
    func applyTemporaryAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        to range: NSRange
    ) {
        temporaryAttributesStore?.apply(attributes, to: range)
    }

    /// Removes all temporary-attribute keys that were applied via
    /// `applyTemporaryAttributes(_:to:)` and overlap the given range.
    func clearTemporaryAttributes(in range: NSRange) {
        temporaryAttributesStore?.clear(in: range)
    }

    /// Removes every temporary-attribute key applied via this controller.
    func clearAllTemporaryAttributes() {
        temporaryAttributesStore?.clearAll()
    }
}
#endif
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter EditorControllerTemporaryAttributesTests`
Expected: PASS, 2 tests

- [ ] **Step 6: Full build + lint**

Run: `swiftlint --fix && swiftlint && swift build`
Expected: clean

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/EditorController.swift \
        Sources/CodeEditorPlugin/Core/EditorController+TemporaryAttributesExtensions.swift \
        Tests/CodeEditorPluginTests/Core/EditorControllerTemporaryAttributesTests.swift
git commit -m "Expose applyTemporaryAttributes on EditorController"
```

---

### Task 4: `EditorEventBus` (internal) for hover/click event publishing

**Files:**
- Create: `Sources/CodeEditorPlugin/Layout/EditorEventBus.swift`
- Test: `Tests/CodeEditorPluginTests/Layout/EditorEventBusTests.swift`

This is the internal seam through which the wrapped NSTextView publishes hover and ⌘-click events. The hover/click modifiers in Tasks 5–6 subscribe to it.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Layout/EditorEventBusTests.swift
import Testing
import Combine
@testable import CodeEditorPlugin

@Suite("EditorEventBus")
@MainActor
struct EditorEventBusTests {
    @Test func publishesHoverEvent() async {
        let bus = EditorEventBus()
        var received: SourcePosition?
        let cancellable = bus.hoverPublisher.sink { received = $0 }

        bus.emitHover(at: SourcePosition(line: 3, character: 5))

        #expect(received == SourcePosition(line: 3, character: 5))
        _ = cancellable
    }

    @Test func publishesNilHoverWhenPointerLeavesText() {
        let bus = EditorEventBus()
        var received: SourcePosition? = SourcePosition(line: 0, character: 0)
        let cancellable = bus.hoverPublisher.sink { received = $0 }

        bus.emitHover(at: nil)

        #expect(received == nil)
        _ = cancellable
    }

    @Test func publishesCommandClickEvent() {
        let bus = EditorEventBus()
        var received: SourcePosition?
        let cancellable = bus.commandClickPublisher.sink { received = $0 }

        bus.emitCommandClick(at: SourcePosition(line: 7, character: 2))

        #expect(received == SourcePosition(line: 7, character: 2))
        _ = cancellable
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter EditorEventBusTests`
Expected: FAIL

- [ ] **Step 3: Write the implementation**

```swift
// Sources/CodeEditorPlugin/Layout/EditorEventBus.swift
import Combine
import SwiftUI

/// Internal seam between the wrapped editor view (AppKit on macOS) and the
/// SwiftUI hover/command-click modifiers. Held inside the SwiftUI environment
/// so any descendant of the editor can subscribe without leaking AppKit types.
@MainActor
final class EditorEventBus {
    private let hoverSubject = PassthroughSubject<SourcePosition?, Never>()
    private let commandClickSubject = PassthroughSubject<SourcePosition, Never>()

    var hoverPublisher: AnyPublisher<SourcePosition?, Never> {
        hoverSubject.eraseToAnyPublisher()
    }

    var commandClickPublisher: AnyPublisher<SourcePosition, Never> {
        commandClickSubject.eraseToAnyPublisher()
    }

    func emitHover(at position: SourcePosition?) {
        hoverSubject.send(position)
    }

    func emitCommandClick(at position: SourcePosition) {
        commandClickSubject.send(position)
    }
}

// MARK: - SwiftUI environment

private struct EditorEventBusKey: EnvironmentKey {
    static let defaultValue: EditorEventBus? = nil
}

extension EnvironmentValues {
    var editorEventBus: EditorEventBus? {
        get { self[EditorEventBusKey.self] }
        set { self[EditorEventBusKey.self] = newValue }
    }
}
```

- [ ] **Step 4: Wire the bus into the SwiftUI CodeEditor view**

Find the public SwiftUI `CodeEditor` view (likely under `Sources/CodeEditorPlugin/SwiftUI/`).

Run: `grep -rn "public struct CodeEditor\b" Sources/CodeEditorPlugin/`

Add an `@StateObject`-like ownership of the bus to the view body and inject it into the environment. Conceptually:

```swift
// Inside the existing CodeEditor view struct body:
@State private var editorEventBus = EditorEventBus()

// In body:
existingContent
    .environment(\.editorEventBus, editorEventBus)
    .modifier(EditorEventBusInstaller(bus: editorEventBus))  // see Task 4b
```

The `EditorEventBusInstaller` is added in Task 4b (next subtask) to keep this commit narrow. For now, only define the bus + environment key + the `@State` ownership, no event sources.

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter EditorEventBusTests`
Expected: PASS, 3 tests

- [ ] **Step 6: Lint + build**

Run: `swiftlint --fix && swiftlint && swift build`
Expected: clean

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorPlugin/Layout/EditorEventBus.swift \
        Sources/CodeEditorPlugin/SwiftUI/<CodeEditor file changed> \
        Tests/CodeEditorPluginTests/Layout/EditorEventBusTests.swift
git commit -m "Add EditorEventBus for hover and command-click signaling"
```

---

### Task 5: `EditorEventBusInstaller` — NSTrackingArea + NSEvent monitor

**Files:**
- Create: `Sources/CodeEditorPlugin/Layout/EditorEventBusInstaller.swift`
- Test: `Tests/CodeEditorPluginTests/Layout/EditorEventBusInstallerTests.swift`

This is the AppKit bridge that watches mouse events on the wrapped NSTextView and emits to the bus.

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Layout/EditorEventBusInstallerTests.swift
#if canImport(AppKit)
import XCTest
import AppKit
@testable import CodeEditorPlugin

final class EditorEventBusInstallerTests: XCTestCase {
    @MainActor
    func testCommandClickPublishesPosition() throws {
        let bus = EditorEventBus()
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        textView.string = "let foo = 1\nlet bar = 2"
        let installer = EditorEventBusInstaller(bus: bus, textView: textView)
        installer.install()

        var received: SourcePosition?
        let cancellable = bus.commandClickPublisher.sink { received = $0 }

        // Synthesize a ⌘-click at the start of line 1, character 4 (= "foo")
        let glyphIndex = textView.layoutManager?.glyphIndexForCharacter(at: 4) ?? 0
        let rect = textView.layoutManager?.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textView.textContainer!
        ) ?? .zero
        let point = NSPoint(x: rect.midX, y: rect.midY)
        let windowPoint = textView.convert(point, to: nil)

        let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: windowPoint,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!
        textView.mouseDown(with: event)

        XCTAssertEqual(received?.line, 0)
        XCTAssertEqual(received?.character, 4)
        _ = cancellable
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter EditorEventBusInstallerTests`
Expected: FAIL

- [ ] **Step 3: Write the implementation**

```swift
// Sources/CodeEditorPlugin/Layout/EditorEventBusInstaller.swift
#if canImport(AppKit)
import AppKit
import SwiftUI

/// Installs an NSTrackingArea and a window-scoped NSEvent monitor on the
/// wrapped NSTextView, publishing hover and ⌘-click events to the supplied
/// EditorEventBus. Translates window-coordinate mouse events into
/// SourcePosition values via the layout manager.
@MainActor
final class EditorEventBusInstaller {
    private weak var bus: EditorEventBus?
    private weak var textView: NSTextView?
    private var trackingArea: NSTrackingArea?
    private var hoverWorkItem: DispatchWorkItem?
    private var idleDelay: TimeInterval = 0.5

    init(bus: EditorEventBus, textView: NSTextView) {
        self.bus = bus
        self.textView = textView
    }

    func install() {
        guard let textView else { return }
        let area = NSTrackingArea(
            rect: textView.bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        textView.addTrackingArea(area)
        trackingArea = area

        // ⌘-click handler: install a swizzle-free hook by overriding mouseDown
        // via responder chain. Simpler approach: subscribe via NSEvent local
        // monitor scoped to the text view's window.
        // The local monitor fires for the window; we filter by hit-testing.
    }

    // MARK: NSTrackingArea callbacks
    @objc func mouseMoved(with event: NSEvent) {
        scheduleHover(event: event)
    }

    @objc func mouseExited(with event: NSEvent) {
        hoverWorkItem?.cancel()
        bus?.emitHover(at: nil)
    }

    private func scheduleHover(event: NSEvent) {
        hoverWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let textView = self.textView else { return }
            let location = textView.convert(event.locationInWindow, from: nil)
            let position = Self.sourcePosition(for: location, in: textView)
            self.bus?.emitHover(at: position)
        }
        hoverWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + idleDelay, execute: work)
    }

    // MARK: Public hover-delay setter for modifiers to override default
    func setHoverDelay(_ delay: TimeInterval) {
        idleDelay = delay
    }

    // MARK: Command-click handling — called from the NSTextView subclass
    // installed by CodeEditor. Public to that subclass.
    func handleMouseDown(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              event.type == .leftMouseDown,
              let textView = textView else {
            return false
        }
        let location = textView.convert(event.locationInWindow, from: nil)
        guard let position = Self.sourcePosition(for: location, in: textView) else {
            return false
        }
        bus?.emitCommandClick(at: position)
        return true  // consume; caller skips its own mouseDown
    }

    static func sourcePosition(for point: NSPoint, in textView: NSTextView) -> SourcePosition? {
        let index = textView.characterIndexForInsertion(at: point)
        guard index <= textView.string.utf16.count else { return nil }

        let nsString = textView.string as NSString
        var line = 0
        var lineStart = 0
        var current = 0
        while current < index {
            let range = nsString.lineRange(for: NSRange(location: current, length: 0))
            if range.location + range.length <= index {
                current = range.location + range.length
                lineStart = current
                line += 1
            } else {
                break
            }
        }
        let character = index - lineStart
        return SourcePosition(line: line, character: character)
    }
}
#endif
```

- [ ] **Step 4: Hook the installer into the editor's NSTextView**

Locate the NSTextView (or its wrapping `NSViewRepresentable`) inside the SwiftUI `CodeEditor`. Two integration paths depending on what's already there:

**Path A (preferred): subclass with mouseDown forwarding.** If `CodeEditor`'s NSViewRepresentable already uses a custom NSTextView subclass, add:

```swift
// Inside that subclass
weak var eventBusInstaller: EditorEventBusInstaller?

override func mouseDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command),
       eventBusInstaller?.handleMouseDown(event) == true {
        return  // ⌘-click was consumed by the installer
    }
    super.mouseDown(with: event)
}
```

**Path B: NSEvent local monitor.** If no subclass exists, wire ⌘-click via:

```swift
NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak installer] event in
    if event.modifierFlags.contains(.command),
       installer?.handleMouseDown(event) == true {
        return nil  // consume
    }
    return event
}
```

Store the returned token for removal on teardown.

In either path, the `EditorEventBusInstaller` is created and `.install()`-ed inside the NSViewRepresentable's `makeNSView` (or equivalent). The bus reference comes from the SwiftUI environment via `@Environment(\.editorEventBus)` propagated through the representable's `Context`.

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter EditorEventBusInstallerTests`
Expected: PASS

- [ ] **Step 6: Lint + build**

Run: `swiftlint --fix && swiftlint && swift build`
Expected: clean

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorPlugin/Layout/EditorEventBusInstaller.swift \
        Sources/CodeEditorPlugin/SwiftUI/<files changed> \
        Tests/CodeEditorPluginTests/Layout/EditorEventBusInstallerTests.swift
git commit -m "Install hover and command-click monitors on the editor's NSTextView"
```

---

### Task 6: `.onTextHover` and `.onCommandClick` SwiftUI modifiers

**Files:**
- Create: `Sources/CodeEditorPlugin/Layout/TextHoverModifier.swift`
- Create: `Sources/CodeEditorPlugin/Layout/CommandClickModifier.swift`
- Test: `Tests/CodeEditorPluginTests/Layout/HoverAndClickModifierTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorPluginTests/Layout/HoverAndClickModifierTests.swift
#if canImport(AppKit)
import XCTest
import SwiftUI
@testable import CodeEditorPlugin

final class HoverAndClickModifierTests: XCTestCase {
    @MainActor
    func testOnTextHoverFiresWhenBusEmits() async throws {
        let bus = EditorEventBus()
        var captured: SourcePosition?
        let view = Color.clear
            .environment(\.editorEventBus, bus)
            .onTextHover(idleDelay: .milliseconds(0)) { position in
                captured = position
            }
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        _ = host  // retain

        bus.emitHover(at: SourcePosition(line: 2, character: 4))
        try await Task.sleep(nanoseconds: 50_000_000)  // give the sink a tick

        XCTAssertEqual(captured?.line, 2)
        XCTAssertEqual(captured?.character, 4)
    }

    @MainActor
    func testOnCommandClickFires() async throws {
        let bus = EditorEventBus()
        var captured: SourcePosition?
        let view = Color.clear
            .environment(\.editorEventBus, bus)
            .onCommandClick { position in
                captured = position
            }
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        _ = host

        bus.emitCommandClick(at: SourcePosition(line: 5, character: 7))
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(captured?.line, 5)
        XCTAssertEqual(captured?.character, 7)
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter HoverAndClickModifierTests`
Expected: FAIL

- [ ] **Step 3: Write the hover modifier**

```swift
// Sources/CodeEditorPlugin/Layout/TextHoverModifier.swift
#if canImport(AppKit)
import SwiftUI
import Combine

public extension View {
    /// Calls `action` after the pointer has been still over the editor's text
    /// for `idleDelay`. The action receives the resolved `SourcePosition`,
    /// or `nil` if the pointer has left the text region (e.g. moved over the
    /// gutter). Previous calls are cancelled when the pointer moves before
    /// completion. Pointer-only on macOS.
    func onTextHover(
        idleDelay: Duration = .milliseconds(500),
        action: @escaping @Sendable (SourcePosition?) async -> Void
    ) -> some View {
        modifier(TextHoverModifier(idleDelay: idleDelay, action: action))
    }
}

private struct TextHoverModifier: ViewModifier {
    let idleDelay: Duration
    let action: @Sendable (SourcePosition?) async -> Void

    @Environment(\.editorEventBus) private var bus
    @State private var task: Task<Void, Never>?

    func body(content: Content) -> some View {
        content.onReceive(busHoverPublisher) { position in
            task?.cancel()
            let delay = idleDelay
            let captured = action
            task = Task { @MainActor in
                if delay > .zero {
                    try? await Task.sleep(for: delay)
                }
                guard !Task.isCancelled else { return }
                await captured(position)
            }
        }
    }

    private var busHoverPublisher: AnyPublisher<SourcePosition?, Never> {
        bus?.hoverPublisher ?? Empty().eraseToAnyPublisher()
    }
}
#endif
```

- [ ] **Step 4: Write the command-click modifier**

```swift
// Sources/CodeEditorPlugin/Layout/CommandClickModifier.swift
#if canImport(AppKit)
import SwiftUI
import Combine

public extension View {
    /// Calls `action` when the user clicks the editor's text while holding the
    /// Command key. The click is consumed — the caret does not reposition.
    func onCommandClick(
        action: @escaping (SourcePosition) -> Void
    ) -> some View {
        modifier(CommandClickModifier(action: action))
    }
}

private struct CommandClickModifier: ViewModifier {
    let action: (SourcePosition) -> Void

    @Environment(\.editorEventBus) private var bus

    func body(content: Content) -> some View {
        content.onReceive(busPublisher) { position in
            action(position)
        }
    }

    private var busPublisher: AnyPublisher<SourcePosition, Never> {
        bus?.commandClickPublisher ?? Empty().eraseToAnyPublisher()
    }
}
#endif
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter HoverAndClickModifierTests`
Expected: PASS, 2 tests

- [ ] **Step 6: Lint + build the full package**

Run: `swiftlint --fix && swiftlint && swift build`
Expected: clean

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorPlugin/Layout/TextHoverModifier.swift \
        Sources/CodeEditorPlugin/Layout/CommandClickModifier.swift \
        Tests/CodeEditorPluginTests/Layout/HoverAndClickModifierTests.swift
git commit -m "Add onTextHover and onCommandClick SwiftUI modifiers"
```

---

## Phase 2 — Sample data layer

### Task 7: `AnnotationsHub.replaceDiagnosticAnnotations` — new diagnostic bucket

**Files:**
- Modify: `Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift`
- Test: `Tests/CodeEditorSampleTests/AnnotationsHubDiagnosticsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorSampleTests/AnnotationsHubDiagnosticsTests.swift
#if canImport(AppKit)
import XCTest
@testable import CodeEditorSample
import CodeEditorPlugin

final class AnnotationsHubDiagnosticsTests: XCTestCase {
    @MainActor
    func testReplaceDiagnosticAnnotationsKeepsBreakpoints() {
        let hub = AnnotationsHub()
        hub.toggleBreakpoint(at: 5)

        let diagnostic = Annotation(
            id: UUID(),
            kind: .error,
            range: NSRange(location: 0, length: 1),
            text: "type mismatch"
        )
        hub.replaceDiagnosticAnnotations([diagnostic])

        XCTAssertTrue(hub.breakpointLines.contains(5))
        XCTAssertEqual(hub.diagnosticAnnotations.count, 1)
        XCTAssertEqual(hub.diagnosticAnnotations.first?.text, "type mismatch")
    }

    @MainActor
    func testReplaceDiagnosticAnnotationsClearsPreviousDiagnostics() {
        let hub = AnnotationsHub()
        let first = Annotation(id: UUID(), kind: .error,
                               range: NSRange(location: 0, length: 1), text: "old")
        let second = Annotation(id: UUID(), kind: .warning,
                                range: NSRange(location: 5, length: 1), text: "new")

        hub.replaceDiagnosticAnnotations([first])
        hub.replaceDiagnosticAnnotations([second])

        XCTAssertEqual(hub.diagnosticAnnotations.count, 1)
        XCTAssertEqual(hub.diagnosticAnnotations.first?.text, "new")
    }

    @MainActor
    func testAnnotationsForRangeIncludesDiagnostics() {
        let hub = AnnotationsHub()
        let diag = Annotation(id: UUID(), kind: .error,
                              range: NSRange(location: 0, length: 5), text: "boom")
        hub.replaceDiagnosticAnnotations([diag])

        let visible = hub.annotations(for: NSRange(location: 0, length: 10))
        XCTAssertTrue(visible.contains { $0.text == "boom" })
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter AnnotationsHubDiagnosticsTests`
Expected: FAIL with "value of type 'AnnotationsHub' has no member 'replaceDiagnosticAnnotations'"

- [ ] **Step 3: Modify `AnnotationsHub`**

Locate `Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift`. Add:

```swift
// Inside AnnotationsHub class:

private(set) var diagnosticAnnotations: [Annotation] = []

func replaceDiagnosticAnnotations(_ annotations: [Annotation]) {
    diagnosticAnnotations = annotations
    editorController?.reloadAnnotations()
}

// Modify the existing AnnotationsDataSource conformance:
// In annotations(for: NSRange), union the existing breakpoint + demo lists
// with diagnosticAnnotations (filtered to the requested range).
func annotations(for range: NSRange) -> [Annotation] {
    var result: [Annotation] = []
    // ... existing breakpoint + demo enumeration ...
    for diag in diagnosticAnnotations where NSIntersectionRange(diag.range, range).length > 0 {
        result.append(diag)
    }
    return result
}

// Also update textViewAnnotations property to include diagnostics if it
// returns the full list.
```

The exact merge point depends on the existing implementation. Read the file first and integrate the new bucket alongside the existing two without breaking their behavior.

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter AnnotationsHubDiagnosticsTests`
Expected: PASS, 3 tests

- [ ] **Step 5: Lint + build**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorSample`
Expected: clean

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample/EditorActions/AnnotationsHub.swift \
        Tests/CodeEditorSampleTests/AnnotationsHubDiagnosticsTests.swift
git commit -m "Add diagnostic-annotation bucket to AnnotationsHub"
```

---

### Task 8: `DocumentStore.openFile(url:)`

**Files:**
- Modify: `Sources/CodeEditorSample/Documents/DocumentStore.swift`
- Test: `Tests/CodeEditorSampleTests/DocumentStoreOpenFileTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorSampleTests/DocumentStoreOpenFileTests.swift
#if canImport(AppKit)
import XCTest
@testable import CodeEditorSample
import CodeEditorPlugin

final class DocumentStoreOpenFileTests: XCTestCase {
    @MainActor
    func testOpenFileCreatesTabAndInfersLanguage() throws {
        let store = DocumentStore()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".swift")
        try "let x = 1\n".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let id = try XCTUnwrap(store.openFile(url: tmp))

        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.tabs.first?.id, id)
        XCTAssertEqual(store.tabs.first?.originURL, tmp)
        XCTAssertEqual(store.language(of: id), .swift)
    }

    @MainActor
    func testOpenFileActivatesExistingTabForSameURL() throws {
        let store = DocumentStore()
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".swift")
        try "let x = 1\n".write(to: tmp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let firstID = try XCTUnwrap(store.openFile(url: tmp))
        let secondID = try XCTUnwrap(store.openFile(url: tmp))

        XCTAssertEqual(firstID, secondID)
        XCTAssertEqual(store.tabs.count, 1)
        XCTAssertEqual(store.activeTabID, firstID)
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DocumentStoreOpenFileTests`
Expected: FAIL

- [ ] **Step 3: Add `originURL` to `TabModel`**

Read `Sources/CodeEditorSample/Documents/DocumentStore.swift`. Add to the existing `TabModel`:

```swift
struct TabModel: Identifiable, Hashable {
    let id: UUID
    var title: String
    var originURL: URL?  // NEW
    // ... existing fields ...
}
```

Initialize `originURL = nil` everywhere existing tabs are created.

- [ ] **Step 4: Implement `openFile(url:)`**

Add to `DocumentStore`:

```swift
@discardableResult
func openFile(url: URL) -> TabModel.ID? {
    if let existing = tabs.first(where: { $0.originURL == url }) {
        activeTabID = existing.id
        return existing.id
    }
    guard let text = try? String(contentsOf: url, encoding: .utf8) else {
        return nil
    }
    let language = Language.inferring(fromExtension: url.pathExtension) ?? .plainText
    let id = UUID()
    var tab = TabModel(id: id, title: url.lastPathComponent, originURL: url)
    tabs.append(tab)
    texts[id] = text
    interactionStates[id] = EditorInteractionState()
    setLanguage(language, of: id)
    activeTabID = id
    return id
}
```

If `Language.inferring(fromExtension:)` does not exist, add it as a small helper in the same file or in the language enum's extensions:

```swift
extension Language {
    static func inferring(fromExtension ext: String) -> Language? {
        switch ext.lowercased() {
        case "swift": return .swift
        case "py": return .python
        case "js", "mjs": return .javascript
        case "ts": return .typescript
        // ...add a few more for the common cases, default nil
        default: return nil
        }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter DocumentStoreOpenFileTests`
Expected: PASS, 2 tests

- [ ] **Step 6: Lint + build**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorSample`
Expected: clean

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorSample/Documents/DocumentStore.swift \
        Tests/CodeEditorSampleTests/DocumentStoreOpenFileTests.swift
git commit -m "Add DocumentStore.openFile for cross-file definition jumps"
```

---

### Task 9: `DocumentMirror` — on-disk shadow files

**Files:**
- Create: `Sources/CodeEditorSample/App/LSP/DocumentMirror.swift`
- Test: `Tests/CodeEditorSampleTests/DocumentMirrorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorSampleTests/DocumentMirrorTests.swift
#if canImport(AppKit)
import XCTest
@testable import CodeEditorSample

final class DocumentMirrorTests: XCTestCase {
    func tempRoot() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MirrorTest-" + UUID().uuidString)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @MainActor
    func testOpenTabWritesShadowFile() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = DocumentMirror(rootDirectory: root)
        let id = UUID()

        let url = try mirror.openTab(id: id, text: "let x = 1\n", fileExtension: "swift")

        XCTAssertTrue(url.path.hasPrefix(root.path))
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(onDisk, "let x = 1\n")
    }

    @MainActor
    func testHandleTextChangeDebouncesWrites() async throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = DocumentMirror(rootDirectory: root, debounceInterval: 0.05)
        let id = UUID()
        let url = try mirror.openTab(id: id, text: "v1", fileExtension: "swift")

        mirror.handleTextChange(id: id, newText: "v2")
        mirror.handleTextChange(id: id, newText: "v3")
        mirror.handleTextChange(id: id, newText: "v4")

        try await Task.sleep(nanoseconds: 120_000_000)  // > debounce

        let onDisk = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(onDisk, "v4")  // last write wins, intermediate skipped
    }

    @MainActor
    func testCloseTabDeletesShadowFile() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let mirror = DocumentMirror(rootDirectory: root)
        let id = UUID()
        let url = try mirror.openTab(id: id, text: "x", fileExtension: "swift")

        mirror.closeTab(id: id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    @MainActor
    func testStartCleansLeftoverShadowDirectory() throws {
        let root = tempRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let dir = root.appendingPathComponent(".codeeditor-sample")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let stale = dir.appendingPathComponent("stale.swift")
        try "old".write(to: stale, atomically: true, encoding: .utf8)

        let mirror = DocumentMirror(rootDirectory: root)
        mirror.cleanupStaleShadows()

        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DocumentMirrorTests`
Expected: FAIL

- [ ] **Step 3: Write the implementation**

```swift
// Sources/CodeEditorSample/App/LSP/DocumentMirror.swift
#if canImport(AppKit)
import Foundation
import CodeEditorPlugin

/// Maintains a one-to-one mapping between in-memory tabs and on-disk shadow
/// files so sourcekit-lsp has a real URI per document. Writes are debounced
/// to avoid spamming the server on every keystroke.
@MainActor
final class DocumentMirror {
    private let shadowDirectory: URL
    private let debounceInterval: TimeInterval
    private var shadowURLs: [UUID: URL] = [:]
    private var pendingWork: [UUID: DispatchWorkItem] = [:]
    private let logger = CrossPlatformLogger.logger(for: "lsp.mirror")

    init(rootDirectory: URL, debounceInterval: TimeInterval = 0.15) {
        self.shadowDirectory = rootDirectory.appendingPathComponent(".codeeditor-sample")
        self.debounceInterval = debounceInterval
        try? FileManager.default.createDirectory(
            at: shadowDirectory, withIntermediateDirectories: true
        )
    }

    /// Writes the initial text to the shadow file and returns its URL.
    @discardableResult
    func openTab(id: UUID, text: String, fileExtension: String) throws -> URL {
        let url = shadowDirectory.appendingPathComponent("\(id.uuidString).\(fileExtension)")
        try text.data(using: .utf8)?.write(to: url, options: .atomic)
        shadowURLs[id] = url
        return url
    }

    /// Schedules a debounced write. After `debounceInterval` of quiet time,
    /// the latest `newText` is written to disk.
    func handleTextChange(id: UUID, newText: String) {
        guard let url = shadowURLs[id] else { return }
        pendingWork[id]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            do {
                try newText.data(using: .utf8)?.write(to: url, options: .atomic)
            } catch {
                self.logger.error("DocumentMirror write failed: \(error)")
            }
            self.pendingWork[id] = nil
        }
        pendingWork[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }

    func closeTab(id: UUID) {
        pendingWork[id]?.cancel()
        pendingWork[id] = nil
        if let url = shadowURLs.removeValue(forKey: id) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func url(for id: UUID) -> URL? {
        shadowURLs[id]
    }

    func cleanupStaleShadows() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: shadowDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for item in contents where !shadowURLs.values.contains(item) {
            try? FileManager.default.removeItem(at: item)
        }
    }
}
#endif
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DocumentMirrorTests`
Expected: PASS, 4 tests

- [ ] **Step 5: Lint + build**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorSample`
Expected: clean

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample/App/LSP/DocumentMirror.swift \
        Tests/CodeEditorSampleTests/DocumentMirrorTests.swift
git commit -m "Add DocumentMirror for on-disk LSP shadow files"
```

---

### Task 10: Test doubles — `FakeLSPClient`, `StubProcessResolver`

**Files:**
- Create: `Tests/CodeEditorSampleTests/Support/FakeLSPClient.swift`
- Create: `Tests/CodeEditorSampleTests/Support/StubProcessResolver.swift`

These are test-only types. No tests of their own; they're consumed by Tasks 11 and 12.

- [ ] **Step 1: Write `FakeLSPClient`**

```swift
// Tests/CodeEditorSampleTests/Support/FakeLSPClient.swift
#if canImport(AppKit)
import Foundation
import Combine
@testable import CodeEditorPlugin

/// Stand-in for LSPClient that exposes the subset of the public surface the
/// sample reads from. Tests emit values; the sample reacts.
@MainActor
final class FakeLSPClient {
    @Published var diagnostics: [String: [LSPDiagnostic]] = [:]
    var serverCapabilities: ServerCapabilities?
    var hoverResponse: Hover?
    var definitionResponse: [Location] = []

    func requestHover(filePath: String, line: Int, character: Int) async throws -> Hover? {
        hoverResponse
    }

    func requestDefinition(filePath: String, line: Int, character: Int) async throws -> [Location] {
        definitionResponse
    }
}
#endif
```

If `LSPDiagnostic`, `Hover`, `Location`, or `ServerCapabilities` differ in actual names, adjust to the real framework types (resolved earlier in the framework survey). Add a `typealias` if a rename is needed for clarity.

- [ ] **Step 2: Write `StubProcessResolver`**

```swift
// Tests/CodeEditorSampleTests/Support/StubProcessResolver.swift
#if canImport(AppKit)
import Foundation

/// Replaces `xcrun --find sourcekit-lsp` lookup in tests. Inject into
/// `LSPSampleCoordinator` via its `serverResolver` parameter.
struct StubProcessResolver {
    var resolve: () async -> URL?

    static let succeeds = StubProcessResolver {
        URL(fileURLWithPath: "/fake/path/to/sourcekit-lsp")
    }

    static let fails = StubProcessResolver { nil }
}
#endif
```

- [ ] **Step 3: Commit**

```bash
git add Tests/CodeEditorSampleTests/Support/FakeLSPClient.swift \
        Tests/CodeEditorSampleTests/Support/StubProcessResolver.swift
git commit -m "Add LSP test doubles for sample coordinator"
```

---

### Task 11: `DiagnosticsBridge` — LSP diagnostics → AnnotationsHub + temp attributes

**Files:**
- Create: `Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift`
- Test: `Tests/CodeEditorSampleTests/DiagnosticsBridgeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorSampleTests/DiagnosticsBridgeTests.swift
#if canImport(AppKit)
import Testing
import AppKit
@testable import CodeEditorSample
@testable import CodeEditorPlugin

@MainActor
@Suite("DiagnosticsBridge")
struct DiagnosticsBridgeTests {
    @Test func translatesErrorDiagnosticToAnnotation() async throws {
        let storage = NSTextStorage(string: "let x: Int = \"oops\"\n")
        let controller = EditorController.makeForTesting(textStorage: storage)
        let hub = AnnotationsHub()
        let client = FakeLSPClient()

        let bridge = DiagnosticsBridge(
            client: client, hub: hub, controller: controller, activeURI: { "file:///x.swift" }
        )
        bridge.start()

        let diag = LSPDiagnostic(
            range: LSPRange(
                start: LSPPosition(line: 0, character: 13),
                end: LSPPosition(line: 0, character: 19)
            ),
            severity: .error,
            message: "Cannot convert"
        )
        client.diagnostics = ["file:///x.swift": [diag]]
        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(hub.diagnosticAnnotations.count == 1)
        #expect(hub.diagnosticAnnotations.first?.kind == .error)
        #expect(bridge.counts.errors == 1)
    }

    @Test func clearsOnEmptyEmission() async throws {
        let storage = NSTextStorage(string: "let x = 1\n")
        let controller = EditorController.makeForTesting(textStorage: storage)
        let hub = AnnotationsHub()
        let client = FakeLSPClient()
        let bridge = DiagnosticsBridge(
            client: client, hub: hub, controller: controller, activeURI: { "file:///x.swift" }
        )
        bridge.start()

        client.diagnostics = ["file:///x.swift": [
            LSPDiagnostic(range: LSPRange(start: .init(line: 0, character: 0),
                                          end: .init(line: 0, character: 1)),
                          severity: .error, message: "x")
        ]]
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(hub.diagnosticAnnotations.count == 1)

        client.diagnostics = [:]
        try await Task.sleep(nanoseconds: 30_000_000)
        #expect(hub.diagnosticAnnotations.isEmpty)
    }

    @Test func clampsOutOfBoundsRange() async throws {
        let storage = NSTextStorage(string: "ab\n")  // 3 chars
        let controller = EditorController.makeForTesting(textStorage: storage)
        let hub = AnnotationsHub()
        let client = FakeLSPClient()
        let bridge = DiagnosticsBridge(
            client: client, hub: hub, controller: controller, activeURI: { "file:///x.swift" }
        )
        bridge.start()

        let diag = LSPDiagnostic(
            range: LSPRange(start: .init(line: 0, character: 0), end: .init(line: 0, character: 999)),
            severity: .warning,
            message: "way too long"
        )
        client.diagnostics = ["file:///x.swift": [diag]]
        try await Task.sleep(nanoseconds: 30_000_000)

        // Did not crash. Annotation present with a clamped range.
        #expect(hub.diagnosticAnnotations.count == 1)
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DiagnosticsBridgeTests`
Expected: FAIL

- [ ] **Step 3: Write the implementation**

```swift
// Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift
#if canImport(AppKit)
import AppKit
import Combine
import CodeEditorPlugin

@MainActor
final class DiagnosticsBridge {
    struct Counts: Equatable {
        var errors = 0
        var warnings = 0
        var info = 0
        static let zero = Counts()
    }

    private(set) var counts: Counts = .zero

    private let hub: AnnotationsHub
    private let controller: EditorController
    private let activeURI: () -> String?

    // Accept either the real LSPClient or the FakeLSPClient via protocol-shaped duck typing.
    private var subscription: AnyCancellable?
    private let diagnosticsPublisher: AnyPublisher<[String: [LSPDiagnostic]], Never>

    init(
        client: LSPClient,
        hub: AnnotationsHub,
        controller: EditorController,
        activeURI: @escaping () -> String?
    ) {
        self.hub = hub
        self.controller = controller
        self.activeURI = activeURI
        self.diagnosticsPublisher = client.$diagnostics.eraseToAnyPublisher()
    }

    // Test-friendly initializer that accepts any Combine publisher of the same shape.
    init(
        client: FakeLSPClient,
        hub: AnnotationsHub,
        controller: EditorController,
        activeURI: @escaping () -> String?
    ) {
        self.hub = hub
        self.controller = controller
        self.activeURI = activeURI
        self.diagnosticsPublisher = client.$diagnostics.eraseToAnyPublisher()
    }

    func start() {
        subscription = diagnosticsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dict in
                Task { @MainActor in self?.handle(dict) }
            }
    }

    func stop() {
        subscription?.cancel()
        subscription = nil
        controller.clearAllTemporaryAttributes()
        hub.replaceDiagnosticAnnotations([])
        counts = .zero
    }

    private func handle(_ dict: [String: [LSPDiagnostic]]) {
        guard let uri = activeURI() else { return }
        let diagnostics = dict[uri] ?? []

        controller.clearAllTemporaryAttributes()

        var annotations: [Annotation] = []
        var newCounts = Counts()
        let textLength = controller.currentTextStorage?.length ?? 0

        for diag in diagnostics {
            switch diag.severity {
            case .error: newCounts.errors += 1
            case .warning: newCounts.warnings += 1
            default: newCounts.info += 1
            }

            let nsRange = nsRange(from: diag.range, textLength: textLength)
            guard nsRange.length > 0 else { continue }

            let color: NSColor = {
                switch diag.severity {
                case .error: return .systemRed
                case .warning: return .systemYellow
                default: return .systemBlue
                }
            }()

            controller.applyTemporaryAttributes(
                [
                    .underlineColor: color,
                    .underlineStyle: NSUnderlineStyle([.single, .patternDot]).rawValue
                ],
                to: nsRange
            )

            let kind: AnnotationKind = {
                switch diag.severity {
                case .error: return .error
                case .warning: return .warning
                default: return .info
                }
            }()

            annotations.append(Annotation(
                id: UUID(),
                kind: kind,
                range: nsRange,
                text: diag.message
            ))
        }

        hub.replaceDiagnosticAnnotations(annotations)
        counts = newCounts
    }

    private func nsRange(from lspRange: LSPRange, textLength: Int) -> NSRange {
        // For diagnostics that span columns within a line, convert via the
        // text content. For multi-line, approximate by taking start..end of
        // line range. The simplest correct path: ask the controller for a
        // line/column → offset mapping if available; otherwise approximate.
        guard let storage = controller.currentTextStorage else {
            return NSRange(location: 0, length: 0)
        }
        let nsString = storage.string as NSString
        let startOffset = offset(forLine: lspRange.start.line, character: lspRange.start.character, in: nsString)
        let endOffset = offset(forLine: lspRange.end.line, character: lspRange.end.character, in: nsString)
        let clampedStart = max(0, min(startOffset, textLength))
        let clampedEnd = max(clampedStart, min(endOffset, textLength))
        return NSRange(location: clampedStart, length: clampedEnd - clampedStart)
    }

    private func offset(forLine line: Int, character: Int, in nsString: NSString) -> Int {
        var current = 0
        var lineIdx = 0
        while lineIdx < line, current < nsString.length {
            let range = nsString.lineRange(for: NSRange(location: current, length: 0))
            current = range.location + range.length
            lineIdx += 1
        }
        return current + character
    }
}
#endif
```

- [ ] **Step 4: Run test to verify it passes**

Run: `swift test --filter DiagnosticsBridgeTests`
Expected: PASS, 3 tests

- [ ] **Step 5: Lint + build**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorSample`
Expected: clean

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift \
        Tests/CodeEditorSampleTests/DiagnosticsBridgeTests.swift
git commit -m "Add DiagnosticsBridge translating LSP diagnostics into annotations"
```

---

### Task 12: `LSPSampleCoordinator` — state machine

**Files:**
- Create: `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift`
- Create: `Sources/CodeEditorSample/App/LSP/ServerCapabilitiesSummary.swift`
- Test: `Tests/CodeEditorSampleTests/LSPSampleCoordinatorStateTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorSampleTests/LSPSampleCoordinatorStateTests.swift
#if canImport(AppKit)
import Testing
@testable import CodeEditorSample
@testable import CodeEditorPlugin

@MainActor
@Suite("LSPSampleCoordinator state")
struct LSPSampleCoordinatorStateTests {
    @Test func resolverFailureTransitionsToFailed() async {
        let coordinator = LSPSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(),
            serverResolver: StubProcessResolver.fails.resolve
        )

        await coordinator.start(workspaceRoot: nil)

        if case .failed(let message) = coordinator.state {
            #expect(message.contains("sourcekit-lsp"))
        } else {
            Issue.record("expected .failed, got \(coordinator.state)")
        }
    }

    @Test func stopFromOffIsANoOp() async {
        let coordinator = LSPSampleCoordinator(
            memoryMonitor: MemoryMonitor.mock(),
            serverResolver: StubProcessResolver.succeeds.resolve
        )
        #expect(coordinator.state == .off)

        await coordinator.stop()

        #expect(coordinator.state == .off)
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LSPSampleCoordinatorStateTests`
Expected: FAIL

- [ ] **Step 3: Write `ServerCapabilitiesSummary`**

```swift
// Sources/CodeEditorSample/App/LSP/ServerCapabilitiesSummary.swift
#if canImport(AppKit)
import CodeEditorPlugin

struct ServerCapabilitiesSummary: Equatable {
    let hasHover: Bool
    let hasDefinition: Bool
    let hasDiagnostics: Bool
    let hasDocumentSymbols: Bool
    let hasCompletion: Bool

    init(_ caps: ServerCapabilities?) {
        // Flags map to the framework's ServerCapabilities shape. If the
        // framework type uses optional structs (e.g., `hoverProvider: Hover?`),
        // map those to Bool.
        self.hasHover = caps?.hoverProvider != nil
        self.hasDefinition = caps?.definitionProvider != nil
        self.hasDiagnostics = caps?.diagnosticProvider != nil || caps?.publishDiagnostics == true
        self.hasDocumentSymbols = caps?.documentSymbolProvider != nil
        self.hasCompletion = caps?.completionProvider != nil
    }
}
#endif
```

If the actual `ServerCapabilities` field names differ, adjust here in one place.

- [ ] **Step 4: Write `LSPSampleCoordinator`**

```swift
// Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift
#if canImport(AppKit)
import Foundation
import Observation
import CodeEditorPlugin

@MainActor
@Observable
final class LSPSampleCoordinator {
    enum State: Equatable {
        case off
        case starting
        case initializing
        case running(capabilities: ServerCapabilitiesSummary)
        case failed(message: String)
    }

    private(set) var state: State = .off
    private(set) var diagnosticCounts: DiagnosticsBridge.Counts = .zero
    private(set) var lastError: String?
    private(set) var resolvedServerPath: URL?

    private let memoryMonitor: MemoryMonitor
    private let serverResolver: () async -> URL?
    private var manager: LSPManager?
    private var bridge: DiagnosticsBridge?
    private var mirror: DocumentMirror?

    init(
        memoryMonitor: MemoryMonitor,
        serverResolver: @escaping () async -> URL? = Self.defaultResolver
    ) {
        self.memoryMonitor = memoryMonitor
        self.serverResolver = serverResolver
    }

    func start(workspaceRoot: URL?) async {
        guard case .off = state else { return }
        state = .starting

        guard let serverURL = await serverResolver() else {
            state = .failed(message:
                "sourcekit-lsp not found. Install Xcode or run xcode-select."
            )
            return
        }
        resolvedServerPath = serverURL

        let manager = LSPManager(memoryMonitor: memoryMonitor, workspaceRoot: workspaceRoot)
        self.manager = manager

        let config = LanguageServerConfig(
            languageId: "swift",
            serverPath: serverURL.path,
            serverArguments: [],
            fileExtensions: ["swift"],
            autoStart: false
        )
        manager.registerLanguageServer(config)

        state = .initializing
        do {
            try await manager.startLanguageServer(for: "swift")
        } catch {
            state = .failed(message: error.localizedDescription)
            lastError = "\(error)"
            return
        }

        let caps = ServerCapabilitiesSummary(manager.client(for: "swift")?.serverCapabilities)
        state = .running(capabilities: caps)

        let mirrorRoot = workspaceRoot ?? FileManager.default.temporaryDirectory
            .appendingPathComponent("CodeEditorSample-LSP")
        self.mirror = DocumentMirror(rootDirectory: mirrorRoot)
        mirror?.cleanupStaleShadows()
    }

    func stop() async {
        guard state != .off else { return }
        bridge?.stop()
        bridge = nil
        if let manager = manager {
            try? await manager.stopLanguageServer(for: "swift")
        }
        manager = nil
        mirror = nil
        diagnosticCounts = .zero
        state = .off
    }

    static var defaultResolver: () async -> URL? {
        return {
            let task = Process()
            task.launchPath = "/usr/bin/xcrun"
            task.arguments = ["--find", "sourcekit-lsp"]
            let pipe = Pipe()
            task.standardOutput = pipe
            do {
                try task.run()
                task.waitUntilExit()
                guard task.terminationStatus == 0 else { return nil }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !path.isEmpty else { return nil }
                return URL(fileURLWithPath: path)
            } catch {
                return nil
            }
        }
    }
}
#endif
```

If `LanguageServerConfig`, `LSPManager`, or `MemoryMonitor.mock()` parameters differ, adjust to the actual framework signatures (verify via the framework survey results or by reading the relevant file).

- [ ] **Step 5: Run test to verify it passes**

Run: `swift test --filter LSPSampleCoordinatorStateTests`
Expected: PASS, 2 tests

- [ ] **Step 6: Lint + build**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorSample`
Expected: clean

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift \
        Sources/CodeEditorSample/App/LSP/ServerCapabilitiesSummary.swift \
        Tests/CodeEditorSampleTests/LSPSampleCoordinatorStateTests.swift
git commit -m "Add LSPSampleCoordinator with start/stop state machine"
```

---

### Task 13: Coordinator — hover, definition, text-change forwarding

**Files:**
- Modify: `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift`
- Modify: `Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift` (wire-up after start)
- Test: `Tests/CodeEditorSampleTests/LSPSampleCoordinatorRequestsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorSampleTests/LSPSampleCoordinatorRequestsTests.swift
#if canImport(AppKit)
import Testing
@testable import CodeEditorSample
@testable import CodeEditorPlugin

@MainActor
@Suite("LSPSampleCoordinator requests")
struct LSPSampleCoordinatorRequestsTests {
    @Test func handleTextChangeForwardsToMirror() throws {
        // Test the mirror forwarding path through an injected test mirror.
        // The coordinator should call mirror.handleTextChange.
        // Skeleton: integrate via a test-only `setMirrorForTesting` hook.
        // If you'd rather not add a test hook, this test can be deferred
        // and exercised through the integration test in Task 19.
    }
}
#endif
```

Note: this task's primary deliverable is forwarding methods; testing them directly requires either a test hook or the integration test. Pick whichever is more maintainable — both are acceptable.

- [ ] **Step 2: Extend `LSPSampleCoordinator` with the request and forwarding methods**

Add to `LSPSampleCoordinator`:

```swift
struct HoverContent: Equatable {
    let markdown: String
}

func handleTextChange(for tabID: UUID, newText: String) {
    mirror?.handleTextChange(id: tabID, newText: newText)
}

func openTab(_ tabID: UUID, text: String, language: Language) throws -> URL? {
    guard language == .swift else { return nil }
    return try mirror?.openTab(id: tabID, text: text, fileExtension: "swift")
}

func closeTab(_ tabID: UUID) {
    mirror?.closeTab(id: tabID)
}

func requestHover(at position: SourcePosition, in tabID: UUID) async -> HoverContent? {
    guard let manager = manager,
          let mirrorURL = mirror?.url(for: tabID) else { return nil }
    do {
        let hover = try await manager.requestHover(
            filePath: mirrorURL.path,
            line: position.line,
            character: position.character
        )
        return hover.map { HoverContent(markdown: extractMarkdown($0)) }
    } catch {
        return nil
    }
}

func requestDefinition(at position: SourcePosition, in tabID: UUID) async -> [Location] {
    guard let manager = manager,
          let mirrorURL = mirror?.url(for: tabID) else { return [] }
    return (try? await manager.requestDefinition(
        filePath: mirrorURL.path,
        line: position.line,
        character: position.character
    )) ?? []
}

private func extractMarkdown(_ hover: Hover) -> String {
    // LSP Hover.contents has several variants: MarkupContent, MarkedString,
    // or [MarkedString]. Flatten to a single markdown string. The exact
    // variant types depend on the framework's Hover model; this helper is
    // the single place to adjust if the shape differs.
    return String(describing: hover.contents)
}
```

- [ ] **Step 3: Wire the `DiagnosticsBridge` start/stop into `LSPSampleCoordinator`**

In `LSPSampleCoordinator.start(workspaceRoot:)`, after `state = .running`, add the diagnostics bridge wiring. This requires the coordinator to know the active tab's URI and the editor controller. Add these as init parameters:

```swift
// Update init:
init(
    memoryMonitor: MemoryMonitor,
    controller: EditorController,
    activeURI: @escaping @MainActor () -> String?,
    serverResolver: @escaping () async -> URL? = Self.defaultResolver
) {
    // ... existing ...
    self.controller = controller
    self.activeURI = activeURI
}

private let controller: EditorController
private let activeURI: @MainActor () -> String?
private let hub: AnnotationsHub  // pass in too if needed
```

Then in `start()`, after the manager initializes:

```swift
if let client = manager.client(for: "swift") {
    let bridge = DiagnosticsBridge(
        client: client,
        hub: hub,
        controller: controller,
        activeURI: activeURI
    )
    bridge.start()
    self.bridge = bridge
}
```

And in `stop()`:

```swift
bridge?.stop()
bridge = nil
```

The `AppState` wiring in Task 14 fills in the controller, hub, and activeURI closure.

- [ ] **Step 4: Update tests in Task 12 if signature changed**

If you renamed init parameters, update `LSPSampleCoordinatorStateTests` to pass the new args. Use a throwaway `EditorController` (e.g., `EditorController.makeForTesting(textStorage: NSTextStorage())`) and a throwaway `AnnotationsHub()`.

- [ ] **Step 5: Run all coordinator tests**

Run: `swift test --filter LSPSampleCoordinator`
Expected: PASS

- [ ] **Step 6: Lint + build**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorSample`
Expected: clean

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift \
        Sources/CodeEditorSample/App/LSP/DiagnosticsBridge.swift \
        Tests/CodeEditorSampleTests/LSPSampleCoordinator*.swift
git commit -m "Add hover, definition, and text-change forwarding to LSPSampleCoordinator"
```

---

### Task 14: Wire `AppState.lsp` and propagate edits

**Files:**
- Modify: `Sources/CodeEditorSample/App/AppState.swift`
- Modify: `Sources/CodeEditorSample/App/WindowBody.swift` (text-change forwarding)

No new tests — this is wiring; behavior is covered by integration test in Task 19.

- [ ] **Step 1: Add `lsp` property to `AppState`**

Read `Sources/CodeEditorSample/App/AppState.swift`. Add:

```swift
#if canImport(AppKit)
@MainActor
var lsp: LSPSampleCoordinator!  // initialized in init below

// Note: this addition contradicts NEXT.md item 1 (split AppState). Splitting
// AppState is deferred to its own refactor; see
// docs/superpowers/specs/2026-05-13-sample-app-lsp-integration-design.md
// (Deferred Refactors).
#endif
```

In `init()`, after `editorController` and `annotationsHub` are constructed:

```swift
#if canImport(AppKit)
self.lsp = LSPSampleCoordinator(
    memoryMonitor: MemoryMonitor(),
    controller: editorController,
    hub: annotationsHub,
    activeURI: { [weak self] in
        guard let self,
              let activeID = self.documents.activeTabID else { return nil }
        return self.lsp?.mirrorURL(for: activeID)?.absoluteString
    }
)
#endif
```

If `LSPSampleCoordinator` does not yet expose `mirrorURL(for:)`, add it as a tiny pass-through to the internal mirror.

- [ ] **Step 2: Forward text changes from `WindowBody`**

In `Sources/CodeEditorSample/App/WindowBody.swift`, find the existing `.onTextChange { newText in appState.documents.markDirty(activeID, newText: newText) }`. Add the coordinator forward:

```swift
.onTextChange { newText in
    appState.documents.markDirty(activeID, newText: newText)
    #if canImport(AppKit)
    appState.lsp.handleTextChange(for: activeID, newText: newText)
    #endif
}
```

- [ ] **Step 3: Open Swift tabs into the mirror when LSP is running**

In `LSPSampleCoordinator.start`, after the bridge is wired, iterate the current tab list and call `mirror?.openTab(id:text:fileExtension:)` for each Swift tab. This needs read access to `DocumentStore`. Two clean options:

  (a) Pass a closure `swiftTabs: () -> [(id: UUID, text: String)]` into the coordinator init. AppState supplies the closure that reads from `documents`.

  (b) Have AppState call `lsp.openTab(_:text:)` for each existing Swift tab right after `lsp.start()` returns.

Pick (b) — simpler. AppState calls:

```swift
#if canImport(AppKit)
for tab in documents.tabs where documents.language(of: tab.id) == .swift {
    let text = documents.text(for: tab.id) ?? ""
    _ = try? lsp.openTab(tab.id, text: text, language: .swift)
}
#endif
```

Add a UI-side action that runs this after a successful `lsp.start(workspaceRoot:)` (will be triggered from the `LSPInspectorPanel` in Task 15).

- [ ] **Step 4: Build the sample target**

Run: `swift build --target CodeEditorSample`
Expected: success

- [ ] **Step 5: Lint**

Run: `swiftlint --fix && swiftlint`
Expected: zero violations

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorSample/App/AppState.swift \
        Sources/CodeEditorSample/App/WindowBody.swift \
        Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift
git commit -m "Wire LSPSampleCoordinator into AppState and edit propagation"
```

---

## Phase 3 — Sample UI

### Task 15: `LSPInspectorPanel` view (replaces `LSPStatusPanel.swift`)

**Files:**
- Create: `Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift`
- Delete: `Sources/CodeEditorSample/Sidebars/LSPStatusPanel.swift`
- Modify: `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift` (replace the panel reference)
- Test: `Tests/CodeEditorSampleTests/LSPInspectorPanelSnapshotTests.swift`

- [ ] **Step 1: Write the failing snapshot test**

```swift
// Tests/CodeEditorSampleTests/LSPInspectorPanelSnapshotTests.swift
#if canImport(AppKit)
import XCTest
import SwiftUI
import SnapshotTesting
@testable import CodeEditorSample

final class LSPInspectorPanelSnapshotTests: XCTestCase {
    func render(_ panel: LSPInspectorPanel) -> NSView {
        let host = NSHostingView(rootView: panel.frame(width: 360, height: 220))
        host.layoutSubtreeIfNeeded()
        return host
    }

    @MainActor
    func testOffState() {
        let panel = LSPInspectorPanel(state: .off, counts: .zero,
                                      serverPath: nil, lastError: nil,
                                      isSwiftActive: true,
                                      onToggle: {})
        assertSnapshot(of: render(panel), as: .image, named: "off")
    }

    @MainActor
    func testStartingState() {
        let panel = LSPInspectorPanel(state: .starting, counts: .zero,
                                      serverPath: nil, lastError: nil,
                                      isSwiftActive: true,
                                      onToggle: {})
        assertSnapshot(of: render(panel), as: .image, named: "starting")
    }

    @MainActor
    func testRunningStateWithCounts() {
        let caps = ServerCapabilitiesSummary(
            hasHover: true, hasDefinition: true, hasDiagnostics: true,
            hasDocumentSymbols: true, hasCompletion: true
        )
        let panel = LSPInspectorPanel(
            state: .running(capabilities: caps),
            counts: .init(errors: 3, warnings: 1, info: 0),
            serverPath: URL(fileURLWithPath: "/Applications/Xcode.app/Contents/Developer/usr/bin/sourcekit-lsp"),
            lastError: nil, isSwiftActive: true, onToggle: {}
        )
        assertSnapshot(of: render(panel), as: .image, named: "running")
    }

    @MainActor
    func testFailedState() {
        let panel = LSPInspectorPanel(
            state: .failed(message: "sourcekit-lsp not found"),
            counts: .zero,
            serverPath: nil,
            lastError: "sourcekit-lsp not found",
            isSwiftActive: true, onToggle: {}
        )
        assertSnapshot(of: render(panel), as: .image, named: "failed")
    }

    @MainActor
    func testNonSwiftTabDisablesToggle() {
        let panel = LSPInspectorPanel(state: .off, counts: .zero,
                                      serverPath: nil, lastError: nil,
                                      isSwiftActive: false,
                                      onToggle: {})
        assertSnapshot(of: render(panel), as: .image, named: "non-swift")
    }
}
#endif
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LSPInspectorPanelSnapshotTests`
Expected: FAIL with "no such type 'LSPInspectorPanel'"

- [ ] **Step 3: Write the view**

```swift
// Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift
#if canImport(AppKit)
import SwiftUI
import CodeEditorPlugin

struct LSPInspectorPanel: View {
    let state: LSPSampleCoordinator.State
    let counts: DiagnosticsBridge.Counts
    let serverPath: URL?
    let lastError: String?
    let isSwiftActive: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Language Server").font(.headline)
                Spacer()
                statePill
            }

            Toggle(isOn: Binding(get: { isRunning }, set: { _ in onToggle() })) {
                Text("Attach sourcekit-lsp")
            }
            .disabled(!isSwiftActive || isTransitioning)

            if case .running(let caps) = state {
                capabilitiesView(caps)
                countsRow
            }

            if case .failed(let message) = state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let path = serverPath {
                Text(path.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
    }

    private var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    private var isTransitioning: Bool {
        switch state {
        case .starting, .initializing: return true
        default: return false
        }
    }

    private var statePill: some View {
        Text(stateLabel)
            .font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(stateColor.opacity(0.2))
            .clipShape(Capsule())
    }

    private var stateLabel: String {
        switch state {
        case .off: return "Off"
        case .starting: return "Starting…"
        case .initializing: return "Initializing…"
        case .running: return "Running"
        case .failed: return "Failed"
        }
    }

    private var stateColor: Color {
        switch state {
        case .off: return .gray
        case .starting, .initializing: return .blue
        case .running: return .green
        case .failed: return .red
        }
    }

    private var countsRow: some View {
        HStack(spacing: 12) {
            Label("\(counts.errors)", systemImage: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
            Label("\(counts.warnings)", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Label("\(counts.info)", systemImage: "info.circle.fill")
                .foregroundStyle(.blue)
        }
        .font(.caption)
    }

    private func capabilitiesView(_ caps: ServerCapabilitiesSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            row("Hover", caps.hasHover)
            row("Definition", caps.hasDefinition)
            row("Diagnostics", caps.hasDiagnostics)
            row("Document symbols", caps.hasDocumentSymbols)
            row("Completion", caps.hasCompletion)
        }
        .font(.caption)
    }

    private func row(_ label: String, _ value: Bool) -> some View {
        HStack {
            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(value ? .green : .secondary)
            Text(label)
        }
    }
}
#endif
```

- [ ] **Step 4: Record snapshots**

Switch the snapshot tests to recording mode (`isRecording: true` at the top of the test file) and run once:

Run: `swift test --filter LSPInspectorPanelSnapshotTests`
Expected: PASS (tests "fail" the first time but write snapshots)

Re-run after setting `isRecording = false`:
Expected: PASS, 5 snapshots match

Commit the snapshot images (they live under `Tests/CodeEditorSampleTests/__Snapshots__/LSPInspectorPanelSnapshotTests/`).

- [ ] **Step 5: Replace the old panel in `InspectorSidebar.swift`**

Read `Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift`. Replace the `LSPStatusPanel(...)` call with:

```swift
LSPInspectorPanel(
    state: appState.lsp.state,
    counts: appState.lsp.diagnosticCounts,
    serverPath: appState.lsp.resolvedServerPath,
    lastError: appState.lsp.lastError,
    isSwiftActive: appState.documents.activeLanguage == .swift,
    onToggle: {
        Task {
            switch appState.lsp.state {
            case .off, .failed:
                await appState.lsp.start(workspaceRoot: appState.workspaceRoot)
                // After start, open existing Swift tabs into the mirror.
                for tab in appState.documents.tabs
                    where appState.documents.language(of: tab.id) == .swift {
                    let text = appState.documents.text(for: tab.id) ?? ""
                    _ = try? appState.lsp.openTab(tab.id, text: text, language: .swift)
                }
            case .running:
                await appState.lsp.stop()
            default:
                break
            }
        }
    }
)
```

- [ ] **Step 6: Delete the old panel**

```bash
git rm Sources/CodeEditorSample/Sidebars/LSPStatusPanel.swift
```

- [ ] **Step 7: Build + lint**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorSample`
Expected: clean

- [ ] **Step 8: Commit**

```bash
git add Sources/CodeEditorSample/Sidebars/LSPInspectorPanel.swift \
        Sources/CodeEditorSample/Sidebars/InspectorSidebar.swift \
        Tests/CodeEditorSampleTests/LSPInspectorPanelSnapshotTests.swift \
        Tests/CodeEditorSampleTests/__Snapshots__/LSPInspectorPanelSnapshotTests
git rm Sources/CodeEditorSample/Sidebars/LSPStatusPanel.swift
git commit -m "Replace LSPStatusPanel with LSPInspectorPanel showing live state"
```

---

### Task 16: `HoverSession` and `LSPHoverPopover`

**Files:**
- Create: `Sources/CodeEditorSample/App/LSP/HoverSession.swift`
- Create: `Sources/CodeEditorSample/App/LSP/LSPHoverPopover.swift`

- [ ] **Step 1: Write `HoverSession`**

```swift
// Sources/CodeEditorSample/App/LSP/HoverSession.swift
#if canImport(AppKit)
import Foundation
import Observation

@MainActor
@Observable
final class HoverSession {
    struct Display: Identifiable, Equatable {
        let id = UUID()
        let markdown: String
    }

    private(set) var displayed: Display?

    func show(markdown: String) {
        displayed = Display(markdown: markdown)
    }

    func dismiss() {
        displayed = nil
    }
}
#endif
```

- [ ] **Step 2: Write `LSPHoverPopover`**

```swift
// Sources/CodeEditorSample/App/LSP/LSPHoverPopover.swift
#if canImport(AppKit)
import SwiftUI

struct LSPHoverPopover: View {
    let markdown: String

    var body: some View {
        ScrollView {
            Text(LocalizedStringKey(markdown))
                .textSelection(.enabled)
                .padding(8)
        }
        .frame(minWidth: 280, idealWidth: 360, maxWidth: 480,
               minHeight: 40, idealHeight: 120, maxHeight: 300)
    }
}
#endif
```

- [ ] **Step 3: Expose `HoverSession` on the coordinator**

In `LSPSampleCoordinator`:

```swift
let hoverSession = HoverSession()
```

- [ ] **Step 4: Build + lint**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorSample`
Expected: clean

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorSample/App/LSP/HoverSession.swift \
        Sources/CodeEditorSample/App/LSP/LSPHoverPopover.swift \
        Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift
git commit -m "Add HoverSession state and LSPHoverPopover view"
```

---

### Task 17: Wire hover and ⌘-click into `WindowBody`

**Files:**
- Modify: `Sources/CodeEditorSample/App/WindowBody.swift`

No new tests — integration test in Task 19 covers behavior.

- [ ] **Step 1: Attach the modifiers**

In `WindowBody.swift`, locate where the `CodeEditor` view is constructed. Add chained modifiers:

```swift
CodeEditor(text: appState.documents.textBinding(for: activeID))
    .onTextChange { newText in
        appState.documents.markDirty(activeID, newText: newText)
        #if canImport(AppKit)
        appState.lsp.handleTextChange(for: activeID, newText: newText)
        #endif
    }
    .editorController(appState.editorController)
    .editorInteractionState(appState.documents.interactionBinding(for: activeID))
    .codeEditorEnvironment(
        language: appState.documents.activeLanguage ?? .plainText,
        configuration: appState.configuration,
        becomeFirstResponder: .yes,
        workspaceRoot: appState.workspaceRoot
    )
    #if canImport(AppKit)
    .onTextHover { position in
        guard case .running = appState.lsp.state else { return }
        guard let position else {
            appState.lsp.hoverSession.dismiss()
            return
        }
        let content = await appState.lsp.requestHover(at: position, in: activeID)
        if let content {
            appState.lsp.hoverSession.show(markdown: content.markdown)
        } else {
            appState.lsp.hoverSession.dismiss()
        }
    }
    .onCommandClick { position in
        Task {
            await appState.lsp.jumpToDefinition(at: position, in: activeID)
        }
    }
    .popover(item: Binding(
        get: { appState.lsp.hoverSession.displayed },
        set: { appState.lsp.hoverSession.displayed = $0 }
    )) { display in
        LSPHoverPopover(markdown: display.markdown)
    }
    #endif
    .frame(maxWidth: .infinity, maxHeight: .infinity)
```

- [ ] **Step 2: Build + lint**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorSample`
Expected: clean (note: `jumpToDefinition` doesn't exist yet — temporarily stub it as `func jumpToDefinition(at:in:) async {}` on the coordinator and implement in Task 18)

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorSample/App/WindowBody.swift \
        Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift
git commit -m "Attach hover popover and command-click handlers to editor view"
```

---

### Task 18: Definition jump implementation

**Files:**
- Modify: `Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift`
- Test: `Tests/CodeEditorSampleTests/LSPSampleCoordinatorDefinitionTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// Tests/CodeEditorSampleTests/LSPSampleCoordinatorDefinitionTests.swift
#if canImport(AppKit)
import Testing
import Foundation
@testable import CodeEditorSample
@testable import CodeEditorPlugin

@MainActor
@Suite("LSPSampleCoordinator definition")
struct LSPSampleCoordinatorDefinitionTests {
    @Test func reportsToastForOutOfWorkspaceLocation() async {
        let coordinator = LSPSampleCoordinator.makeTestInstance()
        let outside = Location(
            uri: "file:///Applications/Xcode.app/Foundation.swift",
            range: LSPRange(start: .init(line: 10, character: 0),
                            end: .init(line: 10, character: 5))
        )
        coordinator.setTestDefinitionResponse([outside])

        let result = await coordinator.resolveDefinitionTarget(
            locations: [outside],
            workspaceRoot: URL(fileURLWithPath: "/Users/me/proj")
        )

        if case .toast(let message) = result {
            #expect(message.contains("Foundation.swift"))
        } else {
            Issue.record("expected .toast, got \(result)")
        }
    }

    @Test func reportsOpenForInWorkspaceLocation() async {
        let coordinator = LSPSampleCoordinator.makeTestInstance()
        let inside = Location(
            uri: "file:///Users/me/proj/Foo.swift",
            range: LSPRange(start: .init(line: 3, character: 0),
                            end: .init(line: 3, character: 1))
        )

        let result = await coordinator.resolveDefinitionTarget(
            locations: [inside],
            workspaceRoot: URL(fileURLWithPath: "/Users/me/proj")
        )

        if case .openInWorkspace(let url, let line) = result {
            #expect(url.path == "/Users/me/proj/Foo.swift")
            #expect(line == 3)
        } else {
            Issue.record("expected .openInWorkspace, got \(result)")
        }
    }

    @Test func reportsEmptyForNoLocations() async {
        let coordinator = LSPSampleCoordinator.makeTestInstance()
        let result = await coordinator.resolveDefinitionTarget(
            locations: [],
            workspaceRoot: URL(fileURLWithPath: "/Users/me/proj")
        )

        if case .none = result {
            // pass
        } else {
            Issue.record("expected .none, got \(result)")
        }
    }
}
#endif
```

You may need a `makeTestInstance()` static factory and `setTestDefinitionResponse(_:)` test hook on `LSPSampleCoordinator`. Add them under `#if DEBUG` or as test-only helpers.

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter LSPSampleCoordinatorDefinitionTests`
Expected: FAIL

- [ ] **Step 3: Implement `jumpToDefinition` and the pure resolver helper**

In `LSPSampleCoordinator`:

```swift
enum DefinitionTarget: Equatable {
    case openInWorkspace(url: URL, line: Int)
    case toast(message: String)
    case none
}

func jumpToDefinition(at position: SourcePosition, in tabID: UUID) async {
    let locations = await requestDefinition(at: position, in: tabID)
    let target = await resolveDefinitionTarget(
        locations: locations,
        workspaceRoot: currentWorkspaceRoot
    )
    apply(target: target)
}

func resolveDefinitionTarget(
    locations: [Location],
    workspaceRoot: URL?
) async -> DefinitionTarget {
    guard let first = locations.first,
          let uri = URL(string: first.uri) else {
        return locations.isEmpty ? .none : .toast(message: "No definition found.")
    }
    let path = uri.path
    if let root = workspaceRoot, path.hasPrefix(root.path) {
        return .openInWorkspace(url: uri, line: first.range.start.line)
    } else {
        return .toast(message: "Defined in \(path):\(first.range.start.line)")
    }
}

private func apply(target: DefinitionTarget) {
    switch target {
    case .openInWorkspace(let url, let line):
        if let id = onRequestOpen?(url) {
            onRequestScroll?(id, line)
        }
    case .toast(let message):
        lastError = message  // surfaced in LSPInspectorPanel as the "last error" line
    case .none:
        break
    }
}

// AppState injects these closures so the coordinator stays UI-free.
var onRequestOpen: ((URL) -> UUID?)?
var onRequestScroll: ((UUID, Int) -> Void)?

var currentWorkspaceRoot: URL?
```

- [ ] **Step 4: Wire the closures in `AppState.init`**

```swift
#if canImport(AppKit)
self.lsp.onRequestOpen = { [weak self] url in
    self?.documents.openFile(url: url)
}
self.lsp.onRequestScroll = { [weak self] id, line in
    self?.editorController.scrollToLine(line)
}
#endif
```

Also keep `lsp.currentWorkspaceRoot` synced when `workspaceRoot` changes:

```swift
// In a didSet on workspaceRoot, or via a SwiftUI .onChange in WindowBody:
appState.lsp.currentWorkspaceRoot = appState.workspaceRoot
```

If `EditorController.scrollToLine(_:)` does not exist, use whichever scroll API the controller exposes (e.g., `goto(line:)` or `scrollLine(toVisible:)`); verify by reading the controller.

- [ ] **Step 5: Run test**

Run: `swift test --filter LSPSampleCoordinatorDefinitionTests`
Expected: PASS, 3 tests

- [ ] **Step 6: Build + lint**

Run: `swiftlint --fix && swiftlint && swift build --target CodeEditorSample`
Expected: clean

- [ ] **Step 7: Commit**

```bash
git add Sources/CodeEditorSample/App/LSP/LSPSampleCoordinator.swift \
        Sources/CodeEditorSample/App/AppState.swift \
        Tests/CodeEditorSampleTests/LSPSampleCoordinatorDefinitionTests.swift
git commit -m "Implement jumpToDefinition with workspace-vs-stdlib branching"
```

---

## Phase 4 — Validation

### Task 19: Live integration smoke test (gated)

**Files:**
- Create: `Tests/CodeEditorSampleTests/LSPLiveIntegrationTests.swift`

- [ ] **Step 1: Write the gated test**

```swift
// Tests/CodeEditorSampleTests/LSPLiveIntegrationTests.swift
#if canImport(AppKit)
import XCTest
@testable import CodeEditorSample
@testable import CodeEditorPlugin

final class LSPLiveIntegrationTests: XCTestCase {
    func testDiagnosticAppearsForKnownTypeError() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CODE_EDITOR_LSP_LIVE"] == "1",
            "Set CODE_EDITOR_LSP_LIVE=1 to run live sourcekit-lsp tests."
        )

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("LSPLive-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let storage = NSTextStorage(string: "let x: Int = \"oops\"\n")
        let controller = await EditorController.makeForTesting(textStorage: storage)
        let hub = await AnnotationsHub()

        let coordinator = await LSPSampleCoordinator(
            memoryMonitor: MemoryMonitor(),
            controller: controller,
            hub: hub,
            activeURI: { nil }
        )

        await coordinator.start(workspaceRoot: tmp)
        let id = UUID()
        let url = try await coordinator.openTab(id, text: storage.string, language: .swift)
        XCTAssertNotNil(url)

        // Wait up to 10s for diagnostics to arrive
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            let count = await MainActor.run { hub.diagnosticAnnotations.count }
            if count > 0 { break }
            try await Task.sleep(nanoseconds: 250_000_000)
        }

        let final = await MainActor.run { hub.diagnosticAnnotations }
        XCTAssertFalse(final.isEmpty, "expected at least one diagnostic")
        XCTAssertTrue(final.contains { $0.kind == .error })

        await coordinator.stop()
    }
}
#endif
```

- [ ] **Step 2: Run gated test locally (optional)**

Run: `CODE_EDITOR_LSP_LIVE=1 swift test --filter LSPLiveIntegrationTests`
Expected: PASS when sourcekit-lsp is installed; otherwise the test is skipped.

Run without the env var: `swift test --filter LSPLiveIntegrationTests`
Expected: SKIPPED with the documented message.

- [ ] **Step 3: Commit**

```bash
git add Tests/CodeEditorSampleTests/LSPLiveIntegrationTests.swift
git commit -m "Add gated live-sourcekit-lsp integration smoke test"
```

---

### Task 20: Quality pipeline + manual verification

- [ ] **Step 1: Full quality run**

Run: `swift build && swiftlint --fix && swiftlint && swift test --parallel`
Expected: build success, zero lint violations, all tests pass (live test skipped without env var).

- [ ] **Step 2: Sample app smoke build for both platforms**

Run:
```bash
swift build --target CodeEditorSample
xcrun --sdk iphonesimulator swift build --target CodeEditorSample 2>&1 | tail -20
```
Expected: both succeed. iOS build should compile without errors because the whole feature is gated.

- [ ] **Step 3: Manual verification on macOS**

Run: `swift run CodeEditorSample`

Tick each item:

- [ ] Toggle LSP on with no workspaceRoot → state progresses to Running.
- [ ] Toggle on with workspaceRoot set to a real Swift package → state progresses to Running, panel shows the resolved sourcekit-lsp path.
- [ ] Edit a Swift file, introduce `let x: Int = "oops"` → red squiggle + gutter badge appear within ~1s.
- [ ] Fix the error → squiggle + badge disappear.
- [ ] Hover over an identifier → markdown popover after ~500ms.
- [ ] ⌘-click an in-workspace identifier → opens the correct file at the correct line.
- [ ] ⌘-click a stdlib identifier → inspector's last-error line shows the path.
- [ ] Toggle off → all squiggles, gutter badges, popover dismissed; shadow files deleted.
- [ ] Kill `sourcekit-lsp` via `kill <pid>` → after retries exhaust, state → Failed.
- [ ] iOS simulator build runs without `LSPInspectorPanel` visible; app otherwise unchanged.

- [ ] **Step 4: Commit any final cleanups**

If the manual run surfaces fix-it issues, address them and commit each separately. No catch-all "fix everything" commit.

- [ ] **Step 5: Final commit message for the feature branch**

When the branch is ready for review, ensure each commit has a clear standalone message — no squash-style mega-commits. The branch should read as the design coming to life one component at a time.

---

## Self-Review

(Performed by the plan author before handoff.)

**Spec coverage:** Each section of the spec maps to tasks:
- Framework `SourcePosition` → Task 1
- Framework `applyTemporaryAttributes` → Tasks 2, 3
- Framework `.onTextHover` + `.onCommandClick` → Tasks 4, 5, 6
- Sample `LSPSampleCoordinator` → Tasks 12, 13
- Sample `DocumentMirror` → Task 9
- Sample `DiagnosticsBridge` → Task 11
- Sample `LSPInspectorPanel` (replaces old) → Task 15
- Sample `HoverSession` + `LSPHoverPopover` → Tasks 16, 17
- Sample `DocumentStore.openFile` → Task 8
- Sample `AnnotationsHub.replaceDiagnosticAnnotations` → Task 7
- Sample `AppState.lsp` wiring → Task 14
- Definition-jump workspace branching → Task 18
- Test doubles → Task 10
- Manual verification checklist → Task 20

**Placeholder scan:** Tasks include several "find the file first" or "if the framework type differs, adjust" notes. These are not blockers — they're acknowledgements that the spec described the intended shape and the implementer adapts to actual names. Verified: no "TODO", "TBD", or empty test bodies (the one stub in Task 13 is explicitly justified).

**Type consistency:** `LSPSampleCoordinator.State` uses `.running(capabilities:)` consistently. `DiagnosticsBridge.Counts` named consistently in the coordinator and panel. `Annotation.kind` is one of `.error/.warning/.info`. `Location` and `Hover` are the framework's existing LSP types; `LSPDiagnostic`, `LSPRange`, `LSPPosition` likewise.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-13-sample-app-lsp-integration.md`. Two execution options:

**1. Subagent-Driven (recommended)** — fresh subagent per task, two-stage review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints for review.

Which approach?
