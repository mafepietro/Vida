import Foundation
import UserNotifications

/// Com a conta gratuita da Apple, o app instalado pelo Xcode para de abrir
/// depois de 7 dias. Aqui o app descobre sozinho quando isso vai acontecer
/// (lendo o "perfil de instalação" que o Xcode coloca dentro dele) e avisa antes.
enum AppExpiry {
    static let expirationDate: Date? = readExpirationDate()

    static var daysLeft: Int? {
        guard let expirationDate else { return nil }
        let seconds = expirationDate.timeIntervalSinceNow
        return max(0, Int((seconds / 86_400).rounded(.down)))
    }

    private static func readExpirationDate() -> Date? {
        // No simulador esse arquivo não existe, e tudo bem: aí não tem aviso.
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>"),
              start.lowerBound < end.upperBound else { return nil }

        let plistText = String(text[start.lowerBound..<end.upperBound])
        guard let plistData = plistText.data(using: .isoLatin1),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            return nil
        }
        return plist["ExpirationDate"] as? Date
    }

    /// Avisos 2 dias e 1 dia antes de expirar, às 19h.
    static func notificationRequests() -> [UNNotificationRequest] {
        guard let expirationDate else { return [] }
        let calendar = Calendar.current
        let now = Date()

        return [2, 1].compactMap { daysBefore in
            guard let day = calendar.date(byAdding: .day, value: -daysBefore, to: expirationDate),
                  let fireDate = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: day),
                  fireDate > now else { return nil }

            let content = UNMutableNotificationContent()
            content.title = daysBefore == 1 ? "O Vida expira amanhã ⏳" : "O Vida expira em 2 dias ⏳"
            content.body = "Conecte o iPhone no Mac, abra o Xcode e aperte ▶︎ para renovar. Sem isso, os lembretes param."
            content.sound = .default
            content.categoryIdentifier = NotificationManager.Category.expiry
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            return UNNotificationRequest(
                identifier: "\(NotificationManager.Prefix.expiry)\(daysBefore)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
        }
    }
}
