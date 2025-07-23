import Foundation
import SwiftUI

// MARK: - Performance Status View

/// Performance status indicator view
public struct PerformanceStatusView: View {
    @ObservedObject var insights: PerformanceInsights

    public init(insights: PerformanceInsights) {
        self.insights = insights
    }

    public var body: some View {
        HStack {
            Circle()
                .fill(insights.status.color)
                .frame(width: 8, height: 8)

            Text(insights.status.description)
                .font(.caption)
                .foregroundColor(.secondary)

            if !insights.issues.isEmpty {
                Text("(\(insights.issues.count) issues)")
                    .font(.caption)
                    .foregroundColor(insights.status.color)
            }
        }
    }
}

// MARK: - Performance Insights Panel

/// Performance insights panel
public struct PerformanceInsightsPanel: View {
    @ObservedObject var insights: PerformanceInsights
    @State private var showingDetailedReport = false

    public init(insights: PerformanceInsights) {
        self.insights = insights
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            metricsSection

            if !insights.issues.isEmpty {
                Divider()
                issuesSection
            }

            if !insights.recommendations.isEmpty {
                Divider()
                recommendationsSection
            }

            Divider()
            actionsSection
        }
        .padding()
        .background(Color(PlatformColors.controlBackground))
        .cornerRadius(8)
        .sheet(isPresented: $showingDetailedReport) {
            DetailedPerformanceReportView(insights: insights)
        }
    }

    private var headerSection: some View {
        HStack {
            Text("Performance Insights")
                .font(.headline)
            Spacer()
            PerformanceStatusView(insights: insights)
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetricRow(label: "CPU", value: "\(Int(insights.metrics.cpuUsage))%")
            MetricRow(label: "Memory", value: String(format: "%.1f GB", insights.metrics.memoryUsage))
            MetricRow(label: "FPS", value: "\(insights.metrics.currentFPS)")
            MetricRow(label: "Response", value: String(format: "%.0f ms", insights.metrics.averageResponseTime * 1_000))
        }
        .padding(.vertical, 4)
    }

    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active Issues")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(insights.issues) { issue in
                IssueRow(issue: issue)
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recommendations")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(insights.recommendations.prefix(3)) { recommendation in
                RecommendationRow(recommendation: recommendation)
            }
        }
    }

    private var actionsSection: some View {
        HStack {
            Button("Detailed Report") {
                showingDetailedReport = true
            }
            .font(.caption)

            Spacer()

            Button("Reset") {
                insights.reset()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
    }
}

// MARK: - Helper Views

private struct IssueRow: View {
    let issue: InsightsPerformanceIssue

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(issue.severity == .critical ? .red : .orange)
                .font(.caption)

            Text(issue.description)
                .font(.caption)
                .lineLimit(2)
        }
    }
}

private struct RecommendationRow: View {
    let recommendation: InsightsPerformanceRecommendation

    var body: some View {
        HStack {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
                .font(.caption)

            Text(recommendation.title)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

// MARK: - Metric Row

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.caption.monospacedDigit())
        }
    }
}

// MARK: - Detailed Performance Report

/// Detailed performance report view
public struct DetailedPerformanceReportView: View {
    @ObservedObject var insights: PerformanceInsights
    @Environment(\.dismiss) private var dismiss

    public init(insights: PerformanceInsights) {
        self.insights = insights
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    performanceStatusSection
                    Divider()
                    metricsSection

                    if !insights.issues.isEmpty {
                        Divider()
                        issuesSection
                    }

                    if !insights.recommendations.isEmpty {
                        Divider()
                        recommendationsSection
                    }
                }
                .padding()
            }
            .navigationTitle("Performance Report")
            #if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            #endif
        }
    }

    @ViewBuilder
    private var performanceStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Overall Performance")
                .font(.headline)

            HStack {
                Circle()
                    .fill(insights.status.color)
                    .frame(width: 16, height: 16)

                Text(insights.status.description)
                    .font(.body)
            }
        }
    }

    @ViewBuilder
    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Real-Time Metrics")
                .font(.headline)

            DetailedMetricRow(label: "CPU Usage", value: "\(Int(insights.metrics.cpuUsage))%", color: cpuColor(insights.metrics.cpuUsage))
            DetailedMetricRow(label: "Memory Usage", value: String(format: "%.2f GB", insights.metrics.memoryUsage), color: memoryColor(insights.metrics.memoryUsage))
            DetailedMetricRow(label: "Frame Rate", value: "\(insights.metrics.currentFPS) FPS", color: fpsColor(insights.metrics.currentFPS))
            DetailedMetricRow(label: "Response Time", value: String(format: "%.0f ms", insights.metrics.averageResponseTime * 1_000), color: responseTimeColor(insights.metrics.averageResponseTime))
            DetailedMetricRow(label: "Active Operations", value: "\(insights.metrics.activeOperations)", color: .primary)
        }
    }

    @ViewBuilder
    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Issues")
                .font(.headline)

            ForEach(insights.issues) { issue in
                IssueDetailRow(issue: issue)
            }
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recommendations")
                .font(.headline)

            ForEach(insights.recommendations) { recommendation in
                RecommendationDetailRow(recommendation: recommendation)
            }
        }
    }

    private func cpuColor(_ usage: Double) -> Color {
        if usage > 80 { return .red }
        if usage > 60 { return .orange }
        return .green
    }

    private func memoryColor(_ usage: Double) -> Color {
        if usage > 1.5 { return .red }
        if usage > 1.0 { return .orange }
        return .green
    }

    private func fpsColor(_ fps: Int) -> Color {
        if fps < 30 { return .red }
        if fps < 45 { return .orange }
        return .green
    }

    private func responseTimeColor(_ time: Double) -> Color {
        if time > 0.1 { return .red }
        if time > 0.05 { return .orange }
        return .green
    }
}

// MARK: - Detail Row Components

private struct DetailedMetricRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

private struct IssueDetailRow: View {
    let issue: InsightsPerformanceIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)

                Text(issue.description)
                    .font(.body)
            }
        }
        .padding(.vertical, 4)
    }

    private var severityIcon: String {
        switch issue.severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    private var severityColor: Color {
        switch issue.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

private struct RecommendationDetailRow: View {
    let recommendation: InsightsPerformanceRecommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)

                Text(recommendation.title)
                    .font(.body)
                    .fontWeight(.medium)
            }

            Text(recommendation.actionDescription)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.leading, 28)
        }
        .padding(.vertical, 4)
    }
}
