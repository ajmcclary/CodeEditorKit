//
//  CodeEditorRepresentableHelper.swift
//  CodeEditorPlugin
//
//  Shared helper methods for CodeEditorRepresentable implementations
//

import SwiftUI

@available(macOS 13.0, iOS 16.0, *)
@MainActor
enum CodeEditorRepresentableHelper {
    /// Clean up resources when view is being removed
    static func dismantle(coordinator: CodeEditorCoordinator) {
        coordinator.removeNotificationObservers()
        coordinator.textUpdateTask?.cancel()
    }
    
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
        coordinator.textDebounceInterval = textDebounceInterval.timeInterval
        return coordinator
    }
}
