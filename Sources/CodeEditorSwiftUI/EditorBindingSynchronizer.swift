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
    /// The last text this synchronizer wrote into the host binding.
    private var lastWrittenText: String?

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

    /// Whether `text` is a value the editor itself produced and sent toward
    /// the host (written, or still waiting to be). Host text equal to one of
    /// these is the host catching up, not the host replacing the text.
    func isEditorEcho(_ text: String) -> Bool {
        text == lastWrittenText || text == pendingText
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
        lastWrittenText = text
        write?(text)
    }

    func waitForPendingWrite() async {
        await pendingTask?.value
    }
}
