#if canImport(AppKit)
@testable import CodeEditorLSP
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import Foundation
import XCTest

/// Regression: `LSPProcessManager.startReadingFromServer` used to busy-poll
/// `fileHandle.availableData` every 1ms (≈1000 wake-ups/sec per server).
/// Replaced with an event-driven `FileHandle.readabilityHandler`. Test
/// verifies the new reader routes raw stdout bytes through the message
/// handler by framing a real LSP notification on a real `Pipe` and asserting
/// the handler's notification callback fires (REVIEW.md LSP/Critical).
@MainActor
final class LSPProcessManagerReaderTests: XCTestCase {
    func testInstalledReaderForwardsAFramedLSPNotificationToTheHandler() async throws {
        let messageHandler = LSPMessageHandler()
        let manager = LSPProcessManager(messageHandler: messageHandler)
        let pipe = Pipe()

        // Capture the notification on a Sendable mailbox.
        let mailbox = NotificationMailbox()
        await messageHandler.setNotificationCallback { method, payload in
            Task { await mailbox.record(method: method, payload: payload) }
        }

        manager.installStdoutReader(on: pipe.fileHandleForReading)

        // Frame: `Content-Length: N\r\n\r\n<json>`. Use a minimal LSP
        // notification ("method": "window/logMessage", no "id" -> notification).
        let body = #"{"jsonrpc":"2.0","method":"window/logMessage","params":{"type":3,"message":"hi"}}"#
        let bodyData = Data(body.utf8)
        let header = "Content-Length: \(bodyData.count)\r\n\r\n"
        var framed = Data(header.utf8)
        framed.append(bodyData)

        try pipe.fileHandleForWriting.write(contentsOf: framed)

        // The readabilityHandler runs on a background dispatch queue and the
        // forwarded `processIncomingData(_:)` runs on the message-handler
        // actor — give those two hops a generous wall-clock budget so the
        // test is robust on busy CI.
        let observed = try await mailbox.wait(timeout: 1.0)
        XCTAssertEqual(observed.method, "window/logMessage")
        // The notification callback receives the JSON-reserialized `params`
        // blob, not the full message body. Just round-trip it and assert
        // both keys made it through.
        let decoded = try JSONSerialization.jsonObject(with: observed.payload) as? [String: Any]
        XCTAssertEqual(decoded?["type"] as? Int, 3)
        XCTAssertEqual(decoded?["message"] as? String, "hi")

        // Trigger EOF cleanup so the test doesn't leave a dangling handler.
        try? pipe.fileHandleForWriting.close()
    }
}

/// Sendable holder used as the cross-actor mailbox in the test above.
private actor NotificationMailbox {
    struct Entry: Equatable, Sendable {
        let method: String
        let payload: Data
    }

    private var entry: Entry?
    private var pendingContinuation: CheckedContinuation<Entry, Error>?

    func record(method: String, payload: Data) {
        let value = Entry(method: method, payload: payload)
        if let continuation = pendingContinuation {
            pendingContinuation = nil
            continuation.resume(returning: value)
        } else {
            entry = value
        }
    }

    func wait(timeout: TimeInterval) async throws -> Entry {
        if let existing = entry {
            entry = nil
            return existing
        }
        return try await withThrowingTaskGroup(of: Entry.self) { group in
            group.addTask { [self] in
                try await withCheckedThrowingContinuation { continuation in
                    Task { await self.setContinuation(continuation) }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw MailboxError.timedOut
            }
            guard let first = try await group.next() else {
                throw MailboxError.timedOut
            }
            group.cancelAll()
            return first
        }
    }

    private func setContinuation(_ continuation: CheckedContinuation<Entry, Error>) {
        if let existing = entry {
            entry = nil
            continuation.resume(returning: existing)
        } else {
            pendingContinuation = continuation
        }
    }

    enum MailboxError: Error { case timedOut }
}
#endif
