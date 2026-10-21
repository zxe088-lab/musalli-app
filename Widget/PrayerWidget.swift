import SwiftUI
import WidgetKit

struct PrayerEntry: TimelineEntry {
    let date: Date
    let prayer: Prayer
    let time: Date
    let hijri: String
    let settings: AppSettings

    static func make(at date: Date, settings: AppSettings = .load()) -> PrayerEntry {
        let next = settings.calculator.nextPrayer(after: date)
        let day = DayKey.local(date, in: settings.timeZone)
        return PrayerEntry(date: date, prayer: next.prayer, time: next.time,
                           hijri: DateText.hijri(day, offset: settings.hijriOffset),
                           settings: settings)
    }
}

struct PrayerProvider: TimelineProvider {
    func placeholder(in context: Context) -> PrayerEntry { .make(at: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(.make(at: Date()))
    }

    /// One entry now, one at each upcoming prayer, and one at local midnight
    /// (for the Hijri date); the countdown itself ticks on its own.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let settings = AppSettings.load()
        let calc = settings.calculator
        let now = Date()
        let today = DayKey.local(now, in: settings.timeZone)
        var dates: [Date] = [now]
        for offset in 0...1 {
            let day = calc.times(for: today.adding(days: offset))
            for p in Prayer.obligatory where day[p] > now { dates.append(day[p]) }
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = settings.timeZone
        if let midnight = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) { dates.append(midnight) }
        dates.sort()
        let entries = dates.map { PrayerEntry.make(at: $0, settings: settings) }
        completion(Timeline(entries: entries, policy: .after(dates.last ?? now.addingTimeInterval(3600))))
    }
}

struct PrayerWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetCard(prayer: entry.prayer, time: entry.time, settings: entry.settings)
                .containerBackground(Theme.navy, for: .widget)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: entry.prayer.symbol).font(.system(size: 12))
                    Text(entry.prayer.arabicName).font(.system(size: 11, weight: .semibold))
                    Text(DateText.time(entry.time, in: entry.settings.timeZone, use24h: entry.settings.use24h))
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                }
                .minimumScaleFactor(0.7)
            }
            .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 0) {
                Label(entry.prayer.arabicName + " " + DateText.time(entry.time, in: entry.settings.timeZone, use24h: entry.settings.use24h),
                      systemImage: entry.prayer.symbol)
                    .font(.headline)
                Text(timerInterval: Date()...max(Date(), entry.time), countsDown: true)
                    .font(.system(size: 20, weight: .medium).monospacedDigit())
                Text(entry.settings.cityName).font(.caption2).opacity(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.clear, for: .widget)
        case .accessoryInline:
            Text("\(entry.prayer.arabicName) \(DateText.time(entry.time, in: entry.settings.timeZone, use24h: entry.settings.use24h))")
                .containerBackground(.clear, for: .widget)
        default:
            WideWidgetCard(prayer: entry.prayer, time: entry.time, cityName: entry.settings.cityName,
                           hijri: entry.hijri, settings: entry.settings)
                .containerBackground(.white, for: .widget)
        }
    }
}

struct PrayerWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PrayerWidget", provider: PrayerProvider()) { entry in
            PrayerWidgetView(entry: entry)
        }
        .configurationDisplayName("المؤذّن")
        .description("الصلاة القادمة والوقت المتبقي عليها")
        .supportedFamilies([.systemMedium, .systemSmall, .accessoryRectangular, .accessoryCircular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

@main
struct AlmuadhinWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerWidget()
    }
}

#Preview(as: .systemMedium) {
    PrayerWidget()
} timeline: {
    PrayerEntry.make(at: Date())
}
