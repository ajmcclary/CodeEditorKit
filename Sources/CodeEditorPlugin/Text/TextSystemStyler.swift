import Foundation

@MainActor
@preconcurrency
public final class TextSystemStyler<Interface: TextSystemInterface> {
    private let textSystem: Interface
    private let tokenProvider: TokenProvider
    private let validator: SinglePhaseRangeValidator<Interface.Content>

    public init(textSystem: Interface, tokenProvider: TokenProvider) {
        self.textSystem = textSystem
        self.tokenProvider = tokenProvider

        let tokenValidator = TokenSystemValidator(
            textSystem: textSystem,
            tokenProvider: tokenProvider
        )

        validator = SinglePhaseRangeValidator(
            configuration: .init(
                versionedContent: textSystem.content,
                provider: tokenValidator.validationProvider
            )
        )
    }

    /// Update internal state in response to an edit.
    ///
    /// This method must be invoked on every text change. The `range` parameter must refer to the range of text that **was** changed.
    /// Consider the example text `"abc"`.
    ///
    /// Inserting a "d" at the end:
    ///
    ///     range = NSRange(3..<3)
    ///     delta = 1
    ///
    /// Deleting the middle "b":
    ///
    ///     range = NSRange(1..<2)
    ///     delta = -1
    public func didChangeContent(in range: NSRange, delta: Int) async {
        await validator.contentChanged(in: range, delta: delta)
    }

    public func invalidate(_ target: RangeTarget) async {
        await validator.invalidate(target)
    }

    public func validate(_ target: RangeTarget = .all) async {
        await validator.validate(target)
    }

    deinit {
        // Cleanup if needed
    }
}
