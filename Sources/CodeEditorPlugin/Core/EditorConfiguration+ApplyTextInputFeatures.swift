import Foundation

// MARK: - EditorConfiguration Text Input Features Integration

extension EditorConfiguration {
    /// Apply text input features using the platform abstraction.
    @MainActor public func applyTextInputFeatures(to textView: any TextInputFeatureTarget) {
        let features = TextInputFeaturesFactory.create()
        features.apply(to: textView, configuration: behavior)
    }
}
