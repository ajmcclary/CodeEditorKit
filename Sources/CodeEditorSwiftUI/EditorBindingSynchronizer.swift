import CodeEditorView
import SwiftUI

/// Synchronizes editor-originated text with a host binding without feedback.
@MainActor
final class EditorBindingSynchronizer {
    typealias Write = (String) -> Void

    var debounce: Duration
    var onEditorText: Write?

    private var write: Write?
    /// Whether the host already holds a value (then a write changes nothing
    /// and no echo will come back).
    private var hostHolds: ((String) -> Bool)?
    private var lastText: String?
    private var pendingTask: Task<Void, Never>?
    /// Editor text waiting for the debounced write.
    private var pendingText: String?
    /// The editor's binding writes the host has not echoed yet, oldest first
    /// (a host that applies writes late has several in flight). A new host
    /// text equal to one of them is the echo of that write and consumes it
    /// and every older one; any other new host text clears them all. So they
    /// are never "any text the editor once wrote": a host may return to an
    /// earlier editor value.
    private var outstandingEchoes: [String] = []
    private static let maximumOutstandingEchoes = 4

    init(
        debounce: Duration = .milliseconds(100),
        write: Write? = nil
    ) {
        self.debounce = debounce
        self.write = write
    }

    func bind(_ binding: Binding<String>) {
        write = { newText in
            guard binding.wrappedValue != newText else { return }
            binding.wrappedValue = newText
        }
        hostHolds = { binding.wrappedValue == $0 }
    }

    func installHostText(_ text: String) {
        guard lastText != text else { return }

        cancel()
        outstandingEchoes.removeAll()
        lastText = text
    }

    func receiveEditorText(_ newText: String) {
        guard newText != lastText else { return }

        lastText = newText
        onEditorText?(newText)
        pendingTask?.cancel()
        pendingText = newText
        pendingTask = Task { [weak self] in
            do {
                guard let self else { return }
                try await Task.sleep(for: self.debounce)
                guard Task.isCancelled == false,
                      self.lastText == newText else { return }
                self.performWrite(newText)
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    /// How a new host text relates to the editor's latest binding write.
    enum EchoMatch {
        /// No write was outstanding: the host changed the text on its own.
        case noWriteAwaited
        /// The host caught up with the write.
        case echo
        /// The host answered the write with different text (it normalizes
        /// what it stores): a rewrite of the editor's own change.
        case rewrite
    }

    /// Called with each new host text (one that differs from the host's text
    /// at the previous render).
    ///
    /// Text that matches no outstanding write is a rewrite only when it
    /// keeps most of the newest write (the common prefix and suffix cover at
    /// least half of the longer text), as normalizing a write does. Anything
    /// else is the host's own change: a host that never takes the editor's
    /// writes leaves one outstanding forever, and its next reload must not
    /// be mistaken for an answer to it.
    func consumeEcho(ofHostText text: String) -> EchoMatch {
        guard let newest = outstandingEchoes.last else { return .noWriteAwaited }
        if let index = outstandingEchoes.firstIndex(of: text) {
            outstandingEchoes.removeFirst(index + 1)
            return .echo
        }
        outstandingEchoes.removeAll()
        return Self.isRewrite(text, of: newest) ? .rewrite : .noWriteAwaited
    }

    static func isRewrite(_ text: String, of written: String) -> Bool {
        let span = CodeEditorView.changedSpan(from: written, to: text)
        let writtenLength = written.utf16.count
        let shared = writtenLength - span.old.length
        return shared > 0 && shared * 2 >= max(writtenLength, text.utf16.count)
    }

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
        pendingText = nil
    }

    /// Writes any pending editor text now instead of after the debounce, so
    /// a view torn down inside the debounce window does not lose keystrokes.
    func flush() {
        guard let pendingText else { return }
        pendingTask?.cancel()
        pendingTask = nil
        if lastText == pendingText {
            performWrite(pendingText)
        }
        self.pendingText = nil
    }

    private func performWrite(_ text: String) {
        pendingText = nil
        // A host that already holds the text (it mirrors `onTextChange`)
        // sends no echo back; expecting one would misread its next change.
        if !(hostHolds?(text) ?? false) {
            outstandingEchoes.append(text)
            if outstandingEchoes.count > Self.maximumOutstandingEchoes {
                outstandingEchoes.removeFirst()
            }
        }
        write?(text)
    }

    func waitForPendingWrite() async {
        await pendingTask?.value
    }
}
