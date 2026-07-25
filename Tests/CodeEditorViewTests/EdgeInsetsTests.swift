//
//  EdgeInsetsTests.swift
//  CodeEditorKitTests
//
//  Created on 2025-06-27.
//

import CodeEditorCommon
@testable import CodeEditorView
import XCTest
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

final class EdgeInsetsTests: XCTestCase {
    // MARK: - Initialization Tests

    func testUniformInitialization() {
        let insets = EdgeInsets(uniform: 10)
        XCTAssertEqual(insets.top, 10)
        XCTAssertEqual(insets.left, 10)
        XCTAssertEqual(insets.bottom, 10)
        XCTAssertEqual(insets.right, 10)
    }

    func testHorizontalVerticalInitialization() {
        let insets = EdgeInsets(horizontal: 20, vertical: 10)
        XCTAssertEqual(insets.top, 10)
        XCTAssertEqual(insets.left, 20)
        XCTAssertEqual(insets.bottom, 10)
        XCTAssertEqual(insets.right, 20)
    }

    // MARK: - Platform Conversion Tests

    #if canImport(AppKit)
    func testNSEdgeInsetsConversion() {
        let nsInsets = NSEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        let edgeInsets = EdgeInsets(nsEdgeInsets: nsInsets)

        XCTAssertEqual(edgeInsets.top, 10)
        XCTAssertEqual(edgeInsets.left, 20)
        XCTAssertEqual(edgeInsets.bottom, 30)
        XCTAssertEqual(edgeInsets.right, 40)

        let convertedBack = edgeInsets.nsEdgeInsets
        XCTAssertEqual(convertedBack.top, nsInsets.top)
        XCTAssertEqual(convertedBack.left, nsInsets.left)
        XCTAssertEqual(convertedBack.bottom, nsInsets.bottom)
        XCTAssertEqual(convertedBack.right, nsInsets.right)
    }

    func testNSSizeConversion() {
        let size = NSSize(width: 15, height: 10)
        let edgeInsets = EdgeInsets(size: size)

        XCTAssertEqual(edgeInsets.top, 10)
        XCTAssertEqual(edgeInsets.left, 15)
        XCTAssertEqual(edgeInsets.bottom, 10)
        XCTAssertEqual(edgeInsets.right, 15)

        let convertedBack = edgeInsets.nsSize
        XCTAssertEqual(convertedBack.width, 15)
        XCTAssertEqual(convertedBack.height, 10)
    }
    #endif

    #if canImport(UIKit)
    func testUIEdgeInsetsConversion() {
        let uiInsets = UIEdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        let edgeInsets = EdgeInsets(uiEdgeInsets: uiInsets)

        XCTAssertEqual(edgeInsets.top, 10)
        XCTAssertEqual(edgeInsets.left, 20)
        XCTAssertEqual(edgeInsets.bottom, 30)
        XCTAssertEqual(edgeInsets.right, 40)

        let convertedBack = edgeInsets.uiEdgeInsets
        XCTAssertEqual(convertedBack.top, uiInsets.top)
        XCTAssertEqual(convertedBack.left, uiInsets.left)
        XCTAssertEqual(convertedBack.bottom, uiInsets.bottom)
        XCTAssertEqual(convertedBack.right, uiInsets.right)
    }
    #endif

    // MARK: - Calculation Tests

    func testTotalCalculations() {
        let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        XCTAssertEqual(insets.totalHorizontal, 60)
        XCTAssertEqual(insets.totalVertical, 40)
    }

    func testApplyToRect() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

        let insetRect = insets.apply(to: rect)
        XCTAssertEqual(insetRect.origin.x, 20)
        XCTAssertEqual(insetRect.origin.y, 10)
        XCTAssertEqual(insetRect.width, 40)
        XCTAssertEqual(insetRect.height, 60)
    }

    func testInvertedInsets() {
        let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        let inverted = insets.inverted()

        XCTAssertEqual(inverted.top, -10)
        XCTAssertEqual(inverted.left, -20)
        XCTAssertEqual(inverted.bottom, -30)
        XCTAssertEqual(inverted.right, -40)
    }

    func testAdditionOperator() {
        let insets1 = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
        let insets2 = EdgeInsets(top: 5, left: 10, bottom: 15, right: 20)

        let sum = insets1 + insets2
        XCTAssertEqual(sum.top, 15)
        XCTAssertEqual(sum.left, 30)
        XCTAssertEqual(sum.bottom, 45)
        XCTAssertEqual(sum.right, 60)
    }

    // MARK: - TextKit Integration Tests

    @MainActor
    func testCodeEditorViewUnifiedInsets() {
        let editorView = CodeEditorView(frame: .zero)
        let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

        editorView.setUnifiedTextContainerInsets(insets)
        let retrievedInsets = editorView.unifiedTextContainerInsets

        // Note: macOS uses only width/height for text container insets
        #if canImport(AppKit)
        XCTAssertEqual(retrievedInsets.left, insets.left)
        XCTAssertEqual(retrievedInsets.top, insets.top)
        #else
        XCTAssertEqual(retrievedInsets.top, insets.top)
        XCTAssertEqual(retrievedInsets.left, insets.left)
        XCTAssertEqual(retrievedInsets.bottom, insets.bottom)
        XCTAssertEqual(retrievedInsets.right, insets.right)
        #endif
    }

    #if canImport(AppKit)
    @MainActor
    func testNSTextViewExtension() {
        let textView = NSTextView(frame: .zero)
        let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

        textView.setTextContainerEdgeInsets(insets)
        let retrievedInsets = textView.textContainerEdgeInsets

        XCTAssertEqual(retrievedInsets.left, insets.left)
        XCTAssertEqual(retrievedInsets.top, insets.top)
    }
    #endif

    #if canImport(UIKit)
    @MainActor
    func testUITextViewExtension() {
        let textView = UITextView()
        let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

        textView.setTextContainerEdgeInsets(insets)
        let retrievedInsets = textView.textContainerEdgeInsets

        XCTAssertEqual(retrievedInsets.top, insets.top)
        XCTAssertEqual(retrievedInsets.left, insets.left)
        XCTAssertEqual(retrievedInsets.bottom, insets.bottom)
        XCTAssertEqual(retrievedInsets.right, insets.right)
    }
    #endif

    // MARK: - Performance Tests

    func testEdgeInsetsCreationPerformance() {
        measure(options: Self.standardMeasureOptions) {
            for _ in 0..<10_000 {
                _ = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)
            }
        }
    }

    func testEdgeInsetsConversionPerformance() {
        let edgeInsets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

        measure(options: Self.standardMeasureOptions) {
            for _ in 0..<10_000 {
                #if canImport(AppKit)
                _ = edgeInsets.nsEdgeInsets
                _ = edgeInsets.nsSize
                #else
                _ = edgeInsets.uiEdgeInsets
                #endif
            }
        }
    }

    func testEdgeInsetsApplyPerformance() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let insets = EdgeInsets(top: 10, left: 20, bottom: 30, right: 40)

        measure(options: Self.standardMeasureOptions) {
            for _ in 0..<10_000 {
                _ = insets.apply(to: rect)
            }
        }
    }

    deinit {
        // Cleanup
    }
}
