import CodeEditorPlatform
#if canImport(AppKit)
@preconcurrency import AppKit

// MARK: - TextLayoutFragment

final class TextLayoutFragment: NSTextLayoutFragment {
    private let defaultParagraphStyle: NSParagraphStyle
    package var isInvisibleCharactersEnabled: Bool = false

    init(textElement: NSTextElement, range rangeInElement: NSTextRange?, paragraphStyle: NSParagraphStyle) {
        defaultParagraphStyle = paragraphStyle
        super.init(textElement: textElement, range: rangeInElement)
    }

    required init?(coder: NSCoder) {
        defaultParagraphStyle = NSParagraphStyle.default
        isInvisibleCharactersEnabled = false
        super.init(coder: coder)
    }

    // Provide default line height based on the typingattributed. By default return (0, 0, 10, 14)
    //
    // override var layoutFragmentFrame: CGRect {
    //    super.layoutFragmentFrame
    // }

    override func draw(at point: CGPoint, in context: CGContext) {
        // Layout fragment draw text at the bottom (after apply baselineOffset) but ignore the paragraph line height
        // This is a workaround/patch to position text nicely in the line
        //
        // Center vertically after applying lineHeightMultiple value
        // super.draw(at: point.moved(dx: 0, dy: offset), in: context)

        if state.rawValue < NSTextLayoutFragment.State.layoutAvailable.rawValue {
            super.draw(at: point, in: context)
            return
        }

        context.saveGState()

        // Font smoothing disabled - requires STObjCLandShim module
        // #if USE_FONT_SMOOTHING_STYLE
        // let useThinStrokes = true
        // var savedFontSmoothingStyle: Int32 = 0
        // if useThinStrokes {
        //     context.setShouldSmoothFonts(true)
        //     savedFontSmoothingStyle = STContextGetFontSmoothingStyle(context)
        //     STContextSetFontSmoothingStyle(context, 16)
        // }
        // #endif

        for lineFragment in textLineFragments {
            // Determine paragraph style. Either from the fragment string or default for the text view
            // the ExtraLineFragment doesn't have information about typing attributes hence layout manager uses a default values - not from text view
            let paragraphStyle: NSParagraphStyle = if !lineFragment.isExtraLineFragment,
                                                      let lineParagraphStyle = lineFragment.attributedString.attribute(
                                                          .paragraphStyle,
                                                          at: 0,
                                                          effectiveRange: nil
                                                      ) as? NSParagraphStyle {
                lineParagraphStyle
            } else {
                defaultParagraphStyle
            }

            let offset = -(lineFragment.typographicBounds.height * (paragraphStyle.stLineHeightMultiple - 1.0) / 2)
            lineFragment.draw(
                at: point
                    .moved(
                        dx: lineFragment.typographicBounds.origin.x,
                        dy: lineFragment.typographicBounds.origin.y + offset
                    ),
                in: context
            )
        }

        // Font smoothing cleanup disabled - requires STObjCLandShim module
        // #if USE_FONT_SMOOTHING_STYLE
        // if (useThinStrokes) {
        //     STContextSetFontSmoothingStyle(context, savedFontSmoothingStyle);
        // }
        // #endif

        if isInvisibleCharactersEnabled {
            drawInvisibles(at: point, in: context)
        }

        context.restoreGState()
    }

    private func drawInvisibles(at _: CGPoint, in context: CGContext) {
        guard let textLayoutManager else {
            return
        }

        context.saveGState()

        for lineFragment in textLineFragments where !lineFragment.isExtraLineFragment {
            let sourceString = lineFragment.attributedString.string

            guard let lineFragmentTextRange = lineFragment.textRange(in: self),
                  let lineFragmentRange = Range(lineFragment.characterRange, in: sourceString)
            else {
                continue
            }

            let substring = sourceString[lineFragmentRange]

            for (offset, character) in substring.utf16.enumerated()
                where Unicode.Scalar(character)?.properties.isWhitespace == true {
                guard let segmentLocation = textLayoutManager.location(
                    lineFragmentTextRange.location,
                    offsetBy: offset
                ),
                    let segmentRange = NSTextRange(location: segmentLocation, end: segmentLocation),
                    let segmentFrame = textLayoutManager.textSegmentFrame(in: segmentRange, type: .standard),
                    let font = lineFragment.attributedString.attribute(
                        .font,
                        at: offset,
                        effectiveRange: nil
                    ) as? PlatformFont
                else {
                    continue
                }

                let symbol: Character = switch character {
                case 0x0020: "\u{00B7}" // • Space
                case 0x0009: "\u{00BB}" // » Tab
                case 0x000A: "\u{00AC}" // ¬ Line Feed
                case 0x000D: "\u{21A9}" // ↩ Carriage Return
                case 0x00A0: "\u{235F}" // ⎵ Non-Breaking Space
                case 0x200B: "\u{205F}" // ⸱ Zero Width Space
                case 0x200C: "\u{200C}" // ‌ Zero Width Non-Joiner
                case 0x200D: "\u{200D}" // ‍ Zero Width Joiner
                case 0x2060: "\u{205F}" //   Word Joiner
                case 0x2028: "\u{23CE}" // ⏎ Line Separator
                case 0x2029: "\u{00B6}" // ¶ Paragraph Separator
                default: "\u{00B7}" // • Default symbol for unspecified whitespace
                }

                let symbolString = String(symbol)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: PlatformColors.placeholderTextColor
                ]

                let charSize = symbolString.size(withAttributes: attributes)
                let writingDirection = textLayoutManager.baseWritingDirection(at: lineFragmentTextRange.location)

                let frameRect = CGRect(
                    origin: CGPoint(
                        x: segmentFrame.origin.x - layoutFragmentFrame.origin.x,
                        y: segmentFrame.origin.y - layoutFragmentFrame.origin.y
                    ),
                    size: segmentFrame.size
                )

                let point = CGPoint(
                    x: frameRect.origin.x - (writingDirection == .leftToRight ? 0 : charSize.width),
                    y: frameRect.origin.y
                )

                symbolString.draw(at: point, withAttributes: attributes)
            }
        }

        context.restoreGState()
    }

    deinit {
        // Cleanup if needed
    }
}
#endif
