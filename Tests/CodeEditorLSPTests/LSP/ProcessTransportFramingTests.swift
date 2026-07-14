#if canImport(AppKit)
@testable import CodeEditorLSP
import Foundation
import XCTest

final class ProcessTransportFramingTests: XCTestCase {
    /// End-to-end framing pin: `send` writes LSPFrameCodec framing to the
    /// child's stdin, and the stdout reader delivers the child's output to
    /// the data handler. `/bin/cat` echoes verbatim, so received == framed.
    func testSendWritesCodecFramingAndReaderDeliversEcho() async throws {
        let transport = ProcessTransport(executablePath: "/bin/cat")
        let payload = Data(#"{"jsonrpc":"2.0","method":"initialized","params":{}}"#.utf8)
        let expected = LSPFrameCodec.encode(payload)

        let received = XCTestExpectation(description: "echoed bytes arrive")
        let collector = FramingByteCollector(target: expected.count) { received.fulfill() }

        await transport.setDataHandler { chunk in
            await collector.append(chunk)
        }
        try await transport.connect()
        try await transport.send(payload)

        await fulfillment(of: [received], timeout: 5.0)
        let bytes = await collector.bytes
        XCTAssertEqual(bytes, expected)
        await transport.disconnect()
    }
}

/// Accumulates reader chunks until a byte target is reached.
actor FramingByteCollector {
    private(set) var bytes = Data()
    private let target: Int
    private let onTarget: @Sendable () -> Void

    init(target: Int, onTarget: @escaping @Sendable () -> Void) {
        self.target = target
        self.onTarget = onTarget
    }

    func append(_ chunk: Data) {
        bytes.append(chunk)
        if bytes.count >= target { onTarget() }
    }
}
#endif
