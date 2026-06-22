import SwiftUI
import Charts

/// Pro feature: history heat-grid, weekly averages, streak-freeze info, CSV export.
struct InsightsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var showExportSheet = false
    @State private var exportText = ""

    private var last30: [DayLog] {
        Array(appModel.allLogs.prefix(30))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        // Summary metrics
                        HStack(spacing: 12) {
                            MetricTile(
                                value: "\(appModel.streak.currentStreak)",
                                label: "Current Streak"
                            )
                            MetricTile(
                                value: "\(appModel.streak.longestStreak)",
                                label: "Best Streak"
                            )
                            MetricTile(
                                value: String(format: "%.0f%%", appModel.underCapRatio * 100),
                                label: "Under Cap"
                            )
                        }
                        .padding(.horizontal)

                        // Weekly average
                        VStack(alignment: .leading, spacing: 8) {
                            Text("7-Day Average Spend")
                                .font(.headline)
                            Text(String(format: "$%.2f / day", appModel.weeklyAverage))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(
                                    appModel.weeklyAverage <= appModel.activeCap
                                    ? Color.qmCorrect
                                    : Color.qmWrong
                                )

                            if !last30.isEmpty {
                                Chart {
                                    ForEach(Array(last30.reversed())) { log in
                                        BarMark(
                                            x: .value("Date", log.date, unit: .day),
                                            y: .value("Spent", log.spent)
                                        )
                                        .foregroundStyle(
                                            log.underCap ? Color.qmAccent.opacity(0.8) : Color.qmWrong.opacity(0.8)
                                        )
                                    }
                                    RuleMark(y: .value("Cap", appModel.activeCap))
                                        .foregroundStyle(Color.qmAccent)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                                        .annotation(position: .top, alignment: .trailing) {
                                            Text("Cap")
                                                .font(.caption2)
                                                .foregroundStyle(Color.qmAccent)
                                        }
                                }
                                .frame(height: 160)
                                .chartXAxis {
                                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                                        AxisGridLine()
                                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                    }
                                }
                            } else {
                                Text("No data yet — start logging daily spend.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(height: 80)
                            }
                        }
                        .qmCard()
                        .padding(.horizontal)

                        // Calendar heat-grid (last 30 days)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Last 30 Days")
                                .font(.headline)

                            let chunks = Array(last30.reversed()).chunked(into: 7)
                            VStack(spacing: 6) {
                                ForEach(Array(chunks.enumerated()), id: \.offset) { _, week in
                                    HStack(spacing: 6) {
                                        ForEach(week) { log in
                                            HeatCell(log: log)
                                        }
                                    }
                                }
                            }
                        }
                        .qmCard()
                        .padding(.horizontal)

                        // Export
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Export")
                                .font(.headline)
                            Text("Download a CSV of all your daily logs.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Export CSV") {
                                exportText = buildCSV()
                                showExportSheet = true
                            }
                            .softButton()
                        }
                        .qmCard()
                        .padding(.horizontal)

                        Spacer(minLength: 32)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("History & Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ShareSheet(text: exportText)
            }
        }
    }

    private func buildCSV() -> String {
        var lines = ["Date,Spent,Cap,Under Cap"]
        let formatter = ISO8601DateFormatter()
        for log in appModel.allLogs {
            let date = formatter.string(from: log.date)
            lines.append("\(date),\(log.spent),\(log.capAmount),\(log.underCap ? "Yes" : "No")")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Heat cell

private struct HeatCell: View {
    let log: DayLog

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(log.underCap ? Color.qmCorrect.opacity(0.7) : Color.qmWrong.opacity(0.6))
                .frame(width: 34, height: 34)
            Text(dayLabel(log.date))
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let cal = Calendar.current
        return "\(cal.component(.day, from: date))"
    }
}

// MARK: - Share sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Array chunk helper

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
