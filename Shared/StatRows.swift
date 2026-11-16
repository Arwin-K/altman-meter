import SwiftUI
import WidgetKit

/// A thin progress bar. When macOS dims/tints desktop widgets, it switches to the
/// primary color so it stays visible; the text next to it always carries the value.
struct StatBar: View {
    let fraction: Double?
    var tint: Color
    var height: CGFloat = 5

    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.13))
                if let fraction {
                    Capsule()
                        .fill(renderingMode == .fullColor ? tint : Color.primary)
                        .frame(width: max(height, proxy.size.width * fraction))
                }
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// One stat: icon + title, value, optional bar and detail line.
struct StatRow: View {
    /// `compact`: medium widget. `tile`: compact plus a detail line (large widget's grid).
    /// `regular`: title and value side by side, with a detail line.
    enum Style { case compact, tile, regular }

    let title: String
    let systemImage: String
    let value: String
    var detail: String? = nil
    var fraction: Double? = nil
    var showsBar = true
    var tint: Color = .accentColor
    var style: Style = .compact
    /// Clicking the row opens this (Activity Monitor, Storage settings).
    var link: DeepLink? = nil

    var body: some View {
        let row = Group {
            switch style {
            case .compact: compact(showsDetail: false)
            case .tile: compact(showsDetail: true)
            case .regular: regular
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)

        if let link {
            Link(destination: link.url) { row }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .help(link.helpText)
        } else {
            row
        }
    }

    /// Title with a small chevron when the row is a link.
    private func titleLabel(size: CGFloat, weight: Font.Weight) -> some View {
        HStack(spacing: 3) {
            Label(title, systemImage: systemImage)
            if link != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: size * 0.75, weight: .bold))
                    .opacity(0.7)
            }
        }
        .font(.system(size: size, weight: weight))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private func compact(showsDetail: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            titleLabel(size: 10, weight: .medium)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if showsBar {
                StatBar(fraction: fraction, tint: tint, height: 4)
                    .padding(.top, 1)
            }
            if showsDetail, let detail {
                Text(detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var regular: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                titleLabel(size: 12, weight: .semibold)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if showsBar {
                StatBar(fraction: fraction, tint: tint, height: 6)
            }
            if let detail {
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

/// Ready-made rows for each stat, so every view words them the same way.
extension StatRow {
    static func ram(_ stats: SystemStats, mood: Mood, style: Style = .compact) -> StatRow {
        let detail: String? = stats.ramUsedFraction.map { _ in
            style == .regular
                ? "\(StatFormat.percent(stats.ramUsedFraction)) used · \(StatFormat.memory(stats.ramAvailableBytes)) available"
                : "\(StatFormat.percent(stats.ramUsedFraction)) used · \(StatFormat.memory(stats.ramAvailableBytes)) free"
        }
        return StatRow(
            title: "RAM",
            systemImage: "memorychip",
            value: StatFormat.ramUsedOfTotal(stats),
            detail: detail ?? "Couldn't read memory use",
            fraction: stats.ramUsedFraction,
            tint: mood.tint,
            style: style,
            link: .memory
        )
    }

    /// How busy the GPU is: the number to watch while a model is generating.
    static func gpu(_ stats: SystemStats, style: Style = .compact) -> StatRow {
        StatRow(
            title: "GPU",
            systemImage: "cpu",
            value: StatFormat.percent(stats.gpuUtilization),
            detail: stats.gpuUtilization == nil ? "Couldn't read the GPU" : StatFormat.chipLine(stats),
            fraction: stats.gpuUtilization,
            tint: .indigo,
            style: style,
            link: .cpu
        )
    }

    /// GPU memory in use against the limit: how big a model still fits.
    static func gpuMemory(_ stats: SystemStats, style: Style = .compact) -> StatRow {
        let detail = stats.gpuMemoryHeadroomBytes.map { "\(StatFormat.memory($0)) left for models" }
        var tint = Color.cyan
        if let fraction = stats.gpuMemoryFraction, fraction > 0.9 { tint = .orange }
        return StatRow(
            title: "GPU memory",
            systemImage: "square.stack.3d.up",
            value: StatFormat.gpuMemory(stats),
            detail: detail ?? "Couldn't read GPU memory",
            fraction: stats.gpuMemoryFraction,
            tint: tint,
            style: style,
            link: .memory
        )
    }

    static func cpu(_ stats: SystemStats, style: Style = .compact) -> StatRow {
        StatRow(
            title: "CPU",
            systemImage: "gauge.with.dots.needle.33percent",
            value: StatFormat.percent(stats.cpuUsage),
            detail: stats.cpuUsage == nil ? "Couldn't read the CPU" : (StatFormat.cpuCores(stats) ?? "All cores"),
            fraction: stats.cpuUsage,
            tint: .teal,
            style: style,
            link: .cpu
        )
    }

    /// Memory pressure. In the medium widget it also carries swap, since the two
    /// together say whether a model really fits in memory.
    static func pressure(_ stats: SystemStats, style: Style = .compact) -> StatRow {
        let word = StatFormat.pressure(stats.memoryPressure)
        let value = style == .compact
            ? "\(word) · \(StatFormat.memoryShort(stats.swapUsedBytes)) swap"
            : word
        let detail = stats.memoryFreePercent.map { "\($0)% of memory free" }
        return StatRow(
            title: style == .compact ? "Pressure · Swap" : "Memory pressure",
            systemImage: "gauge.with.needle",
            value: value,
            detail: detail ?? "Couldn't read memory pressure",
            fraction: stats.pressureFraction,
            tint: pressureTint(stats.memoryPressure),
            style: style,
            link: .memory
        )
    }

    /// Swap: when a model doesn't fit in RAM, macOS pages it to disk and
    /// generation slows to a crawl.
    static func swap(_ stats: SystemStats, style: Style = .compact) -> StatRow {
        let heavy = (stats.swapUsedBytes ?? 0) >= 1 << 30
        let detail: String
        if stats.swapUsedBytes == nil {
            detail = "Couldn't read swap"
        } else if heavy {
            detail = "Heavy swap slows models"
        } else {
            detail = "of \(StatFormat.memoryShort(stats.swapTotalBytes)) swap file"
        }
        return StatRow(
            title: "Swap used",
            systemImage: "arrow.left.arrow.right",
            value: StatFormat.memoryShort(stats.swapUsedBytes),
            detail: detail,
            fraction: stats.swapFraction,
            tint: heavy ? .orange : .mint,
            style: style,
            link: .memory
        )
    }

    /// Heat: above "Nominal", macOS throttles the chip and tokens/s drop.
    static func thermal(_ stats: SystemStats, style: Style = .compact) -> StatRow {
        let tint: Color
        switch stats.thermal {
        case .nominal, nil: tint = .green
        case .fair: tint = .yellow
        case .serious: tint = .orange
        case .critical: tint = .red
        }
        let detail: String
        if stats.lowPowerMode {
            detail = "Low Power Mode on · slower"
        } else if let thermal = stats.thermal, thermal.rawValue >= ThermalLevel.serious.rawValue {
            detail = "Throttling · slower models"
        } else {
            detail = "Low Power Mode off"
        }
        return StatRow(
            title: "Heat",
            systemImage: "thermometer.medium",
            value: StatFormat.thermal(stats.thermal),
            detail: detail,
            fraction: stats.thermalFraction,
            tint: tint,
            style: style
        )
    }

    static func disk(_ stats: SystemStats, style: Style = .compact) -> StatRow {
        let detail: String? = stats.diskUsedFraction.map { _ in
            style == .regular
                ? "of \(StatFormat.disk(stats.diskTotalBytes)) · \(StatFormat.percent(stats.diskUsedFraction)) used"
                : "free of \(StatFormat.disk(stats.diskTotalBytes))"
        }
        return StatRow(
            title: style == .regular ? "Free disk space" : "Disk free",
            systemImage: "internaldrive",
            value: StatFormat.disk(stats.diskFreeBytes),
            detail: detail ?? "Couldn't read the startup disk",
            fraction: stats.diskUsedFraction,
            tint: .blue,
            style: style,
            link: .storage
        )
    }

    private static func pressureTint(_ pressure: MemoryPressure?) -> Color {
        switch pressure {
        case .normal, nil: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}
