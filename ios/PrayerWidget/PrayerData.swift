import Foundation

/// Flutter tarafının `home_widget` üzerinden App Group'a yazdığı veriyi okur.
///
/// Anahtarlar `lib/platform/widget_bridge.dart` ile birebir aynıdır.
/// Android'de aynı işi `PrayerStore.kt` yapar; iki taraf da sıradaki vakti
/// kendisi hesaplar, böylece widget Flutter'ı uyandırmadan çalışır.
enum PrayerData {

    static let appGroup = "group.com.tunahan.namazvakitleri"

    static let prayerCount = 18

    /// Kıble Sâati kronolojik zincire girmez.
    static let qiblaIndex = 17

    struct Snapshot {
        let cityDisplay: String
        let hijri: String
        let dateToday: String
        let timesToday: [String?]
        let timesTomorrow: [String?]
        let visible: Set<Int>
        let language: String
        let showSeconds: Bool
        private let namesTr: [String]
        private let namesEn: [String]

        init(defaults: UserDefaults?) {
            func string(_ key: String) -> String { defaults?.string(forKey: key) ?? "" }

            cityDisplay = string("city_display")
            hijri = string("hijri")
            dateToday = string("date_today")
            timesToday = Snapshot.parseTimes(string("times_today"))
            timesTomorrow = Snapshot.parseTimes(string("times_tomorrow"))
            visible = Snapshot.parseIndices(string("visible_prayers"))
            language = string("language")
            showSeconds = defaults?.object(forKey: "show_seconds") == nil
                ? true
                : defaults?.bool(forKey: "show_seconds") ?? true
            namesTr = string("prayer_names_tr").components(separatedBy: "|")
            namesEn = string("prayer_names_en").components(separatedBy: "|")
        }

        var hasData: Bool {
            !dateToday.isEmpty && timesToday.contains { $0 != nil }
        }

        func name(at index: Int) -> String {
            let names = language == "en" ? namesEn : namesTr
            return index < names.count ? names[index] : ""
        }

        /// "03:59,04:19,…" → 18 elemanlı dizi.
        private static func parseTimes(_ raw: String) -> [String?] {
            guard !raw.isEmpty else { return Array(repeating: nil, count: prayerCount) }
            let parts = raw.components(separatedBy: ",")
            return (0..<prayerCount).map { i -> String? in
                guard i < parts.count else { return nil }
                let value = parts[i]
                return value.count == 5 && value.contains(":") ? value : nil
            }
        }

        /// "0,1,2,6" → {0,1,2,6}
        private static func parseIndices(_ raw: String) -> Set<Int> {
            guard !raw.isEmpty else { return [] }
            return Set(raw.components(separatedBy: ",").compactMap { Int($0) })
        }
    }

    static func load() -> Snapshot {
        Snapshot(defaults: UserDefaults(suiteName: appGroup))
    }
}

/// Vakitleri gerçek zamana oturtur — Dart'taki `PrayerDay.dateTimeOf` ve
/// Kotlin'deki `PrayerSchedule` ile aynı kuralları uygular.
struct PrayerSchedule {

    struct Entry {
        let index: Int
        let date: Date
    }

    let snapshot: PrayerData.Snapshot
    private let calendar = Calendar.current

    init(snapshot: PrayerData.Snapshot) {
        self.snapshot = snapshot
    }

    /// Bugünün ve yarının vakitleri, zaman sırasında.
    func entries(onlyVisible: Bool = true) -> [Entry] {
        guard let anchor = midnight(of: snapshot.dateToday) else { return [] }
        let wanted = onlyVisible ? snapshot.visible : Set(0..<PrayerData.prayerCount)

        var result = appendDay(snapshot.timesToday, anchor: anchor, wanted: wanted)
        if let tomorrowAnchor = calendar.date(byAdding: .day, value: 1, to: anchor) {
            result += appendDay(snapshot.timesTomorrow, anchor: tomorrowAnchor, wanted: wanted)
        }
        return result.sorted { $0.date < $1.date }
    }

    /// Verilen ândan sonraki ilk vakit ve o an içinde bulunulan vakit.
    ///
    /// Kıble Sâati listede görünse de sıraya girmez: bir namaz vakti değil,
    /// günün içinde duran bir andır.
    func next(after now: Date = Date()) -> (next: Entry, current: Entry?)? {
        var current: Entry?
        for entry in entries() where entry.index != PrayerData.qiblaIndex {
            if entry.date > now {
                return (entry, current)
            }
            current = entry
        }
        return nil
    }

    private func appendDay(_ times: [String?], anchor: Date, wanted: Set<Int>) -> [Entry] {
        var out: [Entry] = []
        var dayOffset = 0
        var previousMinutes = -1

        for index in 0..<PrayerData.prayerCount {
            guard let raw = times[index], let minutes = Self.minutes(of: raw) else { continue }

            if index == PrayerData.qiblaIndex {
                // Zincire girmez; günün kendi içinde kalır.
                if wanted.contains(index), let date = at(anchor, days: 0, minutes: minutes) {
                    out.append(Entry(index: index, date: date))
                }
                continue
            }

            if previousMinutes >= 0 && minutes < previousMinutes { dayOffset += 1 }
            previousMinutes = minutes

            if wanted.contains(index), let date = at(anchor, days: dayOffset, minutes: minutes) {
                out.append(Entry(index: index, date: date))
            }
        }
        return out
    }

    private func at(_ anchor: Date, days: Int, minutes: Int) -> Date? {
        guard let shifted = calendar.date(byAdding: .day, value: days, to: anchor) else {
            return nil
        }
        return calendar.date(byAdding: .minute, value: minutes, to: shifted)
    }

    private func midnight(of date: String) -> Date? {
        let parts = date.components(separatedBy: "-").compactMap(Int.init)
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar.date(from: components)
    }

    /// "13:48" → 828
    static func minutes(of hhmm: String) -> Int? {
        let parts = hhmm.components(separatedBy: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              h <= 23, m <= 59 else { return nil }
        return h * 60 + m
    }

    static func clock(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
