@testable import CodeEditorLSP
import Foundation
import Testing

@Suite struct LSPFrameCodecTests {
    @Test func encodeProducesContentLengthHeaderThenPayload() {
        let payload = Data(#"{"id":1}"#.utf8)
        let framed = LSPFrameCodec.encode(payload)
        #expect(framed == Data("Content-Length: 8\r\n\r\n".utf8) + payload)
    }

    @Test func encodeExtractRoundTripsSingleFrame() throws {
        let payload = Data(#"{"method":"initialized"}"#.utf8)
        var buffer = LSPFrameCodec.encode(payload)
        #expect(try LSPFrameCodec.extractCompleteMessage(from: &buffer) == payload)
        #expect(buffer.isEmpty)
    }

    @Test func extractReturnsNilOnPartialFrameWithoutConsuming() throws {
        let payload = Data(#"{"id":2}"#.utf8)
        var buffer = Data(LSPFrameCodec.encode(payload).dropLast(3))
        let before = buffer
        #expect(try LSPFrameCodec.extractCompleteMessage(from: &buffer) == nil)
        #expect(buffer == before)
    }

    @Test func extractDrainsBackToBackFramesInOrder() throws {
        let first = Data(#"{"id":1}"#.utf8)
        let second = Data(#"{"id":2}"#.utf8)
        var buffer = LSPFrameCodec.encode(first) + LSPFrameCodec.encode(second)
        #expect(try LSPFrameCodec.extractCompleteMessage(from: &buffer) == first)
        #expect(try LSPFrameCodec.extractCompleteMessage(from: &buffer) == second)
        #expect(buffer.isEmpty)
    }

    @Test func extractRecoversPastMalformedHeaderToNextFrame() throws {
        let good = Data(#"{"id":3}"#.utf8)
        var buffer = Data("Content-Length: notanumber\r\n\r\n".utf8) + LSPFrameCodec.encode(good)
        #expect(try LSPFrameCodec.extractCompleteMessage(from: &buffer) == good)
    }

    @Test func extractClearsUnrecoverableBuffer() throws {
        var buffer = Data("garbage-without-marker\r\n\r\nmore garbage".utf8)
        #expect(try LSPFrameCodec.extractCompleteMessage(from: &buffer) == nil)
        #expect(buffer.isEmpty)
    }

    @Test func extractRejectsNegativeLengthAsMalformedAndRecovers() throws {
        let good = Data(#"{"id":4}"#.utf8)
        var buffer = Data("Content-Length: -5\r\n\r\n".utf8) + LSPFrameCodec.encode(good)
        #expect(try LSPFrameCodec.extractCompleteMessage(from: &buffer) == good)
    }

    @Test func extractFailsTheStreamOnAnOverflowingLength() {
        var buffer = Data("Content-Length: 9223372036854775807\r\n\r\n{}".utf8)
        #expect(throws: LSPFrameCodecError.self) {
            try LSPFrameCodec.extractCompleteMessage(from: &buffer)
        }
        #expect(buffer.isEmpty)
    }

    @Test func extractFailsTheStreamOnAnOversizedFrame() {
        var buffer = Data("Content-Length: 1000000000000\r\n\r\n{}".utf8)
        #expect(throws: LSPFrameCodecError.frameTooLarge(1_000_000_000_000)) {
            try LSPFrameCodec.extractCompleteMessage(from: &buffer)
        }
    }

    @Test func extractFailsTheStreamOnAnUnterminatedHugeHeader() {
        var buffer = Data(repeating: UInt8(ascii: "x"), count: LSPFrameCodec.maxHeaderBytes + 1)
        #expect(throws: LSPFrameCodecError.headerTooLarge) {
            try LSPFrameCodec.extractCompleteMessage(from: &buffer)
        }
    }

    @Test func headerNameIsCaseInsensitive() throws {
        let payload = Data(#"{"id":5}"#.utf8)
        var buffer = Data("content-length: \(payload.count)\r\n\r\n".utf8) + payload
        #expect(try LSPFrameCodec.extractCompleteMessage(from: &buffer) == payload)
        #expect(buffer.isEmpty)
    }
}
