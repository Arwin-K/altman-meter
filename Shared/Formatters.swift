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

    /// Memory that can be small, like swap: "0 MB", "215 MB", "2.3 GB".
    static func memoryShort(_ bytes: UInt64?) -> String {
        guard let bytes else { return missing }
        if bytes < 1 << 30 {
            return "\(Int((Double(bytes) / Double(1 << 20)).rounded())) MB"
        }
        return memory(bytes)
    }

    /// GPU memory in use of the limit: "9.5 / 13.3 GB"
    static func gpuMemory(_ stats: SystemStats) -> String {
        let used = stats.gpuMemoryInUseBytes.map(gigabytes) ?? missing
        let limit = stats.gpuMemoryLimitBytes.map(gigabytes) ?? missing
        return "\(used) / \(limit) GB"
    }

    /// "Normal", "Warning", "Critical"
    static func pressure(_ pressure: MemoryPressure?) -> String {
        switch pressure {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case nil: return missing
        }
    }

    /// "Nominal", "Fair", "Serious", "Critical"
    static func thermal(_ thermal: ThermalLevel?) -> String {
        switch thermal {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        case nil: return missing
        }
    }

    /// "M3 Pro · 14-core GPU" (drops the "Apple " prefix to save room)
    static func chipLine(_ stats: SystemStats) -> String {
        var name = stats.chipName ?? missing
        if name.hasPrefix("Apple ") { name.removeFirst("Apple ".count) }
        guard let cores = stats.gpuCoreCount else { return name }
        return "\(name) · \(cores)-core GPU"
    }

    /// "5P + 6E cores", or nil on Intel Macs (which don't report core types).
    static func cpuCores(_ stats: SystemStats) -> String? {
        guard let p = stats.performanceCores, let e = stats.efficiencyCores else { return nil }
        return "\(p)P + \(e)E cores"
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
