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
    /// applies them to the text storage.
    func applyAttributes(for range: NSRange) {
        let runs = container.mergedRuns(in: range)
        guard !runs.isEmpty, let textStorage = textView?.textStorage else { return }
        guard range.upperBound <= textStorage.length else { return }

        textStorage.beginEditing()
        var cursor = range.location
        for run in runs {
            let runRange = NSRange(location: cursor, length: run.length)
            let color = run.value.flatMap(resolveColor(for:))
            applyColor(color, to: runRange, in: textStorage)
            cursor += run.length
        }
        textStorage.endEditing()
    }

    // MARK: - Private

    /// Clears the applier's managed attribute from `textStorage` in `range`.
    private func clearAttributes(in range: NSRange) {
        guard let textStorage = textView?.textStorage else { return }
        let clamped = NSRange(
            location: max(0, range.location),
            length: min(range.length, textStorage.length - range.location)
        )
        guard clamped.length > 0 else { return }

        textStorage.beginEditing()
        textStorage.removeAttribute(attributeKey, range: clamped)
        textStorage.endEditing()
    }

    /// Resolves a `StyleElement` to a platform color using the
    /// `TokenType.adaptiveColor` lookup.
    private func resolveColor(for element: StyleElement) -> PlatformColor? {
        guard let capture = element.capture else { return nil }
        return TokenType(rawValue: capture)?.adaptiveColor
    }

    /// Applies `color` to `range` in `textStorage`, skipping ranges that
    /// already uniformly have the same color to avoid unnecessary mutation.
    private func applyColor(
        _ color: PlatformColor?,
        to range: NSRange,
        in textStorage: NSTextStorage
    ) {
        guard let color else {
            textStorage.removeAttribute(attributeKey, range: range)
            return
        }

        // Skip-equal: check the full run, not just the first character.
        // Uses `enumerateAttribute` to walk the range and verify every
        // character already has the target color. If a mid-range edit
        // cleared part of an existing token, the first character might
        // still be correct while the rest is wrong.
        if range.length > 0 {
            var allMatch = true
            textStorage.enumerateAttribute(
                attributeKey,
                in: range,
                options: []
            ) { value, _, stop in
                if (value as? PlatformColor) != color {
                    allMatch = false
                    stop.pointee = true
                }
            }
            if allMatch { return }
        }

        textStorage.addAttribute(attributeKey, value: color, range: range)
    }
}
