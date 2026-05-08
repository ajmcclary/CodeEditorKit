# Text Edit Event Hub Decision

**Gate:** D
**Status:** `go` — `CodeEditorView` owns `TextEditEventHub` property; single canonical `TextEditEvent` struct
**Date:** 2026-05-07

## Context

Multiple features need to respond to text edits: syntax highlighting, folding, gutter, minimap, line cache, and future consumers (diagnostics, annotations). Currently, each feature independently listens to `NSTextStorage.didProcessEditingNotification` via `CodeEditorView.handleTextStorageDidProcessEditing(_:)`, which combines several concerns (cache invalidation, gutter updates, syntax highlighting, event publishing, accessibility).

A canonical edit event hub decouples edit notification from per-feature logic.

## Current Architecture

**Notification flow (in `CodeEditorView+SyntaxHighlightingExtensions.swift`):**

```
NSTextStorage.didProcessEditingNotification
  → CodeEditorView.handleTextStorageDidProcessEditing(_:)
    → lineIndexCache.invalidate()
    → cache pre-warming (deferred Task)
    → gutterView.needsDisplay = true
    → applySyntaxHighlighting(in: editedRange)
    → Mac Catalyst text color fixup
    → eventPublisher.publishSync(.textDidChange)
    → notifyAccessibilityTextDidChange()
    → checkForCompletionTrigger(at: editedRange)
```

**Problems:**
1. All concerns are in one method — adding a new consumer requires editing this method.
2. No canonical edit payload — each consumer recomputes `editedRange`, `changeInLength`, etc. from `textStorage.editedRange`.
3. Ordering is implicit — cache invalidation happens before highlighting, but nothing guarantees this is correct.
4. Testing is hard — all logic is in a `@MainActor` UI extension method.

## Design

### Canonical Payload

```swift
internal struct TextEditEvent: Sendable, Equatable {
    internal var editedRange: NSRange
    internal var changeInLength: Int
    internal var documentLength: Int
    internal var editedCharacters: Bool
}
```

### Hub

```swift
internal final class TextEditEventHub {
    internal func addObserver(_ observer: any TextEditEventObserving)
    internal func removeObserver(_ observer: any TextEditEventObserving)
    internal func publish(_ event: TextEditEvent)
}
internal protocol TextEditEventObserving: AnyObject {
    func textStorageDidApplyEdit(_ event: TextEditEvent)
}
```

### Ownership

The `TextEditEventHub` is a property on `CodeEditorView`. It is NOT a service in `BusinessLogicServiceRegistry` because:
- It is tied to a single editor instance, not application-wide.
- Its lifecycle matches the text view's lifecycle.
- Making it a service would require per-editor service isolation, adding complexity without benefit.

### Lifecycle

- Created during `CodeEditorView` initialization.
- `handleTextStorageDidProcessEditing(_:)` validates the notification belongs to this editor, constructs a `TextEditEvent`, and calls `hub.publish(event)`.
- Existing consumers (line cache, gutter, highlighting) become observers of the hub.
- Additional consumers (RangeStore sync, fold storage sync) subscribe in their own setup.

### Observer Registration Order

Observers are notified in registration order. This is intentional:
1. Line cache invalidates first (so subsequent observers see correct line data).
2. RangeStore sync (keeps data structures in sync).
3. Gutter redraw (uses line cache data).
4. Syntax highlighting (uses RangeStore data).
5. Completion trigger check.
6. Accessibility notification.

## Decision

1. `CodeEditorView` owns a `TextEditEventHub` property.
2. Publish from `handleTextStorageDidProcessEditing(_:)` after validating the notification.
3. Existing consumers migrate to observer pattern incrementally (Phase 2.2 starts with RangeStore as first external consumer).
4. Keep existing behavior for consumers not yet migrated — the hub publishes in addition to, not instead of, current direct handler calls during migration.

## Rejected Alternatives

- **Service in BusinessLogicServiceRegistry:** Requires per-editor service isolation. Over-engineered for an editor-local concern.
- **Combine publisher:** Adds framework dependency for a simple observer pattern. Direct protocol conformance is simpler and testable.
- **No hub, keep direct notification:** Prevents shared range storage from receiving canonical edit events.

## Follow-up

Phase 2.2 implements `TextEditEventHub` and wires it to `CodeEditorView`. Phase 3 (highlighting) and Phase 5 (folding) become consumers.
