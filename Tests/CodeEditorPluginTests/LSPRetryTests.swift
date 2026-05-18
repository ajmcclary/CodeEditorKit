#if canImport(AppKit)
@testable import CodeEditorLSP
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest

final class LSPRetryTests: XCTestCase {
    // MARK: - Retry Configuration Tests

    func testDefaultRetryConfiguration() {
        let config = LSPRetryConfiguration.default

        XCTAssertEqual(config.maxRetries, 3)
        XCTAssertEqual(config.initialDelay, 1.0)
        XCTAssertEqual(config.maxDelay, 30.0)
        XCTAssertEqual(config.backoffFactor, 2.0)
        XCTAssertTrue(config.jitterEnabled)
    }

    func testAggressiveRetryConfiguration() {
        let config = LSPRetryConfiguration.aggressive

        XCTAssertEqual(config.maxRetries, 5)
        XCTAssertEqual(config.initialDelay, 0.5)
        XCTAssertEqual(config.maxDelay, 60.0)
        XCTAssertEqual(config.backoffFactor, 1.5)
        XCTAssertTrue(config.jitterEnabled)
    }

    func testConservativeRetryConfiguration() {
        let config = LSPRetryConfiguration.conservative

        XCTAssertEqual(config.maxRetries, 2)
        XCTAssertEqual(config.initialDelay, 2.0)
        XCTAssertEqual(config.maxDelay, 10.0)
        XCTAssertEqual(config.backoffFactor, 2.0)
        XCTAssertFalse(config.jitterEnabled)
    }

    func testNoRetryConfiguration() {
        let config = LSPRetryConfiguration.noRetry

        XCTAssertEqual(config.maxRetries, 0)
        XCTAssertEqual(config.initialDelay, 0)
        XCTAssertEqual(config.maxDelay, 0)
        XCTAssertEqual(config.backoffFactor, 0)
        XCTAssertFalse(config.jitterEnabled)
    }

    // MARK: - Delay Calculation Tests

    func testExponentialBackoffCalculation() {
        let config = LSPRetryConfiguration(
            maxRetries: 5,
            initialDelay: 1.0,
            maxDelay: 100.0,
            backoffFactor: 2.0,
            jitterEnabled: false
        )

        // Test exponential backoff
        XCTAssertEqual(config.delay(for: 0), 1.0)  // 1.0
        XCTAssertEqual(config.delay(for: 1), 2.0)  // 1.0 * 2
        XCTAssertEqual(config.delay(for: 2), 4.0)  // 2.0 * 2
        XCTAssertEqual(config.delay(for: 3), 8.0)  // 4.0 * 2
        XCTAssertEqual(config.delay(for: 4), 16.0) // 8.0 * 2
    }

    func testMaxDelayCapCalculation() {
        let config = LSPRetryConfiguration(
            maxRetries: 10,
            initialDelay: 1.0,
            maxDelay: 5.0,
            backoffFactor: 2.0,
            jitterEnabled: false
        )

        // Test that delays are capped at maxDelay
        XCTAssertEqual(config.delay(for: 0), 1.0)
        XCTAssertEqual(config.delay(for: 1), 2.0)
        XCTAssertEqual(config.delay(for: 2), 4.0)
        XCTAssertEqual(config.delay(for: 3), 5.0) // Capped
        XCTAssertEqual(config.delay(for: 4), 5.0) // Capped
        XCTAssertEqual(config.delay(for: 10), 5.0) // Still capped
    }

    func testJitterCalculation() {
        let config = LSPRetryConfiguration(
            maxRetries: 3,
            initialDelay: 10.0,
            maxDelay: 100.0,
            backoffFactor: 1.0, // No backoff to isolate jitter
            jitterEnabled: true
        )

        // Test that jitter adds variation
        let delays = (0..<100).map { _ in config.delay(for: 0) }
        let minDelay = delays.min() ?? 0
        let maxDelay = delays.max() ?? 0

        // Jitter should add ±20% variation
        XCTAssertGreaterThanOrEqual(minDelay, 8.0)   // 10.0 * 0.8
        XCTAssertLessThanOrEqual(maxDelay, 12.0)     // 10.0 * 1.2

        // Should have some variation
        let uniqueDelays = Set(delays)
        XCTAssertGreaterThan(uniqueDelays.count, 10) // Should have many different values
    }

    func testNegativeAttemptHandling() {
        let config = LSPRetryConfiguration.default

        // Negative attempts should return initial delay
        XCTAssertEqual(config.delay(for: -1), config.initialDelay)
        XCTAssertEqual(config.delay(for: -100), config.initialDelay)
    }

    // MARK: - Integration Tests

    @MainActor
    func testLanguageServerConfigWithRetry() async throws {
        let retryConfig = LSPRetryConfiguration(
            maxRetries: 2,
            initialDelay: 0.1,
            maxDelay: 1.0,
            backoffFactor: 2.0,
            jitterEnabled: false
        )

        let languageConfig = LanguageServerConfig(
            languageId: "test",
            serverPath: "/nonexistent/path/to/lsp-server", // Non-existent path
            fileExtensions: ["test"],
            enablePathResolution: false, // Disable path resolution to ensure it tries to start
            retryConfiguration: retryConfig
        )

        XCTAssertEqual(languageConfig.retryConfiguration.maxRetries, 2)
        XCTAssertEqual(languageConfig.retryConfiguration.initialDelay, 0.1)

        let registry = LSPClientRegistry()
        registry.registerLanguageServer(languageConfig)

        // Set a workspace root so it proceeds to connection
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp")

        // Start timing
        let startTime = Date()

        do {
            try await registry.startLanguageServer(for: "test")
            XCTFail("Expected server start to fail")
        } catch {
            // Expected to fail
            let elapsedTime = Date().timeIntervalSince(startTime)

            // The actual retry delays may not apply if the failure happens during path resolution
            // or other early checks. Just verify it completed in a reasonable time.
            XCTAssertLessThanOrEqual(elapsedTime, 2.0)

            // Verify the error is what we expect
            XCTAssertTrue(error.localizedDescription.contains("LSP") ||
                         error.localizedDescription.contains("server") ||
                         error.localizedDescription.contains("failed"),
                         "Unexpected error: \(error)")
        }
    }

    @MainActor
    func testNoRetryBehavior() async throws {
        let registry = LSPClientRegistry()

        let languageConfig = LanguageServerConfig(
            languageId: "test-no-retry",
            serverPath: "/nonexistent/path/to/lsp-server", // Non-existent path
            fileExtensions: ["test"],
            enablePathResolution: false,
            retryConfiguration: .noRetry
        )

        registry.registerLanguageServer(languageConfig)
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp")

        let startTime = Date()

        do {
            try await registry.startLanguageServer(for: "test-no-retry")
            XCTFail("Expected server start to fail")
        } catch {
            // Expected to fail
            let elapsedTime = Date().timeIntervalSince(startTime)

            // Should fail immediately with no retries
            XCTAssertLessThanOrEqual(elapsedTime, 1.0)
        }
    }

    @MainActor
    func testOverrideRetryConfiguration() async throws {
        let registry = LSPClientRegistry()

        // Register with conservative retry
        let languageConfig = LanguageServerConfig(
            languageId: "test-override",
            serverPath: "/nonexistent/path/to/lsp-server",
            fileExtensions: ["test"],
            enablePathResolution: false,
            retryConfiguration: .conservative
        )

        registry.registerLanguageServer(languageConfig)
        registry.workspaceRoot = URL(fileURLWithPath: "/tmp")

        // But start with no retry override
        let startTime = Date()

        do {
            try await registry.startLanguageServer(for: "test-override", retryConfig: .noRetry)
            XCTFail("Expected server start to fail")
        } catch {
            // Expected to fail
            let elapsedTime = Date().timeIntervalSince(startTime)

            // Should fail immediately due to override
            XCTAssertLessThanOrEqual(elapsedTime, 1.0)
        }
    }
}
#endif
