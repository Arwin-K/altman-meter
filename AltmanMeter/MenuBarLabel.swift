import SwiftUI

/// The live readout in the menu bar itself, e.g. "🔥 62%".
///
/// It uses an SF Symbol that changes with the mood rather than a tiny render
/// of the face: at 16 pt a photo turns into a blur, while symbols stay crisp
/// and follow the menu bar's light/dark/tinted appearance automatically.
struct MenuBarLabel: View {
    let model: LiveStatsModel
    @AppStorage(BarDisplay.storageKey) private var display = BarDisplay.defaultValue

    var body: some View {
        let stats = model.stats
        let mood = Mood(stats: stats)
        let icon = Image(systemName: mood.menuBarSymbol)

        Group {
            if let text = display.text(for: stats) {
                Text("\(icon) \(text)").monospacedDigit()
            } else {
                icon
            }
        }
        .accessibilityLabel("Altman Meter: boss is \(mood.word.lowercased()), RAM \(StatFormat.percent(stats.ramUsedFraction)) used")
    }
}
