import Foundation
import SwiftData

enum DoseStatus: String, Codable {
    case taken
    case skipped
}

/// Registro de uma dose: tomada ou pulada.
@Model
final class DoseLog {
    var id: UUID = UUID()
    /// O horário em que a dose estava marcada.
    var scheduledAt: Date = Date()
    /// Quando você tocou em "Tomei".
    var takenAt: Date?
    var statusRaw: String = DoseStatus.taken.rawValue
    var medication: Medication?

    var status: DoseStatus {
        get { DoseStatus(rawValue: statusRaw) ?? .taken }
        set { statusRaw = newValue.rawValue }
    }

    init(scheduledAt: Date, status: DoseStatus, takenAt: Date? = nil) {
        self.scheduledAt = scheduledAt
        self.statusRaw = status.rawValue
        self.takenAt = takenAt
    }
}
