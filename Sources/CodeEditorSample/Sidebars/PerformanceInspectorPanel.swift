#if canImport(AppKit)
import CodeEditorPlugin
import SwiftUI

/// Right-rail inspector surfacing live editor performance metrics.
/// Stateless view: all values arrive via init params, no internal `@State`.
struct PerformanceInspectorPanel: View {
    struct Thresholds: Sendable {
        var fpsTarget: Int
        var fpsGreenRatio: Double = 0.92
        var fpsAmberRatio: Double = 0.50
        var healthGreen: Double = 80
        var healthAmber: Double = 50
        var highlightGreenMs: Double = 16
        var highlightAmberMs: Double = 100

        static func `default`(fpsTarget: Int) -> Self {
            Self(fpsTarget: fpsTarget)
        }
    }

    let state: PerformanceSampleCoordinator.State
    let fps: Int
    let memoryStats: MemoryStatistics
    let pressure: MemoryPressure
    let adaptiveMode: PerformanceMode
    let lastHighlightMs: Double?
    let highlightP95Ms: Double?
    let healthScore: Double
    let issuesCount: Int
    let recommendationsCount: Int
    let memorySparkline: [Double]
    let thresholds: Thresholds
    let onResetPeak: () -> Void
    let onShowReport: () -> Void
    let onAppear: () -> Void
    let onDisappear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            adaptiveModeRow
            tileGrid
            pressureRow
            sparkline
            footer
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Performance").font(.headline)
                Spacer()
                statePill
            }
            Divider()
        }
    }

    private var statePill: some View {
        let isLive = state == .live
        return Text(isLive ? "● LIVE" : "STOPPED")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background((isLive ? Color.green : Color.gray).opacity(0.85))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }

    private var adaptiveModeRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles").foregroundStyle(adaptiveModeColor)
            Text("Adaptive: ").foregroundStyle(.secondary)
            Text(adaptiveModeLabel).fontWeight(.semibold).foregroundStyle(adaptiveModeColor)
            Spacer()
        }
        .font(.caption)
        .padding(8)
        .background(adaptiveModeColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var tileGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            MetricTile(
                label: "FPS",
                primary: "\(fps)",
                primaryColor: fpsColor
            )
            MetricTile(
                label: "Health",
                primary: "\(Int(healthScore))",
                primaryColor: healthColor
            )
            MetricTile(
                label: "Memory",
                primary: String(format: "%.0f", memoryStats.currentUsageMB),
                primaryUnit: "MB",
                secondary: "peak \(Int(memoryStats.peakUsageMB)) · avg \(Int(memoryStats.averageUsageMB))",
                trailingIcon: "arrow.counterclockwise",
                trailingAction: onResetPeak
            )
            MetricTile(
                label: "Highlight",
                primary: lastHighlightMs.map { String(format: "%.1f", $0) } ?? "—",
                primaryUnit: lastHighlightMs == nil ? nil : "ms",
                secondary: highlightP95Ms.map { String(format: "p95 %.1f ms", $0) },
                primaryColor: highlightColor
            )
        }
    }

    private var pressureRow: some View {
        HStack {
            Text("Memory pressure").foregroundStyle(.secondary)
            Spacer()
            Circle().fill(pressureColor).frame(width: 8, height: 8)
            Text(pressureLabel).fontWeight(.medium).foregroundStyle(pressureColor)
        }
        .font(.caption)
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private var sparkline: some View {
        if memorySparkline.count > 1 {
            VStack(alignment: .leading, spacing: 2) {
                Text("MEMORY · LAST \(memorySparkline.count) SAMPLES")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Canvas { context, size in
                    guard let maxValue = memorySparkline.max(), maxValue > 0 else { return }
                    let stepX = size.width / max(CGFloat(memorySparkline.count - 1), 1)
                    var path = Path()
                    for (index, value) in memorySparkline.enumerated() {
                        let xPoint = CGFloat(index) * stepX
                        let yPoint = size.height - (CGFloat(value / maxValue) * size.height)
                        if index == 0 {
                            path.move(to: CGPoint(x: xPoint, y: yPoint))
                        } else {
                            path.addLine(to: CGPoint(x: xPoint, y: yPoint))
                        }
                    }
                    context.stroke(path, with: .color(.accentColor), lineWidth: 1.5)
                }
                .frame(height: 32)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    private var footer: some View {
        HStack {
            Text("\(issuesCount) issues · \(recommendationsCount) recs")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(action: onShowReport) {
                Text("Report ›").font(.caption)
            }
            .buttonStyle(.link)
        }
        .padding(.top, 4)
    }

    // MARK: - Threshold-driven colors

    private var fpsColor: Color? {
        let target = Double(thresholds.fpsTarget)
        guard target > 0 else { return nil }
        let ratio = Double(fps) / target
        if ratio >= thresholds.fpsGreenRatio { return nil }
        if ratio >= thresholds.fpsAmberRatio { return .yellow }
        return .red
    }

    private var healthColor: Color? {
        if healthScore >= thresholds.healthGreen { return .green }
        if healthScore >= thresholds.healthAmber { return .yellow }
        return .red
    }

    private var highlightColor: Color? {
        guard let lastMs = lastHighlightMs else { return .secondary }
        if lastMs <= thresholds.highlightGreenMs { return nil }
        if lastMs <= thresholds.highlightAmberMs { return .yellow }
        return .red
    }

    private var adaptiveModeColor: Color {
        switch adaptiveMode {
        case .highQuality: return .blue
        case .balanced: return .orange
        case .performance: return .red
        }
    }

    private var adaptiveModeLabel: String {
        switch adaptiveMode {
        case .highQuality: return "High Quality"
        case .balanced: return "Balanced"
        case .performance: return "Performance"
        }
    }

    private var pressureColor: Color {
        switch pressure {
        case .normal: return .green
        case .warning: return .yellow
        case .urgent: return .orange
        case .critical: return .red
        }
    }

    private var pressureLabel: String {
        switch pressure {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .urgent: return "Urgent"
        case .critical: return "Critical"
        }
    }
}

private struct MetricTile: View {
    let label: String
    let primary: String
    var primaryUnit: String?
    var secondary: String?
    var primaryColor: Color?
    var trailingIcon: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                if let icon = trailingIcon, let action = trailingAction {
                    Button(action: action) {
                        Image(systemName: icon).font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(primary)
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .foregroundStyle(primaryColor ?? .primary)
                if let unit = primaryUnit {
                    Text(unit)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            if let secondary {
                Text(secondary)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}
#endif
