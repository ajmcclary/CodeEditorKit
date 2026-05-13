//
//  CodeEditorRepresentableHelper.swift
//  CodeEditorPlugin
//
//  Shared helper methods for CodeEditorRepresentable implementations
//

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
        let onTextChange: ((String) -> Void)?
        let onSelectionChange: ((NSRange) -> Void)?
    }

    struct UpdateParameters {
        let text: String
        let language: Language
        let theme: Theme
        let configuration: EditorConfiguration
        let runtimeDependencies: EditorRuntimeDependencies
        let interactionState: Binding<EditorInteractionState>
        let editorController: EditorController?
        let environment: EnvironmentValues
    }

    // MARK: - Container Creation and Setup

    /// Creates and sets up a CodeEditorContainerView with common configuration
    static func createAndSetupContainer(
        parameters: ContainerParameters,
        coordinator: CodeEditorCoordinator
    ) -> CodeEditorContainerView {
        let container = CodeEditorContainerView()

        coordinator.updateInteractionStateBinding(parameters.interactionState)
        coordinator.setupContainer(
            container,
            text: parameters.text,
            language: parameters.language,
            theme: parameters.theme,
            configuration: parameters.configuration,
            runtimeDependencies: parameters.runtimeDependencies,
            onTextChange: parameters.onTextChange,
            onSelectionChange: parameters.onSelectionChange
        )
        coordinator.applyInteractionState(to: container.textView)

        CodeEditorPlatformAdapterFactory.make().setupPlatformFeatures(container: container, coordinator: coordinator)

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
        // Push the current theme into the container's equality-gated apply path.
        // The container is the single fan-out point for subview theme propagation
        // — sub-project 3 task 5 establishes the route; later tasks wire each subview.
        container.apply(theme: parameters.theme)

        coordinator.updateInteractionStateBinding(parameters.interactionState)
        coordinator.updateContainer(
            container,
            text: parameters.text,
            language: parameters.language,
            theme: parameters.theme,
            configuration: parameters.configuration,
            runtimeDependencies: parameters.runtimeDependencies
        )
        coordinator.applyInteractionState(to: container.textView)

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

        // Calculate intrinsic content size based on text
        let textContainer = textView.textContainer
        let layoutManager = textView.layoutManager

        guard let textContainer,
              let layoutManager else {
            return proposal.replacingUnspecifiedDimensions()
        }

        // Force layout
        layoutManager.ensureLayout(for: textContainer)

        // Get the used rect
        let usedRect = layoutManager.usedRect(for: textContainer)
        var size = usedRect.size

        // Add platform-specific adjustments
        size = addAppKitSizeAdjustments(size: size, textView: textView, configuration: configuration)

        // Apply common size constraints
        return applyCommonSizeConstraints(size, proposal: proposal)
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
