#if os(macOS) && !targetEnvironment(macCatalyst)
    import AppKit
#elseif os(iOS) || os(visionOS)
    #if canImport(UIKit)
        import UIKit
    #elseif canImport(AppKit)
        import AppKit
    #endif
#endif

extension NSTextLayoutManager {
    /// Extra line layout fragment.
    ///
    /// Only valid when ``state`` greater than NSTextLayoutFragment.State.estimatedUsageBounds
    @nonobjc
    public func extraLineTextLayoutFragment() -> NSTextLayoutFragment? {
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
    public func extraLineTextLineFragment() -> NSTextLineFragment? {
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
    public func textLineFragment(at location: NSTextLocation) -> NSTextLineFragment? {
        textLayoutFragment(for: location)?.textLineFragment(at: location)
    }

    public func textLineFragment(at point: CGPoint) -> NSTextLineFragment? {
        textLayoutFragment(for: point)?.textLineFragment(at: point)
    }
}

extension NSTextLayoutManager {
    /// Returns a location of text produced by a tap or click at the point you specify.
    /// - Parameters:
    ///   - point: A CGPoint that represents the location of the tap or click.
    ///   - containerLocation: A NSTextLocation that describes the contasiner location.
    /// - Returns: A location
    public func location(
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
    public func typographicBounds(in textRange: NSTextRange) -> CGRect? {
        textSegmentFrame(in: textRange, type: .standard, options: [.upstreamAffinity, .rangeNotRequired])
    }

    ///  A text segment is both logically and visually contiguous portion of the text content inside a line fragment.
    public func textSegmentFrame(
        at location: NSTextLocation,
        type: NSTextLayoutManager.SegmentType,
        options: SegmentOptions = [.upstreamAffinity]
    ) -> CGRect? {
        textSegmentFrame(in: NSTextRange(location: location), type: type, options: options)
    }

    /// A text segment is both logically and visually contiguous portion of the text content inside a line fragment.
    /// Text segment is a logically and visually contiguous portion of the text content inside a line fragment that you specify with a single text range.
    /// The framework enumerates the segments visually from left to right.
    public func textSegmentFrame(
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
    public func textSegmentFrames(
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
    public func enumerateTextLayoutFragments(
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
    public var insertionPointLocations: [NSTextLocation] {
        insertionPointSelections.flatMap(\.textRanges).map(\.location).sorted { $0 < $1 }
    }

    public var insertionPointSelections: [NSTextSelection] {
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
    package func substring(in range: NSTextRange) -> String {
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

    package func textSelectionsRanges(_ options: TextSelectionRangesOptions = .withInsertionPoints) -> [NSTextRange] {
        if options.contains(.withoutInsertionPoints) {
            textSelections.flatMap(\.textRanges).filter { !$0.isEmpty }.sorted { $0.location < $1.location }
        } else {
            textSelections.flatMap(\.textRanges).sorted { $0.location < $1.location }
        }
    }

    package func textSelectionsString() -> String? {
        textSelectionsRanges(.withoutInsertionPoints)
            .compactMap { textRange in
                substring(in: textRange)
            }
            .joined(separator: "\n")
    }

    package func textSelectionsAttributedString() -> NSAttributedString? {
        textAttributedString(in: textSelectionsRanges(.withoutInsertionPoints))
    }

    package func textAttributedString(at location: any NSTextLocation) -> NSAttributedString? {
        if let range = NSTextRange(location: location, end: self.location(location, offsetBy: 1)), !range.isEmpty {
            return textAttributedString(in: range)
        }

        return nil
    }

    package func textAttributedString(in textRange: NSTextRange) -> NSAttributedString? {
        textAttributedString(in: [textRange])
    }

    package func textAttributedString(in textRanges: [NSTextRange]) -> NSAttributedString? {
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
