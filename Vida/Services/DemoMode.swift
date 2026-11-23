import Foundation
import SwiftData

/// Modo de demonstração, usado para tirar capturas de tela no GitHub.
/// Abra o app com `-demo -tela hoje|remedios|novo|detalhe`.
/// Usa dados de exemplo num banco temporário: nunca mexe nos seus dados de verdade.
enum DemoMode {
    static let isOn = ProcessInfo.processInfo.arguments.contains("-demo")

    static let screen: String = {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-tela"), index + 1 < args.count else { return "hoje" }
        return args[index + 1]
    }()

    @MainActor
    static func insertSampleData(into context: ModelContext) {
        let calendar = Calendar.current
        let now = Date()
        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: now) ?? now }

        let vitamin = Medication(name: "Vitamina D", dosage: "2.000 UI", unitName: "cápsula",
                                 doseTimes: [8 * 60], stockQuantity: 60, stockDate: daysAgo(12))
        let sertraline = Medication(name: "Sertralina", dosage: "50 mg", doseTimes: [9 * 60, 21 * 60],
                                    stockQuantity: 30, stockDate: daysAgo(10), refillWarningDays: 7,
                                    notes: "Tomar depois do café.")
        let contraceptive = Medication(name: "Anticoncepcional", dosage: "1 comprimido",
                                       doseTimes: [22 * 60], stockQuantity: 28, stockDate: daysAgo(3))
        let magnesium = Medication(name: "Magnésio", dosage: "400 mg", unitName: "cápsula",
                                   doseTimes: [13 * 60], stockQuantity: 30, stockDate: daysAgo(28))
        let all = [vitamin, sertraline, contraceptive, magnesium]
        all.forEach { context.insert($0) }

        // Algumas doses já registradas hoje e ontem.
        let records: [(Medication, Int, Int, DoseStatus)] = [
            (vitamin, 0, 8 * 60, .taken),
            (sertraline, 0, 9 * 60, .taken),
            (vitamin, 1, 8 * 60, .taken),
            (sertraline, 1, 9 * 60, .taken),
            (sertraline, 1, 21 * 60, .skipped),
            (contraceptive, 1, 22 * 60, .taken),
        ]
        for (medication, ago, minutes, status) in records {
            guard let date = TimeFormat.date(minutes: minutes, onDayOf: daysAgo(ago)) else { continue }
            let log = DoseLog(scheduledAt: date, status: status, takenAt: status == .taken ? date : nil)
            context.insert(log)
            log.medication = medication
        }
        try? context.save()
    }
}
