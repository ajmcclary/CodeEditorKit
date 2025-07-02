@testable import CodeEditorPlugin
import XCTest

final class PerformanceBenchmarkTests: XCTestCase {
    deinit {}
    // MARK: - Completion Performance Tests
    
    @MainActor
    func testCompletionPerformanceSmallFile() throws {
        let completionManager = CompletionManager()
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
    
    @MainActor
    func testCompletionPerformanceLargeFile() throws {
        let completionManager = CompletionManager()
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
        let completionManager = CompletionManager()
        let provider = SwiftCompletionProvider()
        completionManager.registerProvider(provider)
        
        let largeSourceCode = String(repeating: """
        import Foundation
        
        class LargeClass {
            var property1: String = ""
            var property2: Int = 0
            var property3: [String] = []
            
            func method1() -> String {
                return "test"
            }
            
            func method2(param: String) -> Int {
                return param.count
            }
        }
        
        """, count: 100)
        
        let language = Language.swift
        let context = CompletionContextModel(
            text: largeSourceCode,
            cursorPosition: largeSourceCode.count - 1,
            language: language,
            triggerKind: .character,
            triggerCharacter: "."
        )
        
        measure {
            let expectation = self.expectation(description: "Memory completion")
            Task {
                do {
                    for _ in 0..<50 {
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
    
    @MainActor
    func testSyntaxHighlightingMemoryUsage() throws {
        let highlighter = SwiftSyntaxHighlighter()
        
        let veryLargeSourceCode = String(repeating: """
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
        
        """, count: 200)
        
        measure {
            for _ in 0..<10 {
                _ = highlighter.highlight(source: veryLargeSourceCode)
            }
        }
    }
}
