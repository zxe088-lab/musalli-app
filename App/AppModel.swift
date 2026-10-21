import CoreLocation
import SwiftUI
import UserNotifications
import WidgetKit

/// App-wide state: settings, location/heading and adhan notifications.
final class AppModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            settings.save()
            WidgetCenter.shared.reloadAllTimelines()
            scheduleNotifications()
        }
    }
    @Published var heading: Double?
    @Published var locating = false
    @Published var locationError: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        settings = AppSettings.load()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: Location

    func useCurrentLocation() {
        locationError = nil
        locating = true
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locating = false
            locationError = "اسمح للتطبيق بالوصول للموقع من الإعدادات ← الخصوصية ← خدمات الموقع."
        default: manager.requestLocation()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard locating else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.locating = false
                self.locationError = "لم يتم السماح بالوصول للموقع."
            }
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        geocoder.reverseGeocodeLocation(loc, preferredLocale: Locale(identifier: "ar")) { placemarks, _ in
            let place = placemarks?.first
            DispatchQueue.main.async {
                var s = self.settings
                s.cityID = "gps"
                s.cityName = place?.locality ?? place?.administrativeArea ?? "موقعي"
                s.latitude = loc.coordinate.latitude
                s.longitude = loc.coordinate.longitude
                s.timeZoneID = (place?.timeZone ?? .current).identifier
                self.settings = s
                self.locating = false
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locating = false
            self.locationError = "تعذّر تحديد الموقع، حاول مرة أخرى."
        }
    }

    // MARK: Compass

    func startHeading() {
        guard CLLocationManager.headingAvailable() else { return }
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        manager.startUpdatingHeading()
    }

    func stopHeading() { manager.stopUpdatingHeading() }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let h = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        DispatchQueue.main.async { self.heading = h }
    }

    // MARK: Notifications

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { DispatchQueue.main.async { self.scheduleNotifications() } }
        }
    }

    /// iOS keeps at most 64 pending notifications, so schedule the next days that fit.
    func scheduleNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard settings.adhanEnabled else { return }

        let s = settings
        let calc = s.calculator
        let perDay = s.preAlertMinutes > 0 ? 10 : 5
        let days = 64 / perDay
        let now = Date()
        let today = DayKey.local(now, in: s.timeZone)
        // Put a file named adhan.caf (≤ 30 s) in the app bundle to use it as the adhan sound.
        let sound: UNNotificationSound = Bundle.main.url(forResource: "adhan", withExtension: "caf") != nil
            ? UNNotificationSound(named: UNNotificationSoundName("adhan.caf")) : .default

        for offset in 0..<days {
            let day = calc.times(for: today.adding(days: offset))
            for p in Prayer.obligatory {
                let t = day[p]
                if t > now {
                    let c = UNMutableNotificationContent()
                    c.title = "حان الآن موعد صلاة \(p.arabicName)"
                    c.body = "\(s.cityName) · \(DateText.time(t, in: s.timeZone, use24h: s.use24h))"
                    c.sound = sound
                    add(c, at: t, id: "adhan-\(day.day.storageKey)-\(p.rawValue)")
                }
                if s.preAlertMinutes > 0 {
                    let pre = t.addingTimeInterval(Double(-s.preAlertMinutes * 60))
                    if pre > now {
                        let c = UNMutableNotificationContent()
                        c.title = "بقي \(s.preAlertMinutes) دقائق على صلاة \(p.arabicName)"
                        c.sound = .default
                        add(c, at: pre, id: "pre-\(day.day.storageKey)-\(p.rawValue)")
                    }
                }
            }
        }
    }

    private func add(_ content: UNNotificationContent, at date: Date, id: String) {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
