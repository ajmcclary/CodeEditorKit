import CodeEditorTextModel
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Range Attribute Applier

/// Applies `StyledRangeContainer` merged runs to `NSTextStorage` attributes
/// with loop prevention and skip-equal optimization.
///
/// The applier:
/// - Subscribes to `TextEditEventHub` as a did-edit observer
/// - Clears stale attributes in the edited range on character edits
/// - Receives `onRangeHighlighted` callbacks from `HighlightProviderState`
///   and applies merged token runs as `.foregroundColor` attributes
/// - Batches attribute writes within `beginEditing`/`endEditing` to suppress
///   nested `.editedAttributes` notifications (Phase 0 already gates the
///   legacy highlighter on `.editedCharacters`, providing defense in depth)
/// - Skips already-correct attribute values to avoid unnecessary mutation
@MainActor
internal final class RangeAttributeApplier: TextEditEventObserving {
    // MARK: - Dependencies

    private weak var textView: CodeEditorView?
    private let container: StyledRangeContainer

    /// The attribute key managed by this applier. Only `.foregroundColor`
    /// is applied currently; other attributes (font, underline, etc.) can
    /// be added here as the styling system matures.
    private let attributeKey: NSAttributedString.Key = .foregroundColor

    // MARK: - Initialization

    init(textView: CodeEditorView, container: StyledRangeContainer) {
        self.textView = textView
        self.container = container
        textView.textEditEventHub.addObserver(self)
    }

    // MARK: - Lifecycle

    func detach() {
        textView?.textEditEventHub.removeObserver(self)
        textView = nil
    }

    // MARK: - TextEditEventObserving

    func textStorageDidApplyEdit(_ event: TextEditEvent) {
        // Attribute-only edits are produced by us — skip to prevent loops.
        guard event.editedCharacters else { return }

        // Clear stale syntax attributes in the affected region. The range
        // covers the edit point plus a small context buffer so nearby tokens
        // that may have shifted are also re-evaluated.
        let clearStart = max(0, event.editedRange.location - 80)
        let clearEnd = min(
            event.editedRange.location + event.editedRange.length + abs(event.changeInLength) + 80,
            event.documentLength
        )
        guard clearStart < clearEnd else { return }
        let clearRange = NSRange(location: clearStart, length: clearEnd - clearStart)
        clearAttributes(in: clearRange)
    }

    // MARK: - Attribute Application

    /// Called by `HighlightProviderState` when a range transitions from
    /// pending → valid. Reads merged style runs from the container and
    /// applies them as rendering attributes (non-destructive; TK2-native).
    func applyAttributes(for range: NSRange) {
        let runs = container.mergedRuns(in: range)
        guard !runs.isEmpty, let textView else { return }
        let bridge = textView.textKitBridge
        guard range.upperBound <= bridge.documentLength else { return }

        var cursor = range.location
        for run in runs {
            let runRange = NSRange(location: cursor, length: run.length)
            let color = run.value.flatMap(resolveColor(for:))
            applyColor(color, to: runRange, via: bridge)
            cursor += run.length
        }
    }

    // MARK: - Private

    /// Clears the applier's managed rendering attribute in `range`.
    private func clearAttributes(in range: NSRange) {
        guard let textView else { return }
        let bridge = textView.textKitBridge
        let documentLength = bridge.documentLength
        // Compute the upper bound explicitly. Naively doing
        // `length: documentLength - range.location` underflows when a stale
        // `range.location` exceeds the current document length and produces
        // a negative `NSRange.length`, which `removeAttributes` then treats
        // as a wild range. Clamp `location` first, then derive `length`
        // from the clamped upper bound.
        let lowerBound = max(0, min(range.location, documentLength))
        let upperBound = max(lowerBound, min(range.location + range.length, documentLength))
        let clamped = NSRange(location: lowerBound, length: upperBound - lowerBound)
        guard clamped.length > 0 else { return }
        bridge.removeAttributes([attributeKey], range: clamped)
    }

    /// Resolves a `StyleElement` to a platform color using the applied theme
    /// when available, otherwise falling back to `SyntaxColorScheme.default`.
    private func resolveColor(for element: StyleElement) -> PlatformColor? {
        guard let capture = element.capture else { return nil }
        if let theme = textView?.appliedTheme {
            return SyntaxColorScheme.color(forCapture: capture, in: theme)
        }
        guard let tokenType = TokenType(rawValue: capture) else { return nil }
        return SyntaxColorScheme.default.color(for: tokenType)
    }

    /// Applies `color` to `range` as a rendering attribute via the bridge.
    /// Rendering attributes don't trigger NSTextStorage didProcessEditing
    /// notifications, so the original skip-equal optimization (which existed
    /// to avoid loop-triggering attribute mutations) is no longer needed.
    private func applyColor(
        _ color: PlatformColor?,
        to range: NSRange,
        via bridge: TextKitBridge
    ) {
        guard let color else {
            bridge.removeAttributes([attributeKey], range: range)
            return
        }
        bridge.addAttributes([attributeKey: color], range: range)
    }
}
