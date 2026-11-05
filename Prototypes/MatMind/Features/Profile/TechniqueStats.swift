import SwiftUI
import Charts

/// Personal technique counts only: shown after the first saved technique log.
/// The same cards work below the interactive and read-only rhythm heatmaps.
struct TechniqueStatsSection: View {
    @Environment(AppModel.self) private var mm
    var inCard = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let history = TechniqueTrendHistory(logs: mm.quickLogs, hitsByID: mm.quickLogHitsByID, now: context.date)
            if !history.trends.isEmpty {
                VStack(alignment: .leading, spacing: MMSpace.s5) {
                    Text("Techniques").mmFont(.display, 18).foregroundStyle(MMColor.textPrimary)
                    legend
                    ForEach(history.trends) { trend in
                        TechniqueTrendCard(trend: trend, currentDayIndex: history.currentDayIndex)
                    }
                }
                .padding(.horizontal, inCard ? 0 : MMSpace.s6)
                .padding(.top, inCard ? 0 : MMSpace.s6)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: MMSpace.s6) {
            HStack(spacing: MMSpace.s3) {
                Capsule().fill(MMColor.accent).frame(width: MMSpace.s6, height: MMSpace.s1)
                Text("This week")
            }
            HStack(spacing: MMSpace.s3) {
                HStack(spacing: MMSpace.s1) {
                    ForEach(0..<3) { _ in
                        Capsule().fill(MMColor.ink400).frame(width: MMSpace.s2, height: MMSpace.s1)
                    }
                }
                Text("Last week")
            }
        }
        .mmFont(.body, 12)
        .foregroundStyle(MMColor.textSecondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week is solid coral. Last week is dashed.")
    }
}

private struct TechniqueTrendCard: View {
    let trend: TechniqueTrend
    let currentDayIndex: Int

    private var yCeiling: Double {
        let peak = max(trend.thisWeek.max() ?? 0, trend.lastWeek.max() ?? 0)
        return max(2, ceil(Double(peak) / 2) * 2)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MMSpace.s6) {
            HStack(alignment: .top, spacing: MMSpace.s5) {
                Text(trend.name)
                    .mmFont(.display, 18)
                    .foregroundStyle(MMColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: MMSpace.s2) {
                    Text("\(trend.thisWeekTotal) \(trend.thisWeekTotal == 1 ? "hit" : "hits") this week")
                        .mmFont(.body, 13, .semibold).foregroundStyle(MMColor.textPrimary)
                    Text("\(trend.lastWeekTotal) last week")
                        .mmFont(.body, 12).foregroundStyle(MMColor.textTertiary)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            chart
                .frame(height: MMLayout.tapTarget * 3)
                .accessibilityLabel("\(trend.name), daily hits, Monday to Sunday")
                .accessibilityValue("\(trend.thisWeekTotal) hits so far this week; \(trend.lastWeekTotal) last week. This week stops at today.")
        }
        .padding(MMSpace.s6)
        .mmCardSurface()
        .accessibilityElement(children: .contain)
    }

    private var chart: some View {
        Chart {
            ForEach(0..<7, id: \.self) { day in
                LineMark(x: .value("Day", day), y: .value("Hits", trend.lastWeek[day]), series: .value("Week", "Last week"))
                    .foregroundStyle(MMColor.ink400)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 4]))
                    .interpolationMethod(.linear)
            }
            ForEach(0...currentDayIndex, id: \.self) { day in
                LineMark(x: .value("Day", day), y: .value("Hits", trend.thisWeek[day]), series: .value("Week", "This week"))
                    .foregroundStyle(MMColor.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.linear)
            }
            PointMark(x: .value("Day", currentDayIndex), y: .value("Hits", trend.thisWeek[currentDayIndex]))
                .foregroundStyle(MMColor.accent)
                .symbolSize(MMSpace.s8)
        }
        .chartXScale(domain: 0...6)
        .chartYScale(domain: 0...yCeiling)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: Array(0...6)) { value in
                AxisValueLabel {
                    if let day = value.as(Int.self), (0..<7).contains(day) {
                        Text(["M", "T", "W", "T", "F", "S", "S"][day])
                            .font(MMFont.body(11)).foregroundStyle(MMColor.textTertiary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, yCeiling / 2, yCeiling]) { value in
                AxisGridLine().foregroundStyle(MMColor.borderSubtle)
                AxisValueLabel {
                    if let count = value.as(Double.self) {
                        Text(count.formatted(.number.precision(.fractionLength(0))))
                            .font(MMFont.body(11)).foregroundStyle(MMColor.textTertiary)
                    }
                }
            }
        }
    }
}
