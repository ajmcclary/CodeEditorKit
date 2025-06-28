import SwiftUI

// MARK: - SafeButton

/// A safe button wrapper that avoids concurrency crashes on macOS 26.0 beta
struct SafeButton<Label: View>: View {
    let action: () -> Void
    let label: () -> Label
    
    init(action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.label = label
    }
    
    var body: some View {
        label()
            .contentShape(Rectangle())
            .onTapGesture {
                // Execute action synchronously on main thread
                // This avoids the SwiftUI button gesture crash
                action()
            }
    }
}

/// Convenience init for simple image buttons
extension SafeButton where Label == Image {
    init(systemName: String, action: @escaping () -> Void) {
        self.init(action: action) {
            Image(systemName: systemName)
        }
    }
}

// MARK: - SafeToggle

/// A safe toggle that avoids SwiftUI Toggle concurrency crashes
struct SafeToggle: View {
    let title: String
    @Binding var isOn: Bool
    let style: SafeToggleStyle
    
    enum SafeToggleStyle {
        case checkmark
        case `switch`
    }
    
    init(_ title: String, isOn: Binding<Bool>, style: SafeToggleStyle = .checkmark) {
        self.title = title
        self._isOn = isOn
        self.style = style
    }
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            
            switch style {
            case .checkmark:
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isOn ? .accentColor : .secondary)
                    .font(.system(size: 16))
                    
            case .switch:
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isOn ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 32, height: 18)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .offset(x: isOn ? 7 : -7)
                        .animation(.easeInOut(duration: 0.2), value: isOn)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isOn.toggle()
            }
        }
    }
}

// MARK: - SafeSlider

/// A safe slider wrapper that provides smoother updates
struct SafeSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let formatter: (Double) -> String
    
    init(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1.0,
        formatter: @escaping (Double) -> String = { "\($0)" }
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.formatter = formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(formatter(value))
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            Slider(value: $value, in: range, step: step)
                .tint(.accentColor)
        }
    }
}

/// Alternative SafeToggle that looks like a traditional toggle switch
struct SafeToggleSwitch: View {
    let title: String
    @Binding var isOn: Bool
    
    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            
            // Custom switch-like appearance with tap gesture
            RoundedRectangle(cornerRadius: 16)
                .fill(isOn ? Color.accentColor : Color.secondary.opacity(0.3))
                .frame(width: 32, height: 20)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 16, height: 16)
                        .offset(x: isOn ? 6 : -6)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isOn.toggle()
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOn.toggle()
            }
        }
    }
}

// MARK: - SafeToggle Extensions

extension SafeToggle {
    /// Create a SafeToggle with custom styling
    func toggleStyle<Style: ToggleStyle>(_ style: Style) -> some View {
        // For now, ignore the style since we're using custom implementation
        // This maintains API compatibility
        self
    }
}
