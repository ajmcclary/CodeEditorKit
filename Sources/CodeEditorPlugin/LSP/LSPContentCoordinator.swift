import CodeEditorCommon
import Foundation

// MARK: - LSP Content Coordinator

/// Bridges the editor's edit-event stream to LSP `textDocument/didChange`
/// notifications with ~250 ms debounce batching.
///
/// This coordinator subscribes to `TextEditEventHub` as both a will-edit
/// and did-edit observer. Pre-edit state (range + replacement text) is
/// captured from `WillEditEvent`; post-edit computation produces
/// `TextDocumentContentChangeEvent` values that are batched and flushed
/// to `LSPManager.updateDocument(filePath:content:changes:)`.
///
/// Sync strategy is determined by the server's advertised
/// `TextDocumentSyncKind` (queried via `LSPManager.syncKind(for:)`):
/// - `.incremental`: range-and-text change events
/// - `.full` (or unknown): full document text on each flush
/// - `.disabled`: coordinator is a no-op
///
/// A post-batch callback (`onBatchFlushed`) fires after each flush so
/// downstream consumers (e.g. semantic-token refresh) can react to the
/// known server-side document version.
@MainActor
final class LSPContentCoordinator {
    // MARK: - Types

    /// Accumulated pre-edit state captured from `WillEditEvent`.
    private struct PendingEdit {
        let preEditRange: NSRange
        let replacementText: String
        let startPosition: Position
        let endPosition: Position
    }

    // MARK: - Dependencies

    private weak var textView: CodeEditorView?
    private unowned var lspManager: LSPManager
    private let filePath: String
    private let languageId: String

    // MARK: - Batching state

    private var pendingChanges: [TextDocumentContentChangeEvent] = []
    private var pendingEdits: [PendingEdit] = []
    private var batchTask: Task<Void, Never>?
    private let batchIntervalNanos: UInt64 = 250_000_000 // 250 ms

    // MARK: - Sync strategy

    private var syncKind: TextDocumentSyncKind {
        lspManager.syncKind(for: languageId)
    }

    // MARK: - Post-batch hook

    /// Called on the main actor after a batch of changes has been
    /// successfully flushed to the server.
    var onBatchFlushed: (@MainActor () -> Void)?

    // MARK: - Initialization

    init(
        textView: CodeEditorView,
        lspManager: LSPManager,
        filePath: String,
        languageId: String
    ) {
        self.textView = textView
        self.lspManager = lspManager
        self.filePath = filePath
        self.languageId = languageId

        textView.textEditEventHub.addWillEditObserver(self)
        textView.textEditEventHub.addObserver(self)
    }

    // MARK: - Lifecycle

    func detach() {
        batchTask?.cancel()
        batchTask = nil
        textView?.textEditEventHub.removeWillEditObserver(self)
        textView?.textEditEventHub.removeObserver(self)
        textView = nil
    }

    // MARK: - Event observation

    func textStorageWillApplyEdit(_ event: WillEditEvent) {
        guard syncKind != .disabled else { return }

        // Compute the start Position from the pre-edit full source.
        // `shouldChangeText` fires before the mutation, so `textStorage.string`
        // is still the pre-edit document.
        let fullSource = textView?.textKitBridge.documentString ?? ""
        let startPos = Self.position(
            for: event.preEditRange.location,
            in: fullSource
        )
        let endPos = Self.position(
            for: event.preEditRange.location + event.preEditRange.length,
            in: fullSource
        )
        pendingEdits.append(
            PendingEdit(
                preEditRange: event.preEditRange,
                replacementText: event.replacementText,
                startPosition: startPos,
                endPosition: endPos
            )
        )
    }

    func textStorageDidApplyEdit(_ event: TextEditEvent) {
        guard syncKind != .disabled, event.editedCharacters else { return }

        // Consume pending pre-edit state (oldest first).
        while !pendingEdits.isEmpty {
            let edit = pendingEdits.removeFirst()

            let change: TextDocumentContentChangeEvent
            if syncKind == .incremental {
                change = TextDocumentContentChangeEvent(
                    text: edit.replacementText,
                    range: LSPRange(start: edit.startPosition, end: edit.endPosition),
                    rangeLength: edit.preEditRange.length
                )
            } else {
                // Full-sync — placeholder; the full document text is sent on flush.
                change = TextDocumentContentChangeEvent(text: "")
            }

            pendingChanges.append(change)
        }

        scheduleBatchFlush()
    }

    // MARK: - Batching

    private func scheduleBatchFlush() {
        batchTask?.cancel()
        batchTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: self.batchIntervalNanos)
            } catch {
                return // Cancelled
            }
            guard !Task.isCancelled else { return }
            await self.flushBatch()
        }
    }

    private func flushBatch() async {
        guard !pendingChanges.isEmpty else { return }

        let fullText = textView?.textKitBridge.documentString ?? ""

        let changes: [TextDocumentContentChangeEvent]
        if syncKind == .incremental {
            changes = pendingChanges
        } else {
            changes = [TextDocumentContentChangeEvent(text: fullText)]
        }

        // Clear the buffer before the async send so overlapping edits
        // accumulate into the next batch.
        pendingChanges.removeAll()

        do {
            try await lspManager.updateDocument(
                filePath: filePath,
                content: fullText,
                changes: changes
            )
            onBatchFlushed?()
        } catch {
            let log = CrossPlatformLogger.logger(
                subsystem: "com.codeeditor.lsp",
                category: "LSPContentCoordinator"
            )
            log.error("Batch flush failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Position helpers

    /// Converts a UTF-16 offset into an LSP `Position` by scanning the
    /// full document source. Returns `(0, 0)` when the offset is out of
    /// bounds or the source is empty.
    internal static func position(for utf16Offset: Int, in fullSource: String) -> Position {
        guard utf16Offset >= 0, !fullSource.isEmpty else {
            return Position(line: 0, character: 0)
        }
        let utf16 = fullSource.utf16
        let clampedOffset = min(utf16Offset, utf16.count)
        var line = 0
        var lineStart = 0
        var pos = 0
        var cursor = utf16.startIndex

        while pos < clampedOffset, cursor < utf16.endIndex {
            if utf16[cursor] == 0x0A { // U+000A LINE FEED
                line &+= 1
                lineStart = pos &+ 1
            }
            utf16.formIndex(after: &cursor)
            pos &+= 1
        }

        return Position(line: line, character: clampedOffset - lineStart)
    }
}

// MARK: - Observer conformances

extension LSPContentCoordinator: WillEditEventObserving {}
extension LSPContentCoordinator: TextEditEventObserving {}
