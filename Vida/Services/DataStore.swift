import Foundation
import SwiftData

/// Guarda todos os dados do app no próprio iPhone.
/// (Sem iCloud, porque a conta gratuita da Apple não permite.)
@MainActor
final class DataStore {
    static let shared = DataStore()

    static let schema = Schema([Medication.self, DoseLog.self])

    let container: ModelContainer

    var context: ModelContext { container.mainContext }

    private init() {
        let configuration = ModelConfiguration(
            schema: Self.schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            container = try ModelContainer(for: Self.schema, configurations: [configuration])
        } catch {
            fatalError("Não foi possível abrir o banco de dados: \(error)")
        }
    }

    /// Banco de dados de mentira, só para as pré-visualizações do Xcode.
    static var preview: ModelContainer = {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let calendar = Calendar.current
        let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: Date())!
        let samples = [
            Medication(name: "Vitamina D", dosage: "1 cápsula", doseTimes: [8 * 60], stockQuantity: 30, stockDate: tenDaysAgo),
            Medication(name: "Sertralina", dosage: "50 mg", doseTimes: [9 * 60, 21 * 60], stockQuantity: 28, stockDate: tenDaysAgo, refillWarningDays: 7),
        ]
        samples.forEach { container.mainContext.insert($0) }
        return container
    }()
}
