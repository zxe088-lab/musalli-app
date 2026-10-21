import Foundation

/// User settings, shared with the widget through the App Group.
struct AppSettings: Codable, Equatable {
    var cityID: String = "jeddah"
    var cityName: String = "جدة"
    var latitude: Double = 21.5433
    var longitude: Double = 39.1728
    var timeZoneID: String = "Asia/Riyadh"
    var method: CalculationMethod = .ummAlQura
    var asrFactor: Double = 1
    var use24h: Bool = false
    var hijriOffset: Int = 0
    var adhanEnabled: Bool = true
    var preAlertMinutes: Int = 0

    static let appGroup = "group.com.zxe088.almuadhin"
    private static let key = "settings.v1"

    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }

    static func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let s = try? JSONDecoder().decode(AppSettings.self, from: data) else { return AppSettings() }
        return s
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { AppSettings.defaults.set(data, forKey: AppSettings.key) }
    }

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    var coordinates: Coordinates { Coordinates(latitude: latitude, longitude: longitude) }

    var calculator: PrayerCalculator {
        PrayerCalculator(coordinates: coordinates, timeZone: timeZone, method: method,
                         asrFactor: asrFactor, hijriOffset: hijriOffset)
    }

    mutating func apply(_ city: City) {
        cityID = city.id
        cityName = city.name
        latitude = city.latitude
        longitude = city.longitude
        timeZoneID = city.timeZoneID
        method = city.method
    }
}

struct City: Identifiable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String
    let method: CalculationMethod

    static let all: [City] = [
        City(id: "jeddah", name: "جدة", latitude: 21.5433, longitude: 39.1728, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "makkah", name: "مكة المكرمة", latitude: 21.4225, longitude: 39.8262, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "madinah", name: "المدينة المنورة", latitude: 24.4672, longitude: 39.6111, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "taif", name: "الطائف", latitude: 21.2703, longitude: 40.4158, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "riyadh", name: "الرياض", latitude: 24.7136, longitude: 46.6753, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "dammam", name: "الدمام", latitude: 26.4207, longitude: 50.0888, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "buraydah", name: "بريدة", latitude: 26.3592, longitude: 43.9818, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "abha", name: "أبها", latitude: 18.2164, longitude: 42.5053, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "tabuk", name: "تبوك", latitude: 28.3838, longitude: 36.5550, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "hail", name: "حائل", latitude: 27.5114, longitude: 41.7208, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "jazan", name: "جازان", latitude: 16.8892, longitude: 42.5511, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "najran", name: "نجران", latitude: 17.4924, longitude: 44.1277, timeZoneID: "Asia/Riyadh", method: .ummAlQura),
        City(id: "kuwait", name: "الكويت", latitude: 29.3759, longitude: 47.9774, timeZoneID: "Asia/Kuwait", method: .kuwait),
        City(id: "dubai", name: "دبي", latitude: 25.2048, longitude: 55.2708, timeZoneID: "Asia/Dubai", method: .uae),
        City(id: "abudhabi", name: "أبوظبي", latitude: 24.4539, longitude: 54.3773, timeZoneID: "Asia/Dubai", method: .uae),
        City(id: "doha", name: "الدوحة", latitude: 25.2854, longitude: 51.5310, timeZoneID: "Asia/Qatar", method: .qatar),
        City(id: "manama", name: "المنامة", latitude: 26.2285, longitude: 50.5860, timeZoneID: "Asia/Bahrain", method: .ummAlQura),
        City(id: "muscat", name: "مسقط", latitude: 23.5880, longitude: 58.3829, timeZoneID: "Asia/Muscat", method: .mwl),
        City(id: "cairo", name: "القاهرة", latitude: 30.0444, longitude: 31.2357, timeZoneID: "Africa/Cairo", method: .egypt),
        City(id: "amman", name: "عمّان", latitude: 31.9454, longitude: 35.9284, timeZoneID: "Asia/Amman", method: .mwl),
        City(id: "istanbul", name: "إسطنبول", latitude: 41.0082, longitude: 28.9784, timeZoneID: "Europe/Istanbul", method: .turkey),
        City(id: "london", name: "لندن", latitude: 51.5074, longitude: -0.1278, timeZoneID: "Europe/London", method: .mwl),
    ]
}

/// Arabic date and time strings.
enum DateText {
    private static let arabicLatn = Locale(identifier: "ar_SA@numbers=latn")

    private static func formatter(_ calendar: Calendar.Identifier, _ format: String) -> DateFormatter {
        let f = DateFormatter()
        var cal = Calendar(identifier: calendar)
        cal.timeZone = TimeZone(identifier: "UTC")!
        f.calendar = cal
        f.locale = arabicLatn
        f.timeZone = cal.timeZone
        f.dateFormat = format
        return f
    }

    private static let hijriLong = formatter(.islamicUmmAlQura, "EEEE d MMMM y")
    private static let hijriShort = formatter(.islamicUmmAlQura, "d MMMM y")
    private static let gregorian = formatter(.gregorian, "d MMMM y")
    private static let weekdayF = formatter(.gregorian, "EEEE")

    /// e.g. "الأربعاء 10 جمادى الأولى 1448"
    static func hijri(_ day: DayKey, offset: Int, weekday: Bool = true) -> String {
        let shifted = day.adding(days: offset).utcNoon
        let text = (weekday ? hijriLong : hijriShort).string(from: shifted)
        // Weekday follows the real day, not the shifted Hijri day.
        if weekday && offset != 0 {
            return weekdayF.string(from: day.utcNoon) + " " + hijriShort.string(from: shifted)
        }
        return text
    }

    static func gregorian(_ day: DayKey) -> String { gregorian.string(from: day.utcNoon) }
    static func weekday(_ day: DayKey) -> String { weekdayF.string(from: day.utcNoon) }

    /// "12:08" (12h without suffix) or "12:08" / "17:54" in 24h.
    static func time(_ date: Date, in tz: TimeZone, use24h: Bool) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.hour, .minute], from: date)
        var h = c.hour ?? 0
        if !use24h { h = h % 12 == 0 ? 12 : h % 12 }
        return use24h ? String(format: "%02d:%02d", h, c.minute ?? 0) : String(format: "%d:%02d", h, c.minute ?? 0)
    }

    /// "ص" before noon, "م" after.
    static func period(_ date: Date, in tz: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return (cal.component(.hour, from: date)) < 12 ? "ص" : "م"
    }
}
