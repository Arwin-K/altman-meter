import Foundation

/// Numbers and names used by both the app and the widget.
enum AppConstants {
    /// The widget's "kind". The app uses it to ask WidgetKit to reload the widget.
    static let widgetKind = "AltmanMeterWidget"

    /// The desktop widget is a snapshot: it asks macOS for a new one after this long.
    static let widgetRefreshInterval: TimeInterval = 15 * 60

    /// How often the menu bar readout updates.
    static let menuBarRefreshInterval: TimeInterval = 5

    /// How often the menu bar panel updates while it's open.
    static let panelRefreshInterval: TimeInterval = 2

    /// How long each boss line stays before the next one rotates in.
    static let quoteRotationInterval: TimeInterval = 10 * 60

    /// Shown in place of any reading that failed.
    static let missingValue = "—"
}
