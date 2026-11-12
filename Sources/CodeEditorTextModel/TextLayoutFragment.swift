import CodeEditorPlatform
#if canImport(AppKit)
@preconcurrency import AppKit

// MARK: - TextLayoutFragment

package final class TextLayoutFragment: NSTextLayoutFragment {
    private let defaultParagraphStyle: NSParagraphStyle
    package var isInvisibleCharactersEnabled: Bool = false
    /// Whether each line is moved up to sit in the middle of a line taller
    /// than its font (`lineHeightMultiple` > 1). Off draws the lines where
    /// the system's own fragment does.
    package var centersLinesVertically: Bool = true

    package init(textElement: NSTextElement, range rangeInElement: NSTextRange?, paragraphStyle: NSParagraphStyle) {
        defaultParagraphStyle = paragraphStyle
        super.init(textElement: textElement, range: rangeInElement)
    }

    package required init?(coder: NSCoder) {
        defaultParagraphStyle = NSParagraphStyle.default
        isInvisibleCharactersEnabled = false
        super.init(coder: coder)
    }

    // Provide default line height based on the typingattributed. By default return (0, 0, 10, 14)
    //
    // override var layoutFragmentFrame: CGRect {
    //    super.layoutFragmentFrame
    // }

    /// A line-ending mark is drawn past the end of the line's own glyphs,
    /// outside the surface the system would otherwise give the fragment.
    override package var renderingSurfaceBounds: CGRect {
        let bounds = super.renderingSurfaceBounds
        guard isInvisibleCharactersEnabled else { return bounds }
        return bounds.insetBy(dx: -Self.lineEndingMarkAllowance, dy: 0)
    }

    private static let lineEndingMarkAllowance: CGFloat = 32

    override package func draw(at point: CGPoint, in context: CGContext) {
        // Layout fragment draw text at the bottom (after apply baselineOffset) but ignore the paragraph line height
        // This is a workaround/patch to position text nicely in the line
        //
        // Center vertically after applying lineHeightMultiple value
        // super.draw(at: point.moved(dx: 0, dy: offset), in: context)

        if state.rawValue < NSTextLayoutFragment.State.layoutAvailable.rawValue {
            super.draw(at: point, in: context)
            return
        }

        guard centersLinesVertically else {
            super.draw(at: point, in: context)
            if isInvisibleCharactersEnabled {
                context.saveGState()
                context.translateBy(x: point.x, y: point.y)
                drawInvisibles(in: context)
                context.restoreGState()
            }
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
            context.translateBy(x: point.x, y: point.y)
            drawInvisibles(in: context)
        }

        context.restoreGState()
    }

    /// Draws a mark over each whitespace character, in the character's own
    /// font so the mark sits on the line's baseline.
    private func drawInvisibles(in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }

        for lineFragment in textLineFragments where !lineFragment.isExtraLineFragment {
            let attributedString = lineFragment.attributedString
            // swiftlint:disable:next legacy_objc_type
            let text = attributedString.string as NSString
            let range = lineFragment.characterRange
            guard range.location != NSNotFound, NSMaxRange(range) <= text.length else { continue }
            let lineOrigin = lineFragment.typographicBounds.origin

            for index in range.location..<NSMaxRange(range) {
                let character = text.character(at: index)
                guard Unicode.Scalar(character)?.properties.isWhitespace == true,
                      let font = attributedString.attribute(.font, at: index, effectiveRange: nil) as? PlatformFont
                else {
                    continue
                }

                let symbol: Character = switch character {
                case 0x0020: "\u{00B7}" // · Space
                case 0x0009: "\u{00BB}" // » Tab
                case 0x000A: "\u{00AC}" // ¬ Line Feed
                case 0x000D: "\u{21A9}" // ↩ Carriage Return
                case 0x00A0: "\u{235F}" // ⍟ Non-Breaking Space
                case 0x2028: "\u{23CE}" // ⏎ Line Separator
                case 0x2029: "\u{00B6}" // ¶ Paragraph Separator
                default: "\u{00B7}" // · Any other whitespace
                }

                let location = lineFragment.locationForCharacter(at: index)
                String(symbol).draw(
                    at: CGPoint(
                        x: lineOrigin.x + location.x,
                        y: lineOrigin.y + lineFragment.glyphOrigin.y - font.ascender
                    ),
                    withAttributes: [
                        .font: font,
                        .foregroundColor: PlatformColors.placeholderTextColor
                    ]
                )
            }
        }
    }

    deinit {
        // Cleanup if needed
    }
}
#endif
