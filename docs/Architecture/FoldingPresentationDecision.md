# Folding Presentation Strategy Decision

**Gate:** C
**Status:** `go` — Keep `attributeHidden` as active strategy; overlay placeholder as preferred future strategy
**Date:** 2026-05-07

## Context

Code folding must visually hide folded content without destroying document text or conflicting with syntax highlighting attributes. CodeEditSourceEditor uses `TextAttachment`-based placeholders (`LineFoldPlaceholder`), but CodeEditorKit does not have the attachment infrastructure that makes this safe.

## Evaluation

### Strategy 1: `attributeHidden` (current, KEPT)

**Implementation:** `FoldingOperationsService` hides folded content by applying `ParagraphStyleCache.hiddenParagraphStyle` + font size 0.1 + clear foreground color.

**Pros:**
- Already implemented and working.
- Does not modify document text (only attributes).
- Simple to reason about.

**Cons:**
- Conflicts with syntax highlighting (syntax attributes must be re-applied after unfold).
- Font size 0.1 is a hack; can cause layout artifacts.
- No visual placeholder in the collapsed region (content is invisible).

**Risk:** Low. Already battle-tested.

### Strategy 2: `textAttachmentReplacement`

**Implementation:** Replace folded text with a `TextAttachment` placeholder while preserving the original text separately.

**Pros:**
- Clean visual placeholder (like CodeEditSourceEditor's `LineFoldPlaceholder`).
- No attribute conflicts with syntax highlighting.

**Cons:**
- Modifies document text — must virtualize carefully to avoid corrupting the underlying NSTextStorage.
- CodeEditorKit does not have CodeEditSourceEditor's `TextAttachment` base class or `layoutManager.attachments.add/remove` APIs.
- High risk of document corruption if attachment management has bugs.
- TextKit2 attachment behavior differs from the older legacy TextKit attachment APIs many sample implementations were written against.

**Risk:** VERY HIGH for first implementation. Not rejecting, but not for initial delivery.

### Strategy 3: `overlayPlaceholder` (PREFERRED FUTURE)

**Implementation:** Draw a placeholder overlay (pill shape with "..." dots) over the folded region without modifying text storage attributes.

**Pros:**
- Does not modify document text or storage attributes.
- Cannot conflict with syntax highlighting (two separate drawing layers).
- Can draw rich visual indicators (chevrons, fold count, etc.).

**Cons:**
- Requires custom drawing code in the text view or overlay view.
- Must track folded regions and invalidate on scroll/layout changes.
- Higher initial implementation complexity.

**Risk:** Medium. Custom drawing requires careful invalidation management.

### Strategy 4: `TextKit2RenderingAttributes`

**Implementation:** Use TextKit2 rendering attributes to hide folded content.

**Pros:**
- TextKit2 rendering attributes don't conflict with storage attributes.
- Potentially simpler than overlay drawing.
- Since 0.2.0 the framework is TextKit2-only on every supported platform, so
  the platform-fragmentation concern that motivated avoiding this strategy
  no longer applies.

**Cons:**
- TextKit2 rendering attributes API is limited and not designed for content hiding.

**Risk:** Medium. The dual-stack hazard is gone, but the API ergonomics may
not match what content-hiding really needs.

## Decision

**Current active strategy: `attributeHidden` (keep as default).**
**Preferred future strategy: `overlayPlaceholder` (implement behind feature flag in Phase 5.3).**

Rationale:
1. `attributeHidden` works now. Don't break it before a replacement exists.
2. `overlayPlaceholder` avoids all document-modification and attribute-conflict risks.
3. `textAttachmentReplacement` requires infrastructure CodeEditorKit doesn't have (attachment management APIs).
4. The `FoldPresentationStrategy` protocol in Phase 5.3 enables both strategies to coexist — `attributeHidden` as default, `overlayPlaceholder` as the feature-flagged upgrade path.

## Required Implementation (Phase 5.3)

```swift
internal protocol FoldPresentationStrategy: AnyObject {
    func collapse(_ fold: FoldableRegion, in textView: CodeEditorView)
    func expand(_ fold: FoldableRegion, in textView: CodeEditorView)
}
```

- `AttributeFoldPresentationStrategy`: wraps current `FoldingOperationsService` behavior.
- `OverlayFoldPresentationStrategy`: draws placeholder overlay without attribute manipulation (future).

## Rejected Alternatives

- **`textAttachmentReplacement`:** Too risky without the attachment infrastructure CodeEditSourceEditor has.

## Follow-up

After Phase 5 fold storage is implemented, build `OverlayFoldPresentationStrategy` behind a feature flag and run parity tests against `AttributeFoldPresentationStrategy`.
