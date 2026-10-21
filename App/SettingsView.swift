import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var notificationsDenied = false

    var body: some View {
        Form {
            Section("الموقع") {
                Button {
                    model.useCurrentLocation()
                } label: {
                    HStack {
                        Label("استخدم موقعي الحالي", systemImage: "location.fill")
                        Spacer()
                        if model.locating { ProgressView() }
                    }
                }
                if let err = model.locationError {
                    Text(err).font(.footnote).foregroundStyle(.red)
                }
                Picker("المدينة", selection: Binding(
                    get: { model.settings.cityID },
                    set: { id in
                        if let c = City.all.first(where: { $0.id == id }) { model.settings.apply(c) }
                    })) {
                    if model.settings.cityID == "gps" { Text("\(model.settings.cityName) (موقعي)").tag("gps") }
                    ForEach(City.all) { Text($0.name).tag($0.id) }
                }
                LabeledContent("الإحداثيات") {
                    Text(String(format: "%.4f، %.4f", model.settings.latitude, model.settings.longitude))
                        .monospacedDigit().environment(\.layoutDirection, .leftToRight)
                }
            }

            Section("طريقة الحساب") {
                Picker("الطريقة", selection: $model.settings.method) {
                    ForEach(CalculationMethod.allCases) { Text($0.arabicName).tag($0) }
                }
                Picker("العصر", selection: $model.settings.asrFactor) {
                    Text("الجمهور").tag(1.0)
                    Text("الحنفي").tag(2.0)
                }
                Picker("تعديل التاريخ الهجري", selection: $model.settings.hijriOffset) {
                    Text("-1 يوم").tag(-1)
                    Text("بدون").tag(0)
                    Text("+1 يوم").tag(1)
                }
                Toggle("صيغة 24 ساعة", isOn: $model.settings.use24h)
            }

            Section {
                Toggle("تنبيه الأذان", isOn: $model.settings.adhanEnabled)
                Picker("تنبيه قبل الأذان", selection: $model.settings.preAlertMinutes) {
                    Text("بدون").tag(0)
                    Text("5 دقائق").tag(5)
                    Text("10 دقائق").tag(10)
                    Text("15 دقيقة").tag(15)
                }
                if notificationsDenied {
                    Button("الإشعارات مقفلة، افتح إعدادات الجوال") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .foregroundStyle(.red)
                }
            } header: {
                Text("التنبيهات")
            } footer: {
                Text("يُجدول التطبيق تنبيهات الأيام القادمة تلقائيًا كل ما فتحته.")
            }

            Section {
                LabeledContent("الإصدار", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
            }
        }
        .navigationTitle("الإعدادات")
        .task {
            let s = await UNUserNotificationCenter.current().notificationSettings()
            notificationsDenied = s.authorizationStatus == .denied
        }
    }
}
