import SwiftUI

// MARK: - Cross-Platform onChange Extension

extension View {
    /// A cross-platform onChange modifier that handles both old and new APIs
    /// This avoids deprecation warnings on macOS 14+ while maintaining compatibility with iOS 16+
    @ViewBuilder
    public func onChangeCompat<Value: Equatable>(
        of value: Value,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value, perform: action)
        }
    }
    
    /// A cross-platform onChange modifier for when you don't need the new value
    @ViewBuilder
    public func onChangeCompat<Value: Equatable>(
        of value: Value,
        perform action: @escaping () -> Void
    ) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            self.onChange(of: value) {
                action()
            }
        } else {
            self.onChange(of: value) { _ in
                action()
            }
        }
    }
}
