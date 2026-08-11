import SwiftUI
import WidgetKit

// MARK: - Timeline

struct PrayerEntry: TimelineEntry {
    let date: Date
    let snapshot: PrayerData.Snapshot
    let next: PrayerSchedule.Entry?
    let current: PrayerSchedule.Entry?
    let upcoming: [PrayerSchedule.Entry]
}

/// Widget'ı besleyen zaman çizelgesi.
///
/// Geri sayım `Text(date, style: .timer)` ile gösterildiği için sistem
/// saniyeleri kendisi işler; zaman çizelgesinde yalnızca **vakit geçişlerinde**
/// yenileme noktası koymak yeterli.
struct PrayerProvider: TimelineProvider {

    func placeholder(in context: Context) -> PrayerEntry {
        makeEntry(at: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(makeEntry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = Date()
        let entry = makeEntry(at: now)

        let snapshot = PrayerData.load()
        let schedule = PrayerSchedule(snapshot: snapshot)
        // Sonraki birkaç vakit geçişinde yenile; sonrasını uygulama tazeler.
        let refreshDates = schedule.entries()
            .map(\.date)
            .filter { $0 > now }
            .prefix(6)

        var entries = [entry]
        for date in refreshDates {
            entries.append(makeEntry(at: date.addingTimeInterval(1)))
        }

        let policy: TimelineReloadPolicy = refreshDates.last
            .map { .after($0.addingTimeInterval(60)) } ?? .after(now.addingTimeInterval(3600))
        completion(Timeline(entries: entries, policy: policy))
    }

    private func makeEntry(at date: Date) -> PrayerEntry {
        let snapshot = PrayerData.load()
        let schedule = PrayerSchedule(snapshot: snapshot)
        let pair = schedule.next(after: date)
        let dayAhead = date.addingTimeInterval(24 * 60 * 60)
        let upcoming = schedule.entries().filter { $0.date < dayAhead }

        return PrayerEntry(
            date: date,
            snapshot: snapshot,
            next: pair?.next,
            current: pair?.current,
            upcoming: upcoming
        )
    }
}

// MARK: - Görünümler

/// Sıradaki vakit — ad, saat ve canlı geri sayım.
struct NextPrayerView: View {
    let entry: PrayerEntry

    var body: some View {
        if let next = entry.next {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(entry.snapshot.name(at: next.index))
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(PrayerSchedule.clock(next.date))
                        .font(.headline)
                        .foregroundStyle(.tint)
                }
                Text(next.date, style: .timer)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(entry.snapshot.cityDisplay)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            EmptyStateView()
        }
    }
}

/// 1×1 karşılığı — yalnızca sıradaki vaktin saati.
struct CompactPrayerView: View {
    let entry: PrayerEntry

    var body: some View {
        if let next = entry.next {
            VStack(spacing: 0) {
                Text(entry.snapshot.name(at: next.index))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(PrayerSchedule.clock(next.date))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        } else {
            EmptyStateView()
        }
    }
}

/// Günün seçili vakitleri.
struct DailyTimesView: View {
    let entry: PrayerEntry

    var body: some View {
        if let next = entry.next {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(entry.snapshot.cityDisplay)
                            .font(.caption).bold()
                            .lineLimit(1)
                        Text(entry.snapshot.hijri)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(entry.snapshot.name(at: next.index))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(next.date, style: .timer)
                            .font(.caption).bold()
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                }
                Divider()
                ForEach(entry.upcoming.indices, id: \.self) { i in
                    let item = entry.upcoming[i]
                    let isNext = item.index == next.index && item.date == next.date
                    HStack {
                        Text(entry.snapshot.name(at: item.index))
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text(PrayerSchedule.clock(item.date))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .fontWeight(isNext ? .bold : .regular)
                    .foregroundStyle(
                        item.date < entry.date && !isNext ? .secondary : .primary
                    )
                }
            }
        } else {
            EmptyStateView()
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack {
            Image(systemName: "moon")
            Text("Vakitler için uygulamayı açın")
                .font(.caption2)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Widget tanımları

struct NextPrayerWidgetProvider: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextPrayerWidgetProvider", provider: PrayerProvider()) {
            NextPrayerView(entry: $0).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Sıradaki vakit")
        .description("Sıradaki vakit ve geri sayım")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CompactWidgetProvider: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CompactWidgetProvider", provider: PrayerProvider()) {
            CompactPrayerView(entry: $0).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Kompakt vakit")
        .description("Sadece sıradaki vaktin saati")
        .supportedFamilies([.systemSmall, .accessoryCircular])
    }
}

struct DailyTimesWidgetProvider: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DailyTimesWidgetProvider", provider: PrayerProvider()) {
            DailyTimesView(entry: $0).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Günün vakitleri")
        .description("Günün seçili vakitleri ve geri sayım")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct PrayerWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextPrayerWidgetProvider()
        DailyTimesWidgetProvider()
        CompactWidgetProvider()
    }
}
