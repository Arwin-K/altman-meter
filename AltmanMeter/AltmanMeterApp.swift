import SwiftUI

/// Entry point of the menu bar app. There is no window and no Dock icon
/// (`LSUIElement = YES`); everything lives in the menu bar item.
@main
struct AltmanMeterApp: App {
    /// Handles altmanmeter:// links from the widget (open Activity Monitor / Storage).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = LiveStatsModel()
    @State private var loginItem = LoginItemController()

    init() {
        // `AltmanMeter --dump-stats` prints one reading and quits. Handy for
        // checking the readers work inside the app sandbox.
        if CommandLine.arguments.contains("--dump-stats") {
            print(StatsReader.read().textSummary)
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(model: model, loginItem: loginItem)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
