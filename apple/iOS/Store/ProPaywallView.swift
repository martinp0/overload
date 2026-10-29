import StoreKit
import SwiftUI

struct ProPaywallView: View {
    @EnvironmentObject private var pro: ProStore
    @Environment(\.dismiss) private var dismiss
    @State private var manage = false

    private let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    private let privacy = URL(string: "https://martinpohl.cz/en/overload/privacy")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label("Unlimited saved workouts (free: \(ProGate.freeTemplates))", systemImage: "bookmark")
                    Label("Your full history (free: last \(ProGate.freeHistoryMonths) months)", systemImage: "clock.arrow.circlepath")
                    Label("Supports an indie app with no ads and no tracking", systemImage: "heart")
                } header: {
                    Text("Overload Pro")
                } footer: {
                    Text("Older workouts are never deleted and are always included in Export backup.")
                }

                if pro.isPro {
                    Section {
                        Label("Overload Pro is active", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        if pro.activeProductID != ProGate.lifetimeID {
                            Button("Manage subscription") { manage = true }
                        }
                    }
                } else {
                    Section {
                        switch pro.state {
                        case .idle, .loading:
                            ProgressView()
                        case .failed:
                            Text("Couldn't load prices from the App Store.").foregroundStyle(.secondary)
                            Button("Try again") { Task { await pro.load() } }
                        case .loaded:
                            ForEach(pro.products, id: \.id) { p in
                                Button { Task { await pro.buy(p) } } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(p.displayName).font(.headline)
                                            if let intro = p.subscription?.introductoryOffer, intro.paymentMode == .freeTrial {
                                                Text("Free trial, then \(p.displayPrice)").font(.caption).foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if pro.purchasingID == p.id {
                                            ProgressView()
                                        } else {
                                            Text("\(p.displayPrice) \(ProStore.periodText(p))").bold()
                                        }
                                    }
                                }
                                .disabled(pro.purchasingID != nil)
                            }
                        }
                    }
                }

                Section {
                    Button("Restore purchases") { Task { await pro.restore() } }
                } footer: {
                    Text("Payment is charged to your Apple ID. Subscriptions renew automatically unless cancelled in your Apple ID settings at least 24 hours before the end of the current period. Lifetime is a one-time purchase.")
                }

                Section {
                    Link("Terms of Use (EULA)", destination: terms)
                    Link("Privacy Policy", destination: privacy)
                }
            }
            .navigationTitle("Overload Pro")
            .toolbar { Button("Close") { dismiss() } }
            .manageSubscriptionsSheet(isPresented: $manage)
            .task { if pro.state == .idle || pro.state == .failed { await pro.load() } }
            .alert(pro.notice ?? "", isPresented: Binding(get: { pro.notice != nil }, set: { if !$0 { pro.notice = nil } })) {
                Button("OK", role: .cancel) {}
            }
        }
    }
}
