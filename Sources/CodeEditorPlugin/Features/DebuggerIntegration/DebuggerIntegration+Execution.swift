#if canImport(Combine)
import Combine
#endif
import Foundation

// MARK: - Execution Control

@available(macOS 10.15, iOS 13.0, *)
extension DebuggerIntegrationCore {
    /// Continue execution
    func continueExecution() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.continue(threadId: session.currentThreadId)
    }
    
    /// Step over
    func stepOver() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.next(threadId: session.currentThreadId)
    }
    
    /// Step into
    func stepInto() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.stepIn(threadId: session.currentThreadId)
    }
    
    /// Step out
    func stepOut() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.stepOut(threadId: session.currentThreadId)
    }
    
    /// Pause execution
    func pause() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.pause(threadId: session.currentThreadId)
    }
    
    /// Restart debugging
    func restart() async throws {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }
        
        try await session.adapter.restart()
    }
}
