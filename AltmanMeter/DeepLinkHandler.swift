import AppKit
import OSLog

private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AltmanMeter", category: "links")

/// Receives `altmanmeter://` links (from widget taps and the panel's stat rows).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if let link = DeepLink(url: url) {
                DeepLinkHandler.open(link)
            }
        }
    }
}

@MainActor
enum DeepLinkHandler {
    static func open(_ link: DeepLink) {
        switch link {
        case .storage:
            if let url = URL(string: "x-apple.systempreferences:com.apple.settings.Storage") {
                NSWorkspace.shared.open(url)
            }
        case .memory:
            ActivityMonitor.show(.memory)
        case .cpu:
            ActivityMonitor.show(.cpu)
        }
    }
}

/// Opens Activity Monitor on a given tab.
///
/// Activity Monitor has no URL or AppleScript for choosing a tab. It does remember
/// the selected tab in its preferences (`SelectedTab`: 0 = CPU, 1 = Memory) and reads
/// it at launch. So: if it's closed, set the preference and open it; if it's open on
/// another tab, quit it and reopen it on the one we want. Reading and writing that one
/// preference is allowed by the `shared-preference` entitlement in
/// `Config/AltmanMeter.entitlements`.
@MainActor
enum ActivityMonitor {
    private static let bundleID = "com.apple.ActivityMonitor"
    private static let tabKey = "SelectedTab" as CFString

    enum Tab: Int {
        case cpu = 0
        case memory = 1
    }

    static func show(_ tab: Tab) {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        log.notice("\(String(describing: tab)) link: Activity Monitor running=\(!running.isEmpty), saved tab=\(String(describing: currentTab()))")
        guard !running.isEmpty else {
            launch(on: tab)
            return
        }
        if currentTab() == tab.rawValue {
            // Already on that tab: just bring it forward. (Opening it via NSWorkspace
            // works from a menu bar app; NSRunningApplication.activate() doesn't.)
            launch(on: tab)
            return
        }
        // It saves its own tab when it quits, so set ours only after it has gone.
        for app in running {
            let asked = app.terminate()
            log.notice("Asked Activity Monitor to quit: \(asked)")
        }
        Task { @MainActor in
            for _ in 0..<40 where !running.allSatisfy(\.isTerminated) {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            log.notice("Activity Monitor quit: \(running.allSatisfy(\.isTerminated))")
            launch(on: tab)
        }
    }

    private static func currentTab() -> Int? {
        CFPreferencesAppSynchronize(bundleID as CFString)
        return CFPreferencesCopyAppValue(tabKey, bundleID as CFString) as? Int
    }

    private static func launch(on tab: Tab) {
        CFPreferencesSetAppValue(tabKey, tab.rawValue as CFNumber, bundleID as CFString)
        CFPreferencesAppSynchronize(bundleID as CFString)
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    }
}
