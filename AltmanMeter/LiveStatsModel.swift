import Foundation
import Observation

/// Live readings for the menu bar: every 5 seconds all the time, and every
/// 2 seconds while the panel is open.
@Observable
@MainActor
final class LiveStatsModel {
    private(set) var stats: SystemStats

    @ObservationIgnored private var barTimer: Timer?
    @ObservationIgnored private var panelTimer: Timer?

    /// - Parameter live: pass `false` (with sample stats) for SwiftUI previews.
    init(stats: SystemStats? = nil, live: Bool = true) {
        self.stats = stats ?? StatsReader.read()
        if live {
            barTimer = makeTimer(every: AppConstants.menuBarRefreshInterval)
        }
    }

    /// Times you've clicked his face in the panel; picks his line.
    private(set) var pokes = 0

    func refresh() {
        stats = StatsReader.read()
    }

    func poke() {
        pokes += 1
    }

    /// Called when the panel opens: fresh numbers right away, then every 2 s.
    func panelDidOpen() {
        refresh()
        panelTimer?.invalidate()
        panelTimer = makeTimer(every: AppConstants.panelRefreshInterval)
    }

    func panelDidClose() {
        panelTimer?.invalidate()
        panelTimer = nil
    }

    private func makeTimer(every interval: TimeInterval) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = interval * 0.1
        // `.common` keeps it firing while menus are being tracked.
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
