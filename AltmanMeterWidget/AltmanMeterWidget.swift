import WidgetKit
import SwiftUI

/// One snapshot of the Mac's stats.
struct StatsEntry: TimelineEntry {
    let date: Date
    let stats: SystemStats
    /// How many times he's been poked; picks his line.
    var pokes = 0
}

/// Gives WidgetKit a single entry with fresh readings, and asks for a new one
/// in 15 minutes. The widget reads the stats itself, so no App Group is needed.
/// Poking his face (PokeBossIntent) also triggers a reload.
struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: .now, stats: .previewFurious)
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        let entry = currentEntry()
        let next = entry.date.addingTimeInterval(AppConstants.widgetRefreshInterval)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> StatsEntry {
        let now = Date()
        return StatsEntry(date: now, stats: StatsReader.read(now: now), pokes: BossPokes.count)
    }
}

struct AltmanMeterWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: AppConstants.widgetKind, provider: StatsProvider()) { entry in
            AltmanMeterWidgetView(entry: entry)
        }
        .configurationDisplayName("Altman Meter")
        .description("RAM, disk and battery, judged by a boss who is never happy. Click his face to poke him.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
