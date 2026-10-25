import Foundation
import WatchConnectivity

/// iPhone side of WatchConnectivity: pushes templates/"last time" sets to the Watch and
/// receives finished workouts from it.
@MainActor
final class PhoneSync: NSObject, ObservableObject {
    @Published private(set) var watchAvailable = false
    private weak var store: OverloadStore?

    func start(store: OverloadStore) {
        guard self.store == nil else { return }
        self.store = store
        store.onChange = { [weak self] in self?.pushContext() }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func pushContext() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled,
              let store, let raw = try? JSONCoding.encoder.encode(store.watchContext())
        else { return }
        do {
            try WCSession.default.updateApplicationContext([SyncKey.context: raw])
        } catch {
            print("Overload: watch context update failed: \(error.localizedDescription)")
        }
    }

    fileprivate func receive(_ userInfo: [String: Any]) {
        guard let raw = userInfo[SyncKey.workout] as? Data,
              let workout = try? JSONCoding.decoder.decode(Workout.self, from: raw) else { return }
        store?.addWorkout(workout)
    }

    fileprivate func refreshState() {
        let s = WCSession.default
        watchAvailable = s.activationState == .activated && s.isPaired && s.isWatchAppInstalled
        pushContext()
    }
}

extension PhoneSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.refreshState() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after switching watches.
        WCSession.default.activate()
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in self.refreshState() }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let info = userInfo
        Task { @MainActor in self.receive(info) }
    }
}
