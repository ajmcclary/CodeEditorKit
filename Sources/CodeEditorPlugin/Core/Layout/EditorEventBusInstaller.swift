#if canImport(AppKit)
@preconcurrency import AppKit
import CodeEditorCommon
import CodeEditorLayout

/// Bridges AppKit mouse events on a wrapped `NSTextView` into an
/// `EditorEventBus`. The bus carries hover positions (after an idle
/// delay) and ⌘-click positions to SwiftUI modifiers downstream.
///
/// Lifecycle is owned by `EditorController.attach(to:)`. Tests can drive
/// `handleMouseDown` and `handleMouseMoved` directly to verify behavior
/// without going through the full AppKit event pipeline.
@MainActor
final class EditorEventBusInstaller: NSObject {
    private weak var bus: EditorEventBus?
    private weak var textView: NSTextView?
    private var trackingArea: NSTrackingArea?
    private var hoverWorkItem: DispatchWorkItem?
    private var eventMonitor: Any?
    private var idleDelay: TimeInterval = 0.5

    init(bus: EditorEventBus, textView: NSTextView) {
        self.bus = bus
        self.textView = textView
        super.init()
    }

    /// Install the NSTrackingArea on the text view and add an NSEvent local
    /// monitor for ⌘-click. Safe to call once per installer.
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

        // `addLocalMonitorForEvents` invokes its closure on the main thread
        // per AppKit docs. The closure type is already `@MainActor` under
        // modern AppKit SDKs, so `self` and `event` can be captured directly
        // — no unchecked-Sendable shuttle or `assumeIsolated` hop required.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard let self,
                  event.modifierFlags.contains(.command),
                  self.handleMouseDown(event) else { return event }
            return nil
        }
    }

    func uninstall() {
        if let trackingArea, let textView {
            textView.removeTrackingArea(trackingArea)
        }
        trackingArea = nil
        if let token = eventMonitor {
            NSEvent.removeMonitor(token)
        }
        eventMonitor = nil
        hoverWorkItem?.cancel()
        hoverWorkItem = nil
    }

    func setHoverDelay(_ delay: TimeInterval) {
        idleDelay = delay
    }

    // MARK: - NSTrackingArea callbacks
    // NSTrackingArea dispatches mouseMoved:/mouseExited: to its owner via
    // Objective-C selectors. We're not subclassing NSResponder so no
    // `override` keyword — just expose the selectors.

    @objc func mouseMoved(with event: NSEvent) {
        scheduleHover(event: event)
    }

    @objc func mouseExited(with _: NSEvent) {
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

    // MARK: - Public hook (also used by tests)

    /// Returns true when the event was a ⌘-click that landed on text — the
    /// caller (an NSEvent local monitor) should then return nil to consume
    /// the event so the editor does not also reposition the caret.
    func handleMouseDown(_ event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command),
              event.type == .leftMouseDown,
              let textView else {
            return false
        }
        let point = event.window == nil
            ? event.locationInWindow
            : textView.convert(event.locationInWindow, from: nil)
        guard let position = Self.sourcePosition(for: point, in: textView) else {
            return false
        }
        bus?.emitCommandClick(at: position)
        return true
    }

    /// Translate a text-view-local point into a zero-based `SourcePosition`.
    /// Returns nil when the point falls outside the text region.
    ///
    /// Fast path: when the text view is a `CodeEditorView`, the incremental
    /// `LineGeometryStore` gives O(log n) line + column lookup. Falls back
    /// to a UTF-16 walk for plain `NSTextView` instances (tests, embedded
    /// non-editor uses).
    static func sourcePosition(for point: NSPoint, in textView: NSTextView) -> SourcePosition? {
        let index = textView.characterIndexForInsertion(at: point)
        let utf16Length = textView.string.utf16.count
        guard index <= utf16Length else { return nil }

        if let editor = textView as? CodeEditorView, editor.lineGeometryStore.lineCount > 0 {
            let line = editor.lineGeometryStore.lineIndex(forUtf16Offset: index)
            let lineStart = editor.lineGeometryStore.utf16Offset(forLineIndex: line)
            let character = max(0, index - lineStart)
            return SourcePosition(line: line, character: character)
        }

        let utf16 = textView.string.utf16
        var line = 0
        var lineStart = 0
        var pos = 0
        var current = utf16.startIndex
        while pos < index, current < utf16.endIndex {
            let unit = utf16[current]
            pos += 1
            current = utf16.index(after: current)
            if unit == 0x000A {  // newline
                line += 1
                lineStart = pos
            }
        }
        let character = index - lineStart
        return SourcePosition(line: line, character: character)
    }
}
#endif
