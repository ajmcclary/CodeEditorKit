#if canImport(AppKit)
import AppKit
#else
import Foundation
#endif
@testable import CodeEditorPlugin
import XCTest

final class TextRangeUtilitiesRegressionTests: XCTestCase {
    func testUTF16RangesHandleEmojiZWJAndComposedCharacters() throws {
        let family = "👨‍👩‍👧‍👦"
        let composed = "e\u{301}"
        let text = "a\(family) caf\(composed)\nnext 😀 word"

        let familyRange = NSRange(try XCTUnwrap(text.range(of: family)), in: text)
        let composedRange = NSRange(try XCTUnwrap(text.range(of: composed)), in: text)

        XCTAssertEqual(TextRangeUtilities.utf16Length(of: family), family.utf16.count)
        XCTAssertEqual(TextRangeUtilities.substring(inUTF16Range: familyRange, from: text), family)
        XCTAssertEqual(TextRangeUtilities.substring(inUTF16Range: composedRange, from: text), composed)
        XCTAssertTrue(TextRangeUtilities.isValid(familyRange, in: text))
        XCTAssertTrue(TextRangeUtilities.isValid(composedRange, in: text))
    }

    func testLineLookupAndFullDocumentRangesUseUTF16Offsets() {
        let firstLine = "a👨‍👩‍👧‍👦 cafe\u{301}"
        let secondLine = "next 😀 word"
        let text = "\(firstLine)\n\(secondLine)"
        let secondLineOffset = TextRangeUtilities.utf16Length(of: firstLine) + 1

        XCTAssertEqual(TextRangeUtilities.fullRange(in: text), NSRange(location: 0, length: text.utf16.count))
        XCTAssertEqual(TextRangeUtilities.lineNumber(for: secondLineOffset, in: text), 1)
        XCTAssertEqual(
            TextRangeUtilities.lineRange(containing: secondLineOffset + 3, in: text),
            NSRange(location: secondLineOffset, length: TextRangeUtilities.utf16Length(of: secondLine))
        )
        XCTAssertEqual(TextRangeUtilities.startOfLine(1, in: text), secondLineOffset)
    }

    func testWordRangeUsesUTF16Offsets() throws {
        let text = "😀 alpha_beta"
        let wordRange = NSRange(try XCTUnwrap(text.range(of: "alpha_beta")), in: text)
        let offsetInsideWord = wordRange.location + 5

        XCTAssertEqual(TextRangeUtilities.wordRange(at: offsetInsideWord, in: text), wordRange)
    }

    func testRangeMutationPoliciesForInsertionsAndDeletions() {
        let range = NSRange(location: 10, length: 10)
        let insertion = RangeMutation(range: NSRange(location: 15, length: 0), delta: 3)
        let deletion = RangeMutation(range: NSRange(location: 15, length: 4), delta: -4)

        XCTAssertEqual(
            RangeMutationEngine.transform(range, applying: insertion, policy: .invalidateOnOverlap),
            []
        )
        XCTAssertEqual(
            RangeMutationEngine.transform(range, applying: insertion, policy: .preserveSurvivingSegments),
            [NSRange(location: 10, length: 5), NSRange(location: 18, length: 5)]
        )
        XCTAssertEqual(
            RangeMutationEngine.transform(range, applying: insertion, policy: .expandForInsertions),
            [NSRange(location: 10, length: 13)]
        )

        XCTAssertEqual(
            RangeMutationEngine.transform(range, applying: deletion, policy: .invalidateOnOverlap),
            []
        )
        XCTAssertEqual(
            RangeMutationEngine.transform(range, applying: deletion, policy: .preserveSurvivingSegments),
            [NSRange(location: 10, length: 5), NSRange(location: 15, length: 1)]
        )
    }

    func testRangeMutationShiftsRangesAroundEdits() {
        let range = NSRange(location: 10, length: 5)

        XCTAssertEqual(
            RangeMutationEngine.transformSingle(
                range,
                applying: RangeMutation(range: NSRange(location: 2, length: 0), delta: 3),
                policy: .preserveSurvivingSegments
            ),
            NSRange(location: 13, length: 5)
        )
        XCTAssertEqual(
            RangeMutationEngine.transformSingle(
                range,
                applying: RangeMutation(range: NSRange(location: 2, length: 3), delta: -3),
                policy: .preserveSurvivingSegments
            ),
            NSRange(location: 7, length: 5)
        )
    }

    #if canImport(AppKit)
    func testTextKitRangeConversionRoundTripsUTF16Offsets() throws {
        let text = "a😀e\u{301} z"
        let contentStorage = NSTextContentStorage()
        contentStorage.textStorage = NSTextStorage(string: text)
        let layoutManager = NSTextLayoutManager()
        contentStorage.addTextLayoutManager(layoutManager)

        let utf16Range = NSRange(try XCTUnwrap(text.range(of: "😀e\u{301}")), in: text)
        let textRange = try XCTUnwrap(TextRangeUtilities.convert(utf16Range, in: contentStorage))

        XCTAssertEqual(TextRangeUtilities.convert(textRange, in: contentStorage), utf16Range)
    }
    #endif
}
