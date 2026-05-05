import CodeEditorDesignTokens
import CodeEditorPlugin
import SwiftUI

// MARK: - Toggle

struct ToggleRow: View {
    let label: String
    @Binding var value: Bool

    var body: some View {
        Toggle(isOn: $value) { Text(label).font(.system(size: 11)) }
            .toggleStyle(.switch)
            .controlSize(.mini)
    }
}

// MARK: - Stepper (Int)

struct StepperRow: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        HStack {
            Text(label).font(.system(size: 11))
            Spacer()
            Stepper(value: $value, in: range, step: step) {
                Text("\(value)").font(.system(size: 11, design: .monospaced))
            }
            .controlSize(.mini)
            .labelsHidden()
            Text("\(value)")
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 56, alignment: .trailing)
        }
    }
}

// MARK: - Slider (Double)

struct SliderRow: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 0
    var format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(2))

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.system(size: 11))
                Spacer()
                Text(value, format: format).font(.system(size: 11, design: .monospaced))
            }
            if step > 0 {
                Slider(value: $value, in: range, step: step)
            } else {
                Slider(value: $value, in: range)
            }
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
    let label: String
    @Binding var value: T
    let cases: [T]
    let display: (T) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .semibold))
            Picker(label, selection: $value) {
                ForEach(cases, id: \.self) { item in
                    Text(display(item)).tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
    }
}

// MARK: - Color (PlatformColor)

struct ColorRow: View {
    let label: String
    @Binding var value: PlatformColor

    var body: some View {
        HStack {
            Text(label).font(.system(size: 11))
            Spacer()
            ColorPicker(label, selection: bridgedBinding, supportsOpacity: true)
                .labelsHidden()
        }
    }

    private var bridgedBinding: Binding<Color> {
        Binding(
            get: { PlatformColorBridge.swiftUI(from: value) },
            set: { value = PlatformColorBridge.platform(from: $0) }
        )
    }
}

// MARK: - Char-set (Set<Character>)

struct CharSetRow: View {
    let label: String
    @Binding var value: Set<Character>
    @State private var editing: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 11, weight: .semibold))
            TextField("comma-separated", text: $editing)
                .font(.system(size: 11, design: .monospaced))
                .textFieldStyle(.roundedBorder)
                .onSubmit { commit() }
                .onAppear { editing = render(value) }
                .onChange(of: value) { _, newValue in editing = render(newValue) }
        }
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

    /// Duration → milliseconds as Double.
    private static func milliseconds(_ duration: Duration) -> Double {
        let attos = duration.components.attoseconds
        let seconds = Double(duration.components.seconds)
        return seconds * 1_000 + Double(attos) / 1_000_000_000_000_000
    }
}

// MARK: - Helpers — Color ↔ PlatformColor bridge

private enum PlatformColorBridge {
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
}
