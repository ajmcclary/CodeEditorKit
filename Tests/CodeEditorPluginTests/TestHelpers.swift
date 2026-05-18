#if canImport(AppKit)
import AppKit
@testable import CodeEditorSwiftUI
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
@testable import CodeEditorView
import Foundation

// MARK: - Mock TextLocation for Testing

public class MockTextLocation: NSObject, NSTextLocation {
    public let offset: Int

    public init(offset: Int) {
        self.offset = offset
        super.init()
    }

    public func compare(_ other: NSTextLocation) -> ComparisonResult {
        guard let otherMock = other as? Self else {
            return .orderedSame
        }

        if offset < otherMock.offset {
            return .orderedAscending
        } else if offset > otherMock.offset {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    deinit {
        // Cleanup
    }
}
