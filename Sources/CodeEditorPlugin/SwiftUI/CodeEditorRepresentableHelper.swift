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

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        let theme: CodeEditorSwiftUITheme
        let configuration: EditorConfiguration
        let memoryMonitor: MemoryMonitor
        let onTextChange: ((String) -> Void)?
        let onSelectionChange: ((NSRange) -> Void)?
    }
    
    struct UpdateParameters {
        let text: String
        let language: Language
        let theme: CodeEditorSwiftUITheme
        let configuration: EditorConfiguration
        let environment: EnvironmentValues
    }
    
    // MARK: - Container Creation and Setup
    
    /// Creates and sets up a CodeEditorContainerView with common configuration
    static func createAndSetupContainer(
        parameters: ContainerParameters,
        coordinator: CodeEditorCoordinator
    ) -> CodeEditorContainerView {
        let container = CodeEditorContainerView()
        
        coordinator.setupContainer(
            container,
            text: parameters.text,
            language: parameters.language,
            theme: parameters.theme,
            configuration: parameters.configuration,
            memoryMonitor: parameters.memoryMonitor,
            onTextChange: parameters.onTextChange,
            onSelectionChange: parameters.onSelectionChange
        )
        
        // Platform-specific setup
        setupPlatformSpecificFeatures(container: container, coordinator: coordinator)
        
        return container
    }
    
    /// Updates container with new values using common logic
    static func updateContainer(
        _ container: CodeEditorContainerView,
        parameters: UpdateParameters,
        coordinator: CodeEditorCoordinator
    ) {
        coordinator.updateContainer(container, text: parameters.text, language: parameters.language, theme: parameters.theme, configuration: parameters.configuration)
        
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
    
    // MARK: - Platform-Specific Setup
    
    private static func setupPlatformSpecificFeatures(
        container: CodeEditorContainerView,
        coordinator: CodeEditorCoordinator
    ) {
        #if canImport(UIKit)
        // Set up the text view delegate for iOS
        coordinator.setupTextViewDelegate(container.textView)
        #endif
        
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        // macOS-specific setup can be added here if needed
        #endif
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
        #elseif canImport(AppKit) && !targetEnvironment(macCatalyst)
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
        let width = proposal.width ?? UIScreen.main.bounds.width
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
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private static func calculateAppKitSize(
        textView: CodeEditorView,
        proposal: ProposedViewSize,
        configuration: EditorConfiguration
    ) -> CGSize? {
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
        
        if configuration.display.showMinimap {
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
        textDebounceInterval: Duration
    ) -> CodeEditorCoordinator {
        let coordinator = CodeEditorCoordinator(
            text: text,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange
        )
        coordinator.textDebounceInterval = textDebounceInterval
        return coordinator
    }
}
