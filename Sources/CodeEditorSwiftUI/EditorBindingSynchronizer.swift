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
        pendingTask = Task { [weak self] in
            do {
                guard let self else { return }
                try await Task.sleep(for: self.debounce)
                guard Task.isCancelled == false,
                      self.lastText == newText else { return }
                self.write?(newText)
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    func cancel() {
        pendingTask?.cancel()
        pendingTask = nil
    }

    func waitForPendingWrite() async {
        await pendingTask?.value
    }
}
