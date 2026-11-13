import SwiftUI

/// Synchronizes editor-originated text with a host binding without feedback.
@MainActor
final class EditorBindingSynchronizer {
    typealias Write = (String) -> Void

    var debounce: Duration
    var onEditorText: Write?

    private var write: Write?
    private var lastText: String?
    private var pendingTask: Task<Void, Never>?
    /// Editor text waiting for the debounced write.
    private var pendingText: String?
    /// The value of the editor's most recent binding write, expected to come
    /// back from the host as an echo. One-shot: the next host text that
    /// differs from what the host showed before consumes it, matching or not,
    /// and a host replacement clears it. It is never "any text the editor
    /// once wrote", so a host may return to an earlier editor value.
    private var expectedEcho: String?

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
    }

    func installHostText(_ text: String) {
        guard lastText != text else { return }

        cancel()
        expectedEcho = nil
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

    /// Called with each new host text (one that differs from the host's text
    /// at the previous render). Returns true when it is the echo of the
    /// editor's latest binding write — the host catching up, which must not
    /// overwrite typing done since — and consumes that expectation either
    /// way.
    func consumeEcho(ofHostText text: String) -> Bool {
        guard let expectedEcho else { return false }
        self.expectedEcho = nil
        return text == expectedEcho
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
        expectedEcho = text
        write?(text)
    }

    func waitForPendingWrite() async {
        await pendingTask?.value
    }
}
