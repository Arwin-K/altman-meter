import AppIntents
import Foundation

/// Runs when you click the boss's face on the desktop widget. It counts the poke,
/// and WidgetKit then reloads the widget, which picks a new line and fresh stats.
///
/// It's compiled into both targets because the shared views reference it, but only
/// the widget uses it. The count lives in the widget's own sandboxed defaults.
struct PokeBossIntent: AppIntent {
    static var title: LocalizedStringResource = "Poke the Boss"
    static var description = IntentDescription("Poke the boss for a new line.")
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        BossPokes.increment()
        return .result()
    }
}

/// How many times the boss has been poked (widget side).
enum BossPokes {
    private static let key = "bossPokes"

    static var count: Int {
        UserDefaults.standard.integer(forKey: key)
    }

    static func increment() {
        UserDefaults.standard.set(count &+ 1, forKey: key)
    }
}
