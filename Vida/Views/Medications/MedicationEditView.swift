import SwiftUI
import SwiftData

/// Formulário para criar ou editar um remédio.
struct MedicationEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// `nil` quando é um remédio novo.
    let medication: Medication?

    enum StockInput: String, CaseIterable, Identifiable {
        case quantity = "Quantidade"
        case days = "Dias"
        var id: String { rawValue }
    }

    @State private var name = ""
    @State private var dosage = ""
    @State private var unitName = "comprimido"
    @State private var unitsPerDose = 1.0
    struct TimeEntry: Identifiable {
        let id = UUID()
        var date: Date
    }

    @State private var times: [TimeEntry] = []
    @State private var stockInput: StockInput = .quantity
    @State private var quantityText = ""
    @State private var days = 30
    @State private var stockDate = Date()
    @State private var refillWarningDays = 7
    @State private var notes = ""
    @State private var loaded = false

    private let unitOptions = ["comprimido", "cápsula", "gota", "ml", "sachê", "aplicação"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Remédio") {
                    TextField("Nome (ex.: Vitamina D)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Dose (ex.: 50 mg, em jejum)", text: $dosage)
                }

                Section {
                    Picker("Unidade", selection: $unitName) {
                        ForEach(unitOptions, id: \.self) { Text($0).tag($0) }
                    }
                    Stepper(value: $unitsPerDose, in: 0.5...50, step: 0.5) {
                        LabeledContent("Por horário", value: "\(TimeFormat.number(unitsPerDose)) \(unitName)(s)")
                    }
                    ForEach($times) { $entry in
                        DatePicker("Horário", selection: $entry.date, displayedComponents: .hourAndMinute)
                    }
                    .onDelete { times.remove(atOffsets: $0) }
                    Button {
                        times.append(TimeEntry(date: suggestedNextTime()))
                    } label: {
                        Label("Adicionar horário", systemImage: "plus.circle")
                    }
                } header: {
                    Text("Quando tomar")
                } footer: {
                    Text("Você recebe um alarme em cada horário, com o botão \"Tomei\".")
                }

                Section {
                    Picker("Informar por", selection: $stockInput) {
                        ForEach(StockInput.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch stockInput {
                    case .quantity:
                        HStack {
                            Text("Quantidade")
                            TextField("ex.: 30", text: $quantityText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                            Text("\(unitName)(s)")
                                .foregroundStyle(.secondary)
                        }
                    case .days:
                        Stepper(value: $days, in: 1...365) {
                            LabeledContent("Dá para", value: days == 1 ? "1 dia" : "\(days) dias")
                        }
                    }

                    DatePicker("Comprei em", selection: $stockDate, in: ...Date(), displayedComponents: .date)

                    Stepper(value: $refillWarningDays, in: 1...60) {
                        LabeledContent("Avisar para pedir receita", value: "\(refillWarningDays) dias antes")
                    }
                } header: {
                    Text("Estoque")
                } footer: {
                    Text("O app desconta cada dose e avisa quando estiver na hora de pedir uma nova receita ao médico.")
                }

                Section("Observações") {
                    TextField("Opcional", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(medication == nil ? "Novo remédio" : "Editar remédio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: load)
        }
    }

    private var timeMinutes: [Int] {
        MedicationMath.validTimes(times.map { TimeFormat.minutes(from: $0.date) })
    }

    private var stockUnits: Double? {
        switch stockInput {
        case .quantity:
            return Double(quantityText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
        case .days:
            return Double(days) * unitsPerDose * Double(max(1, timeMinutes.count))
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !timeMinutes.isEmpty && (stockUnits ?? -1) >= 0
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let medication {
            name = medication.name
            dosage = medication.dosage
            unitName = medication.unitName
            unitsPerDose = medication.unitsPerDose
            times = medication.sortedTimes
                .compactMap { TimeFormat.date(minutes: $0, onDayOf: Date()) }
                .map { TimeEntry(date: $0) }
            quantityText = TimeFormat.number(medication.stockQuantity)
            stockDate = medication.stockDate
            refillWarningDays = medication.refillWarningDays
            notes = medication.notes
        } else {
            times = [TimeEntry(date: TimeFormat.date(minutes: 8 * 60, onDayOf: Date()) ?? Date())]
        }
        if !unitOptions.contains(unitName) { unitName = "comprimido" }
    }

    private func suggestedNextTime() -> Date {
        let last = times.last.map { TimeFormat.minutes(from: $0.date) } ?? 8 * 60
        let next = (last + 12 * 60) % (24 * 60)
        return TimeFormat.date(minutes: next, onDayOf: Date()) ?? Date()
    }

    private func save() {
        guard let units = stockUnits else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let target: Medication
        if let medication {
            target = medication
        } else {
            target = Medication(name: trimmedName, doseTimes: timeMinutes, stockQuantity: units)
            context.insert(target)
        }
        target.name = trimmedName
        target.dosage = dosage.trimmingCharacters(in: .whitespaces)
        target.unitName = unitName
        target.unitsPerDose = unitsPerDose
        target.doseTimes = timeMinutes
        target.stockQuantity = units
        target.stockDate = stockDate
        target.refillWarningDays = refillWarningDays
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        MedicationActions.saveAndReschedule(context)
        dismiss()
    }
}

#Preview {
    MedicationEditView(medication: nil)
        .modelContainer(DataStore.preview)
}
