//
//  CodeEditorRepresentableHelper.swift
//  CodeEditorPlugin
//
//  Shared helper methods for CodeEditorRepresentable implementations
//

import CodeEditorCommon
import CodeEditorCompletion
import CodeEditorConfiguration
import CodeEditorLanguages
import CodeEditorPlatform
import CodeEditorTheming
import CodeEditorView
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

// MARK: - CodeEditor Representable Helper

@available(macOS 13.0, iOS 16.0, *)
@MainActor
enum CodeEditorRepresentableHelper {
    // MARK: - Types

    struct ContainerParameters {
        let text: String
        let language: Language
        let theme: Theme
        let configuration: EditorConfiguration
        let runtimeDependencies: EditorRuntimeDependencies
        let interactionState: Binding<EditorInteractionState>
        let editorController: EditorController?
        let hostEditorState: EditorState
        let onTextChange: ((String) -> Void)?
        let onSelectionChange: ((NSRange) -> Void)?
        let swiftUICompletionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
    }

    struct UpdateParameters {
        let text: String
        let language: Language
        let theme: Theme
        let configuration: EditorConfiguration
        let runtimeDependencies: EditorRuntimeDependencies
        let interactionState: Binding<EditorInteractionState>
        let editorController: EditorController?
        let hostEditorState: EditorState
        let environment: EnvironmentValues
        let swiftUICompletionProvider: (@Sendable (SwiftUICompletionContext) async -> [SwiftUICompletionItem])?
    }

    // MARK: - Container Creation and Setup

    /// Creates and sets up a CodeEditorContainerView with common configuration
    static func createAndSetupContainer(
        parameters: ContainerParameters,
        coordinator: CodeEditorCoordinator
    ) -> CodeEditorContainerView {
        let container = CodeEditorContainerView()
        CodeEditorRenderingDiagnostics.logContainer(
            "representable.make.created",
            container: container,
            theme: parameters.theme,
            note: "language=\(parameters.language.rawValue)"
        )

        coordinator.updateInteractionStateBinding(parameters.interactionState)
        coordinator.hostEditorState = parameters.hostEditorState
        coordinator.setupContainer(
            container,
            text: parameters.text,
            language: parameters.language,
            theme: parameters.theme,
            configuration: parameters.configuration,
            runtimeDependencies: parameters.runtimeDependencies,
            onTextChange: parameters.onTextChange,
            onSelectionChange: parameters.onSelectionChange,
            swiftUICompletionProvider: parameters.swiftUICompletionProvider
        )
        CodeEditorRenderingDiagnostics.logContainer(
            "representable.make.afterSetup",
            container: container,
            theme: parameters.theme,
            note: "language=\(parameters.language.rawValue)"
        )
        coordinator.applyInteractionState(to: container.textView)
        CodeEditorRenderingDiagnostics.logContainer(
            "representable.make.afterInteractionState",
            container: container,
            theme: parameters.theme
        )

        CodeEditorPlatformAdapterFactory.make().setupPlatformFeatures(container: container, coordinator: coordinator)
        CodeEditorRenderingDiagnostics.logContainer(
            "representable.make.afterPlatformFeatures",
            container: container,
            theme: parameters.theme
        )

        // Attach the host's controller (if any) to the underlying view.
        // The controller weakly references the view and is responsible for
        // detaching on dismantle.
        if let controller = parameters.editorController {
            coordinator.editorController = controller
            controller.attach(to: container.textView)
        }

        return container
    }

    /// Updates container with new values using common logic
    static func updateContainer(
        _ container: CodeEditorContainerView,
        parameters: UpdateParameters,
        coordinator: CodeEditorCoordinator
    ) {
        CodeEditorRenderingDiagnostics.logContainer(
            "representable.update.begin",
            container: container,
            theme: parameters.theme,
            note: "language=\(parameters.language.rawValue)"
        )
        coordinator.updateInteractionStateBinding(parameters.interactionState)
        coordinator.hostEditorState = parameters.hostEditorState
        coordinator.updateContainer(
            container,
            text: parameters.text,
            language: parameters.language,
            theme: parameters.theme,
            configuration: parameters.configuration,
            runtimeDependencies: parameters.runtimeDependencies,
            swiftUICompletionProvider: parameters.swiftUICompletionProvider
        )
        CodeEditorRenderingDiagnostics.logContainer(
            "representable.update.afterCoordinator",
            container: container,
            theme: parameters.theme,
            note: "language=\(parameters.language.rawValue)"
        )
        coordinator.applyInteractionState(to: container.textView)
        CodeEditorRenderingDiagnostics.logContainer(
            "representable.update.afterInteractionState",
            container: container,
            theme: parameters.theme
        )

        // Apply theme after coordinator mutations so setText/configuration
        // changes cannot wipe the text view's storage foreground stamp.
        // CodeEditorContainerView forwards same-theme applies to the text
        // view even when the rest of the theme fan-out is equality-gated.
        container.apply(theme: parameters.theme)
        CodeEditorRenderingDiagnostics.logContainer(
            "representable.update.afterThemeApply",
            container: container,
            theme: parameters.theme
        )

        // Re-attach controller on update so that SwiftUI re-creating the
        // representable does not leave the controller pointing at a stale
        // view. If the host swapped controllers (rare), update the
        // coordinator's reference too.
        if let controller = parameters.editorController {
            if coordinator.editorController !== controller {
                coordinator.editorController?.attach(to: nil)
                coordinator.editorController = controller
            }
            controller.attach(to: container.textView)
        } else if let existing = coordinator.editorController {
            existing.attach(to: nil)
            coordinator.editorController = nil
        }

        // Handle focus request from environment using coordinator's tracking
        coordinator.requestFocusIfNeeded(
            for: container,
            shouldBecomeFirstResponder: parameters.environment.codeEditorBecomeFirstResponder
        )

        // Reset tracking if focus is no longer requested
        if !parameters.environment.codeEditorBecomeFirstResponder {
            coordinator.resetFocusTracking()
        }
    }

    // MARK: - Size Calculation

    /// Calculates size for the container view with platform-appropriate logic
    static func calculateSize(
        for container: CodeEditorContainerView,
        proposal: ProposedViewSize,
        configuration: EditorConfiguration
    ) -> CGSize? {
        let textView = container.textView

        #if canImport(UIKit)
        return calculateUIKitSize(textView: textView, proposal: proposal, configuration: configuration)
        #elseif canImport(AppKit)
        return calculateAppKitSize(textView: textView, proposal: proposal, configuration: configuration)
        #else
        return proposal.replacingUnspecifiedDimensions()
        #endif
    }

    #if canImport(UIKit)
    private static func calculateUIKitSize(
        textView: CodeEditorView,
        proposal: ProposedViewSize,
        configuration: EditorConfiguration
    ) -> CGSize? {
        // If proposal has explicit dimensions, respect them
        if let proposedWidth = proposal.width, let proposedHeight = proposal.height {
            return CGSize(width: proposedWidth, height: proposedHeight)
        }

        // Save current frame
        let originalFrame = textView.frame

        // Set a temporary width for size calculation
        let width = proposal.width ?? UIKitScreenMetrics.bounds(for: textView).width
        textView.frame.size.width = width

        // Calculate content size
        let sizeThatFits = textView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))

        // Restore original frame
        textView.frame = originalFrame

        var size = sizeThatFits

        // Add platform-specific adjustments
        size = addUIKitSizeAdjustments(size: size, textView: textView, configuration: configuration)

        // Apply common size constraints
        return applyCommonSizeConstraints(size, proposal: proposal)
    }

    private static func addUIKitSizeAdjustments(
        size: CGSize,
        textView: CodeEditorView,
        configuration: EditorConfiguration
    ) -> CGSize {
        var adjustedSize = size

        // Add padding for line numbers if enabled
        if configuration.display.isLineNumbersEnabled {
            adjustedSize.width += configuration.layout.gutterWidth
        }

        // Add text container insets
        let containerInset = textView.textContainerInset
        adjustedSize.width += containerInset.left + containerInset.right
        adjustedSize.height += containerInset.top + containerInset.bottom

        return adjustedSize
    }
    #endif

    #if canImport(AppKit)
    private static func calculateAppKitSize(
        textView: CodeEditorView,
        proposal: ProposedViewSize,
        configuration: EditorConfiguration
    ) -> CGSize? {
        // If proposal has explicit dimensions, respect them — the editor is a
        // flex container and should fill the space its parent offers, not
        // collapse to its (possibly empty) text content.
        if let proposedWidth = proposal.width, let proposedHeight = proposal.height {
            return CGSize(width: proposedWidth, height: proposedHeight)
        }

        var size = estimateAppKitContentSize(
            textView: textView,
            proposal: proposal,
            configuration: configuration
        )

        // Add platform-specific adjustments
        size = addAppKitSizeAdjustments(size: size, textView: textView, configuration: configuration)

        // Apply common size constraints
        return applyCommonSizeConstraints(size, proposal: proposal)
    }

    private static func estimateAppKitContentSize(
        textView: CodeEditorView,
        proposal: ProposedViewSize,
        configuration: EditorConfiguration
    ) -> CGSize {
        let font = textView.font ?? PlatformFonts.monospacedSystemFont(ofSize: 12, weight: .regular)
        let text = textView.textContentStorage?.textStorage?.string ?? ""
        let lines = text.components(separatedBy: .newlines)
        let lineHeight = TextMetricsCalculator.calculateLineHeight(for: font)
            * configuration.layout.lineHeightMultiple

        let lineWidths = lines.map { TextMetricsCalculator.measureTextWidth($0, font: font) }
        let maxLineWidth = lineWidths.max() ?? 0
        let lineCount = estimatedAppKitVisualLineCount(
            lineWidths: lineWidths,
            textView: textView,
            proposal: proposal,
            configuration: configuration
        )

        return CGSize(
            width: maxLineWidth,
            height: CGFloat(max(1, lineCount)) * lineHeight
        )
    }

    private static func estimatedAppKitVisualLineCount(
        lineWidths: [CGFloat],
        textView: CodeEditorView,
        proposal: ProposedViewSize,
        configuration: EditorConfiguration
    ) -> Int {
        guard configuration.layout.wrapLines else {
            return max(1, lineWidths.count)
        }

        let availableWidth = appKitAvailableTextWidth(
            textView: textView,
            proposal: proposal,
            configuration: configuration
        )
        guard availableWidth > 0 else {
            return max(1, lineWidths.count)
        }

        return lineWidths.reduce(0) { count, width in
            count + max(1, Int(ceil(width / availableWidth)))
        }
    }

    private static func appKitAvailableTextWidth(
        textView: CodeEditorView,
        proposal: ProposedViewSize,
        configuration: EditorConfiguration
    ) -> CGFloat {
        let proposedWidth = proposal.width ?? textView.bounds.width
        guard proposedWidth > 0 else { return 0 }

        var chromeWidth = textView.textContainerInset.width * 2
        if configuration.display.isLineNumbersEnabled {
            chromeWidth += configuration.layout.gutterWidth
        }
        if configuration.display.isMinimapVisible {
            chromeWidth += configuration.layout.minimapWidth
        }
        return max(0, proposedWidth - chromeWidth)
    }

    private static func addAppKitSizeAdjustments(
        size: CGSize,
        textView: CodeEditorView,
        configuration: EditorConfiguration
    ) -> CGSize {
        var adjustedSize = size

        // Add padding for line numbers and minimap if enabled
        if configuration.display.isLineNumbersEnabled {
            adjustedSize.width += configuration.layout.gutterWidth
        }

        if configuration.display.isMinimapVisible {
            adjustedSize.width += configuration.layout.minimapWidth
        }

        // Add text container insets
        let containerInset = textView.textContainerInset
        adjustedSize.width += containerInset.width * 2
        adjustedSize.height += containerInset.height * 2

        return adjustedSize
    }
    #endif

    // MARK: - Resource Management

    /// Clean up resources when view is being removed
    static func dismantle(coordinator: CodeEditorCoordinator) {
        coordinator.removeNotificationObservers()
        coordinator.textUpdateTask?.cancel()
        // Detach the host's controller so it stops vending operations
        // against a view that's about to disappear.
        coordinator.editorController?.attach(to: nil)
        coordinator.editorController = nil
    }

    // MARK: - Common Utilities

    /// Apply common size constraints
    static func applyCommonSizeConstraints(_ size: CGSize, proposal: ProposedViewSize) -> CGSize {
        var finalSize = size

        // Respect proposal constraints
        if let proposedWidth = proposal.width {
            finalSize.width = min(finalSize.width, proposedWidth)
        }

        if let proposedHeight = proposal.height {
            finalSize.height = min(finalSize.height, proposedHeight)
        }

        // Ensure minimum size
        finalSize.width = max(finalSize.width, 100)
        finalSize.height = max(finalSize.height, 50)

        return finalSize
    }

    /// Create a coordinator with common setup
    static func makeCoordinator(
        text: Binding<String>,
        onTextChange: ((String) -> Void)?,
        onSelectionChange: ((NSRange) -> Void)?,
        textDebounceInterval: Duration,
        interactionState: Binding<EditorInteractionState> = .constant(EditorInteractionState())
    ) -> CodeEditorCoordinator {
        let coordinator = CodeEditorCoordinator(
            text: text,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            interactionState: interactionState
        )
        coordinator.textDebounceInterval = textDebounceInterval
        return coordinator
    }
}
