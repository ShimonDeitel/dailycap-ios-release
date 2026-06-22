import SwiftUI
import SwiftData

struct HomeView: View {
    var forceScreen: String? = nil

    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store

    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showInsights = false
    @State private var showCapEditor = false

    var body: some View {
        ZStack {
            QMBackground()

            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily Cap")
                                .font(.largeTitle.weight(.bold))
                            Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.title2)
                                .foregroundStyle(Color.qmAccent)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Today's status card
                    TodayStatusCard(showCapEditor: $showCapEditor)

                    // Streak tile row
                    HStack(spacing: 12) {
                        MetricTile(
                            value: "\(appModel.streak.currentStreak)",
                            label: "Streak"
                        )
                        MetricTile(
                            value: "\(appModel.streak.longestStreak)",
                            label: "Best"
                        )
                        MetricTile(
                            value: String(format: "$%.0f", appModel.activeCap),
                            label: "Cap"
                        )
                    }
                    .padding(.horizontal)

                    // Check-in entry
                    CheckInCard()

                    // Pro insights tile
                    Button {
                        if store.isPro {
                            showInsights = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: store.isPro ? "chart.bar.fill" : "lock.fill")
                                .foregroundStyle(Color.qmAccent)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("History & Insights")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(store.isPro ? "Tap to view trends" : "Unlock with Pro")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .qmCard()
                        .padding(.horizontal)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 32)
                }
                .padding(.top)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appModel)
                .environmentObject(store)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showInsights) {
            InsightsView()
                .environmentObject(appModel)
                .environmentObject(store)
        }
        .sheet(isPresented: $showCapEditor) {
            CapEditorSheet()
                .environmentObject(appModel)
        }
        .onAppear {
            if forceScreen == "insights" { showInsights = true }
            if forceScreen == "paywall" { showPaywall = true }
        }
    }
}

// MARK: - Today status card

private struct TodayStatusCard: View {
    @EnvironmentObject var appModel: AppModel
    @Binding var showCapEditor: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Gauge visual
            GaugeView(
                spent: appModel.todayLog?.spent ?? 0,
                cap: appModel.activeCap
            )
            .frame(height: 140)

            if let log = appModel.todayLog {
                let under = log.underCap
                HStack(spacing: 8) {
                    Image(systemName: under ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(under ? Color.qmCorrect : Color.qmWrong)
                        .font(.title2)
                    Text(under ? "Under cap — nice!" : "Over cap today")
                        .font(.headline)
                        .foregroundStyle(under ? Color.qmCorrect : Color.qmWrong)
                }
            } else {
                Text("Log your spend below to check in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                showCapEditor = true
            } label: {
                Text("Edit cap")
                    .font(.caption)
                    .foregroundStyle(Color.qmAccent)
            }
        }
        .qmCard()
        .padding(.horizontal)
    }
}

// MARK: - Gauge View (speedometer style)

private struct GaugeView: View {
    let spent: Double
    let cap: Double

    private var ratio: Double {
        guard cap > 0 else { return 0 }
        return min(spent / cap, 1.5)
    }

    private var needleAngle: Double {
        // -130 degrees (empty) to +130 degrees (full/over)
        return -130 + (ratio * 260)
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.85)
            let radius = size * 0.42

            ZStack {
                // Arc track
                ArcShape(startAngle: -220, endAngle: -320, clockwise: false)
                    .stroke(Color.qmCard2, lineWidth: 10)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                // Filled arc
                ArcShape(startAngle: -220, endAngle: -220 + (ratio * 260), clockwise: false)
                    .stroke(ratio > 1.0 ? Color.qmWrong : Color.qmAccent, lineWidth: 10)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                // Cap line tick
                TickMark(center: center, radius: radius, angle: -90, length: 14)
                    .stroke(Color.qmAccent, lineWidth: 2)

                // Needle
                NeedleShape(center: center, radius: radius * 0.85, angle: needleAngle - 90)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))

                // Center dot
                Circle()
                    .fill(Color.qmAccent)
                    .frame(width: 10, height: 10)
                    .position(center)

                // Labels
                VStack(spacing: 2) {
                    Text(String(format: "$%.2f", spent))
                        .font(.title2.weight(.bold))
                    Text("of $\(Int(cap)) cap")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .position(x: geo.size.width / 2, y: center.y - radius * 0.3)
            }
        }
    }
}

private struct ArcShape: Shape {
    var startAngle: Double
    var endAngle: Double
    var clockwise: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        p.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: clockwise
        )
        return p
    }
}

private struct NeedleShape: Shape {
    var center: CGPoint
    var radius: CGFloat
    var angle: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let rad = angle * .pi / 180
        let tip = CGPoint(
            x: center.x + cos(rad) * radius,
            y: center.y + sin(rad) * radius
        )
        p.move(to: center)
        p.addLine(to: tip)
        return p
    }
}

private struct TickMark: Shape {
    var center: CGPoint
    var radius: CGFloat
    var angle: Double
    var length: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let rad = angle * .pi / 180
        let outer = CGPoint(
            x: center.x + cos(rad) * (radius + length / 2),
            y: center.y + sin(rad) * (radius + length / 2)
        )
        let inner = CGPoint(
            x: center.x + cos(rad) * (radius - length / 2),
            y: center.y + sin(rad) * (radius - length / 2)
        )
        p.move(to: inner)
        p.addLine(to: outer)
        return p
    }
}

// MARK: - Check-in card

private struct CheckInCard: View {
    @EnvironmentObject var appModel: AppModel
    @State private var spendText: String = ""
    @State private var submitted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Spend")
                .font(.headline)
            HStack {
                Text("$")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("0.00", text: $spendText)
                    .keyboardType(.decimalPad)
                    .font(.title3)
                    .onAppear {
                        if let log = appModel.todayLog {
                            spendText = String(format: "%.2f", log.spent)
                        }
                    }
            }
            .padding(12)
            .background(Color.qmField, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                guard let amount = Double(spendText.replacingOccurrences(of: ",", with: ".")) else { return }
                appModel.logSpend(amount)
                Haptics.success()
                submitted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { submitted = false }
            } label: {
                HStack {
                    if submitted {
                        Image(systemName: "checkmark")
                    } else {
                        Text("Check In")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .prominentButton()
            .disabled(spendText.isEmpty)
        }
        .qmCard()
        .padding(.horizontal)
    }
}

// MARK: - Cap editor sheet

struct CapEditorSheet: View {
    @EnvironmentObject var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var capText: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Set your daily spending cap.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("$")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("50", text: $capText)
                        .keyboardType(.decimalPad)
                        .font(.title2)
                }
                .padding(14)
                .background(Color.qmField, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button("Save Cap") {
                    if let val = Double(capText.replacingOccurrences(of: ",", with: ".")), val > 0 {
                        appModel.setDailyCap(val)
                        Haptics.tap()
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity)
                .prominentButton()

                Spacer()
            }
            .padding()
            .navigationTitle("Daily Cap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            capText = String(format: "%.0f", appModel.activeCap)
        }
    }
}
