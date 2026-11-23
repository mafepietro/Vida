import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Hoje", systemImage: "sun.max.fill") {
                TodayView()
            }
            Tab("Remédios", systemImage: "pills.fill") {
                MedicationListView()
            }
        }
        .task {
            _ = await NotificationManager.shared.requestAuthorization()
            NotificationManager.shared.rescheduleAll()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationManager.shared.rescheduleAll()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(DataStore.preview)
}
