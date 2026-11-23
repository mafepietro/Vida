import SwiftUI
import SwiftData

@main
struct VidaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(DataStore.shared.container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Precisa ser configurado logo no início para receber os toques nos botões
        // das notificações ("Tomei", "Lembrar em 10 min"...) mesmo com o app fechado.
        NotificationManager.shared.configure()
        return true
    }
}
