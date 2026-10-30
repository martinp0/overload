import Foundation
import StoreKit

/// Overload Pro with StoreKit 2: monthly and yearly subscriptions plus a one-time lifetime unlock.
/// Prices, periods and trials come from the App Store; nothing is hard-coded.
@MainActor
final class ProStore: ObservableObject {
    enum LoadState: Equatable { case idle, loading, loaded, failed }

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var activeProductID: String?
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var purchasingID: String?
    @Published var notice: String?

    private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(result)
            }
        }
    }

    deinit { updates?.cancel() }

    func load() async {
        if state == .loading { return }
        state = .loading
        do {
            let found = try await Product.products(for: ProGate.productIDs)
            products = found.sorted { (ProGate.productIDs.firstIndex(of: $0.id) ?? 9) < (ProGate.productIDs.firstIndex(of: $1.id) ?? 9) }
            state = products.isEmpty ? .failed : .loaded
        } catch {
            state = .failed
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var active: String?
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, ProGate.productIDs.contains(t.productID), t.revocationDate == nil else { continue }
            if let exp = t.expirationDate, exp < Date() { continue }
            // Lifetime wins over a subscription for display.
            if active == nil || t.productID == ProGate.lifetimeID { active = t.productID }
        }
        activeProductID = active
        isPro = active != nil
    }

    func buy(_ product: Product) async {
        purchasingID = product.id
        defer { purchasingID = nil }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await handle(result)
            case .pending:
                notice = "Your purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            notice = "The purchase didn't go through. Please try again."
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            notice = isPro ? "Overload Pro has been restored." : "No purchases to restore."
        } catch {
            notice = "Couldn't restore purchases."
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result else {
            notice = "The purchase couldn't be verified."
            return
        }
        await t.finish()
        await refreshEntitlements()
    }

    /// "/ month", "/ year" for subscriptions, "one-time" for the lifetime unlock.
    static func periodText(_ p: Product) -> String {
        guard let period = p.subscription?.subscriptionPeriod else { return "one-time" }
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = ""
        }
        return period.value == 1 ? "/ \(unit)" : "/ \(period.value) \(unit)s"
    }
}
