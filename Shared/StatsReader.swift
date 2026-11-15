import Foundation
import Darwin
import IOKit.ps

/// Reads RAM, disk and battery using public macOS APIs only. Everything happens
/// on this Mac; nothing touches the network. Every function returns nil (or
/// `.unavailable`) instead of crashing when a reading fails.
enum StatsReader {
    static func read(now: Date = .now) -> SystemStats {
        let disk = diskSpace()
        return SystemStats(
            sampledAt: now,
            ramTotalBytes: ramTotal(),
            ramUsedBytes: ramUsed(),
            diskFreeBytes: disk.free,
            diskTotalBytes: disk.total,
            battery: battery()
        )
    }

    // MARK: RAM

    /// Installed RAM.
    static func ramTotal() -> UInt64? {
        let total = ProcessInfo.processInfo.physicalMemory
        return total > 0 ? total : nil
    }

    /// RAM in use, computed the way Activity Monitor's "Memory Used" is:
    /// app memory (internal − purgeable) + wired + compressed, times the page size.
    static func ramUsed() -> UInt64? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        guard pageSize > 0 else { return nil }

        let internalPages = UInt64(info.internal_page_count)
        let purgeable = UInt64(info.purgeable_count)
        let wired = UInt64(info.wire_count)
        let compressed = UInt64(info.compressor_page_count)

        let appPages = internalPages > purgeable ? internalPages - purgeable : 0
        let usedBytes = (appPages + wired + compressed) * pageSize
        return usedBytes > 0 ? usedBytes : nil
    }

    // MARK: Disk

    /// Free and total space on the startup disk ("/").
    static func diskSpace() -> (free: Int64?, total: Int64?) {
        func values(_ keys: Set<URLResourceKey>) -> URLResourceValues? {
            var root = URL(fileURLWithPath: "/")
            root.removeAllCachedResourceValues()
            return try? root.resourceValues(forKeys: keys)
        }

        // "Important usage" counts space macOS can free up (caches, purgeable files),
        // which matches what Finder shows. Fall back to the plain number.
        var free = values([.volumeAvailableCapacityForImportantUsageKey])?
            .volumeAvailableCapacityForImportantUsage
        if free == nil || free! <= 0 {
            free = values([.volumeAvailableCapacityKey])?.volumeAvailableCapacity.map(Int64.init)
        }
        let total = values([.volumeTotalCapacityKey])?.volumeTotalCapacity.map(Int64.init)

        return (
            free.flatMap { $0 > 0 ? $0 : nil },
            total.flatMap { $0 > 0 ? $0 : nil }
        )
    }

    // MARK: Battery

    /// The internal battery only (ignores UPSes and connected accessories).
    static func battery() -> BatteryReading {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return .unavailable }
        guard let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return .unavailable
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            guard description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }

            if let present = description[kIOPSIsPresentKey] as? Bool, !present { return .noBattery }

            guard let current = description[kIOPSCurrentCapacityKey] as? Int,
                  let maximum = description[kIOPSMaxCapacityKey] as? Int,
                  maximum > 0 else { return .unavailable }

            let percent = min(max(Int((Double(current) / Double(maximum) * 100).rounded()), 0), 100)
            let onAC = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false
            let isCharged = description[kIOPSIsChargedKey] as? Bool ?? false

            let state: ChargeState
            if isCharging {
                state = .charging
            } else if onAC && (isCharged || percent >= 100) {
                state = .charged
            } else if onAC {
                state = .pluggedInNotCharging
            } else {
                state = .onBattery
            }
            return .battery(percent: percent, state: state)
        }
        return .noBattery
    }
}

extension SystemStats {
    /// Plain-text summary, printed by `AltmanMeter --dump-stats`.
    var textSummary: String {
        let mood = Mood(stats: self)
        return """
        Sampled:  \(StatFormat.time(sampledAt))
        RAM:      \(StatFormat.ramUsedOfTotal(self)) (\(StatFormat.percent(ramUsedFraction)) used)
        Disk:     \(StatFormat.disk(diskFreeBytes)) free of \(StatFormat.disk(diskTotalBytes))
        Battery:  \(StatFormat.batteryLine(battery))
        Mood:     \(mood.word) — \(mood.quote(at: sampledAt))
        """
    }
}
