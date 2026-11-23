import Foundation
import SwiftData

/// Ações que mudam os dados dos remédios. Ficam juntas aqui para que a tela
/// e as notificações façam exatamente a mesma coisa.
@MainActor
enum MedicationActions {
    static func record(_ status: DoseStatus, for medication: Medication, scheduledAt: Date, in context: ModelContext) {
        if let existing = medication.log(at: scheduledAt) {
            existing.status = status
            existing.takenAt = status == .taken ? Date() : nil
        } else {
            let log = DoseLog(scheduledAt: scheduledAt, status: status, takenAt: status == .taken ? Date() : nil)
            context.insert(log)
            log.medication = medication
        }
        saveAndReschedule(context)
    }

    static func undo(_ log: DoseLog, in context: ModelContext) {
        context.delete(log)
        saveAndReschedule(context)
    }

    /// Comprou mais: soma ao que sobrou e recomeça a contagem a partir de agora.
    static func restock(_ medication: Medication, adding units: Double, in context: ModelContext) {
        let now = Date()
        let remaining = medication.stockStatus(at: now).unitsRemaining
        medication.stockQuantity = remaining + units
        medication.stockDate = now
        medication.refillRequestedAt = nil
        saveAndReschedule(context)
    }

    /// Corrige o estoque para o número que você contou na caixa.
    static func setStock(_ medication: Medication, to units: Double, in context: ModelContext) {
        medication.stockQuantity = units
        medication.stockDate = Date()
        saveAndReschedule(context)
    }

    static func markRefillRequested(_ medication: Medication, in context: ModelContext) {
        medication.refillRequestedAt = Date()
        saveAndReschedule(context)
    }

    static func delete(_ medication: Medication, in context: ModelContext) {
        context.delete(medication)
        saveAndReschedule(context)
    }

    static func saveAndReschedule(_ context: ModelContext) {
        try? context.save()
        NotificationManager.shared.rescheduleAll()
    }
}
