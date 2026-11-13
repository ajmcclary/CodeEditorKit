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
        await fulfillment(of: [received], timeout: arrivalTimeout)

        let bytes = await collector.bytes
        XCTAssertEqual(String(data: bytes, encoding: .utf8), "eof-check\n")

        // EOF propagation is asynchronous; poll (a failure to arrive after
        // 30 s, not a speed check).
        for _ in 0..<300 where await transport.isConnected {
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

        do {
            // Writes succeed into the pipe until the child has closed its
            // read end, which takes as long as the machine takes to start
            // it (a fixed 300 ms wait plus two sends was not always enough).
            // Keep sending until the kernel reports it.
            let deadline = Date().addingTimeInterval(30)
            var probe = 0
            while Date() < deadline {
                probe += 1
                try await transport.send(Data(#"{"probe":\#(probe)}"#.utf8))
                try await Task.sleep(nanoseconds: 50_000_000)
            }
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
        // Wait for the child to have exited (its EOF), not a fixed 300 ms.
        let deadline = Date().addingTimeInterval(30)
        while await transport.isConnected, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        // Wall time on purpose: the regression is waiting out the 2 s
        // SIGTERM grace period, which CPU time cannot see; teardown of an
        // exited child takes milliseconds.
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

    /// A server that never reads stdin must not block the actor: the write
    /// waits off-actor and `disconnect()` still completes.
    func testBlockedWriteDoesNotBlockTheTransport() async throws {
        let transport = ProcessTransport(executablePath: "/bin/sleep", arguments: ["30"])
        try await transport.connect()

        let payload = Data(repeating: UInt8(ascii: "x"), count: 1_024 * 1_024) // > pipe buffer
        let send = Task { try await transport.send(payload) }
        try await Task.sleep(nanoseconds: 200_000_000)

        // Wall time on purpose: a blocked actor would wait until the child
        // (sleeping 30 s) dies, so these bounds tell the two apart with room
        // for a loaded machine.
        let start = ProcessInfo.processInfo.systemUptime
        _ = await transport.isConnected
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 10.0, "actor blocked by the write")

        await transport.disconnect()
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 20.0)
        _ = try? await send.value
    }

    /// Two concurrent disconnects: the second has nothing left to reap.
    func testConcurrentDisconnectsReapOnce() async throws {
        let transport = ProcessTransport(executablePath: "/bin/sleep", arguments: ["30"])
        try await transport.connect()
        async let first: Void = transport.disconnect()
        async let second: Void = transport.disconnect()
        _ = await (first, second)
        let connected = await transport.isConnected
        XCTAssertFalse(connected)
    }

    /// Releasing a running transport reaps its child instead of leaving a
    /// zombie until the app exits.
    func testReleasingARunningTransportReapsTheChild() async throws {
        var transport: ProcessTransport? = ProcessTransport(executablePath: "/bin/sleep", arguments: ["30"])
        try await transport?.connect()
        let runningPID = await transport?.processIdentifierForTesting
        let pid = try XCTUnwrap(runningPID)
        transport = nil

        // A zombie still answers kill(pid, 0); a reaped child does not.
        var reaped = false
        for _ in 0..<100 {
            if kill(pid, 0) == -1 && errno == ESRCH {
                reaped = true
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(reaped, "child \(pid) was not reaped")
    }
}

#endif
