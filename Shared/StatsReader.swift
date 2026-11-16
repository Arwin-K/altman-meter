import Foundation
import Darwin
import IOKit
import Metal

/// Reads RAM, GPU, CPU, swap, memory pressure, heat and disk using macOS APIs.
/// Everything happens on this Mac; nothing touches the network. Every function
/// returns nil instead of crashing when a reading fails.
enum StatsReader {
    static func read(now: Date = .now) -> SystemStats {
        let disk = diskSpace()
        let swap = swapUsage()
        let gpu = gpu()
        let process = ProcessInfo.processInfo
        return SystemStats(
            sampledAt: now,
            ramTotalBytes: ramTotal(),
            ramUsedBytes: ramUsed(),
            swapUsedBytes: swap.used,
            swapTotalBytes: swap.total,
            memoryPressure: sysctlInt("kern.memorystatus_vm_pressure_level").flatMap(MemoryPressure.init(rawValue:)),
            memoryFreePercent: sysctlInt("kern.memorystatus_level").flatMap { (0...100).contains($0) ? $0 : nil },
            gpuUtilization: gpu.utilization,
            gpuMemoryInUseBytes: gpu.memoryInUse,
            gpuMemoryLimitBytes: gpuMemoryLimit(),
            cpuUsage: CPUSampler.shared.usage(),
            chipName: chipName(),
            gpuCoreCount: gpu.cores,
            performanceCores: sysctlInt("hw.perflevel0.physicalcpu"),
            efficiencyCores: sysctlInt("hw.perflevel1.physicalcpu"),
            thermal: ThermalLevel(process.thermalState),
            lowPowerMode: process.isLowPowerModeEnabled,
            diskFreeBytes: disk.free,
            diskTotalBytes: disk.total
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

    /// Swap in use and the current size of the swap files (macOS grows them as needed).
    static func swapUsage() -> (used: UInt64?, total: UInt64?) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return (nil, nil) }
        return (usage.xsu_used, usage.xsu_total)
    }

    // MARK: GPU

    /// GPU busy % and memory in use, from the GPU driver's performance statistics
    /// in the IORegistry (the same numbers Activity Monitor's GPU History uses).
    static func gpu() -> (utilization: Double?, memoryInUse: UInt64?, cores: Int?) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return (nil, nil, nil)
        }
        defer { IOObjectRelease(iterator) }

        var utilization: Double?
        var memory: UInt64?
        var cores: Int?
        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            var properties: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = properties?.takeRetainedValue() as? [String: Any],
                  let perf = dict["PerformanceStatistics"] as? [String: Any] else { continue }

            // Macs with more than one GPU: report the busiest one, and add up memory.
            if let percent = perf["Device Utilization %"] as? Int {
                utilization = max(utilization ?? 0, min(max(Double(percent) / 100, 0), 1))
            }
            if let bytes = (perf["In use system memory"] as? NSNumber)?.uint64Value {
                memory = (memory ?? 0) + bytes
            }
            if let count = dict["gpu-core-count"] as? Int { cores = max(cores ?? 0, count) }
        }
        return (utilization, memory, cores)
    }

    /// The most memory the GPU may use. If you raised it with
    /// `sudo sysctl iogpu.wired_limit_mb=…`, that wins; otherwise Metal's
    /// recommended working set (about 2/3 to 3/4 of RAM on Apple silicon).
    static func gpuMemoryLimit() -> UInt64? {
        if let mb = sysctlInt("iogpu.wired_limit_mb"), mb > 0 {
            return UInt64(mb) << 20
        }
        return metalWorkingSet
    }

    /// Asked once: creating a Metal device isn't free, and the default doesn't change.
    private static let metalWorkingSet: UInt64? = {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        let size = device.recommendedMaxWorkingSetSize
        return size > 0 ? size : nil
    }()

    // MARK: Chip

    /// "Apple M3 Pro"
    static func chipName() -> String? {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else { return nil }
        let name = String(cString: buffer).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
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

    // MARK: Helpers

    /// An integer sysctl (32- or 64-bit), or nil if it doesn't exist.
    static func sysctlInt(_ name: String) -> Int? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0 else { return nil }
        switch size {
        case 4:
            var value: Int32 = 0
            return sysctlbyname(name, &value, &size, nil, 0) == 0 ? Int(value) : nil
        case 8:
            var value: Int64 = 0
            return sysctlbyname(name, &value, &size, nil, 0) == 0 ? Int(value) : nil
        default:
            return nil
        }
    }
}

/// CPU use is a difference between two readings of the kernel's tick counters.
/// The app samples every few seconds, so it compares with the last call. The
/// widget runs fresh each time, so when the last reading is missing or stale it
/// takes two readings a quarter of a second apart.
final class CPUSampler: @unchecked Sendable {
    static let shared = CPUSampler()

    private struct Ticks { var busy: UInt64; var total: UInt64; var at: Date }
    private var last: Ticks?
    /// Returned when the counters haven't moved since the last reading.
    private var lastUsage: Double?
    private let lock = NSLock()

    /// The kernel updates these counters lazily and sometimes not at all for a few
    /// hundred milliseconds, so wait for at least this many ticks to pass.
    private static let minimumTicks: UInt64 = 50

    func usage() -> Double? {
        lock.lock()
        defer { lock.unlock() }

        guard let previous = last, Date().timeIntervalSince(previous.at) < 10 else {
            // Fresh start (the widget, or the app's first reading): take a reading,
            // then poll for up to a second until the counters have moved enough.
            guard let first = Self.ticks() else { return nil }
            last = first
            for _ in 0..<10 {
                usleep(100_000)
                guard let now = Self.ticks() else { return nil }
                if let value = Self.usage(from: first, to: now) {
                    last = now
                    lastUsage = value
                    return value
                }
            }
            return nil
        }
        guard let now = Self.ticks() else { return lastUsage }
        guard let value = Self.usage(from: previous, to: now) else {
            // Counters haven't moved (or went backwards): keep the old baseline
            // and repeat the last value rather than flashing "—".
            if now.total < previous.total || now.busy < previous.busy { last = now }
            return lastUsage
        }
        last = now
        lastUsage = value
        return value
    }

    private static func usage(from a: Ticks, to b: Ticks) -> Double? {
        guard b.total >= a.total + minimumTicks, b.busy >= a.busy else { return nil }
        return min(max(Double(b.busy - a.busy) / Double(b.total - a.total), 0), 1)
    }

    private static func ticks() -> Ticks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = UInt64(info.cpu_ticks.0)
        let system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        let busy = user + system + nice
        return Ticks(busy: busy, total: busy + idle, at: Date())
    }
}

extension SystemStats {
    /// Plain-text summary, printed by `AltmanMeter --dump-stats`.
    var textSummary: String {
        let mood = Mood(stats: self)
        return """
        Sampled:     \(StatFormat.time(sampledAt))
        Chip:        \(StatFormat.chipLine(self))
        RAM:         \(StatFormat.ramUsedOfTotal(self)) (\(StatFormat.percent(ramUsedFraction)) used)
        GPU:         \(StatFormat.percent(gpuUtilization)) busy
        GPU memory:  \(StatFormat.gpuMemory(self)) (\(StatFormat.memory(gpuMemoryHeadroomBytes)) free for models)
        CPU:         \(StatFormat.percent(cpuUsage)) busy
        Pressure:    \(StatFormat.pressure(memoryPressure)) (\(memoryFreePercent.map { "\($0)%" } ?? AppConstants.missingValue) memory free)
        Swap:        \(StatFormat.memoryShort(swapUsedBytes)) used of \(StatFormat.memoryShort(swapTotalBytes))
        Heat:        \(StatFormat.thermal(thermal))\(lowPowerMode ? " · Low Power Mode on" : "")
        Disk:        \(StatFormat.disk(diskFreeBytes)) free of \(StatFormat.disk(diskTotalBytes))
        Mood:        \(mood.word) — \(mood.quote(at: sampledAt))
        """
    }
}
