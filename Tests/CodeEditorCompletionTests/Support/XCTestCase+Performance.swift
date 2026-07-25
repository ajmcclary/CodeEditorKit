//
//  XCTestCase+Performance.swift
//  CodeEditorKitTests
//
//  Created to optimize test performance by providing standard measure options
//

import XCTest

extension XCTestCase {
    /// Standard measure options for performance tests
    /// Uses 3 iterations instead of default 10 to significantly reduce test time
    static var standardMeasureOptions: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        return options
    }

    /// Fast measure options for quick performance tests
    /// Uses only 2 iterations for tests that don't need high precision
    static var fastMeasureOptions: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 2
        return options
    }

    /// Ultra-fast measure options for simple performance tests
    /// Uses only 1 iteration - use sparingly for tests that are already slow
    static var ultraFastMeasureOptions: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        return options
    }

    /// Checks if running in test environment
    static var isTestEnvironment: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
