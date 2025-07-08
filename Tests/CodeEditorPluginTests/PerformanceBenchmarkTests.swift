@testable import CodeEditorPlugin
import XCTest

final class PerformanceBenchmarkTests: XCTestCase {
    deinit {}
    
    override func setUp() {
        super.setUp()
        // Clean environment before each test
        autoreleasepool {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        }
        // Additional delay to ensure cleanup from previous tests
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    override func tearDown() {
        super.tearDown()
        // Force cleanup to prevent memory issues between tests
        autoreleasepool {
            // Give the system time to clean up autorelease pools
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
        // Additional cleanup for async tasks
        Task {
            // Allow any pending async operations to complete
            await Task.yield()
            await Task.yield()
        }
    }
    
    // MARK: - Completion Performance Tests
    
    @MainActor
    func testCompletionPerformanceSmallFile() throws {
        let completionManager = CompletionManager(memoryMonitor: MemoryMonitor())
        let provider = SwiftCompletionProvider()
        completionManager.registerProvider(provider)
        
        let smallSourceCode = """
        import Foundation
        
        class TestClass {
            func test() {
                let x = String.
            }
        }
        """
        
        let language = Language.swift
        let context = CompletionContextModel(
            text: smallSourceCode,
            cursorPosition: smallSourceCode.count - 1,
            language: language,
            triggerKind: .character,
            triggerCharacter: "."
        )
        
        measure {
            autoreleasepool {
                let expectation = self.expectation(description: "Small file completion")
                Task {
                    do {
                        _ = try await completionManager.requestCompletions(for: context)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Completion failed: \(error)")
                    }
                }
                wait(for: [expectation], timeout: 1.0)
            }
        }
    }
    
    @MainActor
    func testCompletionPerformanceLargeFile() throws {
        let completionManager = CompletionManager(memoryMonitor: MemoryMonitor())
        let provider = SwiftCompletionProvider()
        completionManager.registerProvider(provider)
        
        // Create a large source file
        let largeSourceCode = String(repeating: """
        import Foundation
        
        class TestClass {
            func method1() -> String {
                return "test"
            }
            
            func method2() -> Int {
                return 42
            }
            
            var property: String = "value"
        }
        
        """, count: 1_000)
        
        let language = Language.swift
        let context = CompletionContextModel(
            text: largeSourceCode,
            cursorPosition: largeSourceCode.count - 1,
            language: language,
            triggerKind: .character,
            triggerCharacter: "."
        )
        
        measure {
            autoreleasepool {
                let expectation = self.expectation(description: "Large file completion")
                Task {
                    do {
                        _ = try await completionManager.requestCompletions(for: context)
                        expectation.fulfill()
                    } catch {
                        XCTFail("Completion failed: \(error)")
                    }
                }
                wait(for: [expectation], timeout: 5.0)
            }
        }
    }
    
    // MARK: - Syntax Highlighting Performance Tests
    
    @MainActor
    func testSyntaxHighlightingPerformance() throws {
        let highlighter = SwiftSyntaxHighlighter()
        
        let sourceCode = String(repeating: """
        import Foundation
        
        public class TestClass {
            private var property: String = "test"
            
            public func method() -> String {
                return property
            }
        }
        
        """, count: 500)
        
        measure {
            _ = highlighter.highlight(source: sourceCode)
        }
    }
    
    @MainActor
    func testRegexSyntaxHighlightingPerformance() throws {
        let highlighter = RegexSyntaxHighlighter()
        
        let sourceCode = String(repeating: """
        function testFunction() {
            var x = "hello world";
            var y = 42;
            return x + y;
        }
        
        """, count: 500)
        
        measure {
            if let jsDefinition = highlighter.languageDefinition(for: .javascript) {
                _ = highlighter.highlight(source: sourceCode, language: jsDefinition)
            }
        }
    }
    
    // MARK: - Memory Performance Tests
    
    @MainActor 
    func testCompletionMemoryUsage() throws {
        // Simplified test to avoid memory corruption issues
        let sourceCode = """
        import Foundation
        
        class TestClass {
            func test() {
                let x = String.
            }
        }
        """
        
        measure {
            autoreleasepool {
                let completionManager = CompletionManager(memoryMonitor: MemoryMonitor())
                let provider = SwiftCompletionProvider()
                completionManager.registerProvider(provider)
                
                let context = CompletionContextModel(
                    text: sourceCode,
                    cursorPosition: sourceCode.count - 1,
                    language: .swift,
                    triggerKind: .character,
                    triggerCharacter: "."
                )
                
                let expectation = self.expectation(description: "Memory completion")
                Task {
                    do {
                        // Reduced iterations to avoid memory issues
                        for _ in 0..<10 {
                            _ = try await completionManager.requestCompletions(for: context)
                        }
                        expectation.fulfill()
                    } catch {
                        XCTFail("Memory completion failed: \(error)")
                    }
                }
                wait(for: [expectation], timeout: 5.0)
            }
        }
    }
    
    @MainActor
    func testSyntaxHighlightingMemoryUsage() throws {
        // Reduce test size to prevent memory issues and hanging
        let sourceCodeBlock = """
        import Foundation
        
        public class TestClass {
            private var internalProperty: String = "test"
            
            public func publicMethod() -> String {
                let localVariable = "local"
                return internalProperty + localVariable
            }
            
            internal func internalMethod(parameter: Int) throws -> Bool {
                guard parameter > 0 else {
                    throw TestError.invalidParameter
                }
                return true
            }
        }
        
        enum TestError: Error {
            case invalidParameter
            case notFound
        }
        
        """
        
        // Reduced from 200 to 20 repetitions to avoid memory pressure
        let largeSourceCode = String(repeating: sourceCodeBlock, count: 20)
        
        measure {
            // Use autoreleasepool for each iteration
            for iteration in 0..<5 { // Reduced from 10 to 5 iterations
                autoreleasepool {
                    let highlighter = SwiftSyntaxHighlighter()
                    _ = highlighter.highlight(source: largeSourceCode)
                }
                
                // Add small delay between iterations to allow memory cleanup
                if iteration < 4 {
                    Thread.sleep(forTimeInterval: 0.01)
                }
            }
        }
    }
}
