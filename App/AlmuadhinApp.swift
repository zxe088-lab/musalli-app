import SwiftUI

@main
struct AlmuadhinApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                HomeView()
            }
            .environmentObject(model)
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.locale, Locale(identifier: "ar"))
            .tint(Theme.navy)
            .onAppear { model.requestNotificationPermission() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Top up the notification queue each time the app opens.
            if phase == .active { model.scheduleNotifications() }
        }
    }
}
