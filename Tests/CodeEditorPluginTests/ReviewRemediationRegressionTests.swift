import CodeEditorAnnotations
import CodeEditorCommon
import CodeEditorLanguages
@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
import CodeEditorTextModel
@testable import CodeEditorView
import XCTest

@MainActor
final class ReviewRemediationRegressionTests: XCTestCase {
    func testPrivateLayoutSelectorIsNotPresentInTextLayoutFragmentSource() throws {
        let source = try String(
            contentsOfFile: sourcePath("Sources/CodeEditorTextModel/TextLayoutFragment.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains("perform(Selector"))
        XCTAssertFalse(source.contains("\"l\" + \"oya\""))
    }

    func testGrammarBackedParserPublicFlagIsNotEnabledByPackage() throws {
        let packageSource = try String(contentsOfFile: sourcePath("Package.swift"), encoding: .utf8)

        XCTAssertFalse(packageSource.contains("CAN_IMPORT_TREE_SITTER"))
        XCTAssertFalse(packageSource.contains("useGrammarBackedHighlighting"))
    }

    func testDeletedAuditAbstractionsHaveNoSourceOrTestReferences() throws {
        let deletedLanguageProviders = [
            "C", "CSS", "Go", "HTML", "JSON", "Java", "JavaScript", "Markdown", "PHP",
            "Python", "Ruby", "Rust", "SQL", "Shell", "Swift", "TypeScript", "XML", "YAML"
        ].map { $0 + "CompletionProvider" }

        let deletedNames = deletedLanguageProviders + [
            "Base" + "CompletionProvider",
            "Range" + "Utilities",
            "Text" + "ProcessingPipeline",
            "Async" + "TextProcessor",
            "Business" + "LogicServiceRegistry",
            "Optimized" + "SymbolNavigator",
            "Tree" + "SitterSymbolProvider",
            "Tree" + "SitterRangeHighlightProvider",
            "Tree" + "SitterFoldProvider",
            "RegexBacked" + "TreeSitterParser"
        ]

        let files = try sourceFiles(relativeRoots: ["Sources/CodeEditorPlugin", "Tests"], extensions: ["swift"])
        for (path, contents) in files {
            for name in deletedNames {
                XCTAssertFalse(containsStandaloneIdentifier(name, in: contents), "\(name) should not be referenced in \(path)")
            }
        }
    }

    func testTextKitAndParserNamingStaysImplementationAccurate() throws {
        let staleTerms = [
            "prefer" + "TextKit2",
            "use" + "TextKit2",
            "supports" + "TextKit2",
            "Text" + "Kit1 fallback",
            "Text" + "Kit1 fallbacks",
            "Tree-sitter-shaped",
            "tree-sitter-shaped",
            "Sources/CodeEditorPlugin/SyntaxHighlighting/" + "TreeSitter"
        ]

        let files = try sourceFiles(
            relativeRoots: ["Sources/CodeEditorPlugin", "Tests", "docs"],
            extensions: ["swift", "md"],
            excludedPathComponents: ["superpowers"]
        )
        for (path, contents) in files {
            for term in staleTerms {
                XCTAssertFalse(contents.contains(term), "\(term) should not be referenced in \(path)")
            }
        }
    }

    func testEditorConfigurationDoesNotContainRuntimeDependencySlots() throws {
        let configurationSource = try String(
            contentsOfFile: sourcePath("Sources/CodeEditorConfiguration/EditorConfiguration.swift"),
            encoding: .utf8
        )
        let runtimeSlots = [
            "eventSystem",
            "actorCoordinator",
            "workspaceRoot",
            "memoryMonitor",
            "languageMetadataRegistry",
            "platformServiceLayer",
            "platformDeviceService"
        ]

        for slot in runtimeSlots {
            XCTAssertFalse(configurationSource.contains(slot), "EditorConfiguration should not contain \(slot)")
        }
    }

    func testAnnotationAndCodeEditorErrorAreSendable() {
        assertSendable(Annotation(range: NSRange(location: 0, length: 1), content: "note"))
        assertSendable(CodeEditorError.serviceUnavailable("CodeFoldingEngine"))
        assertSendable(CodeEditorError.completionRequestFailed("cancelled"))
    }

    func testConfigurationAssignmentRejectsInvalidConfiguration() {
        let textView = CodeEditorView(frame: .zero)
        let originalConfiguration = textView.configuration

        var invalidConfiguration = originalConfiguration
        invalidConfiguration.display.fontSize = -1

        textView.configuration = invalidConfiguration

        XCTAssertEqual(textView.configuration, originalConfiguration)
        XCTAssertEqual(textView.configuration.display.fontSize, originalConfiguration.display.fontSize)
    }

    func testConfigurationApplyThrowsBeforeMutatingView() {
        let textView = CodeEditorView(frame: .zero)
        let originalConfiguration = textView.configuration

        var invalidConfiguration = originalConfiguration
        invalidConfiguration.layout.tabWidth = 0

        XCTAssertThrowsError(try textView.apply(configuration: invalidConfiguration))
        XCTAssertEqual(textView.configuration, originalConfiguration)
    }

    func testEmptyLineGeometryStoreRangeQueriesReturnEmptyCollections() {
        let store = LineGeometryStore()

        XCTAssertTrue(store.lineGeometries(in: NSRange(location: 0, length: 0)).isEmpty)
        XCTAssertTrue(store.lineGeometries(inYRange: 0...100).isEmpty)
        XCTAssertNil(store.visibleLineRange(for: CGRect(x: 0, y: 0, width: 100, height: 100)))
    }

    func testCodeFoldingCoordinatorServiceReportsMissingEngineInsteadOfCrashing() {
        let registry = EditorFeatureRuntimeDependencies()

        XCTAssertThrowsError(try registry.codeFoldingCoordinatorService()) { error in
            guard case CodeEditorError.serviceUnavailable(let serviceName) = error else {
                return XCTFail("Expected serviceUnavailable, got \(error)")
            }
            XCTAssertEqual(serviceName, "CodeFoldingEngine")
        }
    }

    private func assertSendable<T: Sendable>(_: T) {}

    private func sourcePath(_ relativePath: String) -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        return testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
            .path
    }

    private func sourceFiles(
        relativeRoots: [String],
        extensions allowedExtensions: Set<String>,
        excludedPathComponents: Set<String> = []
    ) throws -> [(path: String, contents: String)] {
        let fileManager = FileManager.default
        var files: [(path: String, contents: String)] = []
        let currentTestPath = URL(fileURLWithPath: #filePath).standardizedFileURL.path

        for relativeRoot in relativeRoots {
            let rootURL = URL(fileURLWithPath: sourcePath(relativeRoot))
            guard let enumerator = fileManager.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                let standardizedPath = fileURL.standardizedFileURL.path
                guard standardizedPath != currentTestPath else { continue }
                guard allowedExtensions.contains(fileURL.pathExtension) else { continue }
                guard excludedPathComponents.isDisjoint(with: Set(fileURL.pathComponents)) else { continue }

                let values = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }

                files.append((
                    path: standardizedPath,
                    contents: try String(contentsOf: fileURL, encoding: .utf8)
                ))
            }
        }

        return files
    }

    private func containsStandaloneIdentifier(_ identifier: String, in contents: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: identifier)
        let pattern = #"(?<![A-Za-z0-9_])"# + escaped + #"(?![A-Za-z0-9_])"#
        return contents.range(of: pattern, options: .regularExpression) != nil
    }
}
