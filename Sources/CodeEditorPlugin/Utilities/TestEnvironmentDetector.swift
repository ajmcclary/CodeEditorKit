import Foundation

/// Helper for detecting test environments across the codebase
/// This consolidates the common pattern of checking for XCTestConfigurationFilePath
/// to avoid duplication and ensure consistent test detection logic
public enum TestEnvironmentDetector {
    // MARK: - Test Environment Detection

    /// Detects if the code is currently running in a test environment
    /// 
    /// This method checks for the presence of the XCTestConfigurationFilePath environment variable,
    /// which is set by Xcode when running tests.
    ///
    /// - Returns: `true` if running in a test environment, `false` otherwise
    ///
    /// ## Usage
    ///
    /// Use this to conditionally disable features that shouldn't run during tests:
    ///
    /// ```swift
    /// // Skip memory monitoring during tests
    /// if !TestEnvironmentDetector.isRunningInTests {
    ///     memoryMonitor.startMonitoring()
    /// }
    ///
    /// // Only log in non-test environments
    /// if !TestEnvironmentDetector.isRunningInTests {
    ///     logger.info("Starting background operation")
    /// }
    /// ```
    ///
    /// ## Common Use Cases
    ///
    /// - Disabling background monitoring and cleanup during tests
    /// - Skipping performance-related logging that can interfere with test output
    /// - Avoiding timer-based operations that can cause test flakiness
    /// - Preventing resource-intensive operations during test runs
    ///
    public static var isRunningInTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Detects if the code is NOT running in a test environment
    /// 
    /// Convenience property that's the inverse of `isRunningInTests`.
    /// Useful for positive logic where you want to perform operations only in production.
    ///
    /// - Returns: `true` if NOT running in a test environment, `false` if running in tests
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Start monitoring only in production
    /// if TestEnvironmentDetector.isRunningInProduction {
    ///     performanceMonitor.start()
    /// }
    /// ```
    public static var isRunningInProduction: Bool {
        !isRunningInTests
    }

    // MARK: - Conditional Execution Helpers

    /// Execute a closure only if NOT running in tests
    /// 
    /// This helper method provides a clean way to conditionally execute code
    /// that should only run in production environments.
    ///
    /// - Parameter closure: The closure to execute if not in a test environment
    ///
    /// ## Usage
    ///
    /// ```swift
    /// TestEnvironmentDetector.executeInProduction {
    ///     logger.info("Application started")
    ///     backgroundMonitor.start()
    /// }
    /// ```
    public static func executeInProduction(_ closure: () -> Void) {
        if isRunningInProduction {
            closure()
        }
    }

    /// Execute an async closure only if NOT running in tests
    /// 
    /// Async version of `executeInProduction` for asynchronous operations.
    ///
    /// - Parameter closure: The async closure to execute if not in a test environment
    ///
    /// ## Usage
    ///
    /// ```swift
    /// await TestEnvironmentDetector.executeInProduction {
    ///     await networkMonitor.startHealthChecks()
    /// }
    /// ```
    public static func executeInProduction(_ closure: () async -> Void) async {
        if isRunningInProduction {
            await closure()
        }
    }

    /// Execute a throwing closure only if NOT running in tests
    /// 
    /// Version of `executeInProduction` for operations that can throw errors.
    ///
    /// - Parameter closure: The throwing closure to execute if not in a test environment
    /// - Throws: Any error thrown by the closure
    ///
    /// ## Usage
    ///
    /// ```swift
    /// try TestEnvironmentDetector.executeInProduction {
    ///     try riskySynchronizationOperation()
    /// }
    /// ```
    public static func executeInProduction<T>(_ closure: () throws -> T) rethrows -> T? {
        if isRunningInProduction {
            return try closure()
        }
        return nil
    }

    /// Execute an async throwing closure only if NOT running in tests
    /// 
    /// Async throwing version of `executeInProduction`.
    ///
    /// - Parameter closure: The async throwing closure to execute if not in a test environment
    /// - Throws: Any error thrown by the closure
    ///
    /// ## Usage
    ///
    /// ```swift
    /// try await TestEnvironmentDetector.executeInProduction {
    ///     try await riskyNetworkOperation()
    /// }
    /// ```
    public static func executeInProduction<T>(_ closure: () async throws -> T) async rethrows -> T? {
        if isRunningInProduction {
            return try await closure()
        }
        return nil
    }

    // MARK: - Debug Information

    /// Get debug information about the current environment
    /// 
    /// Useful for debugging environment detection issues.
    ///
    /// - Returns: A dictionary containing environment detection details
    public static var debugInfo: [String: Any] {
        [
            "isRunningInTests": isRunningInTests,
            "isRunningInProduction": isRunningInProduction,
            "xcTestConfigurationPath": ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] as Any,
            "processName": ProcessInfo.processInfo.processName,
            "arguments": ProcessInfo.processInfo.arguments
        ]
    }
}
