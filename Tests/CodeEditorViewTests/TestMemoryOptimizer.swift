@testable import CodeEditorView
import Foundation
import XCTest

/// Helper class to optimize memory usage in tests
final class TestMemoryOptimizer: @unchecked Sendable {
    /// Shared instance for test data caching
    static let shared = TestMemoryOptimizer()

    /// Cache for frequently used test data
    private var dataCache: [String: String] = [:]

    /// Memory pressure threshold (50MB)
    static let memoryPressureThreshold: Int = 50 * 1_024 * 1_024

    private init() {}

    /// Reset cache between test suites
    func reset() {
        dataCache.removeAll()
    }

    /// Get or create cached test data
    func getCachedTestData(
        key: String,
        generator: () -> String
    ) -> String {
        if let cached = dataCache[key] {
            return cached
        }

        let data = generator()

        // Only cache if data is reasonable size (< 1MB)
        if data.utf8.count < 1_024_000 {
            dataCache[key] = data
        }

        return data
    }

    /// Generate optimized repetitive text
    func generateOptimizedText(
        line: String,
        count: Int,
        separator: String = "\n"
    ) -> String {
        // Use more efficient string building for large counts
        if count > 1_000 {
            var result = ""
            result.reserveCapacity(line.count * count + separator.count * (count - 1))

            for index in 0..<count {
                result.append(line)
                if index < count - 1 {
                    result.append(separator)
                }
            }

            return result
        } else {
            return Array(repeating: line, count: count).joined(separator: separator)
        }
    }

    /// Generate test code with minimal allocations
    func generateMinimalSwiftCode(lineCount: Int) -> String {
        let optimizer = self

        return optimizer.getCachedTestData(key: "swift_\(lineCount)") {
            var code = ""
            code.reserveCapacity(lineCount * 50) // Estimate ~50 chars per line

            // Generate varied but minimal code
            for index in 0..<lineCount {
                switch index % 5 {
                case 0:
                    code.append("func test\(index)() { }\n")

                case 1:
                    code.append("let value\(index) = \(index)\n")

                case 2:
                    code.append("// Comment \(index)\n")

                case 3:
                    code.append("class C\(index) { }\n")

                default:
                    code.append("\n")
                }
            }

            return code
        }
    }

    /// Track memory usage during test
    static func measureMemoryUsage<T>(
        operation: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        block: () throws -> T
    ) rethrows -> T {
        let startMemory = currentMemoryUsage()

        let result = try block()

        let endMemory = currentMemoryUsage()
        let memoryDelta = endMemory - startMemory

        if memoryDelta > memoryPressureThreshold {
            XCTFail(
                "\(operation) used excessive memory: \(formatBytes(memoryDelta))",
                file: file,
                line: line
            )
        }

        return result
    }

    /// Get current memory usage in bytes
    private static func currentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }

    /// Format bytes for display
    private static func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

/// Extension for XCTestCase to add memory-optimized helpers
extension XCTestCase {
    /// Create a memory-optimized CodeEditorView
    @MainActor
    func createOptimizedEditorView(
        frame: CGRect = .zero,
        text: String? = nil
    ) -> CodeEditorView {
        let editor = CodeEditorView(frame: frame)

        // Disable expensive features for tests unless needed
        editor.isLineNumbersEnabled = false
        // Note: These performance settings may not exist in the current configuration
        // editor.configuration.performance.enableAsyncHighlighting = false
        // editor.configuration.performance.maxHighlightableFileSize = 10_000

        if let text {
            editor.text = text
        }

        return editor
    }

    /// Clean up editor view properly
    @MainActor
    func cleanupEditorView(_ editor: CodeEditorView) {
        editor.text = ""
        editor.language = .plainText
        editor.removeFromSuperview()
    }

    /// Run test with automatic cleanup
    @MainActor
    func withEditorView<T>(
        text: String? = nil,
        block: (CodeEditorView) throws -> T
    ) rethrows -> T {
        let editor = createOptimizedEditorView(text: text)
        defer { cleanupEditorView(editor) }
        return try block(editor)
    }

    /// Run test with multiple editors and cleanup
    @MainActor
    func withMultipleEditors<T>(
        count: Int,
        block: ([CodeEditorView]) throws -> T
    ) rethrows -> T {
        var editors: [CodeEditorView] = []
        editors.reserveCapacity(count)

        for _ in 0..<count {
            editors.append(createOptimizedEditorView())
        }

        defer {
            editors.forEach { cleanupEditorView($0) }
        }

        return try block(editors)
    }

    /// Generate test data with size limits
    func generateBoundedTestData(
        targetSize: Int,
        maxSize: Int = 100_000
    ) -> String {
        let actualSize = min(targetSize, maxSize)
        return TestMemoryOptimizer.shared.generateOptimizedText(
            line: "Test line with some content",
            count: actualSize / 30 // Approximate line size
        )
    }
}

/// Test data generator with memory limits
enum MemoryBoundedTestData {
    /// Maximum size for performance test data
    static let performanceTestMaxSize = 50_000

    /// Maximum size for stress test data  
    static let stressTestMaxSize = 100_000

    /// Maximum number of test instances
    static let maxTestInstances = 10

    /// Generate bounded Swift code
    static func swiftCode(lines: Int) -> String {
        let boundedLines = min(lines, performanceTestMaxSize)
        return TestMemoryOptimizer.shared.generateMinimalSwiftCode(lineCount: boundedLines)
    }

    /// Generate bounded JSON data
    static func jsonData(objects: Int) -> String {
        let boundedObjects = min(objects, 1_000)
        var json = "[\n"

        for index in 0..<boundedObjects {
            json.append("  { \"id\": \(index), \"name\": \"Item \(index)\" }")
            json.append(index < boundedObjects - 1 ? ",\n" : "\n")
        }

        json.append("]")
        return json
    }

    /// Generate bounded repetitive text
    static func repetitiveText(pattern: String, count: Int) -> String {
        let boundedCount = min(count, performanceTestMaxSize)
        return TestMemoryOptimizer.shared.generateOptimizedText(
            line: pattern,
            count: boundedCount
        )
    }
}
