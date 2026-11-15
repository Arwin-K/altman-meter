import Foundation

/// What the internal battery is doing right now.
enum ChargeState: Equatable, Sendable {
    case charging
    case charged
    case pluggedInNotCharging
    case onBattery
}

/// Result of reading the internal battery.
enum BatteryReading: Equatable, Sendable {
    /// This Mac has no internal battery (iMac, Mac mini, Mac Studio, Mac Pro).
    case noBattery
    /// There is a battery but the reading failed.
    case unavailable
    case battery(percent: Int, state: ChargeState)
}

/// One sample of the Mac's stats. Every reading is optional: `nil` means it failed
/// and the UI shows "—" instead.
struct SystemStats: Equatable, Sendable {
    var sampledAt: Date
    var ramTotalBytes: UInt64?
    var ramUsedBytes: UInt64?
    var diskFreeBytes: Int64?
    var diskTotalBytes: Int64?
    var battery: BatteryReading

    /// Share of RAM in use, 0...1.
    var ramUsedFraction: Double? {
        guard let used = ramUsedBytes, let total = ramTotalBytes, total > 0 else { return nil }
        return min(max(Double(used) / Double(total), 0), 1)
    }

    /// RAM that is not counted as used.
    var ramAvailableBytes: UInt64? {
        guard let used = ramUsedBytes, let total = ramTotalBytes else { return nil }
        return total > used ? total - used : 0
    }

    /// Share of the startup disk in use, 0...1.
    var diskUsedFraction: Double? {
        guard let free = diskFreeBytes, let total = diskTotalBytes, total > 0 else { return nil }
        return min(max(Double(total - free) / Double(total), 0), 1)
    }

    /// Battery charge, 0...1, or nil if there's no reading.
    var batteryFraction: Double? {
        if case let .battery(percent, _) = battery { return Double(percent) / 100 }
        return nil
    }
}

// MARK: - Sample data for SwiftUI previews and the widget gallery placeholder

extension SystemStats {
    private static let gib: UInt64 = 1 << 30

    /// Plenty of free RAM, so the boss is furious.
    static let previewFurious = SystemStats(
        sampledAt: .now,
        ramTotalBytes: 16 * gib,
        ramUsedBytes: 7 * gib,
        diskFreeBytes: 245_000_000_000,
        diskTotalBytes: 994_000_000_000,
        battery: .battery(percent: 82, state: .charging)
    )

    /// RAM mostly in use, so the boss is merely annoyed.
    static let previewAnnoyed = SystemStats(
        sampledAt: .now,
        ramTotalBytes: 16 * gib,
        ramUsedBytes: 13 * gib + gib / 2,
        diskFreeBytes: 61_500_000_000,
        diskTotalBytes: 494_000_000_000,
        battery: .battery(percent: 37, state: .onBattery)
    )

    /// Everything failed, as on a desktop Mac with a broken RAM reading.
    static let previewUnreadable = SystemStats(
        sampledAt: .now,
        ramTotalBytes: 16 * gib,
        ramUsedBytes: nil,
        diskFreeBytes: nil,
        diskTotalBytes: nil,
        battery: .noBattery
    )
}
