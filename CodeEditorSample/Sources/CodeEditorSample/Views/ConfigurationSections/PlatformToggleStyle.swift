import SwiftUI

/// Platform-specific toggle style that provides consistent styling across macOS, iOS, and Mac Catalyst
struct PlatformToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        #if targetEnvironment(macCatalyst)
        Toggle(configuration)
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        #elseif canImport(UIKit)
        Toggle(configuration)
            .toggleStyle(SwitchToggleStyle(tint: .blue))
        #else
        // Use default toggle style for macOS (modern switch)
        Toggle(configuration)
            .toggleStyle(DefaultToggleStyle())
        #endif
    }
}

/// Convenience extension for applying platform toggle style
extension ToggleStyle where Self == PlatformToggleStyle {
    static var platform: PlatformToggleStyle {
        PlatformToggleStyle()
    }
}
