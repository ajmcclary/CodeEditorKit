import CodeEditorDesignTokens
import CodeEditorPlatform
import CodeEditorPlugin
import SwiftUI

// MARK: - Separator

/// Hairline rule used between knob rows; tinted by the active theme.
struct KnobRowSeparator: View {
    @Environment(\.codeEditorTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(Color(tokens: theme.style.borders.variant))
            .frame(height: 0.5)
            .padding(.vertical, 8)
    }
}

// MARK: - Row chrome

/// Shared label cell rendered on the leading edge of every row: optional
/// icon + humanized label. Centralizes the typography so toggles, sliders,
/// steppers, and pickers stay visually aligned.
private struct KnobLabelCell: View {
    @Environment(\.codeEditorTheme) private var theme

    let icon: String?
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            iconView
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(tokens: theme.style.text.base))
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color(tokens: theme.style.icon.muted))
                .frame(width: 18, height: 18)
        } else {
            Spacer().frame(width: 18, height: 18)
        }
    }
}

/// Mono-digit value badge used by sliders and steppers.
private struct KnobValueBadge: View {
    @Environment(\.codeEditorTheme) private var theme

    let text: String
    var minWidth: CGFloat = 44

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(Color(tokens: theme.style.text.base))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .frame(minWidth: minWidth)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(tokens: theme.style.elements.element.background))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color(tokens: theme.style.borders.variant), lineWidth: 0.5)
            )
    }
}

// MARK: - Toggle

struct ToggleRow: View {
    @Environment(\.codeEditorTheme) private var theme
    let label: String
    @Binding var value: Bool

    var body: some View {
        HStack {
            KnobLabelCell(
                icon: KnobIcon.symbol(for: label),
                label: KnobLabel.humanize(label, dropTrailingState: true)
            )
            Spacer(minLength: 8)
            Toggle("", isOn: $value)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Color(tokens: theme.style.text.accent))
        }
        .frame(minHeight: 36)
        .padding(.vertical, 4)
    }
}

// MARK: - Stepper (Int)

struct StepperRow: View {
    @Environment(\.codeEditorTheme) private var theme
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    var format: IntegerFormatStyle<Int> = .number

    var body: some View {
        HStack(spacing: 10) {
            KnobLabelCell(
                icon: KnobIcon.symbol(for: label),
                label: KnobLabel.humanize(label)
            )
            Spacer(minLength: 8)
            KnobValueBadge(text: format.format(value), minWidth: 64)
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
                .controlSize(.small)
        }
        .frame(minHeight: 36)
        .padding(.vertical, 4)
    }
}

// MARK: - Slider (Double)

struct SliderRow: View {
    @Environment(\.codeEditorTheme) private var theme
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                KnobLabelCell(
                    icon: KnobIcon.symbol(for: label),
                    label: KnobLabel.humanize(label)
                )
                Spacer(minLength: 8)
                KnobValueBadge(text: value.formatted(format))
            }
            slider
                .padding(.leading, 28)
                .tint(Color(tokens: theme.style.text.accent))
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var slider: some View {
        if step > 0 {
            Slider(value: $value, in: range, step: step)
        } else {
            Slider(value: $value, in: range)
        }
    }
}

// MARK: - Slider (CGFloat — bridge through Double)

struct CGFloatSliderRow: View {
    let label: String
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    var step: CGFloat = 0
    var format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))

    var body: some View {
        SliderRow(
            label: label,
            value: Binding(get: { Double(value) }, set: { value = CGFloat($0) }),
            range: Double(range.lowerBound)...Double(range.upperBound),
            step: Double(step),
            format: format
        )
    }
}

// MARK: - Picker (generic)

struct PickerRow<T: Hashable & Sendable>: View {
    @Environment(\.codeEditorTheme) private var theme
    let label: String
    @Binding var value: T
    let cases: [T]
    let display: (T) -> String

    var body: some View {
        HStack(spacing: 10) {
            KnobLabelCell(
                icon: KnobIcon.symbol(for: label),
                label: KnobLabel.humanize(label)
            )
            Spacer(minLength: 8)
            menu
        }
        .frame(minHeight: 36)
        .padding(.vertical, 4)
    }

    private var menu: some View {
        Menu {
            ForEach(cases, id: \.self) { item in
                Button {
                    value = item
                } label: {
                    if item == value {
                        Label(display(item), systemImage: "checkmark")
                    } else {
                        Text(display(item))
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(display(value))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(tokens: theme.style.text.base))
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(tokens: theme.style.text.muted))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(tokens: theme.style.elements.element.background))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(tokens: theme.style.borders.base), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

// MARK: - Color (PlatformColor)

struct ColorRow: View {
    @Environment(\.codeEditorTheme) private var theme
    let label: String
    @Binding var value: PlatformColor

    var body: some View {
        HStack(spacing: 10) {
            KnobLabelCell(
                icon: KnobIcon.symbol(for: label),
                label: KnobLabel.humanize(label)
            )
            Spacer(minLength: 8)
            ColorPicker("", selection: bridgedBinding, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 28, height: 20)
            Text(hexString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(tokens: theme.style.text.muted))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(tokens: theme.style.elements.element.background))
                )
                .frame(minWidth: 80, alignment: .trailing)
        }
        .frame(minHeight: 36)
        .padding(.vertical, 4)
    }

    private var bridgedBinding: Binding<Color> {
        Binding(
            get: { PlatformColorBridge.swiftUI(from: value) },
            set: { value = PlatformColorBridge.platform(from: $0) }
        )
    }

    private var hexString: String {
        PlatformColorBridge.hexString(from: value)
    }
}

// MARK: - Char-set (Set<Character>)

struct CharSetRow: View {
    @Environment(\.codeEditorTheme) private var theme
    let label: String
    @Binding var value: Set<Character>
    @State private var editing: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            KnobLabelCell(
                icon: KnobIcon.symbol(for: label),
                label: KnobLabel.humanize(label)
            )
            TextField("comma-separated", text: $editing)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .padding(.leading, 28)
                .onSubmit { commit() }
                .onAppear { editing = render(value) }
                .onChange(of: value) { _, newValue in editing = render(newValue) }
        }
        .padding(.vertical, 6)
    }

    private func commit() {
        let parsed = editing
            .split(separator: ",")
            .compactMap { token -> Character? in
                let trimmed = token.trimmingCharacters(in: .whitespaces)
                return trimmed.first
            }
        value = Set(parsed)
    }

    private func render(_ set: Set<Character>) -> String {
        set.map { String($0) }.sorted().joined(separator: ",")
    }
}

// MARK: - Duration

struct DurationRow: View {
    let label: String
    @Binding var value: Duration
    let rangeMS: ClosedRange<Double>

    var body: some View {
        SliderRow(
            label: label,
            value: Binding(
                get: { Self.milliseconds(value) },
                set: { value = .milliseconds(Int($0)) }
            ),
            range: rangeMS,
            step: 1,
            format: .number.precision(.fractionLength(0))
        )
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        duration.totalMilliseconds
    }
}

// MARK: - Helpers — Color ↔ PlatformColor bridge

enum PlatformColorBridge {
    static func swiftUI(from platform: PlatformColor) -> Color {
        #if canImport(AppKit)
        return Color(nsColor: platform)
        #else
        return Color(uiColor: platform)
        #endif
    }

    static func platform(from color: Color) -> PlatformColor {
        PlatformColor(color)
    }

    /// Renders a `PlatformColor` as `#RRGGBB` (alpha dropped) for compact display
    /// next to a swatch. Falls back to `#000000` when component extraction fails.
    static func hexString(from platform: PlatformColor) -> String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #if canImport(AppKit)
        let resolved = platform.usingColorSpace(.sRGB) ?? platform
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #else
        platform.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif

        let redByte = Int((red * 255).rounded())
        let greenByte = Int((green * 255).rounded())
        let blueByte = Int((blue * 255).rounded())
        return String(format: "#%02X%02X%02X", redByte, greenByte, blueByte)
    }
}
