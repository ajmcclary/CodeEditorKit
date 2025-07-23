import Foundation

/// A text system styler that performs styling operations in three phases for optimal performance.
/// This class manages primary validation, fallback handling, and secondary validation phases.
@MainActor
@preconcurrency
public final class ThreePhaseTextSystemStyler<Interface: TextSystemInterface> where Interface: Sendable {
    /// Type alias for fallback token providers that handle immediate styling needs.
    public typealias FallbackTokenProvider = @Sendable (NSRange) -> TokenApplication
    /// Type alias for secondary validation providers that perform background validation.
    public typealias SecondaryValidationProvider = @Sendable (NSRange) async -> TokenApplication

    private let textSystem: Interface
    private let validator: ThreePhaseRangeValidator<Interface.Content>

    /// Creates a new three-phase text system styler.
    /// - Parameters:
    ///   - textSystem: The text system interface to style
    ///   - tokenProvider: Provider for generating styling tokens
    ///   - fallbackHandler: Handler for immediate fallback styling
    ///   - secondaryValidationProvider: Provider for background validation
    public init(
        textSystem: Interface,
        tokenProvider: TokenProvider,
        fallbackHandler: @escaping FallbackTokenProvider,
        secondaryValidationProvider: @escaping SecondaryValidationProvider
    ) {
        self.textSystem = textSystem

        let tokenValidator = TokenSystemValidator(
            textSystem: textSystem,
            tokenProvider: tokenProvider
        )

        validator = ThreePhaseRangeValidator(
            configuration: .init(
                versionedContent: textSystem.content,
                provider: tokenValidator.validationProvider,
                fallbackHandler: textSystem.validatorFallbackHandler(with: fallbackHandler),
                secondaryProvider: textSystem.validatorSecondaryHandler(with: secondaryValidationProvider),
                secondaryValidationDelay: 3.0
            ),
            isolation: MainActor.shared
        )
    }

    /// Notifies the styler that content has changed in the specified range.
    /// - Parameters:
    ///   - range: The range of content that changed
    ///   - delta: The change in content length (positive for insertions, negative for deletions)
    public func didChangeContent(in range: NSRange, delta: Int) async {
        await validator.contentChanged(in: range, delta: delta)
    }

    /// Invalidates styling for the specified range target.
    /// - Parameter target: The range target to invalidate
    public func invalidate(_ target: RangeTarget) async {
        await validator.invalidate(target)
    }

    /// Validates styling for the specified range target.
    /// - Parameter target: The range target to validate (defaults to all content)
    public func validate(_ target: RangeTarget = .all) async {
        await validator.validate(target, isolation: MainActor.shared)
    }

    /// The name of this styler instance for debugging and identification purposes.
    public var name: String? {
        get {
            // Since we can't use async in a property getter, we'll need to handle this differently
            // For now, return nil and provide an async method to get/set the name
            nil
        }
        set {
            Task {
                await validator.setName(newValue)
            }
        }
    }

    /// Asynchronously retrieves the name of this styler instance.
    /// - Returns: The styler's name, or nil if not set
    public func getName() async -> String? {
        await validator.name
    }

    /// Asynchronously sets the name of this styler instance.
    /// - Parameter newValue: The name to assign to this styler
    public func setName(_ newValue: String?) async {
        await validator.setName(newValue)
    }

    deinit {
        // Cleanup if needed
    }
}
