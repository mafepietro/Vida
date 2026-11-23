import Foundation
import SwiftData

@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    /// Texto livre, ex.: "50 mg" ou "1 cápsula em jejum".
    var dosage: String = ""
    /// Nome da unidade que fica na caixa: comprimido, cápsula, gota, ml...
    var unitName: String = "comprimido"
    /// Quantas unidades você toma em cada horário.
    var unitsPerDose: Double = 1
    /// Horários do dia, em minutos depois da meia-noite (8:30 = 510).
    var doseTimes: [Int] = []
    /// Quantas unidades havia na data `stockDate` (normalmente, quando comprou).
    var stockQuantity: Double = 0
    var stockDate: Date = Date()
    /// Quantos dias antes de acabar o app começa a avisar para pedir receita.
    var refillWarningDays: Int = 7
    /// Quando você marcou "Já pedi a receita".
    var refillRequestedAt: Date?
    var notes: String = ""
    var isActive: Bool = true
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medication)
    var logs: [DoseLog]? = []

    init(
        name: String,
        dosage: String = "",
        unitName: String = "comprimido",
        unitsPerDose: Double = 1,
        doseTimes: [Int],
        stockQuantity: Double,
        stockDate: Date = Date(),
        refillWarningDays: Int = 7,
        notes: String = ""
    ) {
        self.name = name
        self.dosage = dosage
        self.unitName = unitName
        self.unitsPerDose = unitsPerDose
        self.doseTimes = doseTimes.sorted()
        self.stockQuantity = stockQuantity
        self.stockDate = stockDate
        self.refillWarningDays = refillWarningDays
        self.notes = notes
    }
}

extension Medication {
    var sortedTimes: [Int] { doseTimes.sorted() }

    /// Doses que você marcou como "pulei" desde a última compra. Elas não gastam estoque.
    var skippedSinceStock: Int {
        (logs ?? []).filter { $0.status == .skipped && $0.scheduledAt > stockDate }.count
    }

    var stockStatus: StockStatus {
        stockStatus(at: Date())
    }

    func stockStatus(at date: Date) -> StockStatus {
        MedicationMath.status(
            stockQuantity: stockQuantity,
            stockDate: stockDate,
            unitsPerDose: unitsPerDose,
            times: doseTimes,
            skippedDoses: skippedSinceStock,
            refillWarningDays: refillWarningDays,
            now: date
        )
    }

    /// Já pediu a receita depois da última compra?
    var refillAlreadyRequested: Bool {
        guard let requested = refillRequestedAt else { return false }
        return requested >= stockDate
    }

    var timesDescription: String {
        sortedTimes.map(TimeFormat.string(minutes:)).joined(separator: " · ")
    }

    func log(at scheduledAt: Date) -> DoseLog? {
        (logs ?? []).first { abs($0.scheduledAt.timeIntervalSince(scheduledAt)) < 60 }
    }
}
