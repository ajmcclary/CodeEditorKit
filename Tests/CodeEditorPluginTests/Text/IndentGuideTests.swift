@testable import CodeEditorPlugin
@testable import CodeEditorSwiftUI
import CodeEditorTextModel
@testable import CodeEditorView
import Foundation
import Testing

@Suite("Indent guides")
struct IndentGuideTests {
    @Test("Geometry: 8-space leading whitespace at tabWidth=4 yields columns at 1")
    func geometryEightSpaces() {
        let lineText = "        let x = 1"
        let columns = IndentGuideGeometry.indentColumns(
            forLeadingWhitespace: leadingWhitespace(of: lineText),
            tabWidth: 4
        )
        #expect(columns == [1])
    }

    @Test("Geometry: tabs count as tabWidth spaces")
    func geometryTabsCount() {
        let lineText = "\t\tlet x = 1"
        let columns = IndentGuideGeometry.indentColumns(
            forLeadingWhitespace: leadingWhitespace(of: lineText),
            tabWidth: 4
        )
        #expect(columns == [1])
    }

    @Test("Geometry: depth 4 yields columns 1, 2, 3")
    func geometryDeepIndent() {
        let lineText = String(repeating: " ", count: 16) + "x"
        let columns = IndentGuideGeometry.indentColumns(
            forLeadingWhitespace: leadingWhitespace(of: lineText),
            tabWidth: 4
        )
        #expect(columns == [1, 2, 3])
    }

    @Test("Disabled when tabWidth is zero")
    func disabledAtTabWidthZero() {
        let lineText = "        let x = 1"
        let columns = IndentGuideGeometry.indentColumns(
            forLeadingWhitespace: leadingWhitespace(of: lineText),
            tabWidth: 0
        )
        #expect(columns.isEmpty)
    }

    @Test("Geometry: depth < 2 produces no guides")
    func geometryShallowIndent() {
        let lineText = "    x"
        let columns = IndentGuideGeometry.indentColumns(
            forLeadingWhitespace: leadingWhitespace(of: lineText),
            tabWidth: 4
        )
        #expect(columns.isEmpty)
    }

    @Test("Blank-line continuity: blank line inherits prior non-blank depth")
    func blankLineContinuity() {
        let priorDepth = 3
        let blankDepth = IndentGuideGeometry.effectiveDepth(
            forBlankLineWithPriorDepth: priorDepth
        )
        #expect(blankDepth == priorDepth)
    }

    private func leadingWhitespace(of line: String) -> String {
        var result = ""
        for ch in line {
            if ch == " " || ch == "\t" { result.append(ch) } else { break }
        }
        return result
    }
}
