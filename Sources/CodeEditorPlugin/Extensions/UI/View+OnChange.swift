import SwiftUI

// MARK: - Cross-Platform onChange Extension

extension View {
    /// A cross-platform onChange modifier that provides compatibility across SwiftUI versions.
    ///
    /// This modifier automatically uses the appropriate onChange API based on the platform version,
    /// avoiding deprecation warnings on macOS 14+ and iOS 17+ while maintaining compatibility
    /// with earlier versions.
    ///
    /// ## Overview
    ///
    /// SwiftUI's onChange modifier API changed in iOS 17/macOS 14, with the new version
    /// providing both old and new values. This compatibility wrapper ensures your code
    /// works across all supported versions without deprecation warnings.
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct ContentView: View {
    ///     @State private var searchText = ""
    ///     
    ///     var body: some View {
    ///         TextField("Search", text: $searchText)
    ///             .onChangeCompat(of: searchText) { newValue in
    ///                 print("Search text changed to: \(newValue)")
    ///                 performSearch(with: newValue)
    ///             }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - value: The value to observe for changes. Must conform to `Equatable`.
    ///   - action: A closure to run when the value changes. Receives the new value as a parameter.
    ///
    /// - Returns: A view that triggers the specified action when the observed value changes.
    ///
    /// - Note: This modifier maintains the same behavior as the standard onChange modifier,
    ///   triggering only when the value actually changes (not on every view update).
    ///
    /// - SeeAlso: ``onChangeCompat(of:perform:)-8n4jy`` for a variant without the new value parameter
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
    
    /// A cross-platform onChange modifier for when you don't need the new value.
    ///
    /// This variant is useful when you only need to know that a change occurred,
    /// without needing access to the new value. It provides the same cross-version
    /// compatibility as the value-providing variant.
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct ContentView: View {
    ///     @State private var refreshTrigger = false
    ///     @State private var dataVersion = 0
    ///     
    ///     var body: some View {
    ///         List {
    ///             // Content that depends on external data
    ///         }
    ///         .onChangeCompat(of: dataVersion) {
    ///             // Refresh data without needing the version number
    ///             refreshData()
    ///         }
    ///     }
    ///     
    ///     func refreshData() {
    ///         // Perform refresh logic
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - value: The value to observe for changes. Must conform to `Equatable`.
    ///   - action: A closure to run when the value changes. Does not receive any parameters.
    ///
    /// - Returns: A view that triggers the specified action when the observed value changes.
    ///
    /// - SeeAlso: ``onChangeCompat(of:perform:)-73g5w`` for a variant that provides the new value
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
