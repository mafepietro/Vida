import Foundation
import SwiftData
import UserNotifications

/// Cuida de todos os lembretes do app. Tudo é agendado no próprio iPhone
/// (notificações locais), então funciona sem internet e sem servidor.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    /// O iOS guarda no máximo 64 notificações agendadas por app.
    /// Deixamos uma folga para os "lembrar em 10 min".
    private let maxScheduled = 60

    enum Category {
        static let dose = "DOSE"
        static let refill = "REFILL"
        static let expiry = "EXPIRY"
    }

    enum Action {
        static let taken = "TAKEN"
        static let snooze = "SNOOZE"
        static let skip = "SKIP"
        static let refillRequested = "REFILL_REQUESTED"
    }

    enum Prefix {
        static let dose = "dose-"
        static let refill = "refill-"
        static let snooze = "snooze-"
        static let expiry = "expiry-"
    }

    // MARK: - Configuração

    func configure() {
        center.delegate = self

        let taken = UNNotificationAction(identifier: Action.taken, title: "Tomei ✅", options: [])
        let snooze = UNNotificationAction(identifier: Action.snooze, title: "Lembrar em 10 min", options: [])
        let skip = UNNotificationAction(identifier: Action.skip, title: "Pular esta dose", options: [.destructive])
        let dose = UNNotificationCategory(identifier: Category.dose, actions: [taken, snooze, skip], intentIdentifiers: [], options: [])

        let requested = UNNotificationAction(identifier: Action.refillRequested, title: "Já pedi a receita", options: [])
        let refill = UNNotificationCategory(identifier: Category.refill, actions: [requested], intentIdentifiers: [], options: [])

        let expiry = UNNotificationCategory(identifier: Category.expiry, actions: [], intentIdentifiers: [], options: [])

        center.setNotificationCategories([dose, refill, expiry])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: - Agendamento

    /// Apaga e recria todos os lembretes a partir dos dados atuais.
    /// É chamado ao abrir o app e sempre que algo muda.
    func rescheduleAll() {
        let medications = (try? DataStore.shared.context.fetch(FetchDescriptor<Medication>())) ?? []
        let active = medications.filter(\.isActive)

        // Ordem de prioridade, caso passe do limite de 64: remédios, aviso de expiração, receitas.
        var requests: [UNNotificationRequest] = []
        for medication in active {
            requests += doseRequests(for: medication)
        }
        requests += AppExpiry.notificationRequests()
        for medication in active {
            requests += refillRequests(for: medication)
        }
        let finalRequests = Array(requests.prefix(maxScheduled))

        Task {
            let pending = await center.pendingNotificationRequests()
            let toRemove = pending.map(\.identifier).filter { !$0.hasPrefix(Prefix.snooze) }
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
            for request in finalRequests {
                try? await center.add(request)
            }
        }
    }

    private func doseRequests(for medication: Medication) -> [UNNotificationRequest] {
        medication.sortedTimes.map { minutes in
            let content = UNMutableNotificationContent()
            content.title = "Hora do remédio 💊"
            content.body = [medication.name, medication.dosage]
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            content.sound = .default
            content.categoryIdentifier = Category.dose
            content.threadIdentifier = "remedios"
            content.userInfo = ["medicationID": medication.id.uuidString, "minutes": minutes]

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: minutes / 60, minute: minutes % 60),
                repeats: true
            )
            return UNNotificationRequest(
                identifier: "\(Prefix.dose)\(medication.id.uuidString)-\(minutes)",
                content: content,
                trigger: trigger
            )
        }
    }

    /// Avisa todo dia às 10h, a partir da data de aviso, até você marcar "Já pedi a receita".
    private func refillRequests(for medication: Medication) -> [UNNotificationRequest] {
        guard !medication.refillAlreadyRequested else { return [] }
        let status = medication.stockStatus
        guard let warning = status.refillWarningDate, let runOut = status.runOutDate else { return [] }

        let calendar = Calendar.current
        let now = Date()
        let firstDay = max(calendar.startOfDay(for: warning), calendar.startOfDay(for: now))
        let runOutText = runOut.formatted(.dateTime.day().month(.wide))

        var requests: [UNNotificationRequest] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: firstDay),
                  let fireDate = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day),
                  fireDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Hora de pedir receita 📝"
            content.body = fireDate >= runOut
                ? "\(medication.name) acabou. Peça uma nova receita ao médico."
                : "\(medication.name) acaba por volta de \(runOutText). Peça uma nova receita ao médico."
            content.sound = .default
            content.categoryIdentifier = Category.refill
            content.threadIdentifier = "receitas"
            content.userInfo = ["medicationID": medication.id.uuidString]

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            requests.append(UNNotificationRequest(
                identifier: "\(Prefix.refill)\(medication.id.uuidString)-\(offset)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }
        return requests
    }

    private func scheduleSnooze(for medication: Medication, minutes: Int?) {
        let content = UNMutableNotificationContent()
        content.title = "Lembrete: remédio 💊"
        content.body = "Ainda falta tomar \(medication.name)."
        content.sound = .default
        content.categoryIdentifier = Category.dose
        content.threadIdentifier = "remedios"
        var info: [String: Any] = ["medicationID": medication.id.uuidString]
        if let minutes { info["minutes"] = minutes }
        content.userInfo = info

        let request = UNNotificationRequest(
            identifier: "\(Prefix.snooze)\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
        )
        center.add(request, withCompletionHandler: nil)
    }

    // MARK: - Respostas às notificações

    /// Mostra a notificação mesmo com o app aberto.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        let deliveredAt = response.notification.date
        guard let idString = info["medicationID"] as? String,
              let medicationID = UUID(uuidString: idString) else { return }
        let minutes = info["minutes"] as? Int

        await MainActor.run {
            NotificationManager.shared.handle(
                action: action,
                medicationID: medicationID,
                minutes: minutes,
                deliveredAt: deliveredAt
            )
        }
    }

    private func handle(action: String, medicationID: UUID, minutes: Int?, deliveredAt: Date) {
        let context = DataStore.shared.context
        let descriptor = FetchDescriptor<Medication>(predicate: #Predicate { $0.id == medicationID })
        guard let medication = try? context.fetch(descriptor).first else { return }

        // O horário original da dose (mesmo que a notificação tenha sido adiada).
        let scheduledAt = minutes.flatMap { TimeFormat.date(minutes: $0, onDayOf: deliveredAt) } ?? deliveredAt

        switch action {
        case Action.taken:
            MedicationActions.record(.taken, for: medication, scheduledAt: scheduledAt, in: context)
        case Action.skip:
            MedicationActions.record(.skipped, for: medication, scheduledAt: scheduledAt, in: context)
        case Action.snooze:
            scheduleSnooze(for: medication, minutes: minutes)
        case Action.refillRequested:
            MedicationActions.markRefillRequested(medication, in: context)
        default:
            break // Tocou na notificação em si: só abre o app.
        }
    }
}
