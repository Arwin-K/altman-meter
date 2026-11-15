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
    enum Style { case compact, regular }

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
            case .compact: compact
            case .regular: regular
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)

        if let link {
            Link(destination: link.url) { row }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .help(link == .memory ? "Open Activity Monitor → Memory" : "Open Storage settings")
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

    private var compact: some View {
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
        }
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
            "\(StatFormat.percent(stats.ramUsedFraction)) used · \(StatFormat.memory(stats.ramAvailableBytes)) available"
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

    static func disk(_ stats: SystemStats, style: Style = .compact) -> StatRow {
        let detail: String? = stats.diskUsedFraction.map { _ in
            "of \(StatFormat.disk(stats.diskTotalBytes)) · \(StatFormat.percent(stats.diskUsedFraction)) used"
        }
        return StatRow(
            title: style == .compact ? "Disk free" : "Free disk space",
            systemImage: "internaldrive",
            value: StatFormat.disk(stats.diskFreeBytes),
            detail: detail ?? "Couldn't read the startup disk",
            fraction: stats.diskUsedFraction,
            tint: .blue,
            style: style,
            link: .storage
        )
    }

    static func battery(_ stats: SystemStats, style: Style = .compact) -> StatRow {
        let battery = stats.battery
        let value: String
        let detail: String
        switch battery {
        case .noBattery:
            value = StatFormat.batteryValue(battery)
            detail = "This Mac runs on wall power"
        case .unavailable:
            value = StatFormat.batteryValue(battery)
            detail = "Couldn't read the battery"
        case .battery:
            let state = StatFormat.batteryState(battery) ?? ""
            // The compact row is narrow, so it uses the short state words.
            value = style == .compact
                ? "\(StatFormat.batteryValue(battery)) · \(StatFormat.batteryStateShort(battery) ?? "")"
                : StatFormat.batteryValue(battery)
            detail = state
        }
        var tint = Color.green
        if case let .battery(percent, state) = battery, percent < 20, state == .onBattery { tint = .orange }

        return StatRow(
            title: "Battery",
            systemImage: StatFormat.batterySymbol(battery),
            value: value,
            detail: detail,
            fraction: stats.batteryFraction,
            showsBar: stats.batteryFraction != nil,
            tint: tint,
            style: style
        )
    }
}
