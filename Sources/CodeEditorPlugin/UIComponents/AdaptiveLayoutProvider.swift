import SwiftUI

// MARK: - Adaptive Layout System

/// Provides consistent adaptive layout calculations across the codebase
/// Consolidates the duplicate layout helper methods found in configuration sections
public enum AdaptiveLayoutProvider {
    // MARK: - Helper Functions
    
    /// Returns a scale factor based on dynamic type size
    private static func scaleFactor(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall:
            return 0.85

        case .small:
            return 0.92

        case .medium:
            return 1.0

        case .large:
            return 1.08

        case .xLarge:
            return 1.16

        case .xxLarge:
            return 1.24

        case .xxxLarge:
            return 1.32

        case .accessibility1:
            return 1.40

        case .accessibility2:
            return 1.48

        case .accessibility3:
            return 1.56

        case .accessibility4:
            return 1.64

        case .accessibility5:
            return 1.72

        @unknown default:
            return 1.0
        }
    }
    
    // MARK: - Spacing Calculations
    
    /// Standard section spacing that adapts to dynamic type size
    public static func sectionSpacing(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        20 * scaleFactor(for: dynamicTypeSize)
    }
    
    /// Control spacing that adapts to dynamic type size
    public static func controlSpacing(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        12 * scaleFactor(for: dynamicTypeSize)
    }
    
    /// Horizontal padding that adapts to dynamic type size
    public static func horizontalPadding(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        20 * scaleFactor(for: dynamicTypeSize)
    }
    
    /// Vertical padding that adapts to dynamic type size
    public static func verticalPadding(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        16 * scaleFactor(for: dynamicTypeSize)
    }
    
    // MARK: - Font Size Calculations
    
    /// Adaptive font size calculation
    public static func fontSize(base: CGFloat, for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        base * scaleFactor(for: dynamicTypeSize)
    }
    
    // MARK: - Layout Helpers
    
    /// Determines if layout should be compact based on dynamic type size
    public static func isCompactLayout(for dynamicTypeSize: DynamicTypeSize) -> Bool {
        scaleFactor(for: dynamicTypeSize) <= 1.0
    }
    
    /// Returns appropriate corner radius for dynamic type size
    public static func cornerRadius(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        8 * scaleFactor(for: dynamicTypeSize)
    }
}

// MARK: - SwiftUI View Extensions

extension View {
    /// Applies adaptive section spacing
    public func adaptiveSectionSpacing() -> some View {
        modifier(AdaptiveSectionSpacingModifier())
    }
    
    /// Applies adaptive control spacing
    public func adaptiveControlSpacing() -> some View {
        modifier(AdaptiveControlSpacingModifier())
    }
    
    /// Applies adaptive horizontal padding
    public func adaptiveHorizontalPadding() -> some View {
        modifier(AdaptiveHorizontalPaddingModifier())
    }
    
    /// Applies adaptive vertical padding
    public func adaptiveVerticalPadding() -> some View {
        modifier(AdaptiveVerticalPaddingModifier())
    }
    
    /// Applies adaptive corner radius
    public func adaptiveCornerRadius() -> some View {
        modifier(AdaptiveCornerRadiusModifier())
    }
    
    /// Applies adaptive font size to a base size
    public func adaptiveFontSize(_ baseSize: CGFloat) -> some View {
        modifier(AdaptiveFontSizeModifier(baseSize: baseSize))
    }
}

// MARK: - View Modifiers

struct AdaptiveSectionSpacingModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content.padding(.vertical, AdaptiveLayoutProvider.sectionSpacing(for: dynamicTypeSize))
    }
}

struct AdaptiveControlSpacingModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content.padding(.vertical, AdaptiveLayoutProvider.controlSpacing(for: dynamicTypeSize))
    }
}

struct AdaptiveHorizontalPaddingModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content.padding(.horizontal, AdaptiveLayoutProvider.horizontalPadding(for: dynamicTypeSize))
    }
}

struct AdaptiveVerticalPaddingModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content.padding(.vertical, AdaptiveLayoutProvider.verticalPadding(for: dynamicTypeSize))
    }
}

struct AdaptiveCornerRadiusModifier: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content.clipShape(RoundedRectangle(cornerRadius: AdaptiveLayoutProvider.cornerRadius(for: dynamicTypeSize)))
    }
}

struct AdaptiveFontSizeModifier: ViewModifier {
    let baseSize: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content.font(.system(size: AdaptiveLayoutProvider.fontSize(base: baseSize, for: dynamicTypeSize)))
    }
}

// MARK: - Layout Components

/// Adaptive VStack with consistent spacing
public struct AdaptiveVStack<Content: View>: View {
    private let alignment: HorizontalAlignment
    private let content: () -> Content
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    public init(alignment: HorizontalAlignment = .center, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: alignment, spacing: AdaptiveLayoutProvider.controlSpacing(for: dynamicTypeSize)) {
            content()
        }
    }
}

/// Adaptive HStack with consistent spacing
public struct AdaptiveHStack<Content: View>: View {
    private let alignment: VerticalAlignment
    private let content: () -> Content
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    public init(alignment: VerticalAlignment = .center, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.content = content
    }
    
    public var body: some View {
        HStack(alignment: alignment, spacing: AdaptiveLayoutProvider.controlSpacing(for: dynamicTypeSize)) {
            content()
        }
    }
}

/// Adaptive section container with standard styling
public struct AdaptiveSection<Content: View>: View {
    private let title: String?
    private let content: () -> Content
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    public init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: AdaptiveLayoutProvider.controlSpacing(for: dynamicTypeSize)) {
            if let title {
                Text(title)
                    .font(.headline)
                    .adaptiveFontSize(17)
                    .foregroundColor(.primary)
            }
            
            VStack(alignment: .leading, spacing: AdaptiveLayoutProvider.controlSpacing(for: dynamicTypeSize)) {
                content()
            }
            .adaptiveHorizontalPadding()
            .adaptiveVerticalPadding()
            .background(Color.secondary.opacity(0.1))
            .adaptiveCornerRadius()
        }
        .adaptiveSectionSpacing()
    }
}

// MARK: - Configuration Binding Helpers

/// Environment key for configuration binding
struct ConfigurationEnvironmentKey: EnvironmentKey {
    static let defaultValue = EditorConfiguration()
}

extension EnvironmentValues {
    var configuration: EditorConfiguration {
        get { self[ConfigurationEnvironmentKey.self] }
        set { self[ConfigurationEnvironmentKey.self] = newValue }
    }
}

/// Configuration binding builder
public enum ConfigurationBinding {
    /// Creates a binding for a configuration property
    public static func create<T>(
        keyPath: WritableKeyPath<EditorConfiguration, T>,
        get: @escaping () -> EditorConfiguration,
        set: @escaping (EditorConfiguration) -> Void
    ) -> Binding<T> {
        // Capture variables as nonisolated to work around Sendable warnings in UI context
        nonisolated(unsafe) let unsafeGet: () -> EditorConfiguration = get
        nonisolated(unsafe) let unsafeSet: (EditorConfiguration) -> Void = set
        nonisolated(unsafe) let unsafeKeyPath: WritableKeyPath<EditorConfiguration, T> = keyPath
        
        return Binding(
            get: { unsafeGet()[keyPath: unsafeKeyPath] },
            set: { newValue in
                var config = unsafeGet()
                config[keyPath: unsafeKeyPath] = newValue
                unsafeSet(config)
            }
        )
    }
}

// MARK: - Convenience Configuration Controls

extension View {
    /// Creates an adaptive toggle for configuration properties
    public func configurationToggle(
        _ title: String,
        keyPath: WritableKeyPath<EditorConfiguration, Bool>,
        appState _: any ObservableObject
    ) -> some View {
        // This would need to be implemented with the actual app state type
        // For now, providing the interface structure
        self.modifier(ConfigurationToggleModifier(title: title, keyPath: keyPath))
    }
}

struct ConfigurationToggleModifier: ViewModifier {
    let title: String
    let keyPath: WritableKeyPath<EditorConfiguration, Bool>
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        AdaptiveHStack {
            content
            Toggle(title, isOn: .constant(false)) // Placeholder binding
                .toggleStyle(.switch)
                .adaptiveFontSize(16)
        }
        .adaptiveControlSpacing()
    }
}
