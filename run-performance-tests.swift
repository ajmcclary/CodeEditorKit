#!/usr/bin/env swift

import Foundation

// MARK: - Performance Test Runner for CodeEditorPlugin

struct TestResult {
    let testClass: String
    let testMethod: String
    let duration: TimeInterval
    let status: String
    let output: String
    let memoryUsage: String?
}

class PerformanceTestRunner {
    private var results: [TestResult] = []
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
    
    func run() {
        print("🚀 CodeEditorPlugin Performance Test Runner")
        print("==========================================")
        print("Started at: \(dateFormatter.string(from: Date()))\n")
        
        // Get all test classes
        let testClasses = getTestClasses()
        
        print("Found \(testClasses.count) test classes to analyze\n")
        
        // Run each test class
        for testClass in testClasses {
            runTestClass(testClass)
        }
        
        // Generate report
        generateReport()
    }
    
    private func getTestClasses() -> [String] {
        // Focus on performance-related test classes
        return [
            "ComprehensivePerformanceTests",
            "PerformanceBenchmarkTests",
            "PerformanceStressTests",
            "PerformanceRegressionTests",
            "LargeFilePerformanceTests",
            "SyntaxHighlightingPerformanceTests",
            "RegexHighlighterPerformanceTests",
            "LargeFileHighlightingBenchmarkTests",
            "TextKit2OptimizationTests",
            "AsyncSyntaxHighlighterCacheTests",
            "MemoryLeakTests",
            "LineIndexCacheTests",
            "ParagraphStyleCacheTests"
        ]
    }
    
    private func runTestClass(_ testClass: String) {
        print("📋 Running tests in \(testClass)...")
        
        // First, list all test methods in the class
        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        listProcess.arguments = ["test", "--list-tests", "--filter", "CodeEditorPluginTests.\(testClass)"]
        
        let listPipe = Pipe()
        listProcess.standardOutput = listPipe
        listProcess.standardError = Pipe()
        
        do {
            try listProcess.run()
            listProcess.waitUntilExit()
            
            let data = listPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Parse test methods
            let testMethods = output.components(separatedBy: .newlines)
                .filter { $0.contains(testClass) && $0.contains("/") }
                .compactMap { line -> String? in
                    let components = line.trimmingCharacters(in: .whitespaces).components(separatedBy: "/")
                    return components.last
                }
            
            // Run each test method individually
            for testMethod in testMethods {
                runTestMethod(testClass: testClass, testMethod: testMethod)
            }
            
        } catch {
            print("❌ Error listing tests for \(testClass): \(error)")
        }
        
        print("")
    }
    
    private func runTestMethod(testClass: String, testMethod: String) {
        print("  ▶️  \(testMethod)...", terminator: "")
        fflush(stdout)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Run the specific test
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
        process.arguments = [
            "test",
            "--filter", 
            "CodeEditorPluginTests.\(testClass)/\(testMethod)",
            "--parallel",
            "--enable-code-coverage"
        ]
        
        // Set environment variable to get memory info
        process.environment = ProcessInfo.processInfo.environment
        process.environment?["SWIFT_DETERMINISTIC_HASHING"] = "1"
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            let status = process.terminationStatus == 0 ? "✅ PASSED" : "❌ FAILED"
            let combinedOutput = output + "\n" + error
            
            // Extract memory usage if available
            let memoryUsage = extractMemoryUsage(from: combinedOutput)
            
            let result = TestResult(
                testClass: testClass,
                testMethod: testMethod,
                duration: duration,
                status: status,
                output: combinedOutput,
                memoryUsage: memoryUsage
            )
            
            results.append(result)
            
            print(" \(status) (\(String(format: "%.3f", duration))s)")
            
            // Print performance metrics if found
            if let metrics = extractPerformanceMetrics(from: combinedOutput) {
                print("    📊 Performance: \(metrics)")
            }
            
        } catch {
            print(" ❌ ERROR: \(error)")
            
            let result = TestResult(
                testClass: testClass,
                testMethod: testMethod,
                duration: CFAbsoluteTimeGetCurrent() - startTime,
                status: "❌ ERROR",
                output: "Error: \(error)",
                memoryUsage: nil
            )
            
            results.append(result)
        }
    }
    
    private func extractMemoryUsage(from output: String) -> String? {
        // Look for memory-related output patterns
        let patterns = [
            "Memory usage: ([0-9.]+) MB",
            "Peak memory: ([0-9.]+) MB",
            "Allocated: ([0-9.]+) MB"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               let range = Range(match.range(at: 1), in: output) {
                return String(output[range]) + " MB"
            }
        }
        
        return nil
    }
    
    private func extractPerformanceMetrics(from output: String) -> String? {
        // Look for XCTest performance metrics
        if output.contains("measured [Time") {
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("average:") && line.contains("seconds") {
                    return line.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Look for custom performance output
        let patterns = [
            "completed in ([0-9.]+)s",
            "Time: ([0-9.]+) seconds",
            "Duration: ([0-9.]+)s"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: output, range: NSRange(output.startIndex..., in: output)),
               let range = Range(match.range(at: 1), in: output) {
                return String(output[range]) + "s"
            }
        }
        
        return nil
    }
    
    private func generateReport() {
        print("\n📊 Performance Test Report")
        print("=========================\n")
        
        // Summary statistics
        let totalTests = results.count
        let passedTests = results.filter { $0.status.contains("PASSED") }.count
        let failedTests = results.filter { $0.status.contains("FAILED") }.count
        let errorTests = results.filter { $0.status.contains("ERROR") }.count
        let totalDuration = results.reduce(0) { $0 + $1.duration }
        
        print("Summary:")
        print("--------")
        print("Total tests run: \(totalTests)")
        print("Passed: \(passedTests) (\(String(format: "%.1f", Double(passedTests) / Double(totalTests) * 100))%)")
        print("Failed: \(failedTests)")
        print("Errors: \(errorTests)")
        print("Total duration: \(String(format: "%.2f", totalDuration))s")
        print("Average duration: \(String(format: "%.3f", totalDuration / Double(totalTests)))s\n")
        
        // Slowest tests
        print("⏱️  Slowest Tests (Top 10):")
        print("---------------------------")
        let slowestTests = results.sorted { $0.duration > $1.duration }.prefix(10)
        for (index, test) in slowestTests.enumerated() {
            print("\(index + 1). \(test.testClass).\(test.testMethod): \(String(format: "%.3f", test.duration))s")
        }
        
        // Failed tests details
        if failedTests > 0 || errorTests > 0 {
            print("\n❌ Failed/Error Tests:")
            print("---------------------")
            let problemTests = results.filter { !$0.status.contains("PASSED") }
            for test in problemTests {
                print("\n\(test.testClass).\(test.testMethod):")
                print("Status: \(test.status)")
                print("Duration: \(String(format: "%.3f", test.duration))s")
                
                // Print relevant error output
                let relevantOutput = test.output
                    .components(separatedBy: .newlines)
                    .filter { $0.contains("error") || $0.contains("failed") || $0.contains("XCTAssert") }
                    .prefix(5)
                    .joined(separator: "\n")
                
                if !relevantOutput.isEmpty {
                    print("Error details:")
                    print(relevantOutput)
                }
            }
        }
        
        // Performance insights
        print("\n💡 Performance Insights:")
        print("----------------------")
        
        // Group by test class
        let testsByClass = Dictionary(grouping: results) { $0.testClass }
        for (testClass, classResults) in testsByClass.sorted(by: { $0.key < $1.key }) {
            let avgDuration = classResults.reduce(0) { $0 + $1.duration } / Double(classResults.count)
            print("\(testClass): avg \(String(format: "%.3f", avgDuration))s per test")
        }
        
        // Save detailed results
        saveDetailedResults()
        
        print("\n✅ Performance analysis complete!")
        print("Detailed results saved to: performance-test-results.json")
    }
    
    private func saveDetailedResults() {
        let resultsData = results.map { result in
            [
                "testClass": result.testClass,
                "testMethod": result.testMethod,
                "duration": result.duration,
                "status": result.status,
                "memoryUsage": result.memoryUsage ?? "N/A",
                "timestamp": dateFormatter.string(from: Date())
            ] as [String: Any]
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: resultsData, options: .prettyPrinted)
            try jsonData.write(to: URL(fileURLWithPath: "performance-test-results.json"))
        } catch {
            print("Error saving results: \(error)")
        }
    }
}

// Run the performance test runner
let runner = PerformanceTestRunner()
runner.run()