import WidgetKit
import SwiftUI

/// Picks the layout for the widget size the user chose.
struct AltmanMeterWidgetView: View {
    let entry: StatsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let mood = Mood(stats: entry.stats)
        Group {
            switch family {
            case .systemSmall: SmallWidgetView(stats: entry.stats, pokes: entry.pokes)
            case .systemLarge: LargeWidgetView(stats: entry.stats, pokes: entry.pokes)
            default: MediumWidgetView(stats: entry.stats, pokes: entry.pokes)
            }
        }
        .containerBackground(for: .widget) {
            CardBackground(mood: mood)
        }
    }
}

/// Small: a big sticker head, RAM used % and a one-word mood.
/// Sizes follow the space macOS gives the widget, so nothing gets clipped.
struct SmallWidgetView: View {
    let stats: SystemStats
    var pokes = 0
    var poke: PokeableFace.Action = .widgetIntent

    var body: some View {
        GeometryReader { proxy in
            let mood = Mood(stats: stats)
            let h = proxy.size.height
            let face = min(86, h * 0.6)
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 0) {
                    MoodBadge(mood: mood, fontSize: 9.5)
                    Spacer(minLength: 0)
                    Text(StatFormat.percent(stats.ramUsedFraction))
                        .font(.system(size: min(36, h * 0.27), weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("RAM used")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(StatFormat.time(stats.sampledAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .accessibilityLabel(StatFormat.sampled(stats.sampledAt))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                PokeableFace(mood: mood, size: face, pokes: pokes, action: poke)
                    .offset(x: face * 0.14, y: -face * 0.04)
            }
        }
        // The small widget can't hold separate links; tapping it (outside his face)
        // opens Activity Monitor's Memory tab, since it shows RAM.
        .widgetURL(DeepLink.memory.url)
    }
}

/// Medium: the shared card, identical to the menu bar panel.
struct MediumWidgetView: View {
    let stats: SystemStats
    var pokes = 0
    var poke: PokeableFace.Action = .widgetIntent

    var body: some View {
        WidgetCard(stats: stats, pokes: pokes, poke: poke)
    }
}

/// Large: a big head with a speech bubble on top; every stat with a bar and detail line below.
/// Sizes follow the space macOS gives the widget, so nothing gets clipped.
struct LargeWidgetView: View {
    let stats: SystemStats
    var pokes = 0
    var poke: PokeableFace.Action = .widgetIntent

    var body: some View {
        GeometryReader { proxy in
            let mood = Mood(stats: stats)
            let face = min(124, proxy.size.height * 0.31)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center, spacing: 6) {
                    // The mood badge sits on the bottom of his head like a sticker label.
                    ZStack(alignment: .bottom) {
                        PokeableFace(mood: mood, size: face, pokes: pokes, action: poke)
                        MoodBadge(mood: mood, fontSize: 10.5)
                            .background(Color(nsColor: .windowBackgroundColor), in: Capsule())
                            .rotationEffect(.degrees(-4))
                            .offset(y: 8)
                    }
                    .padding(.bottom, 8)
                    SpeechBubble(tail: .leading, tailPosition: face * 0.4) {
                        QuoteText(text: mood.quote(at: stats.sampledAt, pokes: pokes), size: 14, lineLimit: 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer(minLength: 6)
                Divider()
                Spacer(minLength: 6)
                VStack(alignment: .leading, spacing: 9) {
                    StatRow.ram(stats, mood: mood, style: .regular)
                    StatRow.disk(stats, style: .regular)
                    StatRow.battery(stats, style: .regular)
                }
                Spacer(minLength: 4)
                Text("\(StatFormat.sampled(stats.sampledAt)) · click his face to poke him")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

// MARK: - Previews (open this file in Xcode and show the canvas)

#Preview("Small", as: .systemSmall) {
    AltmanMeterWidget()
} timeline: {
    StatsEntry(date: .now, stats: .previewFurious)
    StatsEntry(date: .now, stats: .previewAnnoyed, pokes: 1)
    StatsEntry(date: .now, stats: .previewUnreadable)
}

#Preview("Medium", as: .systemMedium) {
    AltmanMeterWidget()
} timeline: {
    StatsEntry(date: .now, stats: .previewFurious)
    StatsEntry(date: .now, stats: .previewAnnoyed, pokes: 1)
    StatsEntry(date: .now, stats: .previewUnreadable)
}

#Preview("Large", as: .systemLarge) {
    AltmanMeterWidget()
} timeline: {
    StatsEntry(date: .now, stats: .previewFurious)
    StatsEntry(date: .now, stats: .previewAnnoyed, pokes: 1)
    StatsEntry(date: .now, stats: .previewUnreadable)
}
