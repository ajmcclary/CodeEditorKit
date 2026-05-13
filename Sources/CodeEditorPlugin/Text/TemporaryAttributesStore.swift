#if canImport(AppKit)
import AppKit

/// Tracks transient presentation attributes layered on top of the editor's
/// syntax highlighting. Owns the bookkeeping needed to clear previously
/// applied keys without disturbing other consumers of the same attribute
/// keys (for example, find-match highlighting).
///
/// macOS-only: relies on AppKit's `NSTextStorage` attribute APIs.
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
