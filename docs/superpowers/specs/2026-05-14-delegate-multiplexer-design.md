# Delegate Multiplexer — Design

**Status.** Draft, 2026-05-14.
**Tracks.** REVIEW.md "What's left after this round" — `SmartEditingEngine.attach` overwrites the `textView.delegate` slot. Generalises the multi-owner delegate problem the reviewer flagged under "Patterns worth codifying" (one delegate-multiplexer for `NSTextViewDelegate`/`UITextViewDelegate`).

## Problem

The framework has a single `textView.delegate` slot and at least four owners that want it. Today they fight, and the loser is whichever one is assigned last.

Concrete sites that assign `textView.delegate` today (`Sources/CodeEditorPlugin`):

- `Core/TextKitSetupHelper.swift:73-75` — installs `textView.delegateProxy` (the canonical `CodeEditorViewDelegateProxy`) *only* when `delegate == nil`. That proxy gates on `isEditable`, forwards to the public `CodeEditorViewDelegate`, and publishes `WillEditEvent` for downstream `TextEditEventObserving` consumers.
- `Layout/ContainerViewInitializer.swift:213` — iOS, `components.textView.delegate = container`. The container handles `UIScrollViewDelegate` callbacks for minimap / gutter scroll-syncing.
- `Layout/CodeEditorContainerView+UIKitExtensions.swift:75` — iOS, same `textView.delegate = self`. Second site for the same role.
- `SwiftUI/CodeEditor+CoordinatorsExtensions.swift:481` — iOS SwiftUI coordinator's `setupTextViewDelegate(_:)` does `textView.delegate = self`. Coordinator handles text-binding updates and selection forwarding.
- `Features/SmartEditingEngine.swift:60` — `attach(to:)` does `textView.delegate = self` with a "Replacing existing text view delegate" warning log. Engine implements `shouldChangeTextIn` for auto-bracket / auto-indent / multi-cursor and `textViewDidChangeSelection` for multi-cursor mode tracking.

On macOS the conflict is narrower: `CodeEditorViewDelegateProxy` is installed during `setupTextKit`; `SmartEditingEngine.attach` stomps it. The result is silent: the host's `CodeEditorViewDelegate.shouldChangeTextIn` stops being consulted (read-only regions stop being read-only), `isEditable` checks no longer fire from the proxy, and `WillEditEvent` is never published — so `LSPContentCoordinator` and the range-highlight providers lose their pre-edit-state hook for any edit that goes through the smart-editing path. The warning log is the only signal.

On iOS the situation is worse: the container, the coordinator, the proxy (via `TextKitSetupHelper`), and `SmartEditingEngine` all want the slot. Whichever was assigned last keeps it; everyone else's behavior silently drops.

REVIEW.md's framing under "Patterns worth codifying":

> One delegate-multiplexer for `NSTextViewDelegate`/`UITextViewDelegate` — generalize the `TextEditEventObserving` pattern (`CodeFoldingEngine`) so no feature ever overwrites `delegate` again.

Note that "generalize `TextEditEventObserving`" is structural advice, not literal — `TextEditEventObserving` is the framework's existing pattern for fan-out of `textStorageDidApplyEdit` events to multiple weak observers (`Text/TextEditEventHub.swift`). Delegate methods are a different surface (`NSTextViewDelegate`/`UITextViewDelegate`) with richer per-method semantics: some return a value (`undoManager(for:)`), some are veto chains (`shouldChangeTextIn:`), some are simple fan-out (`textViewDidChangeSelection`). The multiplexer takes the same shape (weakly-held observer list with explicit registration) but encodes those per-method semantics rather than fanning out indiscriminately.

## Goals & non-goals

**Goal.** Exactly one object holds `textView.delegate` for the lifetime of the view — a new internal `TextViewDelegateMultiplexer`. Every other consumer becomes a participant, registering through a typed protocol. `shouldChangeTextIn` enforces a phase ordering in the type system so a host veto can't be silently bypassed by behavior interception (the actual bug). After this lands the project gains a SwiftLint rule banning future `textView.delegate = …` outside the multiplexer's install site, so the regression class is structurally closed.

**Non-goals.**

- *Public extension point.* Multiplexer and `TextViewDelegateParticipant` stay `internal`. The host-facing surface is unchanged: hosts keep using `CodeEditorViewDelegate` via the `textDelegate` property, exactly as today. Promoting to `public` is a future call once the protocol shape has lived in-tree for a release.
- *Replacing `TextEditEventObserving`.* The post-edit text-storage fan-out (`textStorageDidApplyEdit`) keeps its existing hub. Delegate-method fan-out is a separate surface; the two don't merge.
- *Folding the public `CodeEditorViewDelegate` protocol.* `CodeEditorViewDelegateProxy` becomes a participant but the protocol it forwards to stays exactly as it is.
- *Cross-platform unification of the platform delegate surface.* The multiplexer still conforms to `NSTextViewDelegate` on macOS and `UITextViewDelegate` on iOS under `#if`s. We expose a *single* participant protocol but the multiplexer's own conformance is platform-gated.
- *Generalising `TextEditEventObserving` literally.* The two patterns are siblings, not heir-and-ancestor.

## Design overview

```
                ┌──────────────────────────────────────────────────────┐
                │ CodeEditorView (NSTextView / UITextView)             │
                │                                                       │
                │   delegate ──→ TextViewDelegateMultiplexer            │
                │                  (sole owner of the delegate slot)   │
                │                                                       │
                │   delegateMultiplexer (internal property)            │
                └──────────────────────────────────────────────────────┘
                                       │
                                       │ walks two ordered lists
                                       ▼
                  ┌─────────────────────────────────────────┐
                  │ Phase .gating   (host delegate proxy,   │
                  │                  isEditable, read-only) │
                  ├─────────────────────────────────────────┤
                  │ Phase .behavior (SmartEditingEngine,    │
                  │                  iOS container scroll,  │
                  │                  iOS SwiftUI coord, …)  │
                  └─────────────────────────────────────────┘
                                       │
                                       │ if both phases say "allow"
                                       ▼
                  Multiplexer intrinsic: publishWillEditEvent
```

One internal `TextViewDelegateMultiplexer: NSObject` conforming to `NSTextViewDelegate` (macOS) / `UITextViewDelegate` (iOS). It is the only thing the framework ever assigns to `textView.delegate`. It holds two `[WeakParticipant]` arrays, one per phase, and walks them with per-method semantics: veto chain for `shouldChangeTextIn`, fan-out for notifications, first-non-nil-wins for value-returning methods, first-handler-wins for click handling, all-must-agree for attachment-interaction gating.

Built-in participants:

- `CodeEditorViewDelegateProxy` → `.gating`. Registered eagerly during `setupTextKit`. Keeps its existing job (forwarding to public `CodeEditorViewDelegate`, gating on `isEditable`). The `publishWillEditEvent` call that lives in its body today moves out — the multiplexer handles that intrinsically after both phases vote allow.
- `SmartEditingEngine` → `.behavior`. Registered in `attach(to:)`. Replaces today's `textView.delegate = self`.
- iOS `CodeEditorContainerView` → `.behavior`. Registered in its UIKit init path. Replaces today's two `textView.delegate = self` sites.
- iOS `CodeEditorCoordinator` → `.behavior`. Registered in `setupTextViewDelegate(_:)`. Replaces today's `textView.delegate = self`.

The phase split exists for exactly one reason: `shouldChangeTextIn` is the method where the bug manifests, and it has two distinct interpretations of "false" — a host gating "false" (edit not allowed) and a smart-editing "false" (I already wrote the replacement). Running gating first and short-circuiting means `SmartEditingEngine`'s side-effects (auto-indent writing to `textStorage`) never fire on a host-vetoed edit. The two-phase shape encodes that invariant in the type system.

For every other delegate method, phase membership only determines iteration order (gating-list-first, then behavior-list) — the semantics (fan-out, first-non-nil, first-handler-wins, all-must-agree) are identical across phases. We don't need a third phase because the multiplexer's own `publishWillEditEvent` step isn't a participant — it's an intrinsic side-effect that runs after the participant phases.

## API surface

### `TextViewDelegateParticipant` (new internal protocol)

```swift
// Sources/CodeEditorPlugin/Core/TextViewDelegateParticipant.swift
@MainActor
internal protocol TextViewDelegateParticipant: AnyObject {
    // Veto chain — default true (allow)
    func textView(_ textView: CodeEditorView,
                  shouldChangeTextIn range: NSRange,
                  replacementString: String?) -> Bool

    // Fan-out notifications — default no-op
    func textViewWillChangeText(_ textView: CodeEditorView)
    func textViewDidChangeText(_ textView: CodeEditorView)
    func textViewDidChangeSelection(_ textView: CodeEditorView)

    // First-non-nil-wins — default nil
    func undoManager(for textView: CodeEditorView) -> UndoManager?
    func completionViewController(for textView: CodeEditorView)
        -> (any CompletionViewControllerRepresentable)?
    func insertionPointView(for textView: CodeEditorView,
                            frame: CGRect) -> (any InsertionPointIndicating)?

    // First-handler-wins — default false
    func textView(_ textView: CodeEditorView,
                  clickedOnLink link: Any,
                  at location: any NSTextLocation) -> Bool
    func textView(_ textView: CodeEditorView,
                  clickedOnAttachment attachment: NSTextAttachment,
                  at location: any NSTextLocation) -> Bool

    // All-must-agree — default true
    func textView(_ textView: CodeEditorView,
                  shouldAllowInteractionWith attachment: NSTextAttachment,
                  at location: any NSTextLocation) -> Bool

    #if canImport(UIKit)
    // Fan-out scroll callbacks — default no-op
    func scrollViewDidScroll(_ scrollView: UIScrollView)
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool)
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    #endif
}

extension TextViewDelegateParticipant {
    func textView(_: CodeEditorView,
                  shouldChangeTextIn _: NSRange,
                  replacementString _: String?) -> Bool { true }
    func textViewWillChangeText(_: CodeEditorView) {}
    func textViewDidChangeText(_: CodeEditorView) {}
    func textViewDidChangeSelection(_: CodeEditorView) {}
    func undoManager(for _: CodeEditorView) -> UndoManager? { nil }
    func completionViewController(for _: CodeEditorView)
        -> (any CompletionViewControllerRepresentable)? { nil }
    func insertionPointView(for _: CodeEditorView,
                            frame _: CGRect) -> (any InsertionPointIndicating)? { nil }
    func textView(_: CodeEditorView, clickedOnLink _: Any,
                  at _: any NSTextLocation) -> Bool { false }
    func textView(_: CodeEditorView, clickedOnAttachment _: NSTextAttachment,
                  at _: any NSTextLocation) -> Bool { false }
    func textView(_: CodeEditorView,
                  shouldAllowInteractionWith _: NSTextAttachment,
                  at _: any NSTextLocation) -> Bool { true }
    #if canImport(UIKit)
    func scrollViewDidScroll(_: UIScrollView) {}
    func scrollViewWillBeginDragging(_: UIScrollView) {}
    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate _: Bool) {}
    func scrollViewDidEndDecelerating(_: UIScrollView) {}
    #endif
}
```

### `TextViewDelegatePhase` (new internal enum)

```swift
internal enum TextViewDelegatePhase {
    /// Run first. Host gating, isEditable checks, read-only regions.
    case gating
    /// Run after gating. Smart-editing interception, scroll forwarding,
    /// SwiftUI coordinator state mirroring. Side-effects (e.g. writes to
    /// textStorage) only fire here if gating allowed.
    case behavior
}
```

Two cases is intentional. The intrinsic `publishWillEditEvent` step is *not* a phase — it runs after both lists, owned by the multiplexer itself. Adding a third `.sideEffect` enum case would invite participants to register there; the side-effect today is a fixed framework concern and should stay one.

### `TextViewDelegateMultiplexer` (new internal class)

```swift
// Sources/CodeEditorPlugin/Core/TextViewDelegateMultiplexer.swift
@MainActor
internal final class TextViewDelegateMultiplexer: NSObject {
    private var gatingParticipants: [WeakParticipant] = []
    private var behaviorParticipants: [WeakParticipant] = []

    internal func addParticipant(_ participant: any TextViewDelegateParticipant,
                                 phase: TextViewDelegatePhase)
    internal func removeParticipant(_ participant: any TextViewDelegateParticipant)
}

#if canImport(AppKit)
extension TextViewDelegateMultiplexer: NSTextViewDelegate { /* per-method impls */ }
#elseif canImport(UIKit)
extension TextViewDelegateMultiplexer: UITextViewDelegate { /* per-method impls */ }
#endif

private struct WeakParticipant {
    weak var value: (any TextViewDelegateParticipant)?
}
```

Weak storage and pruning logic mirror `TextEditEventHub` (`Sources/CodeEditorPlugin/Text/TextEditEventHub.swift:121-144`): prune on add, prune on iterate, identity-based deduplication via `===`. Registration is idempotent — adding the same participant twice is a no-op.

### `CodeEditorView` integration

```swift
// Sources/CodeEditorPlugin/Core/CodeEditorView.swift (additions)
internal let delegateMultiplexer = TextViewDelegateMultiplexer()

internal func addDelegateParticipant(_ p: any TextViewDelegateParticipant,
                                     phase: TextViewDelegatePhase = .behavior) {
    delegateMultiplexer.addParticipant(p, phase: phase)
}

internal func removeDelegateParticipant(_ p: any TextViewDelegateParticipant) {
    delegateMultiplexer.removeParticipant(p)
}
```

The two convenience wrappers keep registration callers from having to reach through the multiplexer property. `.behavior` is the default phase because it's the right answer for every consumer except the proxy (which the framework registers directly during `setupTextKit`).

### `TextKitSetupHelper` changes

`setupTextKit` (`Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift:73-75`) currently does:

```swift
if textView.delegate == nil {
    textView.delegate = textView.delegateProxy
}
```

After this change:

```swift
textView.delegateMultiplexer.addParticipant(textView.delegateProxy, phase: .gating)
textView.delegate = textView.delegateMultiplexer
```

The `if delegate == nil` guard is gone — the multiplexer is the unconditional answer. The proxy keeps existing; it just stops being installed directly.

## Data flow per method

### `shouldChangeTextIn:replacementString:` (the load-bearing one)

```swift
func textView(_ textView: NSTextView, // or UITextView on iOS
              shouldChangeTextIn affectedCharRange: NSRange,
              replacementString: String?) -> Bool {
    guard let codeEditorView = textView as? CodeEditorView else { return true }

    // Phase 1: gating
    pruneGating()
    for entry in gatingParticipants {
        guard entry.value?.textView(codeEditorView,
                                    shouldChangeTextIn: affectedCharRange,
                                    replacementString: replacementString) ?? true
        else { return false }
    }

    // Phase 2: behavior
    pruneBehavior()
    for entry in behaviorParticipants {
        guard entry.value?.textView(codeEditorView,
                                    shouldChangeTextIn: affectedCharRange,
                                    replacementString: replacementString) ?? true
        else { return false }
    }

    // Intrinsic side-effect: pre-mutation hook for TextEditEventHub consumers
    codeEditorView.publishWillEditEvent(
        range: affectedCharRange,
        replacementText: replacementString ?? ""
    )
    return true
}
```

A `false` from any gating participant short-circuits before behavior runs. A `false` from any behavior participant blocks the edit and *also* prevents `publishWillEditEvent`. Both must vote true for the edit to proceed.

Note on iOS: `UITextViewDelegate`'s signature is `shouldChangeTextIn range: NSRange, replacementText text: String` (non-optional). The multiplexer's iOS-side method adapts that to the participant protocol's `replacementString: String?` (passing the iOS text as `.some`).

### Fan-out notifications

`textViewWillChangeText`, `textViewDidChangeText`, `textViewDidChangeSelection`, and on iOS the four `scrollView*` callbacks. Multiplexer concatenates `gatingParticipants + behaviorParticipants` and calls every one in registration order. No early-out. (Participants are still on `@MainActor`, so "no exceptions" is the only contract — but no protocol method throws, so there's nothing to swallow.)

### First-non-nil-wins

`undoManager(for:)`, `completionViewController(for:)`, `insertionPointView(for:frame:)`. Multiplexer walks `gating + behavior`, returns the first non-nil result. If everyone returns nil:

- `undoManager(for:)` → multiplexer returns nil (matches today's proxy behavior — falls back to `NSTextView.undoManager`).
- `completionViewController(for:)` → multiplexer returns a fresh `CompletionViewController()` (macOS) / `BasicCompletionViewController()` (UIKit fallback) — matches the existing `CodeEditorViewDelegate.textViewCompletionViewController(_:)` default impl behavior.
- `insertionPointView(for:frame:)` → multiplexer returns nil (matches existing default).

### First-handler-wins

`textView(_:clickedOnLink:at:)`, `textView(_:clickedOnAttachment:at:)`. Multiplexer walks `gating + behavior`, returns true at the first participant that returns true. Returns false if no one handles. Mirrors today's "did anyone handle this click" semantics in the proxy.

### All-must-agree

`textView(_:shouldAllowInteractionWith attachment:at:)`. Multiplexer walks `gating + behavior`, returns false at the first participant that vetoes. Returns true if everyone allows. Matches the default-true / opt-out shape the proxy uses today.

## Lifecycle

- Participants held weakly. `removeParticipant(_:)` is the explicit teardown call; participants are also implicitly dropped when their strong owner deinits (pruning removes dead `WeakParticipant` entries on next add or iterate).
- `CodeEditorView.deinit` does nothing special for the multiplexer — it goes away with the view, and weak references mean stale entries are harmless.
- `SmartEditingEngine` gains a `detach()` method (`textView?.removeDelegateParticipant(self); self.textView = nil`). There is no current `detach()`; `attach(to:)` is the only lifecycle entry point. `detach()` is new and called from… deliberately, no one yet. The point is the API surface exists for hosts that need to migrate features between text views; the engine being weakly held by the multiplexer means forgetting to call `detach()` doesn't leak.

## Migration plan

Five incremental steps. Build is green after every step.

**Step 1 — Land the multiplexer scaffolding (no behavior change).**
- Add `Sources/CodeEditorPlugin/Core/TextViewDelegateParticipant.swift` (protocol + default impl extension + `TextViewDelegatePhase` enum).
- Add `Sources/CodeEditorPlugin/Core/TextViewDelegateMultiplexer.swift` (class + weak storage + platform-`#if` delegate conformance with empty bodies returning the existing defaults).
- Add `internal let delegateMultiplexer` and the two convenience wrappers on `CodeEditorView`.
- The multiplexer is constructed but nothing registers and nothing installs it as `textView.delegate`. Pure scaffolding.
- Tests: new `TextViewDelegateMultiplexerTests.swift` exercising the multiplexer in isolation with `MockParticipant` doubles (every per-method semantic + weak-storage + ordering).

**Step 2 — Wire the proxy as the only `.gating` participant.**
- Conform `CodeEditorViewDelegateProxy` to `TextViewDelegateParticipant`. Move the body of every `NSTextViewDelegate`/`UITextViewDelegate` method into the corresponding `TextViewDelegateParticipant` method.
- Drop the platform-`#if`'d `extension CodeEditorViewDelegateProxy: NSTextViewDelegate {}` / `UITextViewDelegate {}` (`Sources/CodeEditorPlugin/Core/CodeEditorViewDelegateProxy.swift:212, 214`).
- Move `publishWillEditEvent` out of the proxy's `shouldChangeTextIn:` body and into the multiplexer's intrinsic step.
- Change `TextKitSetupHelper.setupTextKit:73-75` to register the proxy at `.gating` and install the multiplexer as `textView.delegate`. Drop the `if delegate == nil` guard.
- This is the load-bearing change on macOS. The TextKit 2 canary tests (`Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift`) cover the regression risk on the init path.
- Tests: regression test that today's `CodeEditorViewDelegateProxy` behavior is unchanged from the host's perspective.

**Step 3 — Migrate `SmartEditingEngine`.**
- Drop `extension SmartEditingEngine: NSTextViewDelegate` (`Features/SmartEditingEngine.swift:149-203`) and the matching `UITextViewDelegate` extension (`:204-249`). Conform `SmartEditingEngine` to `TextViewDelegateParticipant` directly.
- Replace `textView.delegate = self` in `attach(to:)` with `textView.addDelegateParticipant(self, phase: .behavior)`. Delete the "Replacing existing text view delegate" warning log (the structural problem it warned about is gone).
- Add `detach()` calling `removeDelegateParticipant(self)` and clearing `self.textView`.
- The original REVIEW.md bug is closed here. Regression tests added in the next step (`Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift`):
  - Host's `CodeEditorViewDelegate.shouldChangeTextIn` returning `false` blocks the edit *with* `SmartEditingEngine` attached *and* `SmartEditingEngine`'s auto-indent side-effect does not fire (no write to `textStorage`).
  - Auto-bracket still works end-to-end when the host allows the edit.

**Step 4 — Migrate iOS container and SwiftUI coordinator.**
- iOS `CodeEditorContainerView`: drop `extension CodeEditorContainerView: UITextViewDelegate` (`Layout/CodeEditorContainerView+UIKitExtensions.swift:248`). Conform to `TextViewDelegateParticipant` implementing only the four scroll-forwarding methods. Replace `textView.delegate = self` in `+UIKitExtensions.swift:75` and `ContainerViewInitializer.swift:213` with `textView.addDelegateParticipant(self, phase: .behavior)`. Update the "Set delegate LAST to ensure it's not overridden" comment — it's no longer true and no longer needed.
- iOS `CodeEditorCoordinator`: drop `UITextViewDelegate` conformance (`SwiftUI/CodeEditor+CoordinatorsExtensions.swift:464`). Conform to `TextViewDelegateParticipant` implementing `textViewDidChangeText` (calls `handleTextChange(textView.text ?? "")`) and `textViewDidChangeSelection` (calls `handleSelectionChange(textView.selectedRange)`). Delete the four `scrollView*` methods *from* the coordinator — they walk superviews via `findContainer(for:)` to call methods on `CodeEditorContainerView`, which is itself a participant after this step and will receive the callbacks directly from the multiplexer. The forwarding is pure pass-through with no additional logic (verified by reading `+CoordinatorsExtensions.swift:495-528`), so removal is safe.
- `setupTextViewDelegate(_:)` becomes `textView.addDelegateParticipant(self, phase: .behavior)`.
- macOS path: unchanged in this step. macOS has its own `CodeEditorCoordinator` (`SwiftUI/CodeEditor+CoordinatorsExtensions.swift:443`) but it does not conform to `NSTextViewDelegate` and does not take the `textView.delegate` slot — the proxy handles delegate callbacks on macOS. No iOS-style coordinator-as-participant migration is needed.
- Tests: regression coverage that iOS scroll forwarding still fires the gutter's `setNeedsDisplay`; that the SwiftUI coordinator's text binding still mirrors `textViewDidChange`.

**Step 5 — Lint guard and invariant doc.**
- Add a custom SwiftLint regex rule `forbidden_text_view_delegate_assignment` matching `textView\.delegate\s*=` (or the equivalent `\.delegate\s*=` on any `NSTextView` / `UITextView` typed value), exempting `Sources/CodeEditorPlugin/Core/TextKitSetupHelper.swift` (the install site). Same shape and severity as `no_print_statements` in `.swiftlint.yml`.
- Add a paragraph to the `CodeEditorView.swift:159-169` named-commit invariant block documenting that `textView.delegate` is owned by `TextViewDelegateMultiplexer` and that all participation flows through `addDelegateParticipant(_:phase:)`.

**Sequencing.** Steps 1+2 must land together (or step 1 alone) — installing the multiplexer without registering the proxy would silently drop host delegate forwarding. Steps 3 and 4 are independent and can land in either order or together once step 2 is on `main`. Step 5 lands last (lint rule would otherwise flag the in-progress steps).

Recommended PR shape: PR #1 = steps 1+2 (load-bearing macOS path), PR #2 = step 3 (the REVIEW.md bug fix), PR #3 = steps 4+5 (iOS cleanup + lint guard).

## Testing

### Multiplexer unit tests

New file `Tests/CodeEditorPluginTests/Core/TextViewDelegateMultiplexerTests.swift`. Uses small `MockParticipant` doubles recording call order and returning configurable values. Coverage:

| Test | What it asserts |
|---|---|
| `testGatingVetoShortCircuitsBeforeBehavior` | A gating participant returning `false` blocks the edit; no behavior participant's `shouldChangeTextIn` is called. |
| `testBehaviorVetoBlocksWillEditEvent` | A behavior participant returning `false` blocks the edit AND prevents `publishWillEditEvent`. Uses a `WillEditEvent` observer to assert no event fired. |
| `testAllAllowPublishesExactlyOneWillEditEvent` | Both phases return `true`; multiplexer returns `true`; exactly one `WillEditEvent` is published in the correct order (after both phases, before the actual edit). |
| `testFanOutNotificationsHitAllParticipants` | Add 2 gating + 2 behavior participants; fire `textViewDidChangeSelection`; assert all four called in registration order, no early-out. |
| `testFirstNonNilWinsForUndoManager` | First participant returns nil, second returns an `UndoManager`, third returns a different one — multiplexer returns the second. |
| `testFirstHandlerWinsForClickedOnLink` | First two return false, third returns true, fourth never called — multiplexer returns true. |
| `testAllReturnFalseForClickedOnLink` | Every participant returns false — multiplexer returns false. |
| `testShouldAllowInteractionAllMustAgree` | First participant returns false — multiplexer returns false; if all return true, multiplexer returns true. |
| `testWeakStorageDoesNotRetainParticipants` | Add participant; drop its strong reference; subsequent multiplexer calls don't touch it; next `addParticipant` prunes the dead slot. |
| `testIdempotentRegistration` | Adding the same participant twice keeps one slot; calls fire exactly once. |
| `testRemoveParticipant` | After `removeParticipant`, the participant's methods don't fire on subsequent multiplexer calls. |
| `testParticipantsCalledOnMainActor` | Sanity check that all participant method invocations happen on `@MainActor` (compile-checked via the protocol's actor isolation). |

### Smart-editing regression tests

New file `Tests/CodeEditorPluginTests/Features/SmartEditingEngineMultiplexerTests.swift` (or extend the existing `SmartEditingEngineTests.swift` if it covers the attach path).

| Test | What it asserts |
|---|---|
| `testHostVetoBlocksAutoIndent` | Attach a host `CodeEditorViewDelegate` that returns `false` from `shouldChangeTextIn`. Attach `SmartEditingEngine` with `isAutoIndentEnabled = true`. Send a `\n` keystroke. Assert: (a) `shouldChangeTextIn` ultimately returns false, (b) `textStorage` is unchanged, (c) no `WillEditEvent` was published, (d) the engine's auto-indent code was not reached (verifiable via a probe on the engine's private method or via the textStorage assertion). |
| `testAutoBracketStillWorksWhenHostAllows` | Same setup but host returns true. Type `(`. Assert `()` is in the buffer with the cursor between, exactly one `WillEditEvent` was published. |
| `testNoReplacingDelegateWarningLog` | Attach `SmartEditingEngine` to a fresh `CodeEditorView`. Capture log output. Assert the "Replacing existing text view delegate" warning is not emitted. (Confirms the bug-class indicator is gone.) |

### iOS regression tests

| Test | What it asserts |
|---|---|
| `testIOSContainerScrollForwardingAfterMultiplexerMigration` | Build a `CodeEditorContainerView` on iOS; simulate `scrollViewDidScroll`; assert the gutter's `setNeedsDisplay` was called. Covers the `+UIKitExtensions.swift:248` migration. |
| `testIOSCoordinatorTextChangeMirrorsBinding` | Construct `CodeEditorCoordinator` with a text binding; drive a text change via `textViewDidChange`; assert the binding updated and `onTextChange` callback ran. Covers the `+CoordinatorsExtensions.swift:481` migration. |

### TK2 canary stays green

`Tests/CodeEditorPluginTests/Core/CodeEditorViewTextKit2InitTests.swift` — the two-case canary from the TextKit 2 coercion fix — must keep passing. Installing the multiplexer in `TextKitSetupHelper` is on the load-bearing init path; if the multiplexer's `init` (or registration of the proxy at `.gating`) touches `textStorage` or `layoutManager` directly, it will flip the editor to TK1 and the canary will fail.

### No new snapshot tests

The multiplexer's behavior is non-visual. The existing `__Snapshots__/CodeEditorSnapshotTests/*` baselines are the cross-check that rendering didn't regress.

### Pre-existing failures policy

The following failures reproduce on bare `main` and predate this work (REVIEW.md "Pre-existing test issues"):

- `EditorStatusBarSnapshots/*` — parallel SIGSEGV/SIGBUS under the Swift-Testing → XCTest snapshot bridge.
- `RegexRangeHighlightProviderTests.testParsePerformance10K/100KLines` — flake on slower machines.
- `ScrollPositionPreservationTests.testScrollPositionPreservedWhenTogglingWordWrap`.
- `DemoCompletionProviderTests.returnsThreeDemoItemsOnAnyLanguage` (sample test rot from the Sample coverage gaps batch).
- `LSPSampleCoordinatorStateTests.resolverFailureTransitionsToFailed` (same vintage).
- `PerformanceInsightsRealMetricsTests.currentFPSReflectsInjectedMonitor` (FPS counter not running in headless test env).

Each migration step must confirm these still reproduce on bare `main` and aren't newly induced. The PR should never claim "all tests pass" without enumerating these.

## Public API impact

Strictly additive on the framework. The only new public surface is *no* new public surface — `TextViewDelegateParticipant`, `TextViewDelegatePhase`, `TextViewDelegateMultiplexer`, the `addDelegateParticipant(_:phase:)` / `removeDelegateParticipant(_:)` methods on `CodeEditorView`, and the migrated participant conformances on internal classes are all `internal`.

Source-breaking changes are confined to internal-only deletions:

- `CodeEditorViewDelegateProxy` drops its `NSTextViewDelegate` / `UITextViewDelegate` extensions (internal type; no external callers).
- `SmartEditingEngine` drops its `NSTextViewDelegate` / `UITextViewDelegate` extensions. The class itself is `public final`, but the dropped extensions are protocol conformances on the internal-only `PlatformTextViewDelegate` typealias path. External callers calling `engine.textView(_:shouldChangeTextIn:...)` directly would break — but that would be reaching into AppKit/UIKit delegate-method semantics from outside the framework, which is not a sanctioned use of the type. No in-tree callers exist; sample and tests use `engine.attach(to:)` and `engine.addCursor(at:)` style entry points.
- iOS `CodeEditorContainerView` and `CodeEditorCoordinator` drop their `UITextViewDelegate` extensions. Same reasoning.

The host-facing public surface — `CodeEditorViewDelegate` protocol and `CodeEditorView.textDelegate` property — is entirely unchanged.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Installing the multiplexer in `setupTextKit` touches the textView in a way that flips TK2 → TK1. | The multiplexer's `init` does nothing platform-related (it just allocates two arrays). Registration of the proxy happens before `textView.delegate = multiplexer`. The TK2 canary tests run on every PR. |
| A participant's `shouldChangeTextIn` returns `false` for a legitimate edit, blocking typing. | Phase-`.gating` is exactly one participant (the proxy) at end-of-migration. `.behavior` is at most three (SmartEditingEngine, iOS container, iOS coordinator), each implementing well-bounded predicates. Every behavior participant has a dedicated regression test covering the "allow path". |
| iOS coordinator's old `findContainer(for:)` scroll forwarding does something the container's own scroll handling doesn't. | Verified by reading `+CoordinatorsExtensions.swift:495-528`: the four `scrollView*` methods walk superviews via `findContainer(for:)` and call the same-named method on the container, with no additional logic. After the container itself is a multiplexer participant, the multiplexer delivers those callbacks directly and the coordinator's forwarding becomes dead code. The gutter-redraw regression test covers the path explicitly. |
| Host code that reached for `textView.delegate` directly (cast it to `NSTextViewDelegate?` and inspected) will see the multiplexer instead of whatever they expect. | `textView.delegate` is an AppKit/UIKit property; the framework has never specified what it points at. Hosts that need delegate participation should use `CodeEditorViewDelegate` via `textDelegate`. If a sample or test reaches for `textView.delegate` directly, the migration sweeps will catch it. |
| Lint rule (step 5) flags some legitimate test code that wants to install a custom delegate for isolation. | Custom regex rules in `.swiftlint.yml` support `match_kinds` and per-file exclusions. The rule applies to `Sources/` only; `Tests/` is exempt. If a test legitimately needs to bypass the multiplexer it can use `// swiftlint:disable:next` with a comment explaining why. |
| The protocol grows over time and changes break participants. | Internal-only means we can add methods with default impls freely. The cost of getting the protocol wrong is bounded to in-tree refactor; no external callers to migrate. If the protocol shape feels stable after a release or two, promoting it to public becomes a deliberate API decision rather than a default. |

## Open questions

None. All scope decisions resolved in the brainstorming pass: framework-wide multiplexer ownership, internal-only API, phased participant model with two phases plus intrinsic side-effect.
