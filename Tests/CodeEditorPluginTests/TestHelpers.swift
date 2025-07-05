#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import CodeEditorPlugin
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
