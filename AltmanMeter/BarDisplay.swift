import Foundation

/// What the menu bar item shows next to the mood icon. Saved in UserDefaults.
enum BarDisplay: String, CaseIterable, Identifiable {
    case iconOnly
    case ramPercent
    case ramUsedGB
    case gpuPercent

    static let storageKey = "menuBarDisplay"
    static let defaultValue = BarDisplay.ramPercent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .iconOnly: return "Icon only"
        case .ramPercent: return "RAM %"
        case .ramUsedGB: return "RAM GB"
        case .gpuPercent: return "GPU %"
        }
    }

    /// Text after the icon, or nil for icon only.
    func text(for stats: SystemStats) -> String? {
        switch self {
        case .iconOnly: return nil
        case .ramPercent: return StatFormat.percent(stats.ramUsedFraction)
        case .ramUsedGB: return StatFormat.memory(stats.ramUsedBytes)
        case .gpuPercent: return "GPU \(StatFormat.percent(stats.gpuUtilization))"
        }
    }
}
