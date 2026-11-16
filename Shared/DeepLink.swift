import Foundation

/// Links the widget's stat rows use. They're `altmanmeter://open/<page>` URLs that
/// macOS delivers to the Altman Meter app, which then opens the right place
/// (see `DeepLinkHandler` in the app).
enum DeepLink: String {
    /// Activity Monitor, Memory tab.
    case memory
    /// Activity Monitor, CPU tab (it also has the % GPU column).
    case cpu
    /// System Settings → General → Storage.
    case storage

    static let scheme = "altmanmeter"

    /// Tooltip for rows that open this link.
    var helpText: String {
        switch self {
        case .memory: return "Open Activity Monitor → Memory"
        case .cpu: return "Open Activity Monitor → CPU"
        case .storage: return "Open Storage settings"
        }
    }

    var url: URL {
        URL(string: "\(DeepLink.scheme)://open/\(rawValue)")!
    }

    init?(url: URL) {
        guard url.scheme == DeepLink.scheme, url.host == "open" else { return nil }
        self.init(rawValue: url.lastPathComponent)
    }
}
