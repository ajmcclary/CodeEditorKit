@testable import CodeEditorLSP
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Foundation
import XCTest

/// Regression coverage for `LSPConnectionManager.sendShutdownRequest(timeout:)`.
///
/// Before this was bounded, a wedged or dead language server could
/// suspend `sendRequest` indefinitely on a pending-response continuation
/// that never resumed, leaving `LSPClient.disconnect()` stuck in
/// `.shuttingDown` with the transport/process still alive. These tests
/// pin the bounded behavior so the regression cannot return.
@MainActor
final class LSPConnectionManagerShutdownTests: XCTestCase {
    func testSendShutdownRequestTimesOutWhenServerHangs() async throws {
        // A "wedged server" — sendRequest never returns and never throws.
        let hangingSendRequest: @Sendable (String, any Codable & Sendable) async throws -> LSPResponse = { _, _ in
            try await Task.sleep(for: .seconds(60))
            // Unreachable in the test timing window.
            throw LSPError.notConnected
        }
        let sendNotification: @Sendable (String, any Codable & Sendable) async throws -> Void = { _, _ in }

        let start = ContinuousClock.now
        do {
            try await LSPConnectionManager.sendShutdownRequest(
                sendRequest: hangingSendRequest,
                sendNotification: sendNotification,
                timeout: .milliseconds(150)
            )
            XCTFail("Expected LSPError.timeout to be thrown")
        } catch LSPError.timeout {
            // Expected
        } catch {
            XCTFail("Expected LSPError.timeout, got \(error)")
        }
        let elapsed = ContinuousClock.now - start
        XCTAssertLessThan(
            elapsed,
            .seconds(2),
            "sendShutdownRequest must surface a bounded timeout, not hang on the wedged server"
        )
    }

    func testSendShutdownRequestCompletesNormallyWhenServerResponds() async throws {
        actor MethodLog {
            private(set) var requestMethods: [String] = []
            private(set) var notificationMethods: [String] = []

            func recordRequest(_ method: String) { requestMethods.append(method) }
            func recordNotification(_ method: String) { notificationMethods.append(method) }
        }
        let log = MethodLog()

        let responsePayload = Data("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}".utf8)
        let sendRequest: @Sendable (String, any Codable & Sendable) async throws -> LSPResponse = { method, _ in
            await log.recordRequest(method)
            return LSPResponse(data: responsePayload, messageDict: [:])
        }
        let sendNotification: @Sendable (String, any Codable & Sendable) async throws -> Void = { method, _ in
            await log.recordNotification(method)
        }

        try await LSPConnectionManager.sendShutdownRequest(
            sendRequest: sendRequest,
            sendNotification: sendNotification,
            timeout: .seconds(2)
        )

        let requestMethods = await log.requestMethods
        let notificationMethods = await log.notificationMethods
        XCTAssertEqual(requestMethods, ["shutdown"])
        XCTAssertEqual(notificationMethods, ["exit"])
    }

    func testSendShutdownRequestPropagatesServerErrorBeforeTimeout() async throws {
        let serverError = LSPError.serverError(code: -32_603, message: "internal", data: nil)
        let sendRequest: @Sendable (String, any Codable & Sendable) async throws -> LSPResponse = { _, _ in
            throw serverError
        }
        let sendNotification: @Sendable (String, any Codable & Sendable) async throws -> Void = { _, _ in
            XCTFail("exit notification must not fire when shutdown request fails")
        }

        do {
            try await LSPConnectionManager.sendShutdownRequest(
                sendRequest: sendRequest,
                sendNotification: sendNotification,
                timeout: .seconds(2)
            )
            XCTFail("Expected the underlying server error to propagate")
        } catch LSPError.serverError {
            // Expected — the timeout race must not swallow real errors.
        } catch {
            XCTFail("Expected LSPError.serverError, got \(error)")
        }
    }
}
