import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = DemoMode.screen == "hoje" ? 0 : 1

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Hoje", systemImage: "sun.max.fill", value: 0) {
                TodayView()
            }
            Tab("Remédios", systemImage: "pills.fill", value: 1) {
                MedicationListView()
            }
        }
        .task {
            guard !DemoMode.isOn else { return }
            _ = await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.rescheduleAll()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && !DemoMode.isOn {
                NotificationManager.shared.rescheduleAll()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(DataStore.preview)
}
