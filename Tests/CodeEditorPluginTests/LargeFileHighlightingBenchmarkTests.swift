@testable import CodeEditorPlugin
import Foundation
import XCTest

@MainActor
final class LargeFileHighlightingBenchmarkTests: XCTestCase {
    // MARK: - Test Helpers
    
    private func createTestComponents() -> (AsyncSyntaxHighlighter, CodeEditorView, MemoryMonitor) {
        let memoryMonitor = MemoryMonitor()
        let highlighter = AsyncSyntaxHighlighter(memoryMonitor: memoryMonitor)
        let editorView = CodeEditorView(frame: .zero, memoryMonitor: memoryMonitor)
        editorView.asyncHighlighter = highlighter
        return (highlighter, editorView, memoryMonitor)
    }
    
    private func generateLargeSwiftFile(lines: Int) -> String {
        var code = """
        //
        //  LargeGeneratedFile.swift
        //  Performance Test File
        //
        //  This file is auto-generated for performance testing purposes.
        //
        
        import Foundation
        import UIKit
        import SwiftUI
        
        // MARK: - Constants
        
        private let kDefaultTimeout: TimeInterval = 30.0
        private let kMaxRetries = 3
        private let kBatchSize = 100
        
        """
        
        // Add various Swift constructs
        for lineNumber in 0..<lines {
            let section = lineNumber % 10
            
            switch section {
            case 0: // Class definition
                code += """
                
                /// A sample class for item \(lineNumber)
                public class Item\(lineNumber): NSObject {
                    private let identifier = UUID()
                    private var name: String = "Item \(lineNumber)"
                    private var value: Double = \(Double(lineNumber) * 1.5)
                    
                    override init() {
                        super.init()
                        setupItem()
                    }
                    
                    private func setupItem() {
                        // Complex initialization logic
                        let result = calculateValue()
                        self.value = result
                    }
                    
                    private func calculateValue() -> Double {
                        return Double(arc4random_uniform(100)) * 1.5
                    }
                }
                
                """
                
            case 1: // Protocol definition
                code += """
                
                /// Protocol for handler \(lineNumber)
                protocol Handler\(lineNumber): AnyObject {
                    var identifier: String { get }
                    func handle(_ event: Event) async throws
                    func validate() -> Bool
                }
                
                """
                
            case 2: // Struct with computed properties
                code += """
                
                struct Configuration\(lineNumber) {
                    let id = UUID()
                    var threshold: Double = 0.8
                    var isEnabled: Bool = true
                    
                    var description: String {
                        "Config \(lineNumber): threshold=\\(threshold), enabled=\\(isEnabled)"
                    }
                    
                    var adjustedThreshold: Double {
                        isEnabled ? threshold * 1.2 : threshold
                    }
                }
                
                """
                
            case 3: // Enum with associated values
                code += """
                
                enum State\(lineNumber) {
                    case idle
                    case processing(progress: Double)
                    case completed(result: Result<Data, Error>)
                    case failed(Error)
                    
                    var isTerminal: Bool {
                        switch self {
                        case .completed, .failed:
                            return true

                        default:
                            return false
                        }
                    }
                }
                
                """
                
            case 4: // Function with multiple parameters
                code += """
                
                func processItem\(lineNumber)(
                    data: Data,
                    options: [String: Any] = [:],
                    completion: @escaping (Result<String, Error>) -> Void
                ) async throws -> ProcessingResult {
                    // Validate input
                    guard !data.isEmpty else {
                        throw ProcessingError.invalidInput
                    }
                    
                    // Process data
                    let processed = try await performProcessing(data)
                    
                    // Return result
                    return ProcessingResult(
                        id: UUID(),
                        data: processed,
                        timestamp: Date()
                    )
                }
                
                """
                
            case 5: // Extension with default implementation
                code += """
                
                extension Collection where Element == Item\(lineNumber) {
                    var totalValue: Double {
                        reduce(0) { $0 + $1.value }
                    }
                    
                    func filtered(by predicate: (Element) -> Bool) -> [Element] {
                        filter(predicate)
                    }
                    
                    func sorted(by keyPath: KeyPath<Element, Double>) -> [Element] {
                        sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
                    }
                }
                
                """
                
            case 6: // Async function with error handling
                code += """
                
                @MainActor
                func updateUI\(lineNumber)(with data: Data) async {
                    do {
                        let decoded = try JSONDecoder().decode(Model\(lineNumber).self, from: data)
                        
                        await MainActor.run {
                            self.titleLabel.text = decoded.title
                            self.subtitleLabel.text = decoded.subtitle
                            self.imageView.image = decoded.image
                        }
                        
                        logger.info("Successfully updated UI for item \(lineNumber)")
                    } catch {
                        logger.error("Failed to update UI: \\(error)")
                        showError(error)
                    }
                }
                
                """
                
            case 7: // Generic function
                code += """
                
                func transform\(lineNumber)<T: Codable, U: Codable>(
                    input: T,
                    using transformer: (T) throws -> U
                ) rethrows -> U {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    defer {
                        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                        logger.debug("Transform \(lineNumber) took \\(elapsed)s")
                    }
                    
                    return try transformer(input)
                }
                
                """
                
            case 8: // SwiftUI View
                code += """
                
                struct ItemView\(lineNumber): View {
                    @State private var isExpanded = false
                    @ObservedObject var model: ItemModel\(lineNumber)
                    
                    var body: some View {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(model.title)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            }
                            .onTapGesture {
                                withAnimation {
                                    isExpanded.toggle()
                                }
                            }
                            
                            if isExpanded {
                                Text(model.description)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                """
                
            default: // Comments and simple statements
                code += """
                
                // MARK: - Section \(lineNumber)
                
                // This is a comment explaining the purpose of this section
                // It may span multiple lines to test comment highlighting
                
                let constant\(lineNumber) = "String value \(lineNumber)"
                var variable\(lineNumber) = \(lineNumber * 2)
                
                if variable\(lineNumber) > 1000 {
                    print("Large value: \\(variable\(lineNumber))")
                } else {
                    print("Normal value: \\(variable\(lineNumber))")
                }
                
                """
            }
        }
        
        return code
    }
    
    private func generateLargeJSONFile(objects: Int) -> String {
        var json = "[\n"
        
        for objectIndex in 0..<objects {
            json += """
              {
                "id": "\(UUID())",
                "index": \(objectIndex),
                "name": "Object \(objectIndex),
                "active": \(objectIndex.isMultiple(of: 2) ? "true" : "false"),
                "tags": ["tag\(objectIndex)", "category\(objectIndex % 10)", "type\(objectIndex % 5)"],
                "metadata": {
                  "created": "2024-01-\(String(format: "%02d", (objectIndex % 28) + 1))T10:00:00Z",
                  "modified": "2024-02-\(String(format: "%02d", (objectIndex % 28) + 1))T15:30:00Z",
                  "version": \(objectIndex % 100 + 1),
                  "author": {
                    "id": "user\(objectIndex % 50)",
                    "name": "User \(objectIndex % 50)",
                    "email": "user\(objectIndex % 50)@example.com"
                  }
                },
                "values": {
                  "score": \(Double(objectIndex) * 1.5),
                  "rating": \(Double(objectIndex % 5) + 1),
                  "progress": \(Double(objectIndex % 101) / 100.0),
                  "threshold": \(0.5 + Double(objectIndex % 50) / 100.0)
                }
              }\(objectIndex < objects - 1 ? "," : "")\n
            """
        }
        
        json += "]"
        return json
    }
    
    // MARK: - Swift Highlighting Benchmarks
    
    func testSwiftHighlightingSmallFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let code = generateLargeSwiftFile(lines: 100) // ~10KB
        editorView.text = code
        editorView.language = .swift
        
        // Warm up
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        await highlighter.clearCache()
        
        // Measure multiple runs
        var times: [TimeInterval] = []
        for _ in 0..<5 {
            let start = CFAbsoluteTimeGetCurrent()
            await highlighter.highlightImmediately(for: editorView, language: .swift)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            times.append(elapsed)
            await highlighter.clearCache()
        }
        
        let averageTime = times.reduce(0, +) / Double(times.count)
        print("Small file highlighting average: \(String(format: "%.3f", averageTime))s")
        
        XCTAssertLessThan(averageTime, 1.0, "Small file should highlight in less than 1 second")
    }
    
    func testSwiftHighlightingMediumFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let code = generateLargeSwiftFile(lines: 1_000) // ~100KB
        editorView.text = code
        editorView.language = .swift
        
        // Single run for medium file
        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        print("Medium file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 5.0, "Medium file should highlight in less than 5 seconds")
    }
    
    func testSwiftHighlightingLargeFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let code = generateLargeSwiftFile(lines: 5_000) // ~500KB
        editorView.text = code
        editorView.language = .swift
        
        // Enable background highlighting for large files
        highlighter.enableBackgroundHighlighting = true
        highlighter.backgroundHighlightingThreshold = 100_000 // 100KB
        
        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        print("Large file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 10.0, "Large file should highlight in less than 10 seconds")
    }
    
    // MARK: - JSON Highlighting Benchmarks
    
    func testJSONHighlightingSmallFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let json = generateLargeJSONFile(objects: 100)
        editorView.text = json
        editorView.language = .json
        
        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .json)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        print("JSON small file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 2.0, "JSON small file should highlight quickly")
    }
    
    func testJSONHighlightingLargeFile() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let json = generateLargeJSONFile(objects: 5_000)
        editorView.text = json
        editorView.language = .json
        
        let start = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .json)
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        
        print("JSON large file highlighting: \(String(format: "%.3f", elapsed))s")
        XCTAssertLessThan(elapsed, 5.0, "JSON large file should highlight in reasonable time")
    }
    
    // MARK: - Memory Usage Tests
    
    func testMemoryUsageDuringLargeFileHighlighting() async throws {
        let (highlighter, editorView, memoryMonitor) = createTestComponents()
        defer { highlighter.cleanup() }
        
        // Reset memory statistics
        memoryMonitor.resetStatistics()
        
        // Generate a very large file
        let code = generateLargeSwiftFile(lines: 10_000) // ~1MB
        
        // Get initial memory
        let initialMemory = memoryMonitor.getCurrentMemoryUsage()
        
        // Set the text and highlight
        editorView.text = code
        editorView.language = .swift
        
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        
        // Wait for memory to settle
        try await Task.sleep(for: .seconds(1))
        
        // Get final memory
        let finalMemory = memoryMonitor.getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        // Get memory statistics
        let stats = memoryMonitor.getMemoryStatistics()
        
        // Verify memory usage is reasonable
        XCTAssertLessThan(memoryIncrease, 50.0, "Memory increase should be less than 50MB for 1MB file")
        XCTAssertGreaterThan(stats.peakUsageMB, initialMemory, "Peak usage should be recorded")
        
        // Log results for analysis
        print("""
        Memory Usage Results:
        - Initial: \(String(format: "%.1f", initialMemory))MB
        - Final: \(String(format: "%.1f", finalMemory))MB
        - Increase: \(String(format: "%.1f", memoryIncrease))MB
        - Peak: \(String(format: "%.1f", stats.peakUsageMB))MB
        """)
    }
    
    // MARK: - Background Highlighting Tests
    
    func testBackgroundHighlightingActivation() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        // Configure threshold
        highlighter.enableBackgroundHighlighting = true
        highlighter.backgroundHighlightingThreshold = 50_000 // 50KB
        
        // Test with file below threshold (should use regular highlighting)
        let smallCode = generateLargeSwiftFile(lines: 100) // ~10KB
        editorView.text = smallCode
        editorView.language = .swift
        
        let start1 = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let time1 = CFAbsoluteTimeGetCurrent() - start1
        
        // Test with file above threshold (should use background highlighting)
        let largeCode = generateLargeSwiftFile(lines: 1_000) // ~100KB
        editorView.text = largeCode
        
        let start2 = CFAbsoluteTimeGetCurrent()
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        let time2 = CFAbsoluteTimeGetCurrent() - start2
        
        // Get background highlighting statistics
        let bgStats = highlighter.backgroundStatistics
        
        // Verify background highlighting was used for large file
        XCTAssertGreaterThan(bgStats.totalRequests, 0, "Background highlighting should have been used")
        
        print("""
        Background Highlighting Results:
        - Small file time: \(String(format: "%.3f", time1))s
        - Large file time: \(String(format: "%.3f", time2))s
        - Background requests: \(bgStats.totalRequests)
        - Background completions: \(bgStats.completedRequests)
        """)
    }
    
    // MARK: - Incremental Highlighting Tests
    
    func testIncrementalHighlightingPerformance() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        // Start with a medium-sized file
        let initialCode = generateLargeSwiftFile(lines: 500)
        editorView.text = initialCode
        editorView.language = .swift
        
        // Initial highlighting
        await highlighter.highlightImmediately(for: editorView, language: .swift)
        
        // Measure incremental updates
        var times: [TimeInterval] = []
        for iteration in 0..<5 {
            let newCode = initialCode + "\n// Comment line \(iteration)"
            editorView.text = newCode
            
            let start = CFAbsoluteTimeGetCurrent()
            await highlighter.highlightImmediately(for: editorView, language: .swift)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            times.append(elapsed)
        }
        
        let averageTime = times.reduce(0, +) / Double(times.count)
        print("Incremental update average: \(String(format: "%.3f", averageTime))s")
        
        XCTAssertLessThan(averageTime, 0.5, "Incremental updates should be fast")
    }
    
    // MARK: - Multi-Language Performance
    
    func testMultiLanguageHighlightingComparison() async throws {
        let (highlighter, editorView, _) = createTestComponents()
        defer { highlighter.cleanup() }
        
        let languages: [(Language, String)] = [
            (.swift, generateLargeSwiftFile(lines: 500)),
            (.python, String(repeating: "def function_\(UUID())():\n    pass\n\n", count: 500)),
            (.javascript, String(repeating: "function test() { return Math.random(); }\n", count: 500)),
            (.json, generateLargeJSONFile(objects: 500)),
            (.markdown, String(repeating: "# Heading\n\nParagraph with **bold** and *italic*.\n\n", count: 500))
        ]
        
        var results: [(Language, TimeInterval)] = []
        
        for (language, code) in languages {
            editorView.text = code
            editorView.language = language
            
            let start = CFAbsoluteTimeGetCurrent()
            await highlighter.highlightImmediately(for: editorView, language: language)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            
            results.append((language, elapsed))
            
            // Clear cache between languages for fair comparison
            await highlighter.clearCache()
        }
        
        // Print comparison results
        print("\nLanguage Performance Comparison:")
        for (language, time) in results.sorted(by: { $0.1 < $1.1 }) {
            print("- \(language): \(String(format: "%.3f", time))s")
        }
        
        // Verify all languages completed in reasonable time
        for (language, time) in results {
            XCTAssertLessThan(time, 5.0, "\(language) highlighting should complete within 5 seconds")
        }
    }
}
