import AppIntents
import Foundation

/// Runs when you click Sam Altman's face on the desktop widget. It counts the poke,
/// and WidgetKit then reloads the widget, which picks a new line and fresh stats.
///
/// It's compiled into both targets because the shared views reference it, but only
/// the widget uses it. The count lives in the widget's own sandboxed defaults.
struct PokeAltmanIntent: AppIntent {
    static var title: LocalizedStringResource = "Poke Sam Altman"
    static var description = IntentDescription("Poke Sam Altman for a new line.")
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        AltmanPokes.increment()
        return .result()
    }
}

/// How many times Sam Altman has been poked (widget side).
enum AltmanPokes {
    private static let key = "altmanPokes"
    private static let legacyKey = "bossPokes"

    static var count: Int {
        let defaults = UserDefaults.standard
        return defaults.object(forKey: key) == nil
            ? defaults.integer(forKey: legacyKey)
            : defaults.integer(forKey: key)
    }

    static func increment() {
        UserDefaults.standard.set(count &+ 1, forKey: key)
    }
}
