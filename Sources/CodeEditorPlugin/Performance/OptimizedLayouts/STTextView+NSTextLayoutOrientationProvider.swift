//  Created by Marcin Krzyzanowski
//  https://github.com/krzyzanowskim/STTextView/blob/main/LICENSE.md

@preconcurrency import AppKit

extension STTextView: NSTextLayoutOrientationProvider {
    nonisolated public var layoutOrientation: NSLayoutManager.TextLayoutOrientation {
        MainActor.assumeIsolated {
            switch textLayoutManager.textLayoutOrientation(at: textLayoutManager.documentRange.location) {
            case .horizontal:
                return .horizontal
            case .vertical:
                return .vertical
            @unknown default:
                return textContainer.layoutOrientation
            }
        }
    }
}
