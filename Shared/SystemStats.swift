import Foundation

/// The kernel's memory-pressure level, as Activity Monitor's Memory Pressure graph shows it.
enum MemoryPressure: Int, Equatable, Sendable {
    /// Green: there's room.
    case normal = 1
    /// Yellow: macOS is compressing and swapping to keep up.
    case warning = 2
    /// Red: apps (and local models) will slow down badly or get killed.
    case critical = 4
}

/// How hot the Mac is running. Above `.nominal`, macOS starts slowing the chip down.
enum ThermalLevel: Int, Equatable, Sendable {
    case nominal, fair, serious, critical

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .serious
        }
    }
}

/// One sample of the Mac's stats. Every reading is optional: `nil` means it failed
/// and the UI shows "—" instead.
struct SystemStats: Equatable, Sendable {
    var sampledAt: Date

    // Memory
    var ramTotalBytes: UInt64?
    var ramUsedBytes: UInt64?
    var swapUsedBytes: UInt64?
    var swapTotalBytes: UInt64?
    var memoryPressure: MemoryPressure?
    /// The kernel's "memory free" percentage (0...100), what `memory_pressure` prints.
    var memoryFreePercent: Int?

    // GPU
    /// GPU busy share, 0...1.
    var gpuUtilization: Double?
    /// Memory the GPU has in use right now (loaded model weights, KV cache, etc.).
    var gpuMemoryInUseBytes: UInt64?
    /// The most memory macOS lets the GPU use (Metal's recommended working set,
    /// or `iogpu.wired_limit_mb` if you've raised it). Roughly the biggest model that fits.
    var gpuMemoryLimitBytes: UInt64?

    // CPU and chip
    /// CPU busy share across all cores, 0...1.
    var cpuUsage: Double?
    var chipName: String?
    var gpuCoreCount: Int?
    var performanceCores: Int?
    var efficiencyCores: Int?

    // Heat and power
    var thermal: ThermalLevel?
    var lowPowerMode: Bool

    // Disk
    var diskFreeBytes: Int64?
    var diskTotalBytes: Int64?

    /// Share of RAM in use, 0...1.
    var ramUsedFraction: Double? {
        guard let used = ramUsedBytes, let total = ramTotalBytes, total > 0 else { return nil }
        return clamp(Double(used) / Double(total))
    }

    /// RAM that is not counted as used.
    var ramAvailableBytes: UInt64? {
        guard let used = ramUsedBytes, let total = ramTotalBytes else { return nil }
        return total > used ? total - used : 0
    }

    /// Share of the startup disk in use, 0...1.
    var diskUsedFraction: Double? {
        guard let free = diskFreeBytes, let total = diskTotalBytes, total > 0 else { return nil }
        return clamp(Double(total - free) / Double(total))
    }

    /// Share of the GPU memory limit in use, 0...1.
    var gpuMemoryFraction: Double? {
        guard let used = gpuMemoryInUseBytes, let limit = gpuMemoryLimitBytes, limit > 0 else { return nil }
        return clamp(Double(used) / Double(limit))
    }

    /// GPU memory still free under the limit: about how big a model you could add.
    var gpuMemoryHeadroomBytes: UInt64? {
        guard let used = gpuMemoryInUseBytes, let limit = gpuMemoryLimitBytes else { return nil }
        return limit > used ? limit - used : 0
    }

    /// Share of the current swap file in use, 0...1.
    var swapFraction: Double? {
        guard let used = swapUsedBytes, let total = swapTotalBytes else { return nil }
        return total > 0 ? clamp(Double(used) / Double(total)) : 0
    }

    /// How squeezed memory is, 0...1 (1 − the kernel's "memory free" share).
    var pressureFraction: Double? {
        memoryFreePercent.map { clamp(1 - Double($0) / 100) }
    }

    /// Heat as a bar, 0.25 (nominal) ... 1 (critical).
    var thermalFraction: Double? {
        thermal.map { Double($0.rawValue + 1) / 4 }
    }

    private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}

// MARK: - Sample data for SwiftUI previews and the widget gallery placeholder

extension SystemStats {
    private static let gib: UInt64 = 1 << 30

    /// Plenty of free RAM and an idle GPU, so Sam Altman is furious.
    static let previewFurious = SystemStats(
        sampledAt: .now,
        ramTotalBytes: 18 * gib,
        ramUsedBytes: 7 * gib,
        swapUsedBytes: 0,
        swapTotalBytes: 0,
        memoryPressure: .normal,
        memoryFreePercent: 68,
        gpuUtilization: 0.04,
        gpuMemoryInUseBytes: gib,
        gpuMemoryLimitBytes: 13 * gib + gib / 3,
        cpuUsage: 0.12,
        chipName: "Apple M3 Pro",
        gpuCoreCount: 14,
        performanceCores: 5,
        efficiencyCores: 6,
        thermal: .nominal,
        lowPowerMode: false,
        diskFreeBytes: 245_000_000_000,
        diskTotalBytes: 994_000_000_000
    )

    /// A local model is running: RAM and GPU busy, so Sam Altman is merely annoyed.
    static let previewAnnoyed = SystemStats(
        sampledAt: .now,
        ramTotalBytes: 18 * gib,
        ramUsedBytes: 15 * gib + gib / 2,
        swapUsedBytes: 2 * gib + gib / 4,
        swapTotalBytes: 3 * gib,
        memoryPressure: .warning,
        memoryFreePercent: 21,
        gpuUtilization: 0.93,
        gpuMemoryInUseBytes: 9 * gib + gib / 2,
        gpuMemoryLimitBytes: 13 * gib + gib / 3,
        cpuUsage: 0.38,
        chipName: "Apple M3 Pro",
        gpuCoreCount: 14,
        performanceCores: 5,
        efficiencyCores: 6,
        thermal: .fair,
        lowPowerMode: false,
        diskFreeBytes: 61_500_000_000,
        diskTotalBytes: 494_000_000_000
    )

    /// Everything failed.
    static let previewUnreadable = SystemStats(
        sampledAt: .now,
        ramTotalBytes: 16 * gib,
        ramUsedBytes: nil,
        lowPowerMode: false
    )
}
