#if canImport(AppKit)
@testable import CodeEditorLSP
import Foundation
import XCTest

final class ProcessTransportLifecycleTests: XCTestCase {
    /// EOF: a child that exits closes stdout; the ordered reader delivers
    /// the final bytes and the transport reports disconnected.
    func testChildEOFDeliversBytesThenDisconnects() async throws {
        let transport = ProcessTransport(executablePath: "/bin/echo", arguments: ["eof-check"])
        let received = XCTestExpectation(description: "echo output arrives")
        let collector = FramingByteCollector(target: 1) { received.fulfill() }

        await transport.setDataHandler { chunk in
            await collector.append(chunk)
        }
        try await transport.connect()
        await fulfillment(of: [received], timeout: 5.0)

        let bytes = await collector.bytes
        XCTAssertEqual(String(data: bytes, encoding: .utf8), "eof-check\n")

        // EOF propagation is asynchronous; poll briefly.
        for _ in 0..<50 where await transport.isConnected {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let connected = await transport.isConnected
        XCTAssertFalse(connected)
        await transport.disconnect()
    }

    /// Broken stdin: the child closes its read end; a framed send must
    /// surface `sendFailed` instead of crashing on SIGPIPE.
    func testSendToChildWithClosedStdinThrowsSendFailed() async throws {
        let transport = ProcessTransport(
            executablePath: "/bin/sh",
            arguments: ["-c", "exec 0<&-; sleep 30"]
        )
        try await transport.connect()
        try await Task.sleep(nanoseconds: 300_000_000)

        do {
            // One write may succeed into the pipe buffer before the kernel
            // reports the closed read end; the second is deterministic.
            try await transport.send(Data(#"{"probe":1}"#.utf8))
            try await Task.sleep(nanoseconds: 200_000_000)
            try await transport.send(Data(#"{"probe":2}"#.utf8))
            XCTFail("send into a closed-stdin child should throw")
        } catch let error as LSPTransportError {
            guard case .sendFailed = error else {
                return XCTFail("expected .sendFailed, got \(error)")
            }
        }
        await transport.disconnect()
    }

    /// Child exits before disconnect: teardown must return promptly (the
    /// already-exited child is reaped once, no grace-period stall).
    func testDisconnectAfterChildAlreadyExitedReturnsPromptly() async throws {
        let transport = ProcessTransport(executablePath: "/usr/bin/true")
        try await transport.connect()
        try await Task.sleep(nanoseconds: 300_000_000)

        let start = ProcessInfo.processInfo.systemUptime
        await transport.disconnect()
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 1.5)

        // Post-disconnect sends report notConnected.
        do {
            try await transport.send(Data("x".utf8))
            XCTFail("send after disconnect should throw")
        } catch let error as LSPTransportError {
            guard case .notConnected = error else {
                return XCTFail("expected .notConnected, got \(error)")
            }
        }
    }
}

#endif
