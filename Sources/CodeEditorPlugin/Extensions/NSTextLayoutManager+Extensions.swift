#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension NSTextLayoutManager {
    /// Extra line layout fragment.
    ///
    /// Only valid when ``state`` greater than NSTextLayoutFragment.State.estimatedUsageBounds
    @nonobjc
    func extraLineTextLayoutFragment() -> NSTextLayoutFragment? {
        var extraTextLayoutFragment: NSTextLayoutFragment?
        enumerateTextLayoutFragments(from: nil, options: .reverse) { textLayoutFragment in
            if textLayoutFragment.state.rawValue > NSTextLayoutFragment.State.estimatedUsageBounds.rawValue,
               textLayoutFragment.isExtraLineFragment {
                extraTextLayoutFragment = textLayoutFragment
            }
            return false
        }
        return extraTextLayoutFragment
    }

    /// Extra line fragment.
    ///
    /// Only valid when ``state`` greater than NSTextLayoutFragment.State.estimatedUsageBounds
    @nonobjc
    func extraLineTextLineFragment() -> NSTextLineFragment? {
        if let textLayoutFragment = extraLineTextLayoutFragment() {
            let textLineFragments = textLayoutFragment.textLineFragments
            if textLineFragments.count > 1, let lastTextLineFragment = textLineFragments.last,
               lastTextLineFragment.isExtraLineFragment {
                return lastTextLineFragment
            }
        }
        return nil
    }
}

extension NSTextLayoutManager {
    func textLineFragment(at location: NSTextLocation) -> NSTextLineFragment? {
        textLayoutFragment(for: location)?.textLineFragment(at: location)
    }

    func textLineFragment(at point: CGPoint) -> NSTextLineFragment? {
        textLayoutFragment(for: point)?.textLineFragment(at: point)
    }
}

extension NSTextLayoutManager {
    /// Returns a location of text produced by a tap or click at the point you specify.
    /// - Parameters:
    ///   - point: A CGPoint that represents the location of the tap or click.
    ///   - containerLocation: A NSTextLocation that describes the contasiner location.
    /// - Returns: A location
    func location(
        interactingAt point: CGPoint,
        inContainerAt containerLocation: NSTextLocation
    ) -> NSTextLocation? {
        guard let lineFragmentRange = lineFragmentRange(for: point, inContainerAt: containerLocation) else {
            return nil
        }

        var distance = CGFloat.infinity
        var caretLocation: NSTextLocation?
        enumerateCaretOffsetsInLineFragment(
            at: lineFragmentRange.location
        ) { caretOffset, location, leadingEdge, stop in
            let localDistance = abs(caretOffset - point.x)
            if leadingEdge {
                if localDistance < distance {
                    distance = localDistance
                    caretLocation = location
                } else if localDistance > distance {
                    stop.pointee = true
                }
            }
        }

        return caretLocation
    }
}

extension NSTextLayoutManager {
    /// Typographic bounds of the range.
    /// - Parameter textRange: The range.
    /// - Returns: Typographic bounds of the range.
    ///
    /// Returns a union of each segment frame in the range, which may be larger than the area needed to layout the range.
    func typographicBounds(in textRange: NSTextRange) -> CGRect? {
        textSegmentFrame(in: textRange, type: .standard, options: [.upstreamAffinity, .rangeNotRequired])
    }

    ///  A text segment is both logically and visually contiguous portion of the text content inside a line fragment.
    func textSegmentFrame(
        at location: NSTextLocation,
        type: NSTextLayoutManager.SegmentType,
        options: SegmentOptions = [.upstreamAffinity]
    ) -> CGRect? {
        textSegmentFrame(in: NSTextRange(location: location), type: type, options: options)
    }

    /// A text segment is both logically and visually contiguous portion of the text content inside a line fragment.
    /// Text segment is a logically and visually contiguous portion of the text content inside a line fragment that you specify with a single text range.
    /// The framework enumerates the segments visually from left to right.
    func textSegmentFrame(
        in textRange: NSTextRange,
        type: NSTextLayoutManager.SegmentType,
        options: SegmentOptions = [.upstreamAffinity, .rangeNotRequired]
    ) -> CGRect? {
        var result: CGRect?
        // .upstreamAffinity: When specified, the segment is placed based on the upstream affinity for an empty range.
        //
        // In the context of text editing, upstream affinity means that the selection is biased towards the preceding or earlier portion of the text,
        // while downstream affinity means that the selection is biased towards the following or later portion of the text. The affinity helps determine
        // the behavior of the text selection when the text is modified or manipulated.

        // FB15131180: Extra line fragment frame is not correct, that affects enumerateTextSegments as well.
        enumerateTextSegments(in: textRange, type: type, options: options) { _, textSegmentFrame, _, _ -> Bool in
            result = result?.union(textSegmentFrame) ?? textSegmentFrame
            return true
        }
        return result
    }

    /// Enumerates text segments in the text range you provide.
    func textSegmentFrames(
        in textRange: NSTextRange,
        type: NSTextLayoutManager.SegmentType,
        options: SegmentOptions = [.upstreamAffinity, .rangeNotRequired]
    ) -> [CGRect] {
        var result: [CGRect] = []
        enumerateTextSegments(in: textRange, type: type, options: options) { _, textSegmentFrame, _, _ -> Bool in
            result.append(textSegmentFrame)
            return true
        }
        return result
    }
}

extension NSTextLayoutManager {
    /// Enumerates the text layout fragments in the specified range.
    ///
    /// - Parameters:
    ///   - range: The location where you start the enumeration.
    ///   - options: One or more of the available NSTextLayoutFragmentEnumerationOptions
    ///   - block: A closure you provide that determines if the enumeration finishes early.
    /// - Returns: An NSTextLocation, or nil. If the method enumerates at least one fragment, it returns the edge of the enumerated range.
    @discardableResult
    func enumerateTextLayoutFragments(
        in range: NSTextRange,
        options: NSTextLayoutFragment.EnumerationOptions = [],
        using block: (NSTextLayoutFragment) -> Bool
    ) -> NSTextLocation? {
        enumerateTextLayoutFragments(from: range.location, options: options) { layoutFragment in
            let shouldContinue = layoutFragment.rangeInElement.location <= range.endLocation
            if !shouldContinue {
                return false
            }

            return shouldContinue && block(layoutFragment)
        }
    }
}

extension NSTextLayoutManager {
    var insertionPointLocations: [NSTextLocation] {
        insertionPointSelections.flatMap(\.textRanges).map(\.location).sorted { $0 < $1 }
    }

    var insertionPointSelections: [NSTextSelection] {
        textSelections.filter(kTextSelectionInsertionPointFilter)
    }
}

private let kTextSelectionInsertionPointFilter: @Sendable (NSTextSelection) -> Bool = { textSelection in
    !textSelection.isLogical && textSelection.textRanges.contains(where: \.isEmpty)
}

// MARK: - TextSelectionRangesOptions

package struct TextSelectionRangesOptions: OptionSet {
    package let rawValue: UInt
    package static let withoutInsertionPoints = Self(rawValue: 1 << 0)
    package static let withInsertionPoints = Self(rawValue: 1 << 1)

    package init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}

extension NSTextLayoutManager {
    /// A String in range
    /// - Parameter range: Text range
    /// - Returns: String in the range
    func substring(in range: NSTextRange) -> String {
        guard !range.isEmpty else {
            return ""
        }
        var output = String()
        if let textContentManager {
            output.reserveCapacity(range.length(in: textContentManager))
        } else {
            output.reserveCapacity(128)
        }
        enumerateSubstrings(
            from: range.location,
            options: .byComposedCharacterSequences
        ) { substring, substringRange, _, stop in
            let shouldContinue = substringRange.location <= range.endLocation
            if !shouldContinue {
                stop.pointee = true
                return
            }

            if let substring {
                output += substring
            }
        }
        return output
    }

    func textSelectionsRanges(_ options: TextSelectionRangesOptions = .withInsertionPoints) -> [NSTextRange] {
        if options.contains(.withoutInsertionPoints) {
            textSelections.flatMap(\.textRanges).filter { !$0.isEmpty }.sorted { $0.location < $1.location }
        } else {
            textSelections.flatMap(\.textRanges).sorted { $0.location < $1.location }
        }
    }

    func textSelectionsString() -> String? {
        textSelectionsRanges(.withoutInsertionPoints)
            .compactMap { textRange in
                substring(in: textRange)
            }
            .joined(separator: "\n")
    }

    func textSelectionsAttributedString() -> NSAttributedString? {
        textAttributedString(in: textSelectionsRanges(.withoutInsertionPoints))
    }

    func textAttributedString(at location: any NSTextLocation) -> NSAttributedString? {
        if let range = NSTextRange(location: location, end: self.location(location, offsetBy: 1)), !range.isEmpty {
            return textAttributedString(in: range)
        }

        return nil
    }

    func textAttributedString(in textRange: NSTextRange) -> NSAttributedString? {
        textAttributedString(in: [textRange])
    }

    func textAttributedString(in textRanges: [NSTextRange]) -> NSAttributedString? {
        let attributedString = textRanges.reduce(NSMutableAttributedString()) { partialResult, range in
            if let attributedString = textContentManager?.attributedString(in: range) {
                if partialResult.length != 0 {
                    partialResult.append(NSAttributedString(string: "\n"))
                }
                partialResult.append(attributedString)
            }
            return partialResult
        }

        if attributedString.length == 0 {
            return nil
        }
        return attributedString
    }
}

// MARK: - Enhanced TextKit 2 Viewport Optimization

@available(macOS 12.0, iOS 15.0, *)
extension NSTextLayoutManager {
    /// Enumerates line fragments for a given rectangle with viewport optimization
    public func enumerateLineFragments(for rect: CGRect, strictIntersection: Bool = true, options: NSTextLayoutFragment.EnumerationOptions = [], block: (CGRect, NSRange, inout Bool) -> Void) {
        guard let textContentManager else { return }

        // Viewport optimization - if viewportRange is available, use it as starting point
        let viewportRange = textViewportLayoutController.viewportRange ?? documentRange
        let viewportBounds = textViewportLayoutController.viewportBounds
        let reversed = options.contains(.reverse)

        var location: NSTextLocation

        if reversed {
            location = documentRange.endLocation

            if rect.maxY <= viewportBounds.maxY {
                location = viewportRange.endLocation
            }

            if rect.maxY <= viewportBounds.minY {
                location = viewportRange.location
            }
        } else {
            location = documentRange.location

            if rect.minY >= viewportBounds.minY {
                location = viewportRange.location
            }

            if rect.minY >= viewportBounds.maxY {
                location = viewportRange.endLocation
            }
        }

        enumerateTextLayoutFragments(from: location, options: options) { fragment in
            let frame = fragment.layoutFragmentFrame

            if frame.intersects(rect) == false {
                // Check if we haven't reached the target rectangle yet
                if reversed {
                    return frame.minY < rect.minY
                } else {
                    return frame.maxY < rect.maxY
                }
            }

            var keepGoing: Bool = true

            if strictIntersection {
                fragment.enumerateLineFragments(with: textContentManager, intersecting: rect) { _, lineFrame, elementRange in
                    block(lineFrame, elementRange, &keepGoing)
                    return keepGoing
                }
            } else {
                fragment.enumerateLineFragments(with: textContentManager) { _, lineFrame, elementRange, _ in
                    block(lineFrame, elementRange, &keepGoing)
                    return keepGoing
                }
            }

            return keepGoing
        }
    }

    /// Enumerates line fragments within a specific range
    public func enumerateLineFragments(
        in range: NSRange,
        options: NSTextLayoutFragment.EnumerationOptions = [],
        block: (CGRect, NSRange, inout Bool) -> Void
    ) {
        guard let textContentManager else { return }

        guard
            let start = textContentManager.location(documentRange.location, offsetBy: range.location),
            let end = textContentManager.location(start, offsetBy: range.length)
        else {
            return
        }

        let reverse = options.contains(.reverse)

        enumerateTextLayoutFragments(from: start, options: options) { fragment in
            let fragmentRange = fragment.rangeInElement

            var stop = false

            fragment.enumerateLineFragments(
                in: range,
                with: textContentManager,
                reverse: reverse
            ) { _, frame, elementRange, _ in
                block(frame, elementRange, &stop)
                return stop == false
            }

            let beforeEnd = fragmentRange.endLocation.compare(end) == .orderedAscending

            return stop == false && beforeEnd
        }
    }

    /// Enumerates line fragments starting from a specific index
    public func enumerateLineFragments(
        from index: Int,
        options: NSTextLayoutFragment.EnumerationOptions = [],
        block: (CGRect, NSRange, inout Bool) -> Void
    ) {
        guard let textContentManager else { return }

        let docStart = documentRange.location
        guard let start = textContentManager.location(docStart, offsetBy: index) else {
            return
        }

        let reverse = options.contains(.reverse)

        enumerateTextLayoutFragments(from: start, options: options) { fragment in
            var stop = false

            fragment.enumerateLineFragments(with: textContentManager, reverse: reverse) { _, frame, elementRange, _ in
                // Verify that we're within the requested range
                if reverse {
                    if elementRange.lowerBound > index {
                        return true
                    }
                } else {
                    if elementRange.upperBound < index {
                        return true
                    }
                }

                block(frame, elementRange, &stop)
                return stop == false
            }

            return stop == false
        }
    }

    /// Returns the bounding rectangle for a given range
    public func boundingRect(for range: NSRange) -> CGRect? {
        var rect: CGRect?

        enumerateTextLineFragments(in: range, options: [.ensuresLayout, .ensuresExtraLineFragment]) { fragment, lineFragment, lineRect, lineRange, offset in
            // Limit the check to what overlaps with the target range
            let startIndex = max(range.lowerBound, lineRange.lowerBound) - lineRange.lowerBound
            let endIndex = min(range.upperBound, lineRange.upperBound) - lineRange.lowerBound

            // These positions are relative to the lineRange's location within fragment
            let startPos = lineFragment.locationForCharacter(at: startIndex + offset)
            let endPos = lineFragment.locationForCharacter(at: endIndex + offset)
            let originPadding = fragment.layoutFragmentFrame.origin.x

            let bounds = CGRect(
                x: startPos.x + originPadding,
                y: lineRect.origin.y,
                width: (endPos.x - startPos.x),
                height: lineRect.height
            )

            rect = rect?.union(bounds) ?? bounds
            return true
        }

        return rect
    }

    /// Private helper to get the last text layout fragment
    private func lastTextLayoutFragment() -> NSTextLayoutFragment? {
        guard let textContentManager else { return nil }

        if let fragment = textLayoutFragment(for: documentRange.endLocation) {
            return fragment
        }

        guard let locBefore = textContentManager.location(documentRange.endLocation, offsetBy: -1) else {
            return nil
        }

        return textLayoutFragment(for: locBefore)
    }

    /// Private helper to enumerate text line fragments within a range
    private func enumerateTextLineFragments(
        in range: NSRange,
        options: NSTextLayoutFragment.EnumerationOptions = [],
        block: (NSTextLayoutFragment, NSTextLineFragment, CGRect, NSRange, Int) -> Bool
    ) {
        guard let textContentManager else { return }

        let docStart = documentRange.location
        guard
            let start = textContentManager.location(docStart, offsetBy: range.lowerBound),
            let end = textContentManager.location(docStart, offsetBy: range.upperBound)
        else {
            return
        }

        let reverse = options.contains(.reverse)

        if textContentManager.offset(from: start, to: documentRange.endLocation) == 0 {
            guard let fragment = lastTextLayoutFragment() else { return }

            fragment.enumerateLineFragments(
                in: range,
                with: textContentManager,
                reverse: reverse
            ) { lineFragment, frame, elementRange, offset in
                block(fragment, lineFragment, frame, elementRange, offset)
            }

            return
        }

        enumerateTextLayoutFragments(from: start, options: options) { fragment in
            let fragmentRange = fragment.rangeInElement

            fragment.enumerateLineFragments(
                in: range,
                with: textContentManager,
                reverse: reverse
            ) { lineFragment, frame, elementRange, offset in
                block(fragment, lineFragment, frame, elementRange, offset)
            }

            return fragmentRange.endLocation.compare(end) == .orderedAscending
        }
    }
}
