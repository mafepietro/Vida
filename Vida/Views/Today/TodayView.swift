import SwiftUI
import SwiftData

/// Uma dose marcada para hoje.
struct TodayDose: Identifiable {
    let medication: Medication
    let scheduledAt: Date
    let log: DoseLog?

    var id: String { "\(medication.id.uuidString)-\(scheduledAt.timeIntervalSince1970)" }
}

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Medication> { $0.isActive }, sort: \Medication.name)
    private var medications: [Medication]

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                content(now: timeline.date)
            }
            .navigationTitle(greeting)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let doses = todayDoses(now: now)
        let refills = medications.filter { $0.stockStatus(at: now).needsRefill && !$0.refillAlreadyRequested }

        List {
            if let daysLeft = AppExpiry.daysLeft, daysLeft <= 2 {
                Section {
                    ExpiryBanner(daysLeft: daysLeft)
                }
            }

            if !refills.isEmpty {
                Section("Pedir receita") {
                    ForEach(refills) { medication in
                        RefillRow(medication: medication, now: now) {
                            MedicationActions.markRefillRequested(medication, in: context)
                        }
                    }
                }
            }

            Section {
                if doses.isEmpty {
                    Text(medications.isEmpty
                         ? "Cadastre seus remédios na aba Remédios."
                         : "Nenhum remédio para hoje.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(doses) { dose in
                        TodayDoseRow(dose: dose, now: now) {
                            toggle(dose)
                        }
                    }
                }
            } header: {
                Text("Remédios de hoje")
            } footer: {
                if !doses.isEmpty {
                    Text("Toque para marcar como tomado. Toque de novo para desfazer.")
                }
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Bom dia ☀️"
        case 12..<18: return "Boa tarde 🌤️"
        default: return "Boa noite 🌙"
        }
    }

    private func todayDoses(now: Date) -> [TodayDose] {
        medications
            .flatMap { medication in
                medication.sortedTimes.compactMap { minutes -> TodayDose? in
                    guard let date = TimeFormat.date(minutes: minutes, onDayOf: now) else { return nil }
                    return TodayDose(medication: medication, scheduledAt: date, log: medication.log(at: date))
                }
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private func toggle(_ dose: TodayDose) {
        if let log = dose.log {
            MedicationActions.undo(log, in: context)
        } else {
            MedicationActions.record(.taken, for: dose.medication, scheduledAt: dose.scheduledAt, in: context)
        }
    }
}

private struct TodayDoseRow: View {
    let dose: TodayDose
    let now: Date
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(dose.medication.name)
                        .font(.headline)
                        .strikethrough(dose.log?.status == .taken)
                    if !dose.medication.dosage.isEmpty {
                        Text(dose.medication.dosage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(dose.scheduledAt, format: .dateTime.hour().minute())
                        .font(.subheadline.monospacedDigit())
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(color)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var isLate: Bool { dose.log == nil && dose.scheduledAt < now }

    private var icon: String {
        switch dose.log?.status {
        case .taken: return "checkmark.circle.fill"
        case .skipped: return "minus.circle.fill"
        case nil: return isLate ? "exclamationmark.circle.fill" : "circle"
        }
    }

    private var color: Color {
        switch dose.log?.status {
        case .taken: return .green
        case .skipped: return .gray
        case nil: return isLate ? .orange : .secondary
        }
    }

    private var statusText: String {
        switch dose.log?.status {
        case .taken: return "Tomado"
        case .skipped: return "Pulado"
        case nil: return isLate ? "Atrasado" : "Pendente"
        }
    }
}

private struct RefillRow: View {
    let medication: Medication
    let now: Date
    let markRequested: () -> Void

    var body: some View {
        let status = medication.stockStatus(at: now)
        HStack {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name).font(.headline)
                Text(status.isOut ? "Acabou" : "Restam \(status.daysRemaining) dia(s)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Já pedi", action: markRequested)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
    }
}

private struct ExpiryBanner: View {
    let daysLeft: Int

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(daysLeft == 0 ? "O app expira hoje" : "O app expira em \(daysLeft) dia(s)")
                    .font(.headline)
                Text("Conecte o iPhone no Mac, abra o Xcode e aperte ▶︎ para renovar. Seus dados continuam aqui.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "hourglass")
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(DataStore.preview)
}
