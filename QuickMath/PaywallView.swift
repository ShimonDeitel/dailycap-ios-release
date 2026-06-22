import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    private let benefits: [(icon: String, text: String)] = [
        ("calendar.badge.checkmark", "Calendar heat-grid of under/over days and weekly averages"),
        ("slider.horizontal.3", "Adjustable caps by weekday plus streak-freeze tokens"),
        ("bell.badge", "Daily check-in reminder, trend insights, and CSV export")
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                ScrollView {
                    VStack(spacing: 28) {
                        // Icon
                        Image(systemName: "speedometer")
                            .font(.system(size: 56))
                            .foregroundStyle(Color.qmAccent)
                            .padding(.top, 24)

                        // Title
                        VStack(spacing: 6) {
                            Text("Daily Cap Pro")
                                .font(.title.weight(.bold))
                            Text("\(store.displayPrice) / month. Auto-renews until you cancel.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Benefits
                        VStack(spacing: 14) {
                            ForEach(benefits, id: \.text) { benefit in
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: benefit.icon)
                                        .foregroundStyle(Color.qmAccent)
                                        .font(.title3)
                                        .frame(width: 28)
                                    Text(benefit.text)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                        }
                        .qmCard()
                        .padding(.horizontal)

                        // Purchase button
                        Button {
                            Task {
                                await store.purchase()
                            }
                        } label: {
                            Group {
                                if store.purchaseInFlight {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Unlock Pro — \(store.displayPrice)/mo")
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .prominentButton()
                        .padding(.horizontal)
                        .disabled(store.purchaseInFlight)

                        // Restore
                        Button("Restore Purchase") {
                            Task { await store.restore() }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.qmAccent)

                        // Auto-renew disclosure
                        VStack(spacing: 8) {
                            Text("Daily Cap Pro is an auto-renewable subscription at \(store.displayPrice) per month. Payment will be charged to your Apple ID at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. Manage or cancel in App Store account settings.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            HStack(spacing: 16) {
                                Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                    .font(.caption2)
                                    .foregroundStyle(Color.qmAccent)
                                Link("Privacy", destination: URL(string: "https://shimondeitel.github.io/dailycap-site/privacy.html")!)
                                    .font(.caption2)
                                    .foregroundStyle(Color.qmAccent)
                            }
                        }
                        .padding(.horizontal)

                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
        }
        .onChange(of: store.isPro) { _, newValue in
            if newValue { dismiss() }
        }
    }
}
