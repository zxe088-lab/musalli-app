import Foundation

// Regression check for the prayer-time engine; run with:
//   swiftc Shared/PrayerTimes.swift Tests/main.swift -o /tmp/check && /tmp/check
var failures = 0
func expect(_ name: String, _ got: String, _ want: String) {
    if got == want { print("ok   \(name) \(got)") } else { print("FAIL \(name) got \(got) want \(want)"); failures += 1 }
}
func hm(_ d: Date, _ tz: TimeZone) -> String {
    var c = Calendar(identifier: .gregorian); c.timeZone = tz
    let x = c.dateComponents([.hour, .minute], from: d)
    return String(format: "%02d:%02d", x.hour!, x.minute!)
}

let riyadhTZ = TimeZone(identifier: "Asia/Riyadh")!
let jeddah = PrayerCalculator(coordinates: Coordinates(latitude: 21.5433, longitude: 39.1728),
                              timeZone: riyadhTZ, method: .ummAlQura, asrFactor: 1)
let day = jeddah.times(for: DayKey(year: 2026, month: 10, day: 21))
// Reference values computed by the web prototype for Jeddah, Umm al-Qura.
let want: [Prayer: String] = [.fajr: "05:05", .sunrise: "06:21", .dhuhr: "12:08", .asr: "15:27", .maghrib: "17:54", .isha: "19:24"]
for p in Prayer.allCases { expect("jeddah \(p.rawValue)", hm(day[p], riyadhTZ), want[p]!) }

let night = jeddah.nightMarks(for: day)
expect("jeddah midnight", hm(night.midnight, riyadhTZ), "23:29")
expect("jeddah lastThird", hm(night.lastThird, riyadhTZ), "01:21")

// Next prayer at 08:38 local is Dhuhr.
let morning = DayKey(year: 2026, month: 10, day: 21).utcMidnight.addingTimeInterval(5 * 3600 + 38 * 60)
let next = jeddah.nextPrayer(after: morning)
expect("next prayer", next.prayer.rawValue, "dhuhr")

// After Isha the next prayer is tomorrow's Fajr.
let late = DayKey(year: 2026, month: 10, day: 21).utcMidnight.addingTimeInterval(20 * 3600)
expect("after isha", jeddah.nextPrayer(after: late).prayer.rawValue, "fajr")

// High latitude in summer must still give ordered, finite times.
let londonTZ = TimeZone(identifier: "Europe/London")!
let london = PrayerCalculator(coordinates: Coordinates(latitude: 51.5074, longitude: -0.1278),
                              timeZone: londonTZ, method: .mwl, asrFactor: 1)
let june = london.times(for: DayKey(year: 2026, month: 6, day: 21))
let ordered = zip(Prayer.allCases, Prayer.allCases.dropFirst()).allSatisfy { june[$0.0] < june[$0.1] }
expect("london june ordered", String(ordered), "true")

// Qibla from Riyadh is roughly west-south-west (~244°).
let qibla = Qibla.bearing(from: Coordinates(latitude: 24.7136, longitude: 46.6753))
expect("riyadh qibla", String(Int(qibla.rounded())), "244")

if failures > 0 { print("\(failures) failure(s)"); exit(1) }
print("all checks passed")
