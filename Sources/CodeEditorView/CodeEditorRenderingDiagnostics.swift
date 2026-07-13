import CodeEditorCommon
import CodeEditorConfiguration
import CodeEditorDiagnostics
import CodeEditorLanguages
import CodeEditorPlatform
import DesignKitThemes
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor
package enum CodeEditorRenderingDiagnostics {
    private static let logger = CodeEditorLog.logger(category: "RenderingDiagnostics")
    private static let dispatchLogger = CodeEditorLog.logger(category: "DispatchDiagnostics")

    package static func log(
        _ event: String,
        textView: CodeEditorView,
        theme: Theme? = nil,
        note: String = ""
    ) {
        #if DEBUG
        let documentLength = textView.textKitBridge.documentLength
        let selectedRange = currentSelectedRange(in: textView)
        let sampleLocation = sampleLocation(for: selectedRange, documentLength: documentLength)
        let sampleRange = sampleLocation.map { NSRange(location: $0, length: 1) }

        let storageForeground = sampleRange.flatMap { foregroundStorageAttribute(in: textView, range: $0) }
        let renderingForeground = sampleRange.flatMap { foregroundRenderingAttribute(in: textView, range: $0) }
        let storageFont = sampleRange.flatMap { storageAttribute(.font, in: textView, range: $0) }
        let renderingFont = sampleRange.flatMap { renderingAttribute(.font, in: textView, range: $0) }
        let typingForeground = textView.typingAttributes[.foregroundColor]

        var parts = [
            "CE_RENDER event=\(event)",
            "theme=\(theme?.name ?? textView.appliedTheme?.name ?? "nil")",
            "themeAppearance=\(theme?.appearance.rawValue ?? textView.appliedTheme?.appearance.rawValue ?? "nil")",
            "docLength=\(documentLength)",
            "selected=\(rangeDescription(selectedRange))",
            "sample=\(sampleLocation.map(String.init) ?? "nil")",
            "editable=\(textView.isEditable)",
            "selectable=\(textView.isSelectable)",
            "textLayoutManager=\(textView.textLayoutManager != nil)",
            "textColor=\(colorDescription(textView.textColor, textView: textView))",
            "backgroundColor=\(colorDescription(textView.backgroundColor, textView: textView))",
            "typingForeground=\(attributeDescription(typingForeground, textView: textView))",
            "storageForeground=\(attributeDescription(storageForeground, textView: textView))",
            "renderingForeground=\(attributeDescription(renderingForeground, textView: textView))",
            "viewFont=\(fontDescription(textView.font))",
            "storageFont=\(fontDescription(storageFont))",
            "renderingFont=\(fontDescription(renderingFont))",
            "syntax=\(textView.configuration.display.isSyntaxHighlightingEnabled)",
            "lineNumbers=\(textView.configuration.display.isLineNumbersEnabled)",
            "selectedLine=\(textView.configuration.display.isSelectedLineHighlighted)",
            "annotations=\(textView.configuration.display.areAnnotationsEnabled)",
            "minimap=\(textView.configuration.display.isMinimapVisible)",
            "completion=\(textView.configuration.behavior.isCodeCompletionEnabled)",
            "wrapLines=\(textView.configuration.layout.wrapLines)",
            "hardwareAcceleration=\(textView.configuration.performance.useHardwareAcceleration)",
            "frame=\(rectDescription(textView.frame))",
            "bounds=\(rectDescription(textView.bounds))"
        ]

        #if canImport(AppKit)
        parts.append("drawsBackground=\(textView.drawsBackground)")
        parts.append("wantsLayer=\(textView.wantsLayer)")
        parts.append("textContainerInset=\(sizeDescription(textView.textContainerInset))")
        parts.append("textContainerOrigin=\(pointDescription(textView.textContainerOrigin))")
        if let textContainer = textView.textContainer {
            parts.append("containerSize=\(sizeDescription(textContainer.containerSize))")
            parts.append("widthTracks=\(textContainer.widthTracksTextView)")
            parts.append("linePadding=\(String(format: "%.1f", textContainer.lineFragmentPadding))")
        }
        parts.append("appearance=\(textView.appearance?.name.rawValue ?? "nil")")
        parts.append("effectiveAppearance=\(textView.effectiveAppearance.name.rawValue)")
        parts.append("adaptiveDarkMapping=\(textView.usesAdaptiveColorMappingForDarkAppearance)")
        if let viewportDelegate = textView.textLayoutManager?.textViewportLayoutController.delegate {
            parts.append("viewportDelegate=\(String(describing: type(of: viewportDelegate)))")
            parts.append("viewportDelegateIsTextView=\((viewportDelegate as AnyObject) === textView)")
        } else {
            parts.append("viewportDelegate=nil")
            parts.append("viewportDelegateIsTextView=false")
        }
        if let scrollView = textView.enclosingScrollView {
            parts.append("clipBounds=\(rectDescription(scrollView.contentView.bounds))")
            parts.append("scrollAppearance=\(scrollView.appearance?.name.rawValue ?? "nil")")
            parts.append("hitTestTextView=\(hitTestReachesTextView(textView, in: scrollView))")
        }
        parts.append(contentsOf: visibleTextDescriptions(in: textView, sampleRange: sampleRange))
        parts.append("textSubviews=\(subviewDescription(textView.subviews))")
        parts.append(contentsOf: layoutFragmentDescriptions(in: textView))
        #endif

        if !note.isEmpty {
            parts.append("note=\(note)")
        }

        logger.info(parts.joined(separator: " "))
        #endif
    }

    package static func logContainer(
        _ event: String,
        container: CodeEditorContainerView,
        theme: Theme? = nil,
        note: String = ""
    ) {
        #if DEBUG
        var parts = [
            "containerFrame=\(rectDescription(container.frame))",
            "containerBounds=\(rectDescription(container.bounds))"
        ]
        #if canImport(AppKit)
        parts.append("containerAppearance=\(container.appearance?.name.rawValue ?? "nil")")
        parts.append("containerEffectiveAppearance=\(container.effectiveAppearance.name.rawValue)")
        parts.append("scrollFrame=\(rectDescription(container.scrollView.frame))")
        parts.append("scrollBounds=\(rectDescription(container.scrollView.bounds))")
        parts.append("clipBounds=\(rectDescription(container.scrollView.contentView.bounds))")
        parts.append("gutterAppearance=\(container.macLineNumberRulerView?.appearance?.name.rawValue ?? "nil")")
        #endif

        let suffix = ([note] + parts).filter { !$0.isEmpty }.joined(separator: " ")
        log(event, textView: container.textView, theme: theme, note: suffix)
        #endif
    }

    package static func logHighlighting(
        _ event: String,
        textView: CodeEditorView,
        language: Language,
        tokenCount: Int,
        range: NSRange,
        baseColor: PlatformColor
    ) {
        #if DEBUG
        log(
            event,
            textView: textView,
            theme: textView.appliedTheme,
            note: "language=\(language.rawValue) tokenCount=\(tokenCount) highlightRange=\(rangeDescription(range)) baseColor=\(colorDescription(baseColor, textView: textView))"
        )
        #endif
    }

    package static func logBodyResolution(
        _ event: String,
        manager: EditorDocuments?,
        storedTextLength: Int,
        effectiveTextLength: Int,
        language: Language,
        configuration: EditorConfiguration
    ) {
        #if DEBUG
        let activeDocument = manager?.active
        let activeTextLength = activeDocument?.text.count
        guard effectiveTextLength == 0 || activeTextLength != effectiveTextLength else {
            return
        }

        dispatchLogger.info([
            "CE_DISPATCH event=\(event)",
            "manager=\(manager != nil)",
            "activeID=\(manager?.activeID?.uuidString ?? "nil")",
            "activeName=\(activeDocument?.name ?? "nil")",
            "activeLanguage=\(activeDocument?.language?.rawValue ?? "nil")",
            "activeTextLength=\(activeTextLength.map(String.init) ?? "nil")",
            "storedTextLength=\(storedTextLength)",
            "effectiveTextLength=\(effectiveTextLength)",
            "language=\(language.rawValue)",
            "syntax=\(configuration.display.isSyntaxHighlightingEnabled)",
            "lineNumbers=\(configuration.display.isLineNumbersEnabled)",
            "selectedLine=\(configuration.display.isSelectedLineHighlighted)",
            "wrapLines=\(configuration.layout.wrapLines)",
            "completion=\(configuration.behavior.isCodeCompletionEnabled)"
        ].joined(separator: " "))
        #endif
    }

    package static func logConfigurationDispatch(_ event: String, textView: CodeEditorView) {
        #if DEBUG
        dispatchLogger.info([
            "CE_DISPATCH event=\(event)",
            "docLength=\(textView.textKitBridge.documentLength)",
            "language=\(textView.language.rawValue)",
            "syntax=\(textView.configuration.display.isSyntaxHighlightingEnabled)",
            "lineNumbers=\(textView.configuration.display.isLineNumbersEnabled)",
            "selectedLine=\(textView.configuration.display.isSelectedLineHighlighted)",
            "annotations=\(textView.configuration.display.areAnnotationsEnabled)",
            "minimap=\(textView.configuration.display.isMinimapVisible)",
            "wrapLines=\(textView.configuration.layout.wrapLines)",
            "completion=\(textView.configuration.behavior.isCodeCompletionEnabled)",
            "editable=\(textView.configuration.behavior.isEditable)",
            "theme=\(textView.appliedTheme?.name ?? "nil")",
            "textLayoutManager=\(textView.textLayoutManager != nil)"
        ].joined(separator: " "))
        #endif
    }

    package static func logContainerConfigurationDispatch(_ event: String, container: CodeEditorContainerView) {
        #if DEBUG
        var parts = [
            "CE_DISPATCH event=\(event)",
            "containerConfigLineNumbers=\(container.configuration.display.isLineNumbersEnabled)",
            "textViewConfigLineNumbers=\(container.textView.configuration.display.isLineNumbersEnabled)",
            "docLength=\(container.textView.textKitBridge.documentLength)",
            "syntax=\(container.configuration.display.isSyntaxHighlightingEnabled)",
            "selectedLine=\(container.configuration.display.isSelectedLineHighlighted)",
            "annotations=\(container.configuration.display.areAnnotationsEnabled)",
            "minimap=\(container.configuration.display.isMinimapVisible)",
            "wrapLines=\(container.configuration.layout.wrapLines)",
            "completion=\(container.configuration.behavior.isCodeCompletionEnabled)",
            "editable=\(container.configuration.behavior.isEditable)",
            "theme=\(container.appliedTheme?.name ?? "nil")"
        ]
        #if canImport(AppKit)
        parts.append("hasVerticalRuler=\(container.scrollView.hasVerticalRuler)")
        parts.append("rulersVisible=\(container.scrollView.rulersVisible)")
        parts.append("hasHorizontalScroller=\(container.scrollView.hasHorizontalScroller)")
        parts.append("clipBounds=\(rectDescription(container.scrollView.contentView.bounds))")
        parts.append("textFrame=\(rectDescription(container.textView.frame))")
        #endif
        dispatchLogger.info(parts.joined(separator: " "))
        #endif
    }

    private static func currentSelectedRange(in textView: CodeEditorView) -> NSRange {
        #if canImport(AppKit)
        textView.selectedRange()
        #else
        textView.selectedRange
        #endif
    }

    private static func sampleLocation(for selectedRange: NSRange, documentLength: Int) -> Int? {
        guard documentLength > 0 else { return nil }
        if selectedRange.location != NSNotFound, selectedRange.location < documentLength {
            return max(0, selectedRange.location)
        }
        return 0
    }

    private static func foregroundStorageAttribute(in textView: CodeEditorView, range: NSRange) -> Any? {
        storageAttribute(.foregroundColor, in: textView, range: range)
    }

    private static func storageAttribute(_ key: NSAttributedString.Key, in textView: CodeEditorView, range: NSRange) -> Any? {
        guard let storage = textView.textContentStorage?.textStorage,
              range.location < storage.length
        else { return nil }
        return storage.attribute(key, at: range.location, effectiveRange: nil)
    }

    private static func foregroundRenderingAttribute(in textView: CodeEditorView, range: NSRange) -> Any? {
        renderingAttribute(.foregroundColor, in: textView, range: range)
    }

    private static func renderingAttribute(_ key: NSAttributedString.Key, in textView: CodeEditorView, range: NSRange) -> Any? {
        guard let textLayoutManager = textView.textLayoutManager,
              let textRange = textView.textKitBridge.textRangeFromNSRange(range)
        else { return nil }

        textLayoutManager.ensureLayout(for: textRange)
        var value: Any?
        textLayoutManager.enumerateRenderingAttributes(from: textRange.location, reverse: false) { _, attributes, attributeRange in
            guard attributeRange.intersects(textRange) else { return true }
            value = attributes[key]
            return false
        }
        return value
    }

    private static func attributeDescription(_ value: Any?, textView: CodeEditorView) -> String {
        guard let value else { return "nil" }
        if let color = value as? PlatformColor {
            return colorDescription(color, textView: textView)
        }
        return String(describing: type(of: value))
    }

    private static func colorDescription(_ color: PlatformColor?, textView: CodeEditorView) -> String {
        guard let color else { return "nil" }

        #if canImport(AppKit)
        var convertedColor: NSColor?
        textView.effectiveAppearance.performAsCurrentDrawingAppearance {
            convertedColor = color.usingColorSpace(NSColorSpace.deviceRGB)
        }
        guard let rgb = convertedColor else {
            return String(describing: color)
        }
        #else
        let resolved = color.resolvedColor(with: textView.traitCollection)
        let rgb = resolved
        #endif

        let red = max(0, min(255, Int((rgb.redComponent * 255).rounded())))
        let green = max(0, min(255, Int((rgb.greenComponent * 255).rounded())))
        let blue = max(0, min(255, Int((rgb.blueComponent * 255).rounded())))
        let alpha = max(0, min(255, Int((rgb.alphaComponent * 255).rounded())))
        return String(format: "#%02X%02X%02X/%02X", red, green, blue, alpha)
    }

    private static func fontDescription(_ value: Any?) -> String {
        #if canImport(AppKit)
        guard let font = value as? NSFont else { return "nil" }
        return "\(font.fontName)@\(String(format: "%.1f", font.pointSize))"
        #else
        guard let font = value as? UIFont else { return "nil" }
        return "\(font.fontName)@\(String(format: "%.1f", font.pointSize))"
        #endif
    }

    private static func rangeDescription(_ range: NSRange) -> String {
        "{\(range.location),\(range.length)}"
    }

    private static func rectDescription(_ rect: CGRect) -> String {
        String(
            format: "{%.1f,%.1f,%.1f,%.1f}",
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height
        )
    }

    private static func pointDescription(_ point: CGPoint) -> String {
        "{\(numberDescription(point.x)),\(numberDescription(point.y))}"
    }

    private static func sizeDescription(_ size: CGSize) -> String {
        "{\(numberDescription(size.width)),\(numberDescription(size.height))}"
    }

    private static func numberDescription(_ value: CGFloat) -> String {
        if !value.isFinite {
            return "nonfinite"
        }
        if value > 1_000_000 {
            return "max"
        }
        if value < -1_000_000 {
            return "-max"
        }
        return String(format: "%.1f", value)
    }

    #if canImport(AppKit)
    private static func hitTestReachesTextView(_ textView: CodeEditorView, in scrollView: NSScrollView) -> Bool {
        let point = NSPoint(x: max(1, textView.bounds.midX), y: max(1, textView.bounds.midY))
        let pointInScrollView = textView.convert(point, to: scrollView)
        return scrollView.hitTest(pointInScrollView) === textView
    }

    private static func visibleTextDescriptions(
        in textView: CodeEditorView,
        sampleRange: NSRange?
    ) -> [String] {
        let visibleRect = textView.visibleRect
        var parts = [
            "visibleRect=\(rectDescription(visibleRect))",
            "visibleMidHit=\(hitTestClassName(at: CGPoint(x: visibleRect.midX, y: visibleRect.midY), in: textView))"
        ]

        guard let sampleRange,
              let textLayoutManager = textView.textLayoutManager,
              let textRange = textView.textKitBridge.textRangeFromNSRange(sampleRange)
        else {
            parts.append("sampleSegment=nil")
            return parts
        }

        textLayoutManager.ensureLayout(for: textRange)
        if let segmentFrame = textLayoutManager.textSegmentFrame(in: textRange, type: .standard) {
            parts.append("sampleSegment=\(rectDescription(segmentFrame))")
            parts.append("sampleSegmentVisible=\(segmentFrame.intersects(visibleRect))")
            parts.append("sampleSegmentHit=\(hitTestClassName(at: CGPoint(x: segmentFrame.midX, y: segmentFrame.midY), in: textView))")
        } else {
            parts.append("sampleSegment=nil")
        }

        return parts
    }

    private static func hitTestClassName(at point: CGPoint, in textView: CodeEditorView) -> String {
        guard let scrollView = textView.enclosingScrollView else { return "noScrollView" }
        let pointInScrollView = textView.convert(point, to: scrollView)
        guard let hitView = scrollView.hitTest(pointInScrollView) else { return "nil" }
        if hitView === textView { return "CodeEditorView" }
        return String(describing: type(of: hitView))
    }

    private static func subviewDescription(_ subviews: [NSView]) -> String {
        guard !subviews.isEmpty else { return "none" }
        let descriptions = subviews.prefix(6).map { view in
            let className = String(describing: type(of: view))
            let layerZ = view.layer.map { String(format: "%.1f", $0.zPosition) } ?? "nil"
            return "\(className):frame=\(rectDescription(view.frame)):hidden=\(view.isHidden):alpha=\(String(format: "%.2f", view.alphaValue)):z=\(layerZ)"
        }
        return descriptions.joined(separator: "|")
    }

    private static func layoutFragmentDescriptions(in textView: CodeEditorView) -> [String] {
        guard let textLayoutManager = textView.textLayoutManager else {
            return ["fragmentCount=0"]
        }

        textLayoutManager.ensureLayout(for: textLayoutManager.documentRange)

        var count = 0
        var firstFrame: CGRect?
        var firstLineCount = 0
        textLayoutManager.enumerateTextLayoutFragments(from: textLayoutManager.documentRange.location) { fragment in
            if count == 0 {
                firstFrame = fragment.layoutFragmentFrame
                firstLineCount = fragment.textLineFragments.count
            }
            count += 1
            return count < 64
        }

        return [
            "fragmentCount=\(count)",
            "firstFragment=\(firstFrame.map(rectDescription) ?? "nil")",
            "firstLineFragments=\(firstLineCount)"
        ]
    }
    #endif
}
