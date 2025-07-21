import Foundation
#if targetEnvironment(macCatalyst)
import UIKit

/// Actor responsible for managing color application tasks on Mac Catalyst
/// 
/// This actor ensures structured concurrency for delayed color applications,
/// allowing proper task cancellation and preventing unstructured tasks.
actor CatalystColorTaskManager {
    private var activeTask: Task<Void, Never>?
    
    /// Applies text color with structured delay handling
    /// - Parameters:
    ///   - color: The color to apply
    ///   - textView: The text view to apply the color to
    ///   - delay: The delay before reapplying the color (in milliseconds)
    func applyColorWithDelay(_ color: UIColor, to textView: CodeEditorView, delay: UInt64 = 100) async {
        // Cancel any existing task
        activeTask?.cancel()
        
        // Create a new structured task
        activeTask = Task { @MainActor in
            // Apply color immediately
            textView.applyTextColorForMacCatalyst()
            
            // Wait for the specified delay
            do {
                try await Task.sleep(for: .milliseconds(delay))
                // Reapply color after delay if not cancelled
                if !Task.isCancelled {
                    textView.applyTextColorForMacCatalyst()
                }
            } catch {
                // Task was cancelled, which is expected behavior
            }
        }
        
        // Wait for the task to complete
        await activeTask?.value
    }
    
    /// Cancels any active color application task
    func cancelActiveTask() {
        activeTask?.cancel()
        activeTask = nil
    }
    
    deinit {
        activeTask?.cancel()
    }
}
#endif
