import SwiftUI

// MARK: - Configuration Form Controls
//
// Reusable SwiftUI controls (toggle, slider, …) that wire directly to a
// `Binding<EditorConfiguration>` field via key path. Hosts construct these
// inline; there's intentionally no builder/observer machinery wrapping them.

// MARK: - Configuration View Components

/// Standardized toggle view for configuration options
public struct ConfigurationToggleView: View {
    let title: String
    let binding: Binding<Bool>
    let disabled: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        AdaptiveHStack {
            Text(title)
                .adaptiveFontSize(16)
                .foregroundColor(disabled ? .secondary : .primary)

            Spacer()

            Toggle("", isOn: binding)
                .toggleStyle(.switch)
                .disabled(disabled)
        }
        .adaptiveControlSpacing()
        .accessibilityElement(children: .combine)
        .disabled(disabled)
    }
}

/// Standardized slider view for configuration options
public struct ConfigurationSliderView<T>: View where T: BinaryFloatingPoint, T.Stride: BinaryFloatingPoint {
    let title: String
    let binding: Binding<T>
    let range: ClosedRange<T>
    let step: T.Stride
    let formatter: (T) -> String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        AdaptiveVStack(alignment: .leading) {
            AdaptiveHStack {
                Text(title)
                    .adaptiveFontSize(16)
                    .foregroundColor(.primary)

                Spacer()

                Text(formatter(binding.wrappedValue))
                    .adaptiveFontSize(14)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }

            Slider(value: binding, in: range)
                .accessibilityLabel(title)
                .accessibilityValue(formatter(binding.wrappedValue))
        }
        .adaptiveControlSpacing()
    }
}

/// Standardized picker view for configuration options
public struct ConfigurationPickerView<T: Hashable>: View {
    let title: String
    let binding: Binding<T>
    let allCases: [T]
    let displayName: (T) -> String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        AdaptiveHStack {
            Text(title)
                .adaptiveFontSize(16)
                .foregroundColor(.primary)

            Spacer()

            Picker(title, selection: binding) {
                ForEach(allCases, id: \.self) { value in
                    Text(displayName(value))
                        .tag(value)
                        .adaptiveFontSize(14)
                }
            }
            .pickerStyle(.menu)
            .accessibilityLabel(title)
        }
        .adaptiveControlSpacing()
    }
}

/// Standardized text field view for configuration options
public struct ConfigurationTextFieldView: View {
    let title: String
    let binding: Binding<String>
    let placeholder: String
    let validation: ((String) -> Bool)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isValid: Bool = true

    public init(
        title: String,
        binding: Binding<String>,
        placeholder: String = "",
        validation: ((String) -> Bool)? = nil
    ) {
        self.title = title
        self.binding = binding
        self.placeholder = placeholder
        self.validation = validation
    }

    public var body: some View {
        AdaptiveVStack(alignment: .leading) {
            Text(title)
                .adaptiveFontSize(16)
                .foregroundColor(.primary)

            TextField(placeholder, text: binding)
                .textFieldStyle(.roundedBorder)
                .adaptiveFontSize(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isValid ? Color.clear : Color.red, lineWidth: 1)
                )
                .modifier(OnChangeModifier(binding: binding) { newValue in
                    if let validation {
                        isValid = validation(newValue)
                    }
                })
                .accessibilityLabel(title)
        }
        .adaptiveControlSpacing()
    }
}

/// Standardized stepper view for Int configuration options
public struct ConfigurationIntStepperView: View {
    let title: String
    let binding: Binding<Int>
    let range: ClosedRange<Int>
    let step: Int
    let formatter: (Int) -> String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        title: String,
        binding: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int = 1,
        formatter: @escaping (Int) -> String = { "\($0)" }
    ) {
        self.title = title
        self.binding = binding
        self.range = range
        self.step = step
        self.formatter = formatter
    }

    public var body: some View {
        AdaptiveHStack {
            Text(title)
                .adaptiveFontSize(16)
                .foregroundColor(.primary)

            Spacer()

            Stepper(
                value: binding,
                in: range,
                step: step
            ) {
                Text(formatter(binding.wrappedValue))
                    .adaptiveFontSize(14)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .frame(minWidth: 50, alignment: .trailing)
            }
            .accessibilityLabel(title)
            .accessibilityValue(formatter(binding.wrappedValue))
        }
        .adaptiveControlSpacing()
    }
}

// MARK: - Configuration Section Builder

/// Builder for creating consistent configuration sections
public enum ConfigurationSectionBuilder {
    /// Creates a configuration section with standard styling
    @MainActor
    public static func section<Content: View>(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        AdaptiveSection(title: title) {
            content()
        }
    }

    /// Creates a group of related configuration controls
    @MainActor
    public static func group<Content: View>(
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        AdaptiveVStack(alignment: .leading) {
            content()
        }
        .adaptiveHorizontalPadding()
        .adaptiveVerticalPadding()
        .background(Color.secondary.opacity(0.1))
        .adaptiveCornerRadius()
    }

    /// Creates a header for configuration sections
    @MainActor
    public static func header(_ title: String, subtitle: String? = nil) -> some View {
        AdaptiveVStack(alignment: .leading) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .adaptiveFontSize(22)
                .foregroundColor(.primary)

            if let subtitle {
                Text(subtitle)
                    .adaptiveFontSize(16)
                    .foregroundColor(.secondary)
            }
        }
        .adaptiveSectionSpacing()
    }
}

// MARK: - Configuration View Presets

// MARK: - Migration Helper

/// Helper for migrating to direct binding patterns
/// Recommended pattern: $appState.currentConfiguration.section.property
public enum ConfigurationViewMigrationHelper {
    /// Example of the recommended direct binding pattern
    @MainActor
    public static func directBindingExample() -> some View {
        Text("""
        // Recommended pattern:
        Toggle("Show Line Numbers",
               isOn: $appState.currentConfiguration.display.isLineNumbersEnabled)

        // See AdvancedFeaturesShowcaseView.swift for complete examples
        """)
        .foregroundColor(.secondary)
        .font(.caption)
        .padding()
    }
}

// MARK: - Cross-Platform onChange Support

/// Cross-platform onChange modifier that works with both old and new APIs
struct OnChangeModifier<T: Equatable>: ViewModifier {
    let binding: Binding<T>
    let action: (T) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            content.onChange(of: binding.wrappedValue) { _, newValue in
                action(newValue)
            }
        } else {
            content.onChange(of: binding.wrappedValue) { newValue in
                action(newValue)
            }
        }
    }
}
