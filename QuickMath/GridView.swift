import SwiftUI

/// Primary entry / action screen — shown when user taps a quick-action from a widget or notification.
/// Provides a focused single-field spend entry and the current cap status.
struct GridView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var spendText: String = ""
    @State private var done = false

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                VStack(spacing: 32) {
                    Spacer()

                    // Big spend amount entry
                    VStack(spacing: 8) {
                        Text("Enter today's total spend")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("$")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.secondary)
                            TextField("0", text: $spendText)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 56, weight: .bold))
                                .minimumScaleFactor(0.5)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 220)
                        }

                        if let cap = Double(spendText.replacingOccurrences(of: ",", with: ".")) {
                            let activeCapVal = appModel.activeCap
                            let under = cap <= activeCapVal
                            HStack(spacing: 6) {
                                Image(systemName: under ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(under ? Color.qmCorrect : Color.qmWrong)
                                Text(under
                                     ? String(format: "$%.2f under cap", activeCapVal - cap)
                                     : String(format: "$%.2f over cap", cap - activeCapVal))
                                    .foregroundStyle(under ? Color.qmCorrect : Color.qmWrong)
                                    .font(.subheadline.weight(.medium))
                            }
                            .animation(.easeInOut(duration: 0.2), value: under)
                        }
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                    .background(Color.qmCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal)

                    // Streak status
                    HStack(spacing: 12) {
                        MetricTile(value: "\(appModel.streak.currentStreak)", label: "Streak")
                        MetricTile(value: "\(appModel.streak.longestStreak)", label: "Best")
                    }
                    .padding(.horizontal)

                    // Action buttons
                    VStack(spacing: 12) {
                        Button {
                            submitSpend()
                        } label: {
                            HStack {
                                if done {
                                    Image(systemName: "checkmark")
                                    Text("Checked In")
                                } else {
                                    Text("Check In")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .prominentButton()
                        .disabled(spendText.isEmpty || done)

                        Button("Cancel") { dismiss() }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .navigationTitle("Quick Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
        }
        .onAppear {
            if let existing = appModel.todayLog {
                spendText = String(format: "%.2f", existing.spent)
            }
        }
    }

    private func submitSpend() {
        guard let amount = Double(spendText.replacingOccurrences(of: ",", with: ".")) else { return }
        appModel.logSpend(amount)
        Haptics.success()
        done = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            dismiss()
        }
    }
}
