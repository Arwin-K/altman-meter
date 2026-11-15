import Foundation

/// Turns raw numbers into the short strings the UI shows. Any missing value becomes "—".
enum StatFormat {
    private static let gib = Double(1 << 30)
    private static let missing = AppConstants.missingValue

    /// 0.623 → "62%"
    static func percent(_ fraction: Double?) -> String {
        guard let fraction else { return missing }
        return fraction.formatted(.percent.precision(.fractionLength(0)))
    }

    /// RAM in GB with one decimal, e.g. "9.9 GB". (Like Activity Monitor, 1 GB = 1024³ bytes.)
    static func memory(_ bytes: UInt64?) -> String {
        guard let bytes else { return missing }
        return "\(gigabytes(bytes)) GB"
    }

    /// "9.9 / 16 GB"
    static func ramUsedOfTotal(_ stats: SystemStats) -> String {
        let used = stats.ramUsedBytes.map(gigabytes) ?? missing
        let total = stats.ramTotalBytes.map(gigabytes) ?? missing
        return "\(used) / \(total) GB"
    }

    /// Disk sizes the way Finder counts them (1 GB = 1000³ bytes): "96.8 GB", "245 GB", "1.2 TB".
    static func disk(_ bytes: Int64?) -> String {
        guard let bytes else { return missing }
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 1000 {
            return "\((gb / 1000).formatted(.number.precision(.fractionLength(1)))) TB"
        }
        let digits = gb >= 100 ? 0 : 1
        return "\(gb.formatted(.number.precision(.fractionLength(digits)))) GB"
    }

    /// "82%", "No battery" or "—"
    static func batteryValue(_ battery: BatteryReading) -> String {
        switch battery {
        case .noBattery: return "No battery"
        case .unavailable: return missing
        case let .battery(percent, _): return "\(percent)%"
        }
    }

    /// "Charging", "Charged", "Plugged in, not charging", "On battery"
    static func batteryState(_ battery: BatteryReading) -> String? {
        guard case let .battery(_, state) = battery else { return nil }
        switch state {
        case .charging: return "Charging"
        case .charged: return "Charged"
        case .pluggedInNotCharging: return "Plugged in, not charging"
        case .onBattery: return "On battery"
        }
    }

    /// Shorter state words for narrow spaces: "Plugged in" instead of "Plugged in, not charging".
    static func batteryStateShort(_ battery: BatteryReading) -> String? {
        guard case let .battery(_, state) = battery else { return nil }
        return state == .pluggedInNotCharging ? "Plugged in" : batteryState(battery)
    }

    /// "82% · Charging", or just "No battery" / "—"
    static func batteryLine(_ battery: BatteryReading) -> String {
        let value = batteryValue(battery)
        guard let state = batteryState(battery) else { return value }
        return "\(value) · \(state)"
    }

    /// SF Symbol for the battery row.
    static func batterySymbol(_ battery: BatteryReading) -> String {
        switch battery {
        case .noBattery: return "powerplug"
        case .unavailable: return "battery.0percent"
        case let .battery(percent, state):
            if state == .charging { return "battery.100percent.bolt" }
            switch percent {
            case ..<13: return "battery.0percent"
            case ..<38: return "battery.25percent"
            case ..<63: return "battery.50percent"
            case ..<88: return "battery.75percent"
            default: return "battery.100percent"
            }
        }
    }

    /// "1:42 PM"
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// "Sampled 1:42 PM"
    static func sampled(_ date: Date) -> String {
        "Sampled \(time(date))"
    }

    private static func gigabytes(_ bytes: UInt64) -> String {
        let value = Double(bytes) / gib
        // "16" rather than "16.0" for whole numbers like installed RAM.
        if abs(value - value.rounded()) < 0.05 {
            return value.formatted(.number.precision(.fractionLength(0)))
        }
        return value.formatted(.number.precision(.fractionLength(1)))
    }
}
