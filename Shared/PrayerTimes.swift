import Foundation

// MARK: - Prayer

enum Prayer: String, CaseIterable, Codable, Identifiable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha

    var id: String { rawValue }

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }

    var symbol: String {
        switch self {
        case .fajr: return "moon.haze.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "cloud.sun.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }

    /// The five prayers that have an adhan (sunrise excluded).
    static let obligatory: [Prayer] = [.fajr, .dhuhr, .asr, .maghrib, .isha]
}

// MARK: - Calculation method

enum CalculationMethod: String, CaseIterable, Codable, Identifiable {
    case ummAlQura, mwl, egypt, kuwait, qatar, uae, karachi, isna, morocco, turkey

    var id: String { rawValue }

    var arabicName: String {
        switch self {
        case .ummAlQura: return "أم القرى (السعودية)"
        case .mwl: return "رابطة العالم الإسلامي"
        case .egypt: return "الهيئة المصرية العامة للمساحة"
        case .kuwait: return "الكويت"
        case .qatar: return "قطر"
        case .uae: return "الإمارات"
        case .karachi: return "جامعة العلوم الإسلامية، كراتشي"
        case .isna: return "أمريكا الشمالية (ISNA)"
        case .morocco: return "المغرب"
        case .turkey: return "تركيا (ديانت)"
        }
    }

    var fajrAngle: Double {
        switch self {
        case .ummAlQura: return 18.5
        case .egypt: return 19.5
        case .uae: return 18.2
        case .isna: return 15
        case .morocco: return 19
        default: return 18
        }
    }

    /// Isha by sun angle; nil when Isha is a fixed interval after Maghrib.
    var ishaAngle: Double? {
        switch self {
        case .ummAlQura, .qatar: return nil
        case .mwl, .morocco, .turkey: return 17
        case .egypt, .kuwait: return 17.5
        case .uae: return 18.2
        case .karachi: return 18
        case .isna: return 15
        }
    }

    var ishaMinutes: Double { 90 }

    /// Umm al-Qura delays Isha to 120 minutes during Ramadan.
    var ramadanIshaMinutes: Double? { self == .ummAlQura ? 120 : nil }
}

// MARK: - Calendar day

struct DayKey: Hashable, Codable {
    var year: Int
    var month: Int
    var day: Int

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// Midnight UTC of this calendar day.
    var utcMidnight: Date {
        DayKey.utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    var utcNoon: Date { utcMidnight.addingTimeInterval(12 * 3600) }

    func adding(days: Int) -> DayKey {
        let d = DayKey.utc.date(byAdding: .day, value: days, to: utcMidnight)!
        let c = DayKey.utc.dateComponents([.year, .month, .day], from: d)
        return DayKey(year: c.year!, month: c.month!, day: c.day!)
    }

    static func local(_ date: Date, in tz: TimeZone) -> DayKey {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return DayKey(year: c.year!, month: c.month!, day: c.day!)
    }

    var storageKey: String { "\(year)-\(month)-\(day)" }
}

// MARK: - Results

struct PrayerDay {
    let day: DayKey
    let times: [Prayer: Date]

    subscript(_ p: Prayer) -> Date { times[p]! }
}

struct Coordinates: Codable, Equatable {
    var latitude: Double
    var longitude: Double
}

// MARK: - Calculator

/// Astronomical prayer-time calculation (same algorithm as PrayTimes.org).
struct PrayerCalculator {
    var coordinates: Coordinates
    var timeZone: TimeZone
    var method: CalculationMethod
    /// 1 = Shafi'i, Maliki, Hanbali; 2 = Hanafi.
    var asrFactor: Double
    var hijriOffset: Int = 0

    func times(for day: DayKey) -> PrayerDay {
        let lat = coordinates.latitude
        let lng = coordinates.longitude
        let offset = Double(timeZone.secondsFromGMT(for: day.utcNoon)) / 3600
        let jd = Self.julian(day.year, day.month, day.day) - lng / (15 * 24)

        func midDay(_ t: Double) -> Double {
            Self.fix(12 - Self.sunPosition(jd + t).equation, 24)
        }
        func sunAngleTime(_ angle: Double, _ t: Double, ccw: Bool = false) -> Double {
            let decl = Self.sunPosition(jd + t).declination
            let c = (-Self.dsin(angle) - Self.dsin(decl) * Self.dsin(lat)) / (Self.dcos(decl) * Self.dcos(lat))
            if c > 1 || c < -1 { return .nan }
            let T = Self.darccos(c) / 15
            let noon = midDay(t)
            return noon + (ccw ? -T : T)
        }
        func asrTime(_ t: Double) -> Double {
            let decl = Self.sunPosition(jd + t).declination
            let angle = -Self.darccot(asrFactor + Self.dtan(abs(lat - decl)))
            return sunAngleTime(angle, t)
        }

        var fajr = 5.0, sunrise = 6.0, dhuhr = 12.0, asr = 13.0, sunset = 18.0, isha = 18.0
        for _ in 0..<2 {
            fajr = sunAngleTime(method.fajrAngle, (fajr.isNaN ? 5 : fajr) / 24, ccw: true)
            sunrise = sunAngleTime(0.833, sunrise / 24, ccw: true)
            dhuhr = midDay(dhuhr / 24)
            asr = asrTime(asr / 24)
            sunset = sunAngleTime(0.833, sunset / 24)
            if let a = method.ishaAngle { isha = sunAngleTime(a, (isha.isNaN ? 18 : isha) / 24) }
        }

        let adjust = offset - lng / 15
        fajr += adjust; sunrise += adjust; dhuhr += adjust; asr += adjust; sunset += adjust; isha += adjust
        let maghrib = sunset

        if method.ishaAngle == nil {
            var minutes = method.ishaMinutes
            if let ramadan = method.ramadanIshaMinutes, hijriMonth(of: day) == 9 { minutes = ramadan }
            isha = maghrib + minutes / 60
        }

        // High latitudes: cap Fajr/Isha by the angle-based portion of the night.
        let night = 24 - (sunset - sunrise)
        let fajrPortion = method.fajrAngle / 60 * night
        if fajr.isNaN || sunrise - fajr > fajrPortion { fajr = sunrise - fajrPortion }
        if let a = method.ishaAngle {
            let ishaPortion = a / 60 * night
            if isha.isNaN || isha - sunset > ishaPortion { isha = sunset + ishaPortion }
        }

        let base = day.utcMidnight
        func date(_ hours: Double) -> Date {
            let minutes = ((hours - offset) * 60).rounded()
            return base.addingTimeInterval(minutes * 60)
        }
        return PrayerDay(day: day, times: [
            .fajr: date(fajr), .sunrise: date(sunrise), .dhuhr: date(dhuhr),
            .asr: date(asr), .maghrib: date(maghrib), .isha: date(isha),
        ])
    }

    func today(_ now: Date = Date()) -> PrayerDay {
        times(for: DayKey.local(now, in: timeZone))
    }

    /// The next obligatory prayer strictly after `now`.
    func nextPrayer(after now: Date) -> (prayer: Prayer, time: Date) {
        let day = today(now)
        for p in Prayer.obligatory where day[p] > now { return (p, day[p]) }
        let tomorrow = times(for: day.day.adding(days: 1))
        return (.fajr, tomorrow[.fajr])
    }

    /// Midnight and the start of the last third of the night after `day`'s Maghrib.
    func nightMarks(for day: PrayerDay) -> (midnight: Date, lastThird: Date) {
        let nextFajr = times(for: day.day.adding(days: 1))[.fajr]
        let length = nextFajr.timeIntervalSince(day[.maghrib])
        return (day[.maghrib].addingTimeInterval(length / 2), day[.maghrib].addingTimeInterval(length * 2 / 3))
    }

    func hijriMonth(of day: DayKey) -> Int {
        var cal = Calendar(identifier: .islamicUmmAlQura)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.component(.month, from: day.adding(days: hijriOffset).utcNoon)
    }

    // MARK: Astronomy

    private static func dsin(_ d: Double) -> Double { sin(d * .pi / 180) }
    private static func dcos(_ d: Double) -> Double { cos(d * .pi / 180) }
    private static func dtan(_ d: Double) -> Double { tan(d * .pi / 180) }
    private static func darcsin(_ x: Double) -> Double { asin(x) * 180 / .pi }
    private static func darccos(_ x: Double) -> Double { acos(x) * 180 / .pi }
    private static func darctan2(_ y: Double, _ x: Double) -> Double { atan2(y, x) * 180 / .pi }
    private static func darccot(_ x: Double) -> Double { atan(1 / x) * 180 / .pi }
    private static func fix(_ a: Double, _ b: Double) -> Double {
        let r = a - b * floor(a / b)
        return r < 0 ? r + b : r
    }

    private static func julian(_ year: Int, _ month: Int, _ day: Int) -> Double {
        var y = Double(year), m = Double(month)
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(y / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * (y + 4716)) + floor(30.6001 * (m + 1)) + Double(day) + b - 1524.5
    }

    private static func sunPosition(_ jd: Double) -> (declination: Double, equation: Double) {
        let d = jd - 2451545.0
        let g = fix(357.529 + 0.98560028 * d, 360)
        let q = fix(280.459 + 0.98564736 * d, 360)
        let l = fix(q + 1.915 * dsin(g) + 0.020 * dsin(2 * g), 360)
        let e = 23.439 - 0.00000036 * d
        let ra = fix(darctan2(dcos(e) * dsin(l), dcos(l)) / 15, 24)
        return (darcsin(dsin(e) * dsin(l)), q / 15 - ra)
    }
}

// MARK: - Qibla

enum Qibla {
    static let kaaba = Coordinates(latitude: 21.4225, longitude: 39.8262)

    /// Bearing to the Kaaba in degrees clockwise from true north.
    static func bearing(from c: Coordinates) -> Double {
        let r = Double.pi / 180
        let dl = (kaaba.longitude - c.longitude) * r
        let lat = c.latitude * r, klat = kaaba.latitude * r
        let b = atan2(sin(dl), cos(lat) * tan(klat) - sin(lat) * cos(dl)) / r
        return (b + 360).truncatingRemainder(dividingBy: 360)
    }

    static func distanceKm(from c: Coordinates) -> Double {
        let r = Double.pi / 180
        let dLat = (kaaba.latitude - c.latitude) * r, dLng = (kaaba.longitude - c.longitude) * r
        let a = pow(sin(dLat / 2), 2) + cos(c.latitude * r) * cos(kaaba.latitude * r) * pow(sin(dLng / 2), 2)
        return 6371 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}
