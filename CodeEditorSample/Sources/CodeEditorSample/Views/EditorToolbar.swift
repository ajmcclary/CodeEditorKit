import CodeEditorPlugin
import SwiftUI
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)  
import UIKit
#endif

// MARK: - EditorToolbar

struct EditorToolbar: View {
    @Binding var configuration: EditorConfiguration
    @Binding var showSplitView: Bool
    @Binding var showFeatureTour: Bool

    var body: some View {
        HStack {
            // Quick toggles - using SafeToggle to avoid MainActor crashes
            SafeToggle("Line Numbers", isOn: $configuration.display.showLineNumbers)
            SafeToggle("Invisible Characters", isOn: $configuration.display.showInvisibleCharacters)
            SafeToggle("Highlight Line", isOn: $configuration.display.highlightSelectedLine)

            Divider()
                .frame(height: 20)

            // Font size controls - using SafeButton to avoid MainActor crashes
            HStack(spacing: 4) {
                SafeButton(action: {
                    configuration.display.fontSize = max(10, configuration.display.fontSize - 1)
                }) {
                    Image(systemName: "textformat.size.smaller")
                        .foregroundColor(.accentColor)
                        .padding(4)
                }

                Text("\(Int(configuration.display.fontSize))pt")
                    .font(.caption)
                    .frame(width: 35)
                    .monospacedDigit()

                SafeButton(action: {
                    configuration.display.fontSize = min(32, configuration.display.fontSize + 1)
                }) {
                    Image(systemName: "textformat.size.larger")
                        .foregroundColor(.accentColor)
                        .padding(4)
                }
            }

            Divider()
                .frame(height: 20)

            // View options
            SafeToggle("Split View", isOn: $showSplitView)

            Spacer()

            // Performance indicator
            PerformanceIndicator()

            // Help button
            SafeButton(action: {
                showFeatureTour = true
            }) {
                Image(systemName: "questionmark.circle")
                    .foregroundColor(.accentColor)
                    .padding(4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(PlatformColors.controlBackground))
    }
}

// MARK: - PerformanceIndicator

struct PerformanceIndicator: View {
    @State private var memoryUsage: String = "0 MB"
    @State private var cpuUsage: String = "0%"

    let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            Label(cpuUsage, systemImage: "cpu")
                .font(.caption)
                .foregroundColor(.secondary)

            Label(memoryUsage, systemImage: "memorychip")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onReceive(timer) { _ in
            updatePerformanceMetrics()
        }
    }

    private func updatePerformanceMetrics() {
        // Get memory usage
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if result == KERN_SUCCESS {
            let usedMemoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            memoryUsage = String(format: "%.0f MB", usedMemoryMB)
        }

        // Simplified CPU usage (this is just for demonstration)
        cpuUsage = "~1%"
    }
}
