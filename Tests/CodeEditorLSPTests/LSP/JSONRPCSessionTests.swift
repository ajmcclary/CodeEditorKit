@testable import CodeEditorLSP
import Foundation
import XCTest

private actor RequestIDRecorder {
    private var values: [RequestId] = []

    func append(_ value: RequestId) {
        values.append(value)
    }

    func snapshot() -> [RequestId] {
        values
    }
}

@MainActor
final class JSONRPCSessionTests: XCTestCase {
    private enum SendFailure: Error {
        case partialWrite
    }

    nonisolated private static func requestID(from data: Data) throws -> RequestId {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LSPError.invalidResponse("Expected JSON object")
        }
        if let number = object["id"] as? Int {
            return .number(number)
        }
        guard let value = object["id"] as? String else {
            throw LSPError.invalidResponse("Expected request id")
        }
        return .string(value)
    }

    nonisolated private static func response(for id: RequestId) throws -> LSPResponse {
        let identifier: Any
        switch id {
        case .number(let value):
            identifier = value

        case .string(let value):
            identifier = value
        }
        let dictionary: [String: Any] = [
            "jsonrpc": "2.0",
            "id": identifier,
            "result": ["value": true]
        ]
        return LSPResponse(
            data: try JSONSerialization.data(withJSONObject: dictionary),
            messageDict: dictionary
        )
    }

    func testResponseCompletesRequestAndRemovesContinuation() async throws {
        let session = JSONRPCSession()
        session.setSendHandler { [weak session] data in
            guard let session else { return }
            let id = try Self.requestID(from: data)
            let response = try Self.response(for: id)
            await session.handleResponse(id: id, result: .success(response))
        }

        _ = try await session.request(method: "test", params: EmptyParams())

        XCTAssertEqual(session.pendingCount, 0)
    }

    func testSendFailureAfterResponseDoesNotResumeTwice() async throws {
        let session = JSONRPCSession()
        session.setSendHandler { [weak session] data in
            guard let session else { return }
            let id = try Self.requestID(from: data)
            let response = try Self.response(for: id)
            await session.handleResponse(id: id, result: .success(response))
            throw SendFailure.partialWrite
        }

        _ = try await session.request(method: "test", params: EmptyParams())

        XCTAssertEqual(session.pendingCount, 0)
    }

    func testFailAllPendingCompletesDisconnectedRequest() async {
        let session = JSONRPCSession { _ in }
        let request = Task { @MainActor in
            try await session.request(method: "test", params: EmptyParams())
        }
        while session.pendingCount == 0 {
            await Task.yield()
        }

        session.failAllPending(with: .notConnected)

        do {
            _ = try await request.value
            XCTFail("Expected pending request to fail")
        } catch let error as LSPError {
            guard case .notConnected = error else {
                return XCTFail("Expected notConnected, got \(error)")
            }
        } catch {
            XCTFail("Expected LSPError, got \(error)")
        }
        XCTAssertEqual(session.pendingCount, 0)
    }

    func testRequestIdentifierWrapsFromIntMaxToOne() async throws {
        let session = JSONRPCSession(nextRequestID: .max)
        let observed = RequestIDRecorder()
        session.setSendHandler { [weak session] data in
            guard let session else { return }
            let id = try Self.requestID(from: data)
            await observed.append(id)
            let response = try Self.response(for: id)
            await session.handleResponse(id: id, result: .success(response))
        }

        _ = try await session.request(method: "one", params: EmptyParams())
        _ = try await session.request(method: "two", params: EmptyParams())

        let identifiers = await observed.snapshot()
        XCTAssertEqual(identifiers, [.number(.max), .number(1)])
    }

    func testUnansweredRequestTimesOutAndIsReportedAbandoned() async {
        let session = JSONRPCSession(requestTimeout: .milliseconds(50)) { _ in }
        var abandoned: [RequestId] = []
        session.onAbandon = { abandoned.append($0) }

        do {
            _ = try await session.request(method: "textDocument/hover", params: EmptyParams())
            XCTFail("Expected the request to time out")
        } catch let error as LSPError {
            guard case .timeout = error else { return XCTFail("Expected timeout, got \(error)") }
        } catch {
            XCTFail("Expected LSPError.timeout, got \(error)")
        }
        XCTAssertEqual(session.pendingCount, 0)
        XCTAssertEqual(abandoned, [.number(1)])
    }

    func testCancellingTheCallerFailsThePendingRequest() async {
        let session = JSONRPCSession(requestTimeout: nil) { _ in }
        var abandoned: [RequestId] = []
        session.onAbandon = { abandoned.append($0) }
        let request = Task { @MainActor in
            try await session.request(method: "textDocument/completion", params: EmptyParams())
        }
        while session.pendingCount == 0 {
            await Task.yield()
        }

        request.cancel()

        do {
            _ = try await request.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(error)")
        }
        XCTAssertEqual(session.pendingCount, 0)
        XCTAssertEqual(abandoned, [.number(1)])
    }

    func testNullResultDecodesAsAbsentWithoutRaising() throws {
        let dictionary: [String: Any] = ["jsonrpc": "2.0", "id": 1, "result": NSNull()]
        let response = LSPResponse(data: Data(#"{"jsonrpc":"2.0","id":1,"result":null}"#.utf8), messageDict: dictionary)
        XCTAssertTrue(response.isNullResult)
        XCTAssertNil(try response.decodeIfPresent(as: Hover.self))
        XCTAssertNil(LSPLanguageFeatures.parseHoverResponse(response))
        XCTAssertEqual(try LSPLanguageFeatures.parseDefinitionResponse(response).count, 0)
        XCTAssertEqual(try LSPLanguageFeatures.parseCompletionResponse(response).items.count, 0)
        XCTAssertEqual(try LSPLanguageFeatures.parseDocumentSymbolResponse(response).count, 0)
        XCTAssertThrowsError(try response.decode(as: Hover.self))
    }

    func testScalarResultDecodesWithoutRaising() throws {
        let response = LSPResponse(data: Data(#"{"jsonrpc":"2.0","id":1,"result":42}"#.utf8), messageDict: [:])
        XCTAssertEqual(try response.decode(as: Int.self), 42)
        XCTAssertThrowsError(try response.decode(as: Hover.self))
    }
}
