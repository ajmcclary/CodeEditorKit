#if canImport(Combine)
import Combine
#endif
import Foundation

// MARK: - Variable Evaluation

@available(macOS 10.15, iOS 13.0, *)
extension DebuggerIntegrationCore {
    /// Evaluate expression
    func evaluate(
        expression: String,
        context: EvaluateContext = .repl
    ) async throws -> Variable {
        guard let session = activeSession,
              let frame = currentFrame else {
            throw DebugError.noActiveSession
        }

        return try await session.adapter.evaluate(
            expression: expression,
            frameId: frame.id,
            context: context
        )
    }

    /// Get variable children
    func getVariableChildren(_ variable: Variable) async throws -> [Variable] {
        guard let session = activeSession else {
            throw DebugError.noActiveSession
        }

        guard variable.variablesReference > 0 else {
            return []
        }

        return try await session.adapter.variables(
            variablesReference: variable.variablesReference
        )
    }

    // MARK: - Inline Values

    /// Get inline values for current frame
    func getInlineValues(for range: NSRange) async throws -> [InlineValue] {
        guard configuration.enableInlineValues,
              activeSession != nil,
              currentFrame != nil else {
            return []
        }

        var inlineValues: [InlineValue] = []

        // Get variables in scope
        for variable in variables {
            // Check if variable is referenced in range
            if let location = findVariableLocation(variable.name, in: range) {
                let value = variable.value.count > configuration.maxInlineValueLength ?
                    String(variable.value.prefix(configuration.maxInlineValueLength)) + "..." :
                    variable.value

                inlineValues.append(InlineValue(
                    range: NSRange(location: location, length: variable.name.count),
                    value: value,
                    variableName: variable.name,
                    type: variable.type
                ))
            }
        }

        return inlineValues
    }

    // MARK: - Hover Evaluation

    /// Evaluate expression on hover
    func evaluateOnHover(
        expression: String,
        at location: Int
    ) async throws -> HoverEvaluation? {
        guard configuration.enableHoverEvaluation,
              let session = activeSession,
              let frame = currentFrame else {
            return nil
        }

        do {
            let result = try await session.adapter.evaluate(
                expression: expression,
                frameId: frame.id,
                context: .hover
            )

            return HoverEvaluation(
                expression: expression,
                value: result.value,
                type: result.type,
                hasChildren: result.variablesReference > 0,
                location: location
            )
        } catch {
            // Evaluation failed, return nil
            return nil
        }
    }
}
