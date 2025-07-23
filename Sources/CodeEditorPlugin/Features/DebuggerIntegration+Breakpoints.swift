#if canImport(Combine)
import Combine
#endif
import Foundation

// MARK: - Breakpoint Management

@available(macOS 10.15, iOS 13.0, *)
extension DebuggerIntegrationCore {
    /// Add a breakpoint
    func addBreakpoint(_ breakpoint: Breakpoint) async {
        breakpoints.append(breakpoint)

        // Sync with active sessions
        if isDebugging {
            await syncBreakpoints()
        }

        logger.info("Added breakpoint at \(breakpoint.source.path):\(breakpoint.line)")
    }

    /// Remove a breakpoint
    func removeBreakpoint(_ breakpoint: Breakpoint) async {
        breakpoints.removeAll { $0.id == breakpoint.id }

        // Sync with active sessions
        if isDebugging {
            await syncBreakpoints()
        }

        logger.info("Removed breakpoint at \(breakpoint.source.path):\(breakpoint.line)")
    }

    /// Toggle breakpoint at line
    func toggleBreakpoint(at line: Int, in file: String) async {
        if let existing = breakpoints.first(where: { $0.source.path == file && $0.line == line }) {
            await removeBreakpoint(existing)
        } else {
            let breakpoint = Breakpoint(
                source: Source(path: file, name: URL(fileURLWithPath: file).lastPathComponent),
                line: line
            )
            await addBreakpoint(breakpoint)
        }
    }

    /// Update breakpoint condition
    func updateBreakpointCondition(
        _ breakpoint: Breakpoint,
        condition: String?
    ) async {
        guard let index = breakpoints.firstIndex(where: { $0.id == breakpoint.id }) else {
            return
        }

        breakpoints[index].condition = condition

        // Sync with active sessions
        if isDebugging {
            await syncBreakpoints()
        }
    }

    /// Update breakpoint hit condition
    func updateBreakpointHitCondition(
        _ breakpoint: Breakpoint,
        hitCondition: String?
    ) async {
        guard let index = breakpoints.firstIndex(where: { $0.id == breakpoint.id }) else {
            return
        }

        breakpoints[index].hitCondition = hitCondition

        // Sync with active sessions
        if isDebugging {
            await syncBreakpoints()
        }
    }

    /// Convert breakpoint to logpoint
    func convertToLogpoint(
        _ breakpoint: Breakpoint,
        logMessage: String
    ) async {
        guard let index = breakpoints.firstIndex(where: { $0.id == breakpoint.id }) else {
            return
        }

        breakpoints[index].logMessage = logMessage

        // Sync with active sessions
        if isDebugging {
            await syncBreakpoints()
        }
    }
}
