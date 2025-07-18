import Foundation

#if targetEnvironment(macCatalyst)
import UIKit

// MARK: - Mac Catalyst First Responder Handling

extension CodeEditorView {
    // MARK: - First Responder Overrides
    
    /// Override becomeFirstResponder to preserve word wrap state
    override open func becomeFirstResponder() -> Bool {
        // Preserve the current word wrap state before becoming first responder
        if !hasPreservedWordWrapState {
            preservedWordWrapState = configuration.layout.wrapLines
            hasPreservedWordWrapState = true
        }
        
        let result = super.becomeFirstResponder()
        
        // If we preserved a word wrap state and it changed, restore it
        if hasPreservedWordWrapState && preservedWordWrapState != configuration.layout.wrapLines {
            Self.logger.debug("Mac Catalyst: Restoring word wrap state to \(preservedWordWrapState)")
            
            // Restore the word wrap state without triggering configuration loops
            var updatedConfig = configuration
            updatedConfig.layout.wrapLines = preservedWordWrapState
            
            // Temporarily disable configuration application to avoid loops
            isApplyingConfiguration = true
            defer { isApplyingConfiguration = false }
            
            configuration = updatedConfig
            
            // Ensure text container is properly configured
            updateTextContainerSize()
        }
        
        // Ensure text colors are applied after becoming first responder
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(50))
            self?.applyTextColorForMacCatalyst()
        }
        
        return result
    }
    
    /// Monitor text container changes that might reset word wrap
    internal func monitorTextContainerChanges() {
        // Check if text container configuration matches our expected state
        let expectedWordWrap = hasPreservedWordWrapState ? preservedWordWrapState : configuration.layout.wrapLines
        let actualWordWrap = textContainer.widthTracksTextView
        
        if expectedWordWrap != actualWordWrap {
            Self.logger.debug("Mac Catalyst: Text container word wrap mismatch - expected: \(expectedWordWrap), actual: \(actualWordWrap)")
            
            // Force update text container to match expected state
            updateTextContainerSize()
        }
    }
}
#endif
