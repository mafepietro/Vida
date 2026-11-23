import Foundation

/// Situação do estoque de um remédio num certo momento.
struct StockStatus: Equatable {
    /// Unidades que sobram (comprimidos, gotas...).
    var unitsRemaining: Double
    /// Doses completas que ainda dá para tomar.
    var dosesRemaining: Int
    /// Dias completos de remédio que ainda restam.
    var daysRemaining: Int
    /// Primeira dose que não vai ter remédio. `nil` quando não há horários.
    var runOutDate: Date?
    /// Dia a partir do qual o app avisa para pedir nova receita.
    var refillWarningDate: Date?
    /// Já chegou a hora de pedir receita?
    var needsRefill: Bool
    /// Acabou?
    var isOut: Bool
}

/// Contas do estoque. Não depende de SwiftUI nem do banco de dados,
/// assim é fácil de conferir e testar.
enum MedicationMath {
    static func validTimes(_ times: [Int]) -> [Int] {
        Array(Set(times.filter { (0..<1440).contains($0) })).sorted()
    }

    /// Todos os horários de dose depois de `start` e até `end` (inclusive).
    static func scheduledDoses(
        times: [Int],
        after start: Date,
        through end: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let sorted = validTimes(times)
        guard end > start, !sorted.isEmpty else { return [] }
        var result: [Date] = []
        var day = calendar.startOfDay(for: start)
        while day <= end {
            for minutes in sorted {
                guard let dose = TimeFormat.date(minutes: minutes, onDayOf: day, calendar: calendar) else { continue }
                if dose > start && dose <= end {
                    result.append(dose)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// As próximas `count` doses depois de `start`.
    static func nextDoses(times: [Int], after start: Date, count: Int, calendar: Calendar = .current) -> [Date] {
        let sorted = validTimes(times)
        guard count > 0, !sorted.isEmpty else { return [] }
        var result: [Date] = []
        var day = calendar.startOfDay(for: start)
        while result.count < count {
            for minutes in sorted {
                guard let dose = TimeFormat.date(minutes: minutes, onDayOf: day, calendar: calendar) else { continue }
                if dose > start {
                    result.append(dose)
                    if result.count == count { break }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    /// O estoque é estimado pelos horários: a gente considera que você tomou
    /// todas as doses desde a compra, menos as que marcou como "pulei".
    /// Assim a conta funciona mesmo se você esquecer de tocar em "Tomei".
    static func status(
        stockQuantity: Double,
        stockDate: Date,
        unitsPerDose: Double,
        times: [Int],
        skippedDoses: Int,
        refillWarningDays: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> StockStatus {
        let times = validTimes(times)
        guard !times.isEmpty, unitsPerDose > 0 else {
            return StockStatus(
                unitsRemaining: max(0, stockQuantity),
                dosesRemaining: 0,
                daysRemaining: 0,
                runOutDate: nil,
                refillWarningDate: nil,
                needsRefill: false,
                isOut: stockQuantity <= 0
            )
        }

        let elapsed = scheduledDoses(times: times, after: stockDate, through: now, calendar: calendar).count
        let consumedDoses = max(0, elapsed - skippedDoses)
        let remaining = max(0, stockQuantity - Double(consumedDoses) * unitsPerDose)
        // O 1e-9 evita que 2,9999999 vire 2 por causa de arredondamento.
        let dosesLeft = Int((remaining / unitsPerDose + 1e-9).rounded(.down))
        let daysLeft = dosesLeft / times.count

        // A primeira dose sem remédio é a (dosesLeft + 1)ª a partir de agora.
        let upcoming = nextDoses(times: times, after: now, count: dosesLeft + 1, calendar: calendar)
        let runOut = upcoming.last

        var warning: Date?
        if let runOut,
           let date = calendar.date(byAdding: .day, value: -refillWarningDays, to: calendar.startOfDay(for: runOut)) {
            warning = date
        }

        return StockStatus(
            unitsRemaining: remaining,
            dosesRemaining: dosesLeft,
            daysRemaining: daysLeft,
            runOutDate: runOut,
            refillWarningDate: warning,
            needsRefill: warning.map { now >= $0 } ?? false,
            isOut: dosesLeft == 0
        )
    }
}

enum TimeFormat {
    static func date(minutes: Int, onDayOf day: Date, calendar: Calendar = .current) -> Date? {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    static func string(minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }

    /// Formata números como 1 ou 1,5 (sem ",0").
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
