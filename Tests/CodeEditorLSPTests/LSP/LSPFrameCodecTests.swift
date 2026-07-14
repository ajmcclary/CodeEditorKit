@testable import CodeEditorLSP
import Foundation
import Testing

@Suite struct LSPFrameCodecTests {
    @Test func encodeProducesContentLengthHeaderThenPayload() {
        let payload = Data(#"{"id":1}"#.utf8)
        let framed = LSPFrameCodec.encode(payload)
        #expect(framed == Data("Content-Length: 8\r\n\r\n".utf8) + payload)
    }

    @Test func encodeExtractRoundTripsSingleFrame() {
        let payload = Data(#"{"method":"initialized"}"#.utf8)
        var buffer = LSPFrameCodec.encode(payload)
        #expect(LSPFrameCodec.extractCompleteMessage(from: &buffer) == payload)
        #expect(buffer.isEmpty)
    }

    @Test func extractReturnsNilOnPartialFrameWithoutConsuming() {
        let payload = Data(#"{"id":2}"#.utf8)
        var buffer = Data(LSPFrameCodec.encode(payload).dropLast(3))
        let before = buffer
        #expect(LSPFrameCodec.extractCompleteMessage(from: &buffer) == nil)
        #expect(buffer == before)
    }

    @Test func extractDrainsBackToBackFramesInOrder() {
        let first = Data(#"{"id":1}"#.utf8)
        let second = Data(#"{"id":2}"#.utf8)
        var buffer = LSPFrameCodec.encode(first) + LSPFrameCodec.encode(second)
        #expect(LSPFrameCodec.extractCompleteMessage(from: &buffer) == first)
        #expect(LSPFrameCodec.extractCompleteMessage(from: &buffer) == second)
        #expect(buffer.isEmpty)
    }

    @Test func extractRecoversPastMalformedHeaderToNextFrame() {
        let good = Data(#"{"id":3}"#.utf8)
        var buffer = Data("Content-Length: notanumber\r\n\r\n".utf8) + LSPFrameCodec.encode(good)
        #expect(LSPFrameCodec.extractCompleteMessage(from: &buffer) == good)
    }

    @Test func extractClearsUnrecoverableBuffer() {
        var buffer = Data("garbage-without-marker\r\n\r\nmore garbage".utf8)
        #expect(LSPFrameCodec.extractCompleteMessage(from: &buffer) == nil)
        #expect(buffer.isEmpty)
    }
}
