#if canImport(AppKit)
@testable import CodeEditorSample
import Foundation
import Testing

@Suite("WorkspaceIgnoreRules")
struct WorkspaceIgnoreRulesTests {
    @Test("hides dotfiles")
    func hidesDotfiles() {
        #expect(WorkspaceIgnoreRules.shouldHide(name: ".git"))
        #expect(WorkspaceIgnoreRules.shouldHide(name: ".DS_Store"))
        #expect(WorkspaceIgnoreRules.shouldHide(name: ".env"))
    }

    @Test("hides common build directories")
    func hidesBuildDirs() {
        for name in [".build", ".swiftpm", "node_modules", "DerivedData", "__Snapshots__"] {
            #expect(WorkspaceIgnoreRules.shouldHide(name: name), "expected \(name) hidden")
        }
    }

    @Test("does not hide ordinary file names")
    func keepsOrdinaryFiles() {
        for name in ["Package.swift", "README.md", "Sources", "Tests"] {
            #expect(!WorkspaceIgnoreRules.shouldHide(name: name), "expected \(name) visible")
        }
    }

    @Test("recognizes binary extensions for search indexing")
    func skipsBinaryExtensions() {
        #expect(WorkspaceIgnoreRules.isBinaryExtension("png"))
        #expect(WorkspaceIgnoreRules.isBinaryExtension("PNG"))
        #expect(WorkspaceIgnoreRules.isBinaryExtension("jpg"))
        #expect(!WorkspaceIgnoreRules.isBinaryExtension("swift"))
        #expect(!WorkspaceIgnoreRules.isBinaryExtension(""))
    }
}
#endif
