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
            // Quick toggles
            Toggle(isOn: $configuration.showLineNumbers) {
                Label("Line Numbers", systemImage: "number")
            }
            .toggleStyle(.button)
            .help("Toggle line numbers")

            Toggle(isOn: $configuration.showInvisibleCharacters) {
                Label("Invisibles", systemImage: "text.append")
            }
            .toggleStyle(.button)
            .help("Show invisible characters")

            Toggle(isOn: $configuration.highlightSelectedLine) {
                Label("Highlight Line", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            .toggleStyle(.button)
            .help("Highlight current line")

            Divider()
                .frame(height: 20)

            // Font size controls
            HStack(spacing: 4) {
                Button {
                    configuration.fontSize = max(10, configuration.fontSize - 1)
                } label: {
                    Image(systemName: "textformat.size.smaller")
                }
                .help("Decrease font size")

                Text("\(Int(configuration.fontSize))pt")
                    .font(.caption)
                    .frame(width: 35)
                    .monospacedDigit()

                Button {
                    configuration.fontSize = min(32, configuration.fontSize + 1)
                } label: {
                    Image(systemName: "textformat.size.larger")
                }
                .help("Increase font size")
            }

            Divider()
                .frame(height: 20)

            // View options
            Toggle(isOn: $showSplitView) {
                Label("Split View", systemImage: "rectangle.split.2x1")
            }
            .toggleStyle(.button)
            .help("Show split view to compare configurations")

            Spacer()

            // Performance indicator
            PerformanceIndicator()

            // Help button
            Button {
                showFeatureTour = true
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .help("Show feature tour")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        #if canImport(AppKit)
        .background(Color(NSColor.controlBackgroundColor))
        #else
        .background(Color(.systemGray6))
        #endif
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
