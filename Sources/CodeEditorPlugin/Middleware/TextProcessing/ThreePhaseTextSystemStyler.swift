import Foundation

@MainActor
@preconcurrency
public final class ThreePhaseTextSystemStyler<Interface: TextSystemInterface> where Interface: Sendable {
    public typealias FallbackTokenProvider = @Sendable (NSRange) -> TokenApplication
    public typealias SecondaryValidationProvider = @Sendable (NSRange) async -> TokenApplication

    private let textSystem: Interface
    private let validator: ThreePhaseRangeValidator<Interface.Content>

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

    public func didChangeContent(in range: NSRange, delta: Int) async {
        await validator.contentChanged(in: range, delta: delta)
    }

    public func invalidate(_ target: RangeTarget) async {
        await validator.invalidate(target)
    }

    public func validate(_ target: RangeTarget = .all) async {
        await validator.validate(target, isolation: MainActor.shared)
    }

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

    public func getName() async -> String? {
        await validator.name
    }

    public func setName(_ newValue: String?) async {
        await validator.setName(newValue)
    }

    deinit {
        // Cleanup if needed
    }
}
