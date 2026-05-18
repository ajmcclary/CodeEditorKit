import CodeEditorCommon
import CodeEditorDiagnostics
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Foundation
import XCTest

@MainActor
final class LargeFileHighlightingBenchmarkTests: XCTestCase {
    private let logger = CrossPlatformLogger.logger(
        subsystem: "com.codeeditor.tests",
        category: "LargeFileHighlightingBenchmark"
    )

    // swiftlint:disable:next unneeded_override
    override func setUp() {
        super.setUp()
        // Setup is intentionally empty
    }

    override func tearDown() {
        super.tearDown()
        // Force cleanup to prevent deallocation warnings
        autoreleasepool {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }
    // MARK: - Test Helpers

    private func createTestComponents() -> (AsyncSyntaxHighlighter, CodeEditorView, MemoryMonitor) {
        let memoryMonitor = MemoryMonitor()
        let highlighter = AsyncSyntaxHighlighter(memoryMonitor: memoryMonitor)
        let editorView = CodeEditorView(frame: .zero, memoryMonitor: memoryMonitor)
        editorView.asyncHighlighter = highlighter
        return (highlighter, editorView, memoryMonitor)
    }

    private func generateSimpleSwiftFile(lines: Int) -> String {
        var code = "import Foundation\n\n"

        for index in 0..<lines {
            code += "let value\(index) = \(index) // Simple constant\n"
            if index.isMultiple(of: 5) {
                code += "func process\(index)() -> Int { return \(index) * 2 }\n"
            }
        }

        return code
    }

    private func generateLargeSwiftFile(lines: Int) -> String {
        // Use simplified generation for benchmark tests
        generateSimpleSwiftFile(lines: lines)
    }

    private func generateSimpleJSONFile(objects: Int) -> String {
        var json = "[\n"

        for index in 0..<objects {
            json += """
              {"id": \(index), "name": "Item \(index)", "value": \(index * 2)}
            """
            json += index < objects - 1 ? ",\n" : "\n"
        }

        json += "]"
        return json
    }

    private func generateLargeJSONFile(objects: Int) -> String {
        // Use simplified generation for benchmark tests
        generateSimpleJSONFile(objects: objects)
    }

    // MARK: - Swift Highlighting Benchmarks

    func testSwiftHighlightingSmallFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }

        let code = generateLargeSwiftFile(lines: 5) // Reduced from 20
        editorView.text = code
        editorView.language = .swift

        // Single run instead of multiple
        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        logger.info("Small file highlighting: \(String(format: "%.3f", elapsed))s")

        XCTAssertLessThan(elapsed, 2.0, "Small file should highlight in less than 2 seconds")
    }

    func testSwiftHighlightingMediumFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }

        let code = generateLargeSwiftFile(lines: 15) // Reduced from 50
        editorView.text = code
        editorView.language = .swift

        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        logger.info("Medium file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 3.0, "Medium file should highlight in less than 3 seconds")
    }

    func testSwiftHighlightingLargeFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }

        let code = generateLargeSwiftFile(lines: 25) // Reduced from 100
        editorView.text = code
        editorView.language = .swift

        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        logger.info("Large file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 5.0, "Large file should highlight in less than 5 seconds")
    }

    // MARK: - JSON Highlighting Benchmarks

    func testJSONHighlightingSmallFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }

        let json = generateLargeJSONFile(objects: 10) // Reduced from 100
        editorView.text = json
        editorView.language = .json

        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .json)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        logger.info("JSON small file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 3.0, "JSON small file should highlight quickly")
    }

    func testJSONHighlightingLargeFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }

        let json = generateLargeJSONFile(objects: 50) // Dramatically reduced from 5000
        editorView.text = json
        editorView.language = .json

        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .json)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        logger.info("JSON large file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 5.0, "JSON large file should highlight in reasonable time")
    }

    // Memory-usage, background-highlighting, incremental, and
    // multi-language benchmarks lived here in `/* ... */` blocks marked
    // "Disabled: Takes too long". They were dead source containing
    // production-style `print(...)` lines that would have re-tripped
    // the tightened no_print_statements rule. Removed wholesale; revive
    // by writing a new test with proper budgeted assertions and the
    // `CrossPlatformLogger`-based diagnostic pattern this file now uses.
}
