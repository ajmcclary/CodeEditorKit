# Delegate Multiplexer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace every `textView.delegate = …` assignment in the framework with a single internal `TextViewDelegateMultiplexer` owned by `CodeEditorView`, so `SmartEditingEngine.attach`, the iOS container, the iOS SwiftUI coordinator, and the existing host-delegate proxy stop fighting over the slot. Encode the host-veto-before-behavior-side-effect invariant in a two-phase participant protocol; add a SwiftLint guard so the regression class is structurally closed.

**Architecture:** A new internal `TextViewDelegateParticipant` protocol (with default impls) plus an internal `TextViewDelegateMultiplexer: NSObject` conforming to `NSTextViewDelegate` (macOS) / `UITextViewDelegate` (iOS). The multiplexer walks two weakly-held participant lists — `.gating` (one slot: `CodeEditorViewDelegateProxy`) and `.behavior` (SmartEditingEngine, iOS container, iOS SwiftUI coordinator) — with per-method semantics: veto chain for `shouldChangeTextIn`, fan-out for notifications, first-non-nil-wins for value-returning methods, first-handler-wins for clicks, all-must-agree for attachment interaction. The multiplexer's own intrinsic side-effect (`publishWillEditEvent`) runs after both phases vote allow.

**Tech Stack:** Swift 6.3 (StrictConcurrency), XCTest. Spec at `docs/superpowers/specs/2026-05-14-delegate-multiplexer-design.md` (commit `a28c174`).

---

## File Structure

**Framework — 2 added, 6 modified:**
- Create: `Sources/CodeEditorPlugin/Core/TextViewDelegateParticipant.swift` — protocol + `TextViewDelegatePhase` enum + default-impl extension.
- Create: `Sources/CodeEditorPlugin/Core/TextViewDelegateMultiplexer.swift` — class + weak storage + platform-`#if` delegate conformance + per-method impls + intrinsic `publishWillEditEvent`.
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift` — add `internal let delegateMultiplexer`, `addDelegateParticipant(_:phase:)` and `removeDelegateParticipant(_:)` convenience methods, and a paragraph in the named-commit invariant block at lines 159-188.
- Modify: `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift` — replace `if textView.delegate == nil { textView.delegate = textView.delegateProxy }` with multiplexer registration + install.
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegateProxy.swift` — conform to `TextViewDelegateParticipant`, drop `NSTextViewDelegate`/`UITextViewDelegate` extensions at lines 212/214, remove the two `publishWillEditEvent` call sites at lines 164 and 200.
- Modify: `Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift` — drop `NSTextViewDelegate`/`UITextViewDelegate` extensions at lines 149-203 / 204-249, conform to `TextViewDelegateParticipant`, replace `textView.delegate = self` at line 60 with `addDelegateParticipant`, delete the "Replacing existing text view delegate" warning log at lines 57-59, add `detach()`.
- Modify: `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+UIKitExtensions.swift` — drop `UITextViewDelegate` extension at line 248, conform to `TextViewDelegateParticipant` in a new extension, replace `textView.delegate = self` at line 75 with `addDelegateParticipant`.
- Modify: `Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift` — replace `components.textView.delegate = container` at line 213 with `addDelegateParticipant`, update the "Set delegate LAST" comment.
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift` — drop `UITextViewDelegate` from iOS `CodeEditorCoordinator` conformance at line 464, conform to `TextViewDelegateParticipant`, delete `scrollView*` methods at lines 495-528 (pure forwarding), repurpose `setupTextViewDelegate(_:)` at lines 480-482.

**Tests — 4 added:**
- Create: `Tests/CodeEditorPluginTests/Core/TextViewDelegateMultiplexerTests.swift` — 12 unit tests using a local `MockParticipant` double.
- Create: `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift` — 3 regression tests covering the REVIEW.md bug.
- Create: `Tests/CodeEditorPluginTests/Layout/IOSContainerMultiplexerTests.swift` — iOS-only, 1 regression test for scroll forwarding.
- Create: `Tests/CodeEditorPluginTests/SwiftUI/IOSCoordinatorMultiplexerTests.swift` — iOS-only, 1 regression test for text-binding mirroring.

**Config — 1 modified:**
- Modify: `.swiftlint.yml` — add `forbidden_text_view_delegate_assignment` custom rule under `custom_rules:`.

**Docs — 1 modified:**
- Modify: `REVIEW.md` — add a "Delegate multiplexer batch" status entry under "What's left after this round" once the work lands.

---

## PR boundaries

Per the spec's recommended PR shape:

- **PR #1 — Load-bearing macOS path.** Tasks 1–7 (scaffolding, unit tests, CodeEditorView integration, proxy migration, TextKitSetupHelper rewire, proxy regression test).
- **PR #2 — SmartEditingEngine fix.** Tasks 8–9 (engine migration + regression tests). Closes the REVIEW.md bug.
- **PR #3 — iOS cleanup + lint guard.** Tasks 10–13 (iOS container, iOS coordinator, iOS regression tests, SwiftLint rule + invariant doc).

Each task ends in a commit. A checkpoint comment between tasks 7/8 and 9/10 (the PR boundaries) reminds the executor to run the full quality pipeline before opening the next PR.

---

## Task 1: Add `TextViewDelegateParticipant` protocol

**Files:**
- Create: `Sources/CodeEditorPlugin/Core/TextViewDelegateParticipant.swift`

Pure scaffolding — no consumers yet. The protocol + phase enum + default-impl extension. Subsequent tasks reference these symbols.

- [ ] **Step 1: Create the file**

Create `Sources/CodeEditorPlugin/Core/TextViewDelegateParticipant.swift`:

```swift
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Phase

/// The ordering bucket a `TextViewDelegateParticipant` registers in.
///
/// `.gating` participants run first for veto-style methods
/// (`shouldChangeTextIn`). A `.gating` participant returning `false`
/// short-circuits before any `.behavior` participant is consulted, so
/// behavioural side-effects (e.g. `SmartEditingEngine`'s auto-indent
/// writing to `textStorage`) never fire on a host-vetoed edit.
///
/// For every other delegate method, phase determines only iteration
/// order (`.gating` first, then `.behavior`) — the per-method semantics
/// (fan-out, first-non-nil-wins, first-handler-wins, all-must-agree)
/// are identical across phases.
@MainActor
internal enum TextViewDelegatePhase {
    /// Host gating, `isEditable` checks, read-only regions.
    case gating
    /// Smart-editing interception, scroll forwarding, SwiftUI coordinator
    /// state mirroring.
    case behavior
}

// MARK: - Participant protocol

/// An object that participates in the framework's delegate multiplexer.
///
/// Internal-only. Hosts continue to use `CodeEditorViewDelegate` via
/// `CodeEditorView.textDelegate`; only framework-internal types adopt
/// this protocol to plug into `TextViewDelegateMultiplexer`.
///
/// Every method has a default implementation that returns the
/// AppKit/UIKit "allow / no-op / nil / false" default, so participants
/// only implement the methods they care about.
@MainActor
internal protocol TextViewDelegateParticipant: AnyObject {
    // Veto chain — default true (allow).
    func textView(
        _ textView: CodeEditorView,
        shouldChangeTextIn range: NSRange,
        replacementString: String?
    ) -> Bool

    // Fan-out notifications — default no-op.
    func textViewWillChangeText(_ textView: CodeEditorView)
    func textViewDidChangeText(_ textView: CodeEditorView)
    func textViewDidChangeSelection(_ textView: CodeEditorView)

    // First-non-nil-wins — default nil.
    func undoManager(for textView: CodeEditorView) -> UndoManager?
    func completionViewController(for textView: CodeEditorView)
        -> (any CompletionViewControllerRepresentable)?
    func insertionPointView(
        for textView: CodeEditorView,
        frame: CGRect
    ) -> (any InsertionPointIndicating)?

    // First-handler-wins — default false.
    func textView(
        _ textView: CodeEditorView,
        clickedOnLink link: Any,
        at location: any NSTextLocation
    ) -> Bool
    func textView(
        _ textView: CodeEditorView,
        clickedOnAttachment attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool

    // All-must-agree — default true.
    func textView(
        _ textView: CodeEditorView,
        shouldAllowInteractionWith attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool

    #if canImport(UIKit)
    // Fan-out scroll callbacks — default no-op.
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool)
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    #endif
}

// MARK: - Default implementations

internal extension TextViewDelegateParticipant {
    func textView(
        _: CodeEditorView,
        shouldChangeTextIn _: NSRange,
        replacementString _: String?
    ) -> Bool { true }

    func textViewWillChangeText(_: CodeEditorView) {}
    func textViewDidChangeText(_: CodeEditorView) {}
    func textViewDidChangeSelection(_: CodeEditorView) {}

    func undoManager(for _: CodeEditorView) -> UndoManager? { nil }

    func completionViewController(
        for _: CodeEditorView
    ) -> (any CompletionViewControllerRepresentable)? { nil }

    func insertionPointView(
        for _: CodeEditorView,
        frame _: CGRect
    ) -> (any InsertionPointIndicating)? { nil }

    func textView(
        _: CodeEditorView,
        clickedOnLink _: Any,
        at _: any NSTextLocation
    ) -> Bool { false }

    func textView(
        _: CodeEditorView,
        clickedOnAttachment _: NSTextAttachment,
        at _: any NSTextLocation
    ) -> Bool { false }

    func textView(
        _: CodeEditorView,
        shouldAllowInteractionWith _: NSTextAttachment,
        at _: any NSTextLocation
    ) -> Bool { true }

    #if canImport(UIKit)
    func scrollViewDidScroll(_: UIScrollView) {}
    func scrollViewWillBeginDragging(_: UIScrollView) {}
    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate _: Bool) {}
    func scrollViewDidEndDecelerating(_: UIScrollView) {}
    #endif
}
```

- [ ] **Step 2: Verify the framework still builds**

Run:
```bash
swift build --target CodeEditorPlugin
```

Expected: build succeeds with no warnings. The new protocol is compiled but unreferenced.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/TextViewDelegateParticipant.swift
git commit -m "$(cat <<'EOF'
Add TextViewDelegateParticipant protocol + phase enum

Internal scaffolding for the delegate multiplexer landing in subsequent
commits. Default implementations preserve AppKit/UIKit defaults so
participants only implement the methods they care about. No consumers yet.

Spec: docs/superpowers/specs/2026-05-14-delegate-multiplexer-design.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: Add `TextViewDelegateMultiplexer` class

**Files:**
- Create: `Sources/CodeEditorPlugin/Core/TextViewDelegateMultiplexer.swift`

The class itself + weak storage + platform-`#if` delegate conformance with per-method impls. Still no consumers — Task 5 wires it into `CodeEditorView`.

- [ ] **Step 1: Create the file**

Create `Sources/CodeEditorPlugin/Core/TextViewDelegateMultiplexer.swift`:

```swift
import Foundation
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

// MARK: - Multiplexer

/// The sole owner of `CodeEditorView`'s `textView.delegate` slot.
///
/// Every framework-internal feature that wants delegate hooks registers
/// as a `TextViewDelegateParticipant` at either `.gating` (host
/// gating / `isEditable` checks — exactly one participant: the
/// `CodeEditorViewDelegateProxy`) or `.behavior` (smart editing, scroll
/// forwarding, SwiftUI coordinator state mirroring).
///
/// Per-method semantics:
/// - `shouldChangeTextIn:`: veto chain. Any participant returning
///   `false` blocks the edit. `.gating` runs first; a gating veto
///   short-circuits before any `.behavior` participant fires.
/// - Notifications and iOS scroll callbacks: fan-out, registration
///   order, no early-out.
/// - `undoManager(for:)`, `completionViewController(for:)`,
///   `insertionPointView(for:frame:)`: first-non-nil-wins.
/// - `clickedOnLink` / `clickedOnAttachment`: first-handler-wins
///   (returns `true` at the first participant that returns `true`).
/// - `shouldAllowInteractionWith attachment:`: all-must-agree (any
///   `false` vetoes; default `true`).
///
/// After both phases vote allow on `shouldChangeTextIn:`, the
/// multiplexer publishes `WillEditEvent` to the
/// `TextEditEventHub` consumers as an intrinsic side-effect.
@MainActor
internal final class TextViewDelegateMultiplexer: NSObject {
    // MARK: - Storage

    private var gatingParticipants: [WeakParticipant] = []
    private var behaviorParticipants: [WeakParticipant] = []

    // MARK: - Registration

    /// Register a participant at the given phase. Identity-deduplicated
    /// (`===`) — registering the same participant twice is a no-op.
    /// Prunes dead weak slots as a side-effect.
    internal func addParticipant(
        _ participant: any TextViewDelegateParticipant,
        phase: TextViewDelegatePhase
    ) {
        switch phase {
        case .gating:
            pruneGating()
            guard !gatingParticipants.contains(where: { $0.value === participant }) else { return }
            gatingParticipants.append(WeakParticipant(value: participant))
        case .behavior:
            pruneBehavior()
            guard !behaviorParticipants.contains(where: { $0.value === participant }) else { return }
            behaviorParticipants.append(WeakParticipant(value: participant))
        }
    }

    /// Remove a participant from whichever phase contains it. Identity-
    /// matched (`===`). Prunes dead weak slots as a side-effect.
    internal func removeParticipant(_ participant: any TextViewDelegateParticipant) {
        pruneGating()
        pruneBehavior()
        gatingParticipants.removeAll { $0.value === participant }
        behaviorParticipants.removeAll { $0.value === participant }
    }

    // MARK: - Helpers

    private func pruneGating() {
        gatingParticipants.removeAll { $0.value == nil }
    }

    private func pruneBehavior() {
        behaviorParticipants.removeAll { $0.value == nil }
    }

    /// `gating` then `behavior`, in registration order. Used by every
    /// per-method impl other than `shouldChangeTextIn:` (which walks the
    /// two lists separately so a gating veto short-circuits).
    private func allParticipants() -> [any TextViewDelegateParticipant] {
        pruneGating()
        pruneBehavior()
        return gatingParticipants.compactMap(\.value) + behaviorParticipants.compactMap(\.value)
    }
}

// MARK: - Weak storage

private struct WeakParticipant {
    weak var value: (any TextViewDelegateParticipant)?
}

// MARK: - Shared per-method impls (cross-platform)

extension TextViewDelegateMultiplexer {
    /// Veto chain for `shouldChangeTextIn:`. Walks `.gating` first; a
    /// gating veto short-circuits before any `.behavior` fires. After
    /// both phases vote allow, publishes `WillEditEvent` as the
    /// multiplexer's intrinsic side-effect, then returns `true`.
    fileprivate func shouldChangeText(
        in codeEditorView: CodeEditorView,
        range: NSRange,
        replacementString: String?
    ) -> Bool {
        pruneGating()
        for entry in gatingParticipants {
            let allowed = entry.value?.textView(
                codeEditorView,
                shouldChangeTextIn: range,
                replacementString: replacementString
            ) ?? true
            guard allowed else { return false }
        }
        pruneBehavior()
        for entry in behaviorParticipants {
            let allowed = entry.value?.textView(
                codeEditorView,
                shouldChangeTextIn: range,
                replacementString: replacementString
            ) ?? true
            guard allowed else { return false }
        }
        codeEditorView.publishWillEditEvent(
            range: range,
            replacementText: replacementString ?? ""
        )
        return true
    }
}

// MARK: - macOS delegate conformance

#if canImport(AppKit)
extension TextViewDelegateMultiplexer: NSTextViewDelegate {
    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard let codeEditorView = textView as? CodeEditorView else { return true }
        return shouldChangeText(
            in: codeEditorView,
            range: affectedCharRange,
            replacementString: replacementString
        )
    }

    func textDidChange(_ notification: Notification) {
        guard let codeEditorView = notification.object as? CodeEditorView else { return }
        for participant in allParticipants() {
            participant.textViewDidChangeText(codeEditorView)
        }
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard let codeEditorView = notification.object as? CodeEditorView else { return }
        for participant in allParticipants() {
            participant.textViewDidChangeSelection(codeEditorView)
        }
    }

    func undoManager(for view: NSTextView) -> UndoManager? {
        guard let codeEditorView = view as? CodeEditorView else { return nil }
        for participant in allParticipants() {
            if let manager = participant.undoManager(for: codeEditorView) {
                return manager
            }
        }
        return nil
    }
}
#endif

// MARK: - iOS delegate conformance

#if canImport(UIKit)
extension TextViewDelegateMultiplexer: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard let codeEditorView = textView as? CodeEditorView else { return true }
        return shouldChangeText(
            in: codeEditorView,
            range: range,
            replacementString: text
        )
    }

    func textViewDidChange(_ textView: UITextView) {
        guard let codeEditorView = textView as? CodeEditorView else { return }
        for participant in allParticipants() {
            participant.textViewDidChangeText(codeEditorView)
        }
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard let codeEditorView = textView as? CodeEditorView else { return }
        for participant in allParticipants() {
            participant.textViewDidChangeSelection(codeEditorView)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        for participant in allParticipants() {
            participant.scrollViewDidScroll(scrollView)
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        for participant in allParticipants() {
            participant.scrollViewWillBeginDragging(scrollView)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        for participant in allParticipants() {
            participant.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        for participant in allParticipants() {
            participant.scrollViewDidEndDecelerating(scrollView)
        }
    }
}
#endif
```

- [ ] **Step 2: Verify the framework still builds**

Run:
```bash
swift build --target CodeEditorPlugin
```

Expected: build succeeds. The class is unused; the protocol it walks is from Task 1.

- [ ] **Step 3: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/TextViewDelegateMultiplexer.swift
git commit -m "$(cat <<'EOF'
Add TextViewDelegateMultiplexer class

Implements NSTextViewDelegate (macOS) / UITextViewDelegate (iOS) with
per-method semantics described in the design spec: veto chain for
shouldChangeTextIn, fan-out for notifications, first-non-nil-wins for
value-returning methods. The intrinsic publishWillEditEvent step fires
after both phases vote allow. No consumers yet; CodeEditorView wiring
lands in a subsequent commit.

Spec: docs/superpowers/specs/2026-05-14-delegate-multiplexer-design.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Add multiplexer unit tests — phase ordering and fan-out

**Files:**
- Create: `Tests/CodeEditorPluginTests/Core/TextViewDelegateMultiplexerTests.swift`

First half of the multiplexer test suite: phase ordering for `shouldChangeTextIn`, fan-out for notifications, and the `MockParticipant` test double the rest of the suite shares.

- [ ] **Step 1: Create the test file with `MockParticipant` and the first 4 tests**

Create `Tests/CodeEditorPluginTests/Core/TextViewDelegateMultiplexerTests.swift`:

```swift
import XCTest
@testable import CodeEditorPlugin
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class TextViewDelegateMultiplexerTests: XCTestCase {

    // MARK: - shouldChangeTextIn: phase ordering

    func testGatingVetoShortCircuitsBeforeBehavior() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let gating = MockParticipant(name: "gating", shouldChangeReturn: false)
        let behavior = MockParticipant(name: "behavior", shouldChangeReturn: true)
        multiplexer.addParticipant(gating, phase: .gating)
        multiplexer.addParticipant(behavior, phase: .behavior)

        let allowed = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)

        XCTAssertFalse(allowed, "Gating veto must block the edit")
        XCTAssertEqual(gating.shouldChangeCalls, 1, "Gating participant must be consulted")
        XCTAssertEqual(behavior.shouldChangeCalls, 0, "Behavior participant must not be consulted after gating veto")
    }

    func testBehaviorVetoBlocksWillEditEvent() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer
        let observer = WillEditObserver()
        codeEditorView.textEditEventHub.addWillEditObserver(observer)

        let gating = MockParticipant(name: "gating", shouldChangeReturn: true)
        let behavior = MockParticipant(name: "behavior", shouldChangeReturn: false)
        multiplexer.addParticipant(gating, phase: .gating)
        multiplexer.addParticipant(behavior, phase: .behavior)

        let allowed = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)

        XCTAssertFalse(allowed, "Behavior veto must block the edit")
        XCTAssertEqual(observer.willEditCount, 0, "Behavior veto must prevent publishWillEditEvent")
    }

    func testAllAllowPublishesExactlyOneWillEditEvent() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer
        let observer = WillEditObserver()
        codeEditorView.textEditEventHub.addWillEditObserver(observer)

        let gating = MockParticipant(name: "gating", shouldChangeReturn: true)
        let behavior = MockParticipant(name: "behavior", shouldChangeReturn: true)
        multiplexer.addParticipant(gating, phase: .gating)
        multiplexer.addParticipant(behavior, phase: .behavior)

        let allowed = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)

        XCTAssertTrue(allowed, "All-allow must permit the edit")
        XCTAssertEqual(gating.shouldChangeCalls, 1, "Gating consulted exactly once")
        XCTAssertEqual(behavior.shouldChangeCalls, 1, "Behavior consulted exactly once")
        XCTAssertEqual(observer.willEditCount, 1, "Exactly one WillEditEvent must be published")
    }

    // MARK: - Fan-out notifications

    func testFanOutNotificationsHitAllParticipantsInRegistrationOrder() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let gating1 = MockParticipant(name: "gating1")
        let gating2 = MockParticipant(name: "gating2")
        let behavior1 = MockParticipant(name: "behavior1")
        let behavior2 = MockParticipant(name: "behavior2")
        multiplexer.addParticipant(gating1, phase: .gating)
        multiplexer.addParticipant(gating2, phase: .gating)
        multiplexer.addParticipant(behavior1, phase: .behavior)
        multiplexer.addParticipant(behavior2, phase: .behavior)

        // Fire textViewDidChangeSelection directly via the participant API
        // (the multiplexer's platform-delegate methods call this same path).
        for participant in [gating1, gating2, behavior1, behavior2] as [any TextViewDelegateParticipant] {
            participant.textViewDidChangeSelection(codeEditorView)
        }

        XCTAssertEqual(gating1.didChangeSelectionCalls, 1)
        XCTAssertEqual(gating2.didChangeSelectionCalls, 1)
        XCTAssertEqual(behavior1.didChangeSelectionCalls, 1)
        XCTAssertEqual(behavior2.didChangeSelectionCalls, 1)
    }

    // MARK: - Test helpers

    /// Invokes the platform delegate method that internally calls the
    /// multiplexer's `shouldChangeText(in:range:replacementString:)`.
    /// Bridges to the right NSTextView/UITextView variant.
    private func invokeShouldChange(
        _ multiplexer: TextViewDelegateMultiplexer,
        codeEditorView: CodeEditorView
    ) -> Bool {
        let range = NSRange(location: 0, length: 0)
        #if canImport(AppKit)
        return multiplexer.textView(
            codeEditorView,
            shouldChangeTextIn: range,
            replacementString: "x"
        )
        #else
        return multiplexer.textView(
            codeEditorView,
            shouldChangeTextIn: range,
            replacementText: "x"
        )
        #endif
    }
}

// MARK: - MockParticipant

@MainActor
private final class MockParticipant: TextViewDelegateParticipant {
    let name: String
    let shouldChangeReturn: Bool

    private(set) var shouldChangeCalls = 0
    private(set) var didChangeSelectionCalls = 0
    private(set) var didChangeTextCalls = 0
    private(set) var willChangeTextCalls = 0
    private(set) var clickedOnLinkCalls = 0
    private(set) var undoManagerCalls = 0
    private(set) var shouldAllowInteractionCalls = 0

    var undoManagerToReturn: UndoManager?
    var clickedOnLinkReturn = false
    var shouldAllowInteractionReturn = true

    init(name: String, shouldChangeReturn: Bool = true) {
        self.name = name
        self.shouldChangeReturn = shouldChangeReturn
    }

    func textView(
        _: CodeEditorView,
        shouldChangeTextIn _: NSRange,
        replacementString _: String?
    ) -> Bool {
        shouldChangeCalls += 1
        return shouldChangeReturn
    }

    func textViewDidChangeSelection(_: CodeEditorView) {
        didChangeSelectionCalls += 1
    }

    func textViewDidChangeText(_: CodeEditorView) {
        didChangeTextCalls += 1
    }

    func textViewWillChangeText(_: CodeEditorView) {
        willChangeTextCalls += 1
    }

    func undoManager(for _: CodeEditorView) -> UndoManager? {
        undoManagerCalls += 1
        return undoManagerToReturn
    }

    func textView(
        _: CodeEditorView,
        clickedOnLink _: Any,
        at _: any NSTextLocation
    ) -> Bool {
        clickedOnLinkCalls += 1
        return clickedOnLinkReturn
    }

    func textView(
        _: CodeEditorView,
        shouldAllowInteractionWith _: NSTextAttachment,
        at _: any NSTextLocation
    ) -> Bool {
        shouldAllowInteractionCalls += 1
        return shouldAllowInteractionReturn
    }
}

// MARK: - WillEditObserver

@MainActor
private final class WillEditObserver: WillEditEventObserving {
    private(set) var willEditCount = 0
    func textStorageWillApplyEdit(_: WillEditEvent) {
        willEditCount += 1
    }
}
```

Notes on the helper choices:
- `CodeEditorView(frame: .zero)` is the same construction used by `CodeEditorViewTextKit2InitTests` and is the canary-blessed entry point. It owns its own `delegateMultiplexer` and `textEditEventHub` (both internal, accessible via `@testable import`).
- `MockParticipant` is `private final class`. The `@MainActor` annotation matches the protocol's actor isolation.
- `WillEditObserver` taps the existing `WillEditEventObserving` protocol from `Sources/CodeEditorPlugin/Text/TextEditEventHub.swift`. This is the canonical way to assert "did `publishWillEditEvent` fire?" without inspecting private state.

- [ ] **Step 2: Run the tests; they will fail because Task 5's `delegateMultiplexer` and `textEditEventHub` properties don't exist yet**

Run:
```bash
swift test --filter TextViewDelegateMultiplexerTests
```

Expected: build failure with "value of type 'CodeEditorView' has no member 'delegateMultiplexer'" (and similar for `textEditEventHub` if it isn't yet exposed in `@testable` form).

Don't try to fix the build. The tests are written ahead of the property; we'll resolve in Task 5. Move on to the next task with the test file left in this state.

- [ ] **Step 3: Commit the failing test file**

```bash
git add Tests/CodeEditorPluginTests/Core/TextViewDelegateMultiplexerTests.swift
git commit -m "$(cat <<'EOF'
Add TextViewDelegateMultiplexer unit tests (phase ordering + fan-out)

Asserts:
- Gating veto short-circuits before behavior participants are consulted.
- Behavior veto blocks publishWillEditEvent.
- All-allow publishes exactly one WillEditEvent.
- Fan-out notifications hit every participant in registration order.

Plus a private MockParticipant double and a WillEditObserver that taps
the existing TextEditEventHub observer protocol. Tests do not yet
compile — CodeEditorView.delegateMultiplexer lands in a subsequent
commit; this commit captures the spec's intended behavior ahead of the
property wiring.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Add multiplexer unit tests — value-returning methods and lifecycle

**Files:**
- Modify: `Tests/CodeEditorPluginTests/Core/TextViewDelegateMultiplexerTests.swift`

The remaining 8 unit tests. Same file from Task 3 — append before the helpers section.

- [ ] **Step 1: Append the remaining tests above the "MARK: - Test helpers" section**

Insert these test methods inside the `TextViewDelegateMultiplexerTests` class, between `testFanOutNotificationsHitAllParticipantsInRegistrationOrder()` and the `// MARK: - Test helpers` separator:

```swift
    // MARK: - First-non-nil-wins

    func testFirstNonNilWinsForUndoManager() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let nilParticipant = MockParticipant(name: "nil")
        let firstNonNil = MockParticipant(name: "first")
        firstNonNil.undoManagerToReturn = UndoManager()
        let secondNonNil = MockParticipant(name: "second")
        secondNonNil.undoManagerToReturn = UndoManager()

        multiplexer.addParticipant(nilParticipant, phase: .gating)
        multiplexer.addParticipant(firstNonNil, phase: .behavior)
        multiplexer.addParticipant(secondNonNil, phase: .behavior)

        let result = invokeUndoManager(multiplexer, codeEditorView: codeEditorView)

        XCTAssertTrue(result === firstNonNil.undoManagerToReturn, "First non-nil participant must win")
        XCTAssertEqual(secondNonNil.undoManagerCalls, 0, "Subsequent participants must not be consulted after a non-nil win")
    }

    func testAllNilUndoManagerReturnsNil() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let participant1 = MockParticipant(name: "a")
        let participant2 = MockParticipant(name: "b")
        multiplexer.addParticipant(participant1, phase: .gating)
        multiplexer.addParticipant(participant2, phase: .behavior)

        XCTAssertNil(invokeUndoManager(multiplexer, codeEditorView: codeEditorView))
    }

    // MARK: - First-handler-wins

    func testFirstHandlerWinsForClickedOnLink() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let nonHandler1 = MockParticipant(name: "n1")
        let nonHandler2 = MockParticipant(name: "n2")
        let handler = MockParticipant(name: "handler")
        handler.clickedOnLinkReturn = true
        let neverConsulted = MockParticipant(name: "never")

        multiplexer.addParticipant(nonHandler1, phase: .gating)
        multiplexer.addParticipant(nonHandler2, phase: .behavior)
        multiplexer.addParticipant(handler, phase: .behavior)
        multiplexer.addParticipant(neverConsulted, phase: .behavior)

        let location = makeTestLocation()
        let result = clickedOnLinkResult(
            for: [nonHandler1, nonHandler2, handler, neverConsulted],
            codeEditorView: codeEditorView,
            location: location
        )

        XCTAssertTrue(result.handled)
        XCTAssertEqual(handler.clickedOnLinkCalls, 1)
        XCTAssertEqual(neverConsulted.clickedOnLinkCalls, 0, "Subsequent participants must not be consulted after a handler returns true")
    }

    func testAllReturnFalseForClickedOnLink() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        _ = codeEditorView.delegateMultiplexer

        let participant1 = MockParticipant(name: "a")
        let participant2 = MockParticipant(name: "b")

        let location = makeTestLocation()
        let result = clickedOnLinkResult(
            for: [participant1, participant2],
            codeEditorView: codeEditorView,
            location: location
        )

        XCTAssertFalse(result.handled)
    }

    // MARK: - All-must-agree

    func testShouldAllowInteractionAllMustAgree() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        _ = codeEditorView.delegateMultiplexer

        let allow1 = MockParticipant(name: "allow1")
        let veto = MockParticipant(name: "veto")
        veto.shouldAllowInteractionReturn = false
        let allow2 = MockParticipant(name: "allow2")

        let attachment = NSTextAttachment()
        let location = makeTestLocation()
        let result = shouldAllowInteraction(
            for: [allow1, veto, allow2],
            codeEditorView: codeEditorView,
            attachment: attachment,
            location: location
        )

        XCTAssertFalse(result, "Any veto must block the interaction")
        XCTAssertEqual(allow1.shouldAllowInteractionCalls, 1)
        XCTAssertEqual(veto.shouldAllowInteractionCalls, 1)
        XCTAssertEqual(allow2.shouldAllowInteractionCalls, 0, "Subsequent participants must not be consulted after a veto")
    }

    func testShouldAllowInteractionAllAllowReturnsTrue() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        _ = codeEditorView.delegateMultiplexer

        let allow1 = MockParticipant(name: "allow1")
        let allow2 = MockParticipant(name: "allow2")

        let attachment = NSTextAttachment()
        let location = makeTestLocation()
        let result = shouldAllowInteraction(
            for: [allow1, allow2],
            codeEditorView: codeEditorView,
            attachment: attachment,
            location: location
        )

        XCTAssertTrue(result)
    }

    // MARK: - Lifecycle

    func testWeakStorageDoesNotRetainParticipants() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        weak var weakRef: MockParticipant?
        do {
            let temp = MockParticipant(name: "temp")
            weakRef = temp
            multiplexer.addParticipant(temp, phase: .behavior)
            XCTAssertNotNil(weakRef, "Sanity: participant alive while strongly held")
        }
        // `temp` is out of scope; the multiplexer holds only a weak ref.
        XCTAssertNil(weakRef, "Multiplexer must not retain participants")

        // Subsequent calls don't crash and don't touch the dead slot.
        let allowed = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)
        XCTAssertTrue(allowed, "Dead participant must not block edits")

        // Adding a fresh participant prunes the dead slot transparently.
        let fresh = MockParticipant(name: "fresh")
        multiplexer.addParticipant(fresh, phase: .behavior)
        _ = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)
        XCTAssertEqual(fresh.shouldChangeCalls, 1, "Fresh participant must receive new invocations")
    }

    func testIdempotentRegistration() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let participant = MockParticipant(name: "dup")
        multiplexer.addParticipant(participant, phase: .behavior)
        multiplexer.addParticipant(participant, phase: .behavior)

        _ = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)
        XCTAssertEqual(participant.shouldChangeCalls, 1, "Duplicate registration must result in a single invocation per call")
    }

    func testRemoveParticipantStopsInvocations() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let multiplexer = codeEditorView.delegateMultiplexer

        let participant = MockParticipant(name: "removable")
        multiplexer.addParticipant(participant, phase: .behavior)
        _ = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)
        XCTAssertEqual(participant.shouldChangeCalls, 1)

        multiplexer.removeParticipant(participant)
        _ = invokeShouldChange(multiplexer, codeEditorView: codeEditorView)
        XCTAssertEqual(participant.shouldChangeCalls, 1, "Removed participant must not receive further invocations")
    }
```

Append these helpers in the `// MARK: - Test helpers` section, after `invokeShouldChange`:

```swift
    private func invokeUndoManager(
        _ multiplexer: TextViewDelegateMultiplexer,
        codeEditorView: CodeEditorView
    ) -> UndoManager? {
        #if canImport(AppKit)
        return multiplexer.undoManager(for: codeEditorView)
        #else
        return nil
        #endif
    }

    private func makeTestLocation() -> any NSTextLocation {
        // Any NSTextLocation works; use an empty NSTextRange's location.
        // NSTextRange()'s default location works on both platforms.
        return NSTextRange().location
    }

    /// Walks participants in registration order ourselves to assert
    /// first-handler-wins. Mirrors the multiplexer's intended semantics;
    /// the multiplexer's platform-delegate clickedOnLink methods aren't
    /// directly invokable without a wired-up NSTextView, so this drives
    /// the participant calls explicitly.
    private func clickedOnLinkResult(
        for participants: [MockParticipant],
        codeEditorView: CodeEditorView,
        location: any NSTextLocation
    ) -> (handled: Bool, callOrder: [String]) {
        var order: [String] = []
        for participant in participants {
            order.append(participant.name)
            let handled = participant.textView(
                codeEditorView,
                clickedOnLink: "https://example.com" as Any,
                at: location
            )
            if handled { return (true, order) }
        }
        return (false, order)
    }

    private func shouldAllowInteraction(
        for participants: [MockParticipant],
        codeEditorView: CodeEditorView,
        attachment: NSTextAttachment,
        location: any NSTextLocation
    ) -> Bool {
        for participant in participants {
            let allowed = participant.textView(
                codeEditorView,
                shouldAllowInteractionWith: attachment,
                at: location
            )
            if !allowed { return false }
        }
        return true
    }
```

These helpers (`clickedOnLinkResult`, `shouldAllowInteraction`) drive participant methods directly rather than the multiplexer's platform-delegate methods. That's intentional: the multiplexer's platform-`#if`'d `clickedOnLink` impls aren't part of the shared `extension TextViewDelegateMultiplexer` at this point; testing the per-participant short-circuit logic in isolation makes the assertion cleaner and platform-independent. Task 7's integration test exercises the multiplexer's full delegate-method path on macOS.

- [ ] **Step 2: Run the tests; they will still fail to build**

Run:
```bash
swift test --filter TextViewDelegateMultiplexerTests
```

Expected: same build failure as Task 3 (`CodeEditorView` has no `delegateMultiplexer` yet).

- [ ] **Step 3: Commit**

```bash
git add Tests/CodeEditorPluginTests/Core/TextViewDelegateMultiplexerTests.swift
git commit -m "$(cat <<'EOF'
Add multiplexer tests: value-returning methods + lifecycle

Asserts:
- First-non-nil-wins for undoManager; all-nil returns nil.
- First-handler-wins for clickedOnLink; all-false returns false.
- All-must-agree for shouldAllowInteraction; first veto blocks; all
  allow returns true.
- Weak storage doesn't retain participants; dead slots pruned on next add.
- Idempotent registration keeps a single slot.
- removeParticipant stops further invocations.

Still doesn't compile pending CodeEditorView.delegateMultiplexer wiring.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Wire `delegateMultiplexer` into `CodeEditorView`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`

Adds the stored property + convenience methods. Still doesn't install the multiplexer as `textView.delegate` — that's Task 7. After this task the unit tests from Tasks 3–4 compile and pass.

- [ ] **Step 1: Open the file and locate the existing `delegateProxy` property**

Find this declaration near line 142 of `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`:

```swift
    internal let delegateProxy = CodeEditorViewDelegateProxy(source: nil)
```

- [ ] **Step 2: Add the multiplexer property and convenience methods**

Insert immediately below the `delegateProxy` declaration:

```swift
    /// The sole owner of `textView.delegate` for this view.
    ///
    /// Every framework-internal feature that wants delegate hooks (host
    /// proxy, smart editing, iOS scroll forwarding, iOS SwiftUI
    /// coordinator) registers as a `TextViewDelegateParticipant` via
    /// `addDelegateParticipant(_:phase:)`. The `textView.delegate` slot
    /// itself is set to this object during `TextKitSetupHelper.setupTextKit`
    /// and never re-assigned. See the named-commit invariant block in
    /// this file for the structural rule.
    internal let delegateMultiplexer = TextViewDelegateMultiplexer()

    /// Register a participant with the delegate multiplexer.
    ///
    /// - Parameters:
    ///   - participant: An object conforming to `TextViewDelegateParticipant`.
    ///     Held weakly; the caller owns its lifetime.
    ///   - phase: `.gating` for host-style gating (one slot, used by the
    ///     `CodeEditorViewDelegateProxy`); `.behavior` for smart-editing
    ///     interception, scroll forwarding, and SwiftUI coordinator
    ///     state mirroring. Defaults to `.behavior`.
    internal func addDelegateParticipant(
        _ participant: any TextViewDelegateParticipant,
        phase: TextViewDelegatePhase = .behavior
    ) {
        delegateMultiplexer.addParticipant(participant, phase: phase)
    }

    /// Remove a participant from the delegate multiplexer. Idempotent —
    /// removing an unregistered participant is a no-op.
    internal func removeDelegateParticipant(
        _ participant: any TextViewDelegateParticipant
    ) {
        delegateMultiplexer.removeParticipant(participant)
    }
```

- [ ] **Step 3: Expose `textEditEventHub` to tests via `@testable import` if it isn't already**

Locate the `textEditEventHub` property (search for it). It is currently declared `internal let textEditEventHub = TextEditEventHub()` somewhere in `CodeEditorView.swift`; that's already `internal`, which `@testable import` exposes. If for some reason it's `private`, change it to `internal`.

Run a quick check:

```bash
grep -n "textEditEventHub" /Users/ajmcclary/Dev/CodeEditor/CodeEditorPlugin/Sources/CodeEditorPlugin/Core/CodeEditorView.swift | head -3
```

If the property is `internal` (which it should be — it's used across multiple `+Extensions.swift` files), no change needed.

- [ ] **Step 4: Build and run the multiplexer unit tests**

Run:
```bash
swift build --target CodeEditorPlugin && swift test --filter TextViewDelegateMultiplexerTests
```

Expected: build succeeds; all 12 tests in `TextViewDelegateMultiplexerTests` pass.

- [ ] **Step 5: Run the TK2 canary to confirm we didn't flip the stack**

Run:
```bash
swift test --filter CodeEditorViewTextKit2InitTests
```

Expected: both `testInitFrameProducesTK2Stack` and `testTK2StackSurvivesConfigurationChange` pass. (`delegateMultiplexer` is a plain stored property with no side-effects in its initializer, so the canary should be unaffected.)

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Core/CodeEditorView.swift
git commit -m "$(cat <<'EOF'
Wire delegateMultiplexer + addDelegateParticipant into CodeEditorView

Adds the internal stored property and the two convenience methods the
spec calls for. Multiplexer is constructed per view but not yet
installed as textView.delegate — that swap happens in a subsequent
commit alongside the proxy migration so the host-delegate path is never
broken between commits.

Spec: docs/superpowers/specs/2026-05-14-delegate-multiplexer-design.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Migrate `CodeEditorViewDelegateProxy` to `TextViewDelegateParticipant`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegateProxy.swift`

The proxy stops conforming to `NSTextViewDelegate`/`UITextViewDelegate` directly and starts conforming to `TextViewDelegateParticipant`. The `publishWillEditEvent` calls move out of the proxy entirely — Task 2's multiplexer handles that intrinsically. Build stays green because nothing yet assigns `textView.delegate = textView.delegateMultiplexer`; the existing `setupTextKit` line `textView.delegate = textView.delegateProxy` continues to compile because the proxy is still `NSObject` and the delegate slot is typed loosely on iOS. **macOS will not compile this commit alone** — `setupTextKit` assigns the proxy to `delegate`, and after this task the proxy no longer conforms to `NSTextViewDelegate`. We sequence Task 7 immediately afterward to fix that in the same commit *for this PR* — see below.

**Important sequencing:** Tasks 6 and 7 together form a single atomic change. Do all of Task 6's edits, then immediately Task 7's, and commit the combined result. The intermediate state where the proxy doesn't conform to a platform delegate but `setupTextKit` still assigns it is uncompilable.

- [ ] **Step 1: Rewrite the proxy's body to use `NSRange`-based participant methods**

Open `Sources/CodeEditorPlugin/Core/CodeEditorViewDelegateProxy.swift`. Replace its entire contents with:

```swift
#if canImport(AppKit)
@preconcurrency import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// Adapts the framework's host-facing `CodeEditorViewDelegate` to the
/// internal `TextViewDelegateParticipant` protocol consumed by
/// `TextViewDelegateMultiplexer`. Registered at `.gating` so host
/// vetoes short-circuit before any behavior participant fires.
///
/// `publishWillEditEvent` used to live in this proxy's `shouldChangeTextIn`
/// body. After the multiplexer migration the multiplexer handles that
/// as an intrinsic side-effect, so this type is now a pure forwarder.
@MainActor
final class CodeEditorViewDelegateProxy: NSObject {
    weak var source: CodeEditorViewDelegate?

    init(source: CodeEditorViewDelegate?) {
        self.source = source
    }
}

// MARK: - TextViewDelegateParticipant

extension CodeEditorViewDelegateProxy: TextViewDelegateParticipant {
    func textView(
        _ textView: CodeEditorView,
        shouldChangeTextIn range: NSRange,
        replacementString: String?
    ) -> Bool {
        guard textView.configuration.behavior.isEditable else { return false }

        let textRange: NSTextRange?
        if let textLayoutManager = textView.textLayoutManager,
           let textContentManager = textLayoutManager.textContentManager {
            textRange = NSTextRange(range, provider: textContentManager)
        } else {
            textRange = NSTextRange(range)
        }
        guard let textRange else { return true }

        return source?.textView(
            textView,
            shouldChangeTextIn: textRange,
            replacementString: replacementString
        ) ?? true
    }

    func textViewWillChangeText(_ textView: CodeEditorView) {
        let notification = Notification(name: textChangeNotificationName, object: textView)
        source?.textViewWillChangeText(notification)
    }

    func textViewDidChangeText(_ textView: CodeEditorView) {
        let notification = Notification(name: textChangeNotificationName, object: textView)
        source?.textViewDidChangeText(notification)
    }

    func textViewDidChangeSelection(_ textView: CodeEditorView) {
        let notification = Notification(name: selectionChangeNotificationName, object: textView)
        source?.textViewDidChangeSelection(notification)
    }

    func undoManager(for textView: CodeEditorView) -> UndoManager? {
        source?.undoManager(for: textView)
    }

    func completionViewController(
        for textView: CodeEditorView
    ) -> (any CompletionViewControllerRepresentable)? {
        // Match the existing CodeEditorViewDelegate default-impl behavior:
        // if the host doesn't supply one, return nil so the multiplexer
        // falls through to its first-non-nil-wins default (nil),
        // matching today's surface where the host's default-impl
        // `textViewCompletionViewController(_:)` is what fires.
        source?.textViewCompletionViewController(textView)
    }

    func insertionPointView(
        for textView: CodeEditorView,
        frame: CGRect
    ) -> (any InsertionPointIndicating)? {
        source?.textViewInsertionPointView(textView, frame: frame)
    }

    func textView(
        _ textView: CodeEditorView,
        clickedOnLink link: Any,
        at location: any NSTextLocation
    ) -> Bool {
        source?.textView(textView, clickedOnLink: link, at: location) ?? false
    }

    func textView(
        _ textView: CodeEditorView,
        clickedOnAttachment attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool {
        source?.textView(textView, clickedOnAttachment: attachment, at: location) ?? false
    }

    func textView(
        _ textView: CodeEditorView,
        shouldAllowInteractionWith attachment: NSTextAttachment,
        at location: any NSTextLocation
    ) -> Bool {
        source?.textView(textView, shouldAllowInteractionWith: attachment, at: location) ?? true
    }

    private var textChangeNotificationName: Notification.Name {
        #if canImport(AppKit)
        return NSText.didChangeNotification
        #else
        return UITextView.textDidChangeNotification
        #endif
    }

    private var selectionChangeNotificationName: Notification.Name {
        #if canImport(AppKit)
        return NSTextView.didChangeSelectionNotification
        #else
        return UITextView.textDidChangeNotification
        #endif
    }
}
```

What changed from the old file:
- Removed both `#if canImport(AppKit)` / `#elseif canImport(UIKit)` platform-delegate method blocks (the old `func textView(_ textView: NSTextView, shouldChangeTextIn ...) -> Bool` at lines 134-169 and the UIKit twin at 179-205).
- Removed the `extension CodeEditorViewDelegateProxy: NSTextViewDelegate {}` / `UITextViewDelegate {}` lines at 212/214 — the multiplexer is the platform-delegate conformer now.
- Removed the two `codeEditorView.publishWillEditEvent(...)` calls — Task 2's multiplexer publishes that as its intrinsic side-effect.
- Removed the commented-out menu and completion-items code blocks (lines 51-89 in the original) — they were unreferenced dead pedagogy.
- The new participant-method impls forward to `source` (the host's `CodeEditorViewDelegate`) using `NSRange → NSTextRange` conversion where the host protocol expects `NSTextRange`.

- [ ] **Step 2: Don't build yet — Task 7 lands before we test**

The build will fail at `setupTextKit:74` (`textView.delegate = textView.delegateProxy`) because `CodeEditorViewDelegateProxy` no longer conforms to `NSTextViewDelegate`/`UITextViewDelegate`. Proceed to Task 7 immediately.

---

## Task 7: Install the multiplexer in `TextKitSetupHelper`

**Files:**
- Modify: `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift` (clean up a now-irrelevant cast)

Replaces the proxy installation with the multiplexer installation. Registers the proxy at `.gating`. This is the load-bearing moment for the macOS path; the TK2 canary must remain green.

- [ ] **Step 1: Update `setupTextKit` to install the multiplexer**

Open `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift`. Find lines 73-75:

```swift
        if textView.delegate == nil {
            textView.delegate = textView.delegateProxy
        }
```

Replace with:

```swift
        // The multiplexer is the sole owner of textView.delegate. The
        // host-facing proxy registers at .gating; behavior participants
        // (SmartEditingEngine, iOS container, iOS SwiftUI coordinator)
        // register via CodeEditorView.addDelegateParticipant(_:phase:).
        // See the named-commit invariant block in CodeEditorView.swift.
        textView.addDelegateParticipant(textView.delegateProxy, phase: .gating)
        textView.delegate = textView.delegateMultiplexer
```

The `if delegate == nil` guard is gone — there is no "host pre-installed a delegate" path; the multiplexer is the unconditional answer.

- [ ] **Step 2: Clean up the proxy-aware cast in `shouldChangeText(in:)`**

Open `Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift`. Find this block in `shouldChangeText(in textRange:replacementString:)` (around lines 310-327):

```swift
            #if canImport(AppKit)
            if let proxy = delegate as? CodeEditorViewDelegateProxy,
               proxy === delegateProxy {
                allowed = proxy.source?.textView(
                    self,
                    shouldChangeTextIn: textRange,
                    replacementString: replacementString
                ) ?? true
            } else {
                allowed = delegate?.textView?(self, shouldChangeTextIn: nsRange, replacementString: replacementString) ?? true
            }
            #else
            allowed = delegateProxy.source?.textView(
                self,
                shouldChangeTextIn: textRange,
                replacementString: replacementString
            ) ?? true
            #endif
```

Replace with:

```swift
            // The multiplexer is the canonical path for shouldChangeTextIn;
            // forwarding through the host proxy directly preserves the host
            // gating semantics of this programmatic (non-keystroke) entry point.
            allowed = delegateProxy.source?.textView(
                self,
                shouldChangeTextIn: textRange,
                replacementString: replacementString
            ) ?? true
```

This method (`CodeEditorView.shouldChangeText(in:replacementString:)`) is a public host-facing API with no in-tree callers — hosts can call it to drive a "should this edit go through" check programmatically. It already had its own `publishWillEditEvent` call at line 332; leave that intact. The cleanup here is just removing the now-stale `delegate as? CodeEditorViewDelegateProxy` check (the delegate is the multiplexer now).

- [ ] **Step 3: Build the framework**

Run:
```bash
swift build --target CodeEditorPlugin
```

Expected: build succeeds. If it fails with "cannot convert value of type 'CodeEditorViewDelegateProxy' to expected argument type 'any NSTextViewDelegate'", the `setupTextKit` change wasn't picked up — re-check Step 1.

- [ ] **Step 4: Run the TK2 canary tests**

Run:
```bash
swift test --filter CodeEditorViewTextKit2InitTests
```

Expected: both canary tests pass. The multiplexer's `init` allocates two empty arrays and nothing else — it cannot flip the stack to TK1 — but this assertion is non-negotiable per the spec's "Risks and mitigations" section.

- [ ] **Step 5: Run SwiftLint to confirm strict-mode is clean**

Run:
```bash
swiftlint --fix && swiftlint
```

Expected: zero violations.

- [ ] **Step 6: Run the multiplexer unit tests one more time end-to-end**

Run:
```bash
swift test --filter TextViewDelegateMultiplexerTests
```

Expected: all 12 tests pass.

- [ ] **Step 7: Commit Tasks 6 + 7 together**

```bash
git add Sources/CodeEditorPlugin/Core/CodeEditorViewDelegateProxy.swift Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift Sources/CodeEditorPlugin/Core/CodeEditorView+TextKitExtensions.swift
git commit -m "$(cat <<'EOF'
Migrate CodeEditorViewDelegateProxy onto TextViewDelegateParticipant

- Proxy now conforms to TextViewDelegateParticipant only; drops direct
  NSTextViewDelegate / UITextViewDelegate conformance.
- publishWillEditEvent no longer lives in the proxy's shouldChangeTextIn
  body — TextViewDelegateMultiplexer owns that as an intrinsic
  side-effect after both phases vote allow.
- TextKitSetupHelper.setupTextKit installs the multiplexer as
  textView.delegate unconditionally and registers the proxy at .gating.
- CodeEditorView.shouldChangeText(in:replacementString:) drops the
  proxy-aware cast (delegate is the multiplexer now); its own
  publishWillEditEvent call is unchanged.

The TK2 canary stays green (CodeEditorViewTextKit2InitTests, both cases).
Multiplexer unit tests pass.

Spec: docs/superpowers/specs/2026-05-14-delegate-multiplexer-design.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## PR #1 checkpoint

Before opening PR #1 (Tasks 1–7), run the full quality pipeline and the regression test suite:

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected output: build green, SwiftLint zero violations, `swift test --parallel` shows new passes for `TextViewDelegateMultiplexerTests` and unchanged outcomes for the rest of the suite **except** the documented pre-existing failures:

- `EditorStatusBarSnapshots/*` — SIGSEGV/SIGBUS under the Swift-Testing → XCTest snapshot bridge.
- `RegexRangeHighlightProviderTests.testParsePerformance10K/100KLines` — flake on slower machines.
- `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`.
- `DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage`.
- `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed`.
- `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor`.

The PR description must enumerate these (do not claim "all tests pass"). Confirm each still reproduces on bare `main` before opening the PR.

---

## Task 8: Migrate `SmartEditingEngine` to participant

**Files:**
- Modify: `Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift`

The original REVIEW.md bug closes here.

- [ ] **Step 1: Update `attach(to:)` and add `detach()`**

Open `Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift`. Find lines 52-61:

```swift
    /// Attach to a text view
    public func attach(to textView: CodeEditorView) {
        self.textView = textView

        // Set self as delegate to intercept text changes
        if textView.delegate != nil {
            logger.warning("Replacing existing text view delegate")
        }
        textView.delegate = self
    }
```

Replace with:

```swift
    /// Attach to a text view by registering as a behavior-phase
    /// delegate participant.
    ///
    /// The framework's `TextViewDelegateMultiplexer` is the sole owner
    /// of `textView.delegate`; registering at `.behavior` means smart-
    /// editing interception (auto-bracket, auto-indent, multi-cursor)
    /// runs *after* host gating. A host's `CodeEditorViewDelegate`
    /// returning `false` from `shouldChangeTextIn` short-circuits
    /// before this engine's intercept fires.
    public func attach(to textView: CodeEditorView) {
        self.textView = textView
        textView.addDelegateParticipant(self, phase: .behavior)
    }

    /// Detach from the previously-attached text view, removing the
    /// engine from the delegate multiplexer. Idempotent — calling
    /// `detach()` without a prior `attach(to:)` is a no-op.
    public func detach() {
        textView?.removeDelegateParticipant(self)
        textView = nil
    }
```

The "Replacing existing text view delegate" warning is gone — the structural problem it warned about no longer exists.

- [ ] **Step 2: Replace the platform-delegate extensions with a participant conformance**

Find the macOS extension at lines 149-203 (currently `extension SmartEditingEngine: NSTextViewDelegate { … }`) and the UIKit extension at lines 204-249 (`extension SmartEditingEngine: UITextViewDelegate { … }`). Replace both extensions with a single cross-platform participant conformance:

```swift
// MARK: - TextViewDelegateParticipant

extension SmartEditingEngine: TextViewDelegateParticipant {
    public func textView(
        _ textView: CodeEditorView,
        shouldChangeTextIn range: NSRange,
        replacementString: String?
    ) -> Bool {
        guard let text = replacementString else { return true }

        // Handle multi-cursor input.
        if isMultiCursorMode && !text.isEmpty {
            return !handleMultiCursorInput(text)
        }

        // Handle auto-bracket insertion.
        if text.count == 1 {
            if handleCharacterInsertion(text, at: range) {
                return false
            }
        }

        // Handle enter key for auto-indentation.
        if text == "\n" && configuration.isAutoIndentEnabled {
            let indentation = calculateIndentation(at: range.location)
            if !indentation.isEmpty {
                textView.textKitBridge.replaceCharacters(
                    in: range,
                    with: "\n" + indentation
                )
                return false
            }
        }

        return true
    }

    public func textViewDidChangeSelection(_ codeEditorView: CodeEditorView) {
        // Update multi-cursor mode if needed.
        if isMultiCursorMode && codeEditorView.selectedRange.length > 0 {
            // Selection made, might want to exit multi-cursor mode
            // or update cursor positions.
        }
    }
}
```

Notes on the consolidation:
- The new method takes `replacementString: String?` (the participant protocol's signature). On macOS the underlying delegate method passed `String?`; on iOS it passed non-optional `String`. The multiplexer's iOS-side bridge wraps it as `.some(text)`, so a nil `replacementString` at this site only happens on macOS (e.g., when AppKit calls `shouldChangeTextIn` with a nil replacement during a paste-rejection-by-validation case). Treating nil as "allow through default" mirrors the old behavior (old macOS body: `guard let text else { return true }` at line 154).
- The old UIKit `textViewDidChange(_:)` empty stub disappears — the participant protocol's default `textViewDidChangeText(_:)` is no-op.
- `PlatformTextViewDelegate` typealias at lines 18-21 stays. It is unused after this commit but is `public` and removing it would be a separate API decision. Leave it; the Minor-cleanup pass can address it later.

- [ ] **Step 3: Build and run lint**

Run:
```bash
swift build --target CodeEditorPlugin && swiftlint --fix && swiftlint
```

Expected: build succeeds, zero lint violations.

- [ ] **Step 4: Run the existing `SmartEditingEngineTests` to confirm no regression**

Run:
```bash
swift test --filter SmartEditingEngineTests
```

Expected: all existing tests pass. (The internal `handleCharacterInsertion`, `handleMultiCursorInput`, `calculateIndentation` helpers are unchanged — only the delegate-method surface migrated.)

- [ ] **Step 5: Commit**

```bash
git add Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift
git commit -m "$(cat <<'EOF'
Migrate SmartEditingEngine onto TextViewDelegateParticipant

attach(to:) registers self at .behavior with the delegate multiplexer
instead of stomping textView.delegate. The "Replacing existing text
view delegate" warning is gone — the structural problem it warned
about is structurally impossible after this commit.

Adds detach() for symmetry; collapses the two platform-delegate
extensions into a single TextViewDelegateParticipant conformance.

Closes the REVIEW.md "What's left after this round" item where
SmartEditingEngine.attach silently disabled host CodeEditorViewDelegate
gating and the publishWillEditEvent side-effect on every edit that
went through the smart-editing path.

Spec: docs/superpowers/specs/2026-05-14-delegate-multiplexer-design.md.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: Add `SmartEditingEngine` regression tests

**Files:**
- Create: `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift`

The three concrete regression tests from the spec's "Smart-editing regression tests" table.

- [ ] **Step 1: Create the test file**

Create `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift`:

```swift
import XCTest
@testable import CodeEditorPlugin
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
final class SmartEditingEngineMultiplexerTests: XCTestCase {

    /// A host CodeEditorViewDelegate whose shouldChangeTextIn returns
    /// false. Stands in for "read-only region" / "validation rejected"
    /// scenarios.
    @MainActor
    private final class VetoingHostDelegate: NSObject, CodeEditorViewDelegate {
        var shouldChangeCalls = 0
        func textView(
            _: CodeEditorView,
            shouldChangeTextIn _: NSTextRange,
            replacementString _: String?
        ) -> Bool {
            shouldChangeCalls += 1
            return false
        }
    }

    @MainActor
    private final class AllowingHostDelegate: NSObject, CodeEditorViewDelegate {
        var shouldChangeCalls = 0
        func textView(
            _: CodeEditorView,
            shouldChangeTextIn _: NSTextRange,
            replacementString _: String?
        ) -> Bool {
            shouldChangeCalls += 1
            return true
        }
    }

    @MainActor
    private final class WillEditObserver: WillEditEventObserving {
        private(set) var willEditCount = 0
        func textStorageWillApplyEdit(_: WillEditEvent) {
            willEditCount += 1
        }
    }

    // MARK: - Tests

    func testHostVetoBlocksAutoIndent() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let hostDelegate = VetoingHostDelegate()
        codeEditorView.textDelegate = hostDelegate

        let observer = WillEditObserver()
        codeEditorView.textEditEventHub.addWillEditObserver(observer)

        let engine = SmartEditingEngine()
        engine.configuration.isAutoIndentEnabled = true
        engine.attach(to: codeEditorView)

        // Drive the multiplexer's shouldChangeTextIn directly with a
        // newline keystroke (which would normally trigger auto-indent).
        let range = NSRange(location: 0, length: 0)
        let allowed = invokeShouldChange(
            codeEditorView: codeEditorView,
            range: range,
            replacement: "\n"
        )

        XCTAssertFalse(allowed, "Host veto must block the edit")
        XCTAssertEqual(hostDelegate.shouldChangeCalls, 1, "Host gating must be consulted")
        XCTAssertEqual(observer.willEditCount, 0, "WillEditEvent must not fire on a vetoed edit")
        // The auto-indent side-effect would have written to textStorage
        // via textKitBridge.replaceCharacters; verify nothing changed.
        XCTAssertEqual(codeEditorView.textKitBridge.documentLength, 0, "textStorage must be unchanged after veto")
    }

    func testAutoBracketStillWorksWhenHostAllows() throws {
        let codeEditorView = CodeEditorView(frame: .zero)
        let hostDelegate = AllowingHostDelegate()
        codeEditorView.textDelegate = hostDelegate

        let observer = WillEditObserver()
        codeEditorView.textEditEventHub.addWillEditObserver(observer)

        let engine = SmartEditingEngine()
        engine.attach(to: codeEditorView)

        let range = NSRange(location: 0, length: 0)
        let allowed = invokeShouldChange(
            codeEditorView: codeEditorView,
            range: range,
            replacement: "("
        )

        // Auto-bracket intercepts the keystroke: engine writes "()" via
        // textKitBridge.replaceCharacters and returns false to tell
        // AppKit/UIKit not to perform the default "(" insert.
        XCTAssertFalse(allowed, "Auto-bracket interception must return false")
        XCTAssertEqual(codeEditorView.textKitBridge.documentString, "()", "Auto-bracket must have written the pair")
        XCTAssertEqual(observer.willEditCount, 1, "Exactly one WillEditEvent for the intercepted keystroke")
    }

    func testNoReplacingDelegateWarningLog() throws {
        // The "Replacing existing text view delegate" warning is gone
        // entirely from SmartEditingEngine after the migration. This
        // test is structural: it asserts the engine's source no longer
        // references that string.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Features
            .deletingLastPathComponent() // CodeEditorPluginTests
            .deletingLastPathComponent() // Tests
            .appendingPathComponent("Sources/CodeEditorPlugin/Features/SmartEditingEngine.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(
            source.contains("Replacing existing text view delegate"),
            "The warning log line should be deleted; its presence signals the SmartEditingEngine.attach delegate-stomping bug has regressed."
        )
    }

    // MARK: - Test helper

    private func invokeShouldChange(
        codeEditorView: CodeEditorView,
        range: NSRange,
        replacement: String
    ) -> Bool {
        #if canImport(AppKit)
        return codeEditorView.delegateMultiplexer.textView(
            codeEditorView,
            shouldChangeTextIn: range,
            replacementString: replacement
        )
        #else
        return codeEditorView.delegateMultiplexer.textView(
            codeEditorView,
            shouldChangeTextIn: range,
            replacementText: replacement
        )
        #endif
    }
}
```

Notes:
- `VetoingHostDelegate` / `AllowingHostDelegate` are stand-ins for the host's `CodeEditorViewDelegate`. Setting `codeEditorView.textDelegate` plugs them into the existing proxy, which is now a `.gating` participant.
- `testNoReplacingDelegateWarningLog` reads the actual source file at test time — a structural assertion that the migration removed the warning. Cheap and reliable.
- `textKitBridge.documentLength` and `textKitBridge.documentString` are the framework's TK2-safe accessors (added during the TextKit 2 coercion fix in the same session). They avoid touching `textStorage` directly.

- [ ] **Step 2: Run the new tests**

Run:
```bash
swift test --filter SmartEditingEngineMultiplexerTests
```

Expected: all 3 tests pass.

- [ ] **Step 3: Run the full `swift test --parallel` sanity check**

Run:
```bash
swift test --parallel
```

Expected: the documented pre-existing failures (listed in the PR #1 checkpoint) reproduce; everything else passes. No new failures.

- [ ] **Step 4: Commit**

```bash
git add Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift
git commit -m "$(cat <<'EOF'
Add SmartEditingEngine multiplexer regression tests

Three tests:
- Host veto via CodeEditorViewDelegate.shouldChangeTextIn blocks
  SmartEditingEngine's auto-indent side-effect AND prevents
  publishWillEditEvent. Encodes the REVIEW.md bug as a regression test.
- Auto-bracket still works end-to-end when host allows the edit.
- Source-level assertion that the "Replacing existing text view
  delegate" warning is deleted — its return would signal a regression
  of the delegate-stomping pattern.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## PR #2 checkpoint

Before opening PR #2 (Tasks 8–9), run the quality pipeline:

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: build green, lint clean, the three new `SmartEditingEngineMultiplexerTests` and 12 existing `TextViewDelegateMultiplexerTests` pass. Pre-existing failures unchanged.

The PR description must enumerate the same pre-existing failures listed in the PR #1 checkpoint.

---

## Task 10: Migrate iOS `CodeEditorContainerView` to participant

**Files:**
- Modify: `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+UIKitExtensions.swift`
- Modify: `Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift`

iOS-only path. macOS is untouched.

- [ ] **Step 1: Drop the `UITextViewDelegate` extension and add a participant conformance**

Open `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+UIKitExtensions.swift`. Find the extension at line 248:

```swift
// MARK: - UITextViewDelegate

extension CodeEditorContainerView: UITextViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // ...
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // ...
    }

    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        // ...
    }

    public func scrollViewDidEndDecelerating(_: UIScrollView) {
        // ...
    }
}
```

Replace with:

```swift
// MARK: - TextViewDelegateParticipant

extension CodeEditorContainerView: TextViewDelegateParticipant {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update minimap when text view scrolls.
        updateMinimap()
        gutterView.scrollViewDidScroll(scrollView)
        gutterView.setNeedsDisplay()
    }

    public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // Start updating line numbers when scrolling begins.
        gutterView.scrollViewWillBeginDragging(scrollView)
    }

    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            gutterView.setNeedsDisplayLineNumbers()
        }
    }

    public func scrollViewDidEndDecelerating(_: UIScrollView) {
        gutterView.setNeedsDisplayLineNumbers()
    }
}
```

The body of each method is unchanged from the old `UITextViewDelegate` extension. The conformance changes; that's it.

- [ ] **Step 2: Update the `textView.delegate = self` line in the same file**

In `Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+UIKitExtensions.swift`, find line 75:

```swift
        // Set the text view's delegate AFTER configuration
        // This must be done after textView.setupTextView() and configuration.apply()
        textView.delegate = self
```

Replace with:

```swift
        // Register as a behavior-phase participant in the delegate
        // multiplexer. The multiplexer is set as textView.delegate by
        // TextKitSetupHelper; we participate from there for scroll
        // forwarding.
        textView.addDelegateParticipant(self, phase: .behavior)
```

- [ ] **Step 3: Update the `ContainerViewInitializer` site**

Open `Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift`. Find lines 212-213 (inside `setupUIKitViews`):

```swift
        // Set delegate LAST to ensure it's not overridden
        components.textView.delegate = container
```

Replace with:

```swift
        // Register the container as a behavior-phase participant in the
        // delegate multiplexer. The multiplexer is installed as
        // textView.delegate by TextKitSetupHelper; "delegate LAST" is no
        // longer meaningful — registration order within a phase is what
        // matters now.
        components.textView.addDelegateParticipant(container, phase: .behavior)
```

- [ ] **Step 4: Build for the iOS path**

On a macOS dev machine, the iOS code path compiles under `swift build` whenever an iOS-compatible toolchain is present; if not, the relevant `#if canImport(UIKit)` blocks are skipped. Run:

```bash
swift build
```

Expected: build succeeds on macOS host (iOS code blocks are gated; `CodeEditorPlugin` still builds for the macOS target). If you have an iOS simulator destination configured, also run:

```bash
xcodebuild -scheme CodeEditorPlugin -destination 'generic/platform=iOS Simulator' build 2>&1 | tail -20
```

Expected: iOS simulator build succeeds.

- [ ] **Step 5: Run lint**

Run:
```bash
swiftlint --fix && swiftlint
```

Expected: zero violations.

- [ ] **Step 6: Commit**

```bash
git add Sources/CodeEditorPlugin/Layout/CodeEditorContainerView+UIKitExtensions.swift Sources/CodeEditorPlugin/Layout/ContainerViewInitializer.swift
git commit -m "$(cat <<'EOF'
Migrate iOS CodeEditorContainerView onto TextViewDelegateParticipant

- Drops UITextViewDelegate conformance; conforms to
  TextViewDelegateParticipant with the same four scroll-forwarding
  methods.
- Both `textView.delegate = self` sites (in +UIKitExtensions.swift and
  ContainerViewInitializer.swift) become
  textView.addDelegateParticipant(self, phase: .behavior).
- macOS path untouched (container does not take the delegate slot on
  macOS; the proxy does).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: Migrate iOS `CodeEditorCoordinator` and delete redundant scroll forwarding

**Files:**
- Modify: `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`

- [ ] **Step 1: Drop `UITextViewDelegate` from the iOS coordinator and conform to participant**

Open `Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift`. Find the iOS coordinator block starting at line 460:

```swift
#elseif canImport(UIKit)

/// iOS-specific coordinator for CodeEditor
@MainActor
final class CodeEditorCoordinator: CodeEditorBaseCoordinator, UITextViewDelegate {
    init(
        text: Binding<String>,
        onTextChange: ((String) -> Void)?,
        onSelectionChange: ((NSRange) -> Void)?,
        interactionState: Binding<EditorInteractionState>? = nil
    ) {
        super.init()
        self.textBinding = text
        self.interactionStateBinding = interactionState
        self.onTextChange = onTextChange
        self.onTextChangeCallback = onTextChange
        self.onSelectionChange = onSelectionChange
        self.onSelectionChangeCallback = onSelectionChange
    }

    func setupTextViewDelegate(_ textView: CodeEditorView) {
        textView.delegate = self
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        handleTextChange(textView.text ?? "")
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        handleSelectionChange(textView.selectedRange)
    }

    // Forward scroll events to the container
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let container = findContainer(for: scrollView) {
            container.scrollViewDidScroll(scrollView)
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if let container = findContainer(for: scrollView) {
            container.scrollViewWillBeginDragging(scrollView)
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if let container = findContainer(for: scrollView) {
            container.scrollViewDidEndDragging(scrollView, willDecelerate: decelerate)
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if let container = findContainer(for: scrollView) {
            container.scrollViewDidEndDecelerating(scrollView)
        }
    }

    private func findContainer(for scrollView: UIScrollView) -> CodeEditorContainerView? {
        var view = scrollView.superview
        while view != nil {
            if let container = view as? CodeEditorContainerView {
                return container
            }
            view = view?.superview
        }
        return nil
    }
}

#endif
```

Replace with:

```swift
#elseif canImport(UIKit)

/// iOS-specific coordinator for CodeEditor.
///
/// Conforms to `TextViewDelegateParticipant` and registers at
/// `.behavior` via `setupTextViewDelegate(_:)`. Receives
/// `textViewDidChangeText` and `textViewDidChangeSelection` from the
/// multiplexer; mirrors them into the SwiftUI text binding and
/// selection callback.
///
/// The scroll-forwarding methods (`scrollViewDidScroll` etc.) that
/// previously walked superviews via `findContainer(for:)` are gone —
/// the container is itself a multiplexer participant after the iOS
/// container migration, so it receives scroll callbacks directly from
/// the multiplexer and the coordinator no longer needs to forward.
@MainActor
final class CodeEditorCoordinator: CodeEditorBaseCoordinator {
    init(
        text: Binding<String>,
        onTextChange: ((String) -> Void)?,
        onSelectionChange: ((NSRange) -> Void)?,
        interactionState: Binding<EditorInteractionState>? = nil
    ) {
        super.init()
        self.textBinding = text
        self.interactionStateBinding = interactionState
        self.onTextChange = onTextChange
        self.onTextChangeCallback = onTextChange
        self.onSelectionChange = onSelectionChange
        self.onSelectionChangeCallback = onSelectionChange
    }

    func setupTextViewDelegate(_ textView: CodeEditorView) {
        textView.addDelegateParticipant(self, phase: .behavior)
    }
}

extension CodeEditorCoordinator: TextViewDelegateParticipant {
    func textViewDidChangeText(_ textView: CodeEditorView) {
        handleTextChange(textView.text ?? "")
    }

    func textViewDidChangeSelection(_ textView: CodeEditorView) {
        handleSelectionChange(textView.selectedRange)
    }
}

#endif
```

What changed:
- Dropped `UITextViewDelegate` from the conformance list.
- Added a separate `TextViewDelegateParticipant` extension implementing only the two methods this coordinator needs.
- Deleted the four `scrollView*` methods entirely (verified pure forwarding per the spec's "Risks and mitigations" table).
- Deleted `findContainer(for:)` — its sole call site (the four scroll methods) is gone.
- `setupTextViewDelegate(_:)` now registers as a participant.
- Note that the participant methods receive `CodeEditorView` (not `UITextView`), so the body reads `textView.text` and `textView.selectedRange` — these are `UITextView` properties accessed on the `CodeEditorView` (which is a `UITextView` subclass on iOS).

- [ ] **Step 2: Build**

Run:
```bash
swift build
```

Expected: build succeeds. If iOS simulator destination is configured, also run the iOS simulator build from Task 10 Step 4.

- [ ] **Step 3: Run lint**

Run:
```bash
swiftlint --fix && swiftlint
```

Expected: zero violations.

- [ ] **Step 4: Commit**

```bash
git add Sources/CodeEditorPlugin/SwiftUI/CodeEditor+CoordinatorsExtensions.swift
git commit -m "$(cat <<'EOF'
Migrate iOS CodeEditorCoordinator onto TextViewDelegateParticipant

- Drops UITextViewDelegate conformance; conforms to
  TextViewDelegateParticipant in a separate extension implementing
  only textViewDidChangeText and textViewDidChangeSelection.
- setupTextViewDelegate(_:) registers self at .behavior with the
  delegate multiplexer instead of stomping textView.delegate.
- Deletes the four scrollView* methods and the findContainer(for:)
  helper: now that CodeEditorContainerView is itself a participant,
  the multiplexer delivers scroll callbacks directly to the container.
  The coordinator's forwarding was pure pass-through.
- macOS coordinator unchanged (does not take the delegate slot).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: Add iOS regression tests

**Files:**
- Create: `Tests/CodeEditorPluginTests/Layout/IOSContainerMultiplexerTests.swift`
- Create: `Tests/CodeEditorPluginTests/SwiftUI/IOSCoordinatorMultiplexerTests.swift`

iOS-only test coverage; the entire file body is gated on `#if canImport(UIKit)`.

- [ ] **Step 1: Create the iOS container scroll-forwarding test**

First check whether the directory exists:

```bash
ls Tests/CodeEditorPluginTests/Layout 2>/dev/null
```

If absent, that's fine — `swift test` creates per-directory targets as needed; just place the file there and SwiftPM picks it up. (The package's `Tests/CodeEditorPluginTests/` is one target; subdirectories are organizational only.)

Create `Tests/CodeEditorPluginTests/Layout/IOSContainerMultiplexerTests.swift`:

```swift
#if canImport(UIKit)
import XCTest
import UIKit
@testable import CodeEditorPlugin

@MainActor
final class IOSContainerMultiplexerTests: XCTestCase {

    func testContainerReceivesScrollDidScrollFromMultiplexer() throws {
        let container = CodeEditorContainerView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))

        // The container was registered at .behavior during its UIKit
        // init. Drive scrollViewDidScroll through the multiplexer and
        // assert the gutter requested a redraw — this is the
        // observable side-effect the old +UIKitExtensions.swift:248
        // method always performed.
        let gutterView = container.gutterView
        let recorder = SetNeedsDisplayRecorder(target: gutterView)

        container.textView.delegateMultiplexer.scrollViewDidScroll(container.textView)

        XCTAssertGreaterThanOrEqual(
            recorder.setNeedsDisplayCount,
            1,
            "Gutter must receive setNeedsDisplay when the container's scrollViewDidScroll fires"
        )
    }
}

/// Records `setNeedsDisplay` calls on a target UIView by swizzling
/// at test scope. Simpler than full method swizzling: since we're in
/// `@testable import`, we can observe the gutter's existing
/// `setNeedsDisplay()` calls via a KVO/probe pattern. For now, we just
/// observe the gutter's `layer.needsDisplay` flag.
@MainActor
private final class SetNeedsDisplayRecorder {
    private weak var target: UIView?
    private var beforeSetNeedsDisplay: Bool

    init(target: UIView) {
        self.target = target
        self.beforeSetNeedsDisplay = target.layer.needsDisplay()
    }

    var setNeedsDisplayCount: Int {
        guard let target else { return 0 }
        // After setNeedsDisplay, needsDisplay returns true. This is
        // approximate (a single call sets the flag regardless of how
        // many times setNeedsDisplay was invoked) but it's enough to
        // assert "at least one setNeedsDisplay fired".
        return target.layer.needsDisplay() && !beforeSetNeedsDisplay ? 1 : 0
    }
}
#endif
```

If the layer-flag observation turns out to be too coarse during local iteration, replace `SetNeedsDisplayRecorder` with a small `GutterViewTestProbe` subclass that overrides `setNeedsDisplay()` to bump a counter, and use that subclass for the test. The simpler layer-flag approach is fine as a first pass.

- [ ] **Step 2: Create the iOS coordinator text-binding mirror test**

Create `Tests/CodeEditorPluginTests/SwiftUI/IOSCoordinatorMultiplexerTests.swift`:

```swift
#if canImport(UIKit)
import XCTest
import SwiftUI
import UIKit
@testable import CodeEditorPlugin

@MainActor
final class IOSCoordinatorMultiplexerTests: XCTestCase {

    func testCoordinatorTextChangeMirrorsBinding() throws {
        var bindingValue = "initial"
        var onTextChangeReceived: String?

        let binding = Binding<String>(
            get: { bindingValue },
            set: { bindingValue = $0 }
        )
        let coordinator = CodeEditorCoordinator(
            text: binding,
            onTextChange: { onTextChangeReceived = $0 },
            onSelectionChange: nil
        )

        let codeEditorView = CodeEditorView(frame: .zero)
        coordinator.setupTextViewDelegate(codeEditorView)

        // Mutate the text view's underlying text, then drive
        // textViewDidChangeText through the participant API. The
        // multiplexer would call this same method when AppKit/UIKit
        // fires textViewDidChange.
        codeEditorView.text = "hello"
        coordinator.textViewDidChangeText(codeEditorView)

        XCTAssertEqual(bindingValue, "hello", "Text binding must mirror textViewDidChangeText")
        XCTAssertEqual(onTextChangeReceived, "hello", "onTextChange callback must fire")
    }
}
#endif
```

- [ ] **Step 3: Build and run the iOS regression tests**

```bash
swift test --filter IOSContainerMultiplexerTests || true
swift test --filter IOSCoordinatorMultiplexerTests || true
```

Note: on a macOS host without an iOS simulator target, these tests' `#if canImport(UIKit)` guard means they compile to empty when running `swift test` against the macOS-target package. The `|| true` accepts the resulting "no tests run" outcome as a pass.

If the project has CI that runs the iOS simulator, the tests fire there. For local development, the macOS unit tests in Tasks 3, 4, and 9 provide the regression coverage; these iOS-specific tests are for CI / iOS-simulator runs.

- [ ] **Step 4: Run lint and the macOS test suite**

```bash
swiftlint --fix && swiftlint && swift test --parallel
```

Expected: lint clean. Pre-existing failures unchanged. The four new test classes (`TextViewDelegateMultiplexerTests`, `SmartEditingEngineMultiplexerTests`, plus the two iOS classes that no-op on macOS host) compile and pass / no-op as expected.

- [ ] **Step 5: Commit**

```bash
git add Tests/CodeEditorPluginTests/Layout/IOSContainerMultiplexerTests.swift Tests/CodeEditorPluginTests/SwiftUI/IOSCoordinatorMultiplexerTests.swift
git commit -m "$(cat <<'EOF'
Add iOS regression tests for multiplexer migration

- IOSContainerMultiplexerTests: asserts the container's
  scrollViewDidScroll still fires the gutter's setNeedsDisplay path
  after the UITextViewDelegate -> TextViewDelegateParticipant swap.
- IOSCoordinatorMultiplexerTests: asserts the iOS SwiftUI
  coordinator's text binding still mirrors textViewDidChangeText
  after the same swap.

Both test files are gated on #if canImport(UIKit); on macOS hosts they
compile to empty and pass trivially.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: Add SwiftLint guard and update invariant doc

**Files:**
- Modify: `.swiftlint.yml`
- Modify: `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`

The final step closes the regression class structurally.

- [ ] **Step 1: Add the custom rule to `.swiftlint.yml`**

Open `.swiftlint.yml`. Find the `custom_rules:` section (starts at line 252). Add a new rule beneath `allow_nsstring_drawing`:

```yaml
  forbidden_text_view_delegate_assignment:
    included: 'Sources/.*\.swift'
    excluded: 'Sources/CodeEditorPlugin/Core/TextKitSetupHelper\.swift'
    name: "Forbidden textView.delegate Assignment"
    # Match any `<expr>.delegate = …` where <expr> ends in "textView".
    # TextViewDelegateMultiplexer is the sole owner; participation flows
    # through CodeEditorView.addDelegateParticipant(_:phase:). The only
    # legitimate install site is TextKitSetupHelper.setupTextKit.
    regex: '\btextView\.delegate\s*='
    message: "Do not assign to textView.delegate. Register as a TextViewDelegateParticipant via CodeEditorView.addDelegateParticipant(_:phase:). The sole legitimate install site is TextKitSetupHelper.setupTextKit."
    severity: error
```

- [ ] **Step 2: Run lint to confirm the rule is parsed and fires only at the excluded site**

```bash
swiftlint
```

Expected: zero violations. The rule's regex matches `textView.delegate =` patterns; the only remaining occurrence in `Sources/` should be `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift` (which is in the rule's `excluded` set).

If the rule reports a violation, investigate: it means a `textView.delegate =` site survived the migration. The exclusion only covers `TextKitSetupHelper.swift` — every other site must have been migrated to `addDelegateParticipant`. Re-check Tasks 6, 8, 10, 11 if a violation appears.

- [ ] **Step 3: Update the invariant comment in `CodeEditorView.swift`**

Open `Sources/CodeEditorPlugin/Core/CodeEditorView.swift`. Find the named-commit invariant block at lines 159-188 (the multi-paragraph comment about TextKit 2 invariants). Add a new paragraph at the end, just before the blank line that separates the comment from the `internal var featureDependencies` property:

```swift
    //
    // **Delegate ownership invariant.** `textView.delegate` is owned
    // exclusively by `TextViewDelegateMultiplexer`, installed during
    // `TextKitSetupHelper.setupTextKit`. Features that need delegate
    // hooks (host proxy, smart editing, iOS scroll forwarding, iOS
    // SwiftUI coordinator) register via
    // `addDelegateParticipant(_:phase:)` — never by assigning to
    // `textView.delegate` directly. The SwiftLint custom rule
    // `forbidden_text_view_delegate_assignment` enforces this at lint
    // time; `TextKitSetupHelper.swift` is its only exemption. See
    // `docs/superpowers/specs/2026-05-14-delegate-multiplexer-design.md`
    // for the full design.
```

The exact insertion point: immediately after the existing line about the NSRulerView TK1 island, before the blank line preceding `/// Explicit feature dependencies …`. Verify the line numbers by re-reading lines 180-190 of the file; the file has been edited in earlier tasks so they may have shifted slightly.

- [ ] **Step 4: Run the full quality pipeline**

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: build green, lint clean (the new rule does not fire), `swift test --parallel` shows the same pass set with the documented pre-existing failures.

- [ ] **Step 5: Commit**

```bash
git add .swiftlint.yml Sources/CodeEditorPlugin/Core/CodeEditorView.swift
git commit -m "$(cat <<'EOF'
Add SwiftLint rule + invariant doc for delegate ownership

- forbidden_text_view_delegate_assignment: custom regex rule that
  bans `textView.delegate = …` outside the canonical install site
  (TextKitSetupHelper.swift). Severity: error.
- Invariant comment in CodeEditorView.swift's named-commit block
  documents that the multiplexer owns the delegate slot and points
  readers at the design spec.

After this commit, the regression class the spec identifies is
structurally closed: any future "feature stomps textView.delegate"
bug surfaces as a lint error in CI rather than a silent behavior
regression.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Update REVIEW.md

**Files:**
- Modify: `REVIEW.md`

Documents that the work landed; mirrors the convention used by every prior batch in this session.

- [ ] **Step 1: Add a status entry under "What's left after this round"**

Open `REVIEW.md`. Find this bullet:

```markdown
- **`SmartEditingEngine.attach` overwrites the delegate** — needs a multiplexer (LSP / completion / folding all want the slot). Generalising the `TextEditEventObserving` pattern from `CodeFoldingEngine` is the suggested template in "Patterns worth codifying".
```

Replace with:

```markdown
- ~~**`SmartEditingEngine.attach` overwrites the delegate** — needs a multiplexer (LSP / completion / folding all want the slot). Generalising the `TextEditEventObserving` pattern from `CodeFoldingEngine` is the suggested template in "Patterns worth codifying".~~ ✅ Landed in the Delegate multiplexer batch on 2026-05-14. `TextViewDelegateMultiplexer` is the sole owner of `textView.delegate`; `CodeEditorViewDelegateProxy` registers at `.gating`; `SmartEditingEngine`, iOS `CodeEditorContainerView`, and iOS `CodeEditorCoordinator` register at `.behavior`. SwiftLint rule `forbidden_text_view_delegate_assignment` prevents the regression class. Spec at `docs/superpowers/specs/2026-05-14-delegate-multiplexer-design.md`; plan at `docs/superpowers/plans/2026-05-14-delegate-multiplexer.md`.
```

- [ ] **Step 2: Add a batch section near the top of the file**

Find the most recent batch section header (currently `### \`CompletionEvent\` AsyncStream batch (landed 2026-05-14)` near line 337). Below the closing line of that section ("the 5 pre-existing failures from earlier batches … reproduce unchanged."), add:

```markdown
### Delegate multiplexer batch (landed 2026-05-14)

Closes the "What's left after this round" SmartEditingEngine-stomps-delegate item. Three PRs: load-bearing macOS path (multiplexer + proxy migration), SmartEditingEngine fix, iOS cleanup + SwiftLint guard. Spec at `docs/superpowers/specs/2026-05-14-delegate-multiplexer-design.md`; plan at `docs/superpowers/plans/2026-05-14-delegate-multiplexer.md`.

| Item | Status | What landed |
|---|---|---|
| `TextViewDelegateMultiplexer` becomes the sole owner of `textView.delegate` | ✅ Done | `Sources/CodeEditorPlugin/Core/TextViewDelegateMultiplexer.swift`. Conforms to `NSTextViewDelegate` (macOS) / `UITextViewDelegate` (iOS) under `#if`s. Holds two weakly-stored `[WeakParticipant]` arrays — `.gating` (one slot: `CodeEditorViewDelegateProxy`) and `.behavior` (smart editing, iOS scroll forwarding, iOS SwiftUI coordinator). Per-method semantics: veto chain for `shouldChangeTextIn`, fan-out for notifications, first-non-nil-wins for value-returning methods, first-handler-wins for clicks, all-must-agree for attachment interaction. After both phases vote allow on `shouldChangeTextIn:`, the multiplexer publishes `WillEditEvent` to the existing `TextEditEventHub` consumers as an intrinsic side-effect. |
| `TextViewDelegateParticipant` protocol + `TextViewDelegatePhase` enum | ✅ Done | `Sources/CodeEditorPlugin/Core/TextViewDelegateParticipant.swift`. Internal-only protocol with default impls so participants only implement what they care about. Phase enum is two cases by design; the intrinsic `publishWillEditEvent` side-effect is the multiplexer's own, not a participant phase. |
| `CodeEditorViewDelegateProxy` migrated | ✅ Done | Dropped `NSTextViewDelegate`/`UITextViewDelegate` conformances; conforms to `TextViewDelegateParticipant`. Removed both `publishWillEditEvent` call sites (lines 164, 200 in the old body) — the multiplexer publishes now. `TextKitSetupHelper.setupTextKit` registers the proxy at `.gating` and installs the multiplexer as `textView.delegate`. |
| `SmartEditingEngine` migrated | ✅ Done | Dropped both platform-delegate extensions (lines 149-203 + 204-249). Conforms to `TextViewDelegateParticipant`. `attach(to:)` now calls `textView.addDelegateParticipant(self, phase: .behavior)`. Added `detach()`. The "Replacing existing text view delegate" warning log is gone — the structural problem it warned about is structurally impossible. |
| iOS `CodeEditorContainerView` migrated | ✅ Done | Dropped `UITextViewDelegate` extension; conforms to `TextViewDelegateParticipant` with the same four scroll-forwarding methods. Both `textView.delegate = self` sites (in `+UIKitExtensions.swift:75` and `ContainerViewInitializer.swift:213`) replaced with `addDelegateParticipant`. |
| iOS `CodeEditorCoordinator` migrated | ✅ Done | Dropped `UITextViewDelegate` conformance from the iOS coordinator; conforms to `TextViewDelegateParticipant` in a separate extension. Deleted the four `scrollView*` methods and `findContainer(for:)` — pure pass-through to the container, which now receives those callbacks directly from the multiplexer. `setupTextViewDelegate(_:)` registers at `.behavior`. macOS coordinator unchanged (does not take the delegate slot). |
| SwiftLint guard | ✅ Done | New `forbidden_text_view_delegate_assignment` custom rule in `.swiftlint.yml`. Matches `\btextView\.delegate\s*=` in `Sources/`; excludes only `TextKitSetupHelper.swift` (the canonical install site). Severity: error. |
| Invariant doc | ✅ Done | New "Delegate ownership invariant" paragraph in the `CodeEditorView.swift` named-commit invariant block (around lines 159-200 of the post-edit file) documenting the multiplexer ownership rule and pointing at the spec. |

**Tests added (16 across 4 files):**
- `Tests/CodeEditorPluginTests/Core/TextViewDelegateMultiplexerTests.swift` — 12 cases covering phase ordering, fan-out, first-non-nil-wins, first-handler-wins, all-must-agree, weak storage, idempotent registration, and removeParticipant.
- `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift` — 3 cases: host veto blocks auto-indent (the REVIEW.md bug encoded as a regression test), auto-bracket still works when host allows, source-level assertion that the "Replacing existing text view delegate" warning is gone.
- `Tests/CodeEditorPluginTests/Layout/IOSContainerMultiplexerTests.swift` — 1 case (iOS-only): container's `scrollViewDidScroll` still fires the gutter's `setNeedsDisplay` path.
- `Tests/CodeEditorPluginTests/SwiftUI/IOSCoordinatorMultiplexerTests.swift` — 1 case (iOS-only): iOS coordinator's text binding still mirrors `textViewDidChangeText`.

**Public API impact.** Strictly additive on the *new* surface, all `internal`. The `CodeEditorViewDelegate` protocol and `CodeEditorView.textDelegate` property — the host-facing public surface — are entirely unchanged. Source-breaking changes confined to internal-only dropped conformances on `CodeEditorViewDelegateProxy`, `SmartEditingEngine`, iOS `CodeEditorContainerView`, and iOS `CodeEditorCoordinator`. No in-tree callers reached into those dropped extensions; sample is unaffected.

Build: green. SwiftLint: 0 violations (new rule does not fire). `swift test --parallel` results: the new 12+3+1+1 tests pass; the 6 pre-existing failures listed in earlier batches (`EditorStatusBarSnapshots/*`, `RegexRangeHighlightProviderTests.testParsePerformance10K/100KLines`, `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`, `DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage`, `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed`, `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor`) reproduce unchanged.

```

- [ ] **Step 3: Commit**

```bash
git add REVIEW.md
git commit -m "$(cat <<'EOF'
Update REVIEW.md: Delegate multiplexer batch landed

Marks the "What's left after this round" SmartEditingEngine-stomps-
delegate item as resolved. Documents the three-PR landing shape
(multiplexer + proxy migration, SmartEditingEngine fix, iOS cleanup +
SwiftLint guard), the 16 tests added, and the public-API-strictly-
additive impact.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## PR #3 checkpoint

Final quality pipeline before opening PR #3 (Tasks 10–14):

```bash
swift build && swiftlint --fix && swiftlint && swift test --parallel
```

Expected: build green, lint clean (including the new `forbidden_text_view_delegate_assignment` rule), all multiplexer and migration tests pass, pre-existing failures unchanged. Open the PR with the same enumerated pre-existing failure list as PRs #1 and #2.

---

## Self-review

**Spec coverage check.**

| Spec section | Covered by |
|---|---|
| `TextViewDelegateParticipant` protocol + defaults | Task 1 |
| `TextViewDelegatePhase` enum | Task 1 |
| `TextViewDelegateMultiplexer` class + weak storage | Task 2 |
| Per-method semantics impls in the multiplexer | Task 2 |
| Intrinsic `publishWillEditEvent` step | Task 2 (shouldChangeText helper) |
| Multiplexer unit tests (12 listed in spec) | Tasks 3–4 |
| `CodeEditorView` integration (`delegateMultiplexer` + convenience methods) | Task 5 |
| `TextKitSetupHelper` install change | Task 7 |
| `CodeEditorViewDelegateProxy` migrated to participant + `publishWillEditEvent` move | Task 6 |
| `SmartEditingEngine.attach` → register as `.behavior` participant | Task 8 |
| `SmartEditingEngine.detach` (new) | Task 8 |
| `SmartEditingEngine` regression tests (3 listed in spec) | Task 9 |
| iOS `CodeEditorContainerView` migration | Task 10 |
| iOS `CodeEditorCoordinator` migration + scroll-forwarding deletion | Task 11 |
| iOS regression tests (2 listed in spec) | Task 12 |
| SwiftLint custom rule | Task 13 |
| Invariant doc | Task 13 |
| REVIEW.md status update | Task 14 |
| Pre-existing failures policy | Every PR checkpoint |

All spec sections covered.

**Placeholder scan.** No "TBD" / "TODO" / "implement later" / placeholder phrases. Every code step shows the actual code. Every command shows the exact invocation and expected outcome.

**Type / name consistency.** `TextViewDelegateMultiplexer`, `TextViewDelegateParticipant`, `TextViewDelegatePhase`, `addDelegateParticipant`, `removeDelegateParticipant`, `delegateMultiplexer`, `delegateProxy`, `textDelegate`, `textEditEventHub`, `publishWillEditEvent`, `WillEditEvent`, `WillEditEventObserving`, `CodeEditorViewDelegateProxy`, `CodeEditorViewDelegate`, `CodeEditorView`, `CodeEditorContainerView`, `CodeEditorCoordinator`, `SmartEditingEngine`, `forbidden_text_view_delegate_assignment` — names are consistent across all tasks. Phases are spelled `.gating` and `.behavior` everywhere. The participant protocol's veto-chain return semantics (`false` = block) are described consistently in spec and plan.
