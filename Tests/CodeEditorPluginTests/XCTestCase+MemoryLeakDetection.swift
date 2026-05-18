@testable import CodeEditorSwiftUI
@testable import CodeEditorView
import XCTest

/// A Sendable wrapper for weak references
private final class WeakWrapper: @unchecked Sendable {
    private weak var object: AnyObject?
    private let lock = NSLock()

    init(_ object: AnyObject) {
        self.object = object
    }

    var isNil: Bool {
        lock.lock()
        defer { lock.unlock() }
        return object == nil
    }

    var value: AnyObject? {
        lock.lock()
        defer { lock.unlock() }
        return object
    }
}

extension XCTestCase {
    /// Tracks memory allocations and detects leaks
    func trackForMemoryLeaks(
        _ instance: AnyObject,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // Create a wrapper that captures the weak reference safely
        let weakWrapper = WeakWrapper(instance)

        addTeardownBlock {
            // Check the weak reference in a concurrency-safe way
            let isNil = weakWrapper.isNil
            XCTAssertTrue(
                isNil,
                "Instance should have been deallocated. Potential memory leak detected.",
                file: file,
                line: line
            )
        }
    }

    /// Asserts that a closure doesn't create retain cycles
    func assertNoMemoryLeak<T: AnyObject>(
        of object: T,
        when closure: (T) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        closure(object)

        // Create weak wrapper
        let weakWrapper = WeakWrapper(object)

        // Force object to be eligible for deallocation
        autoreleasepool {
            _ = object // Use object to avoid optimization
        }

        // Give time for deallocation
        let expectation = XCTestExpectation(description: "Object deallocated")

        // Use Task instead of DispatchQueue for Swift 6 compatibility
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            if weakWrapper.isNil {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 0.5)

        XCTAssertTrue(
            weakWrapper.isNil,
            "Object was not deallocated. Potential memory leak.",
            file: file,
            line: line
        )
    }

    /// Monitors memory usage during test execution
    func measureMemoryFootprint(
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> Void
    ) rethrows {
        let initialMemory = currentMemoryUsage()

        try autoreleasepool {
            try block()
        }

        // Force cleanup
        for _ in 0..<3 {
            autoreleasepool { }
        }

        let finalMemory = currentMemoryUsage()
        let delta = finalMemory - initialMemory

        // Log if memory increased significantly (> 10MB)
        if delta > 10 * 1_024 * 1_024 {
            XCTFail(
                "Memory usage increased by \(delta / 1_024 / 1_024)MB",
                file: file,
                line: line
            )
        }
    }

    private func currentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: 1) { pointer in
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    pointer,
                    &count
                )
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}

// Memory leak detection for async contexts
extension XCTestCase {
    /// Tracks memory leaks in async contexts
    func trackForMemoryLeaksAsync<T: AnyObject>(
        _ instance: T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        weak let weakInstance = instance

        // Allow instance to go out of scope
        await Task.yield()

        // Give time for deallocation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        XCTAssertNil(
            weakInstance,
            "Instance should have been deallocated. Potential memory leak detected.",
            file: file,
            line: line
        )
    }
}
