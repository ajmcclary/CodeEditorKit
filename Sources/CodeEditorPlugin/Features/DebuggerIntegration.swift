#if canImport(Combine)
import Combine
#endif
import Foundation

// MARK: - Re-export debugger types

// This file re-exports all debugger integration types from the modular components
// for backward compatibility with existing code that imports DebuggerIntegration

@available(macOS 10.15, iOS 13.0, *)
internal typealias DebuggerIntegration = DebuggerIntegrationCore
