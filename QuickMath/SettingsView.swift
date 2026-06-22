import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("quickmath.theme") private var themeRaw = AppTheme.system.rawValue
    @State private var showPaywall = false
    @State private var showDeleteConfirm = false

    private var theme: AppTheme {
        get { AppTheme(rawValue: themeRaw) ?? .system }
        set { themeRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                QMBackground()
                List {
                    // Pro status
                    Section {
                        if store.isPro {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(Color.qmAccent)
                                Text("Daily Cap Pro — Active")
                                    .font(.headline)
                            }
                            Link("Manage Subscription",
                                 destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                                .foregroundStyle(Color.qmAccent)
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    Image(systemName: "speedometer")
                                        .foregroundStyle(Color.qmAccent)
                                    Text("Unlock Daily Cap Pro")
                                        .font(.headline)
                                        .foregroundStyle(Color.qmAccent)
                                }
                            }
                            Button("Restore Purchase") {
                                Task { await store.restore() }
                            }
                            .foregroundStyle(Color.qmAccent)
                        }
                    } header: {
                        Text("Subscription")
                    }

                    // Appearance
                    Section {
                        Picker("Appearance", selection: Binding(
                            get: { AppTheme(rawValue: themeRaw) ?? .system },
                            set: { themeRaw = $0.rawValue }
                        )) {
                            ForEach(AppTheme.allCases) { t in
                                Text(t.label).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                    } header: {
                        Text("Appearance")
                    }

                    // Links
                    Section {
                        Link("Privacy Policy",
                             destination: URL(string: "https://shimondeitel.github.io/dailycap-site/privacy.html")!)
                            .foregroundStyle(Color.qmAccent)
                        Link("Terms of Use",
                             destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                            .foregroundStyle(Color.qmAccent)
                    } header: {
                        Text("Legal")
                    }

                    // Danger zone
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete All Data", systemImage: "trash")
                        }
                    } header: {
                        Text("Data")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.qmAccent)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(store)
        }
        .confirmationDialog(
            "Delete all data?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                appModel.deleteAllData()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase all logs, caps, and your streak. This action cannot be undone.")
        }
    }
}
