import Foundation

/// Links the widget's stat rows use. They're `altmanmeter://open/<page>` URLs that
/// macOS delivers to the Altman Meter app, which then opens the right place
/// (see `DeepLinkHandler` in the app).
enum DeepLink: String {
    /// Activity Monitor, Memory tab.
    case memory
    /// System Settings → General → Storage.
    case storage

    static let scheme = "altmanmeter"

    var url: URL {
        URL(string: "\(DeepLink.scheme)://open/\(rawValue)")!
    }

    init?(url: URL) {
        guard url.scheme == DeepLink.scheme, url.host == "open" else { return nil }
        self.init(rawValue: url.lastPathComponent)
    }
}
