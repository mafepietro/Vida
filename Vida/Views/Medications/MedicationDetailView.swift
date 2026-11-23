import SwiftUI
import SwiftData

struct MedicationDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var medication: Medication

    @State private var showingEdit = false
    @State private var showingRestock = false
    @State private var showingCount = false
    @State private var showingDelete = false
    @State private var unitsText = ""

    var body: some View {
        let status = medication.stockStatus
        List {
            Section("Estoque") {
                LabeledContent("Sobrando", value: "\(TimeFormat.number(status.unitsRemaining)) \(medication.unitName)(s)")
                LabeledContent("Dá para", value: status.daysRemaining == 1 ? "1 dia" : "\(status.daysRemaining) dias")
                if let runOut = status.runOutDate {
                    LabeledContent("Acaba em", value: runOut.formatted(.dateTime.day().month(.wide).hour().minute()))
                }
                if let warning = status.refillWarningDate {
                    LabeledContent("Aviso de receita", value: warning.formatted(.dateTime.day().month(.wide)))
                }
                StockBadge(status: status, requested: medication.refillAlreadyRequested)
            }

            Section {
                Button {
                    unitsText = ""
                    showingRestock = true
                } label: {
                    Label("Comprei mais", systemImage: "cart.badge.plus")
                }
                Button {
                    unitsText = TimeFormat.number(status.unitsRemaining)
                    showingCount = true
                } label: {
                    Label("Corrigir quantidade", systemImage: "number")
                }
                if !medication.refillAlreadyRequested {
                    Button {
                        MedicationActions.markRefillRequested(medication, in: context)
                    } label: {
                        Label("Já pedi a receita", systemImage: "doc.text")
                    }
                } else if let requested = medication.refillRequestedAt {
                    Label("Receita pedida em \(requested.formatted(.dateTime.day().month()))", systemImage: "checkmark.seal")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("O estoque é calculado pelos horários: o app conta que você tomou todas as doses desde a compra, menos as que você marcou como puladas.")
            }

            Section("Como tomar") {
                if !medication.dosage.isEmpty {
                    LabeledContent("Dose", value: medication.dosage)
                }
                LabeledContent("Por horário", value: "\(TimeFormat.number(medication.unitsPerDose)) \(medication.unitName)(s)")
                LabeledContent("Horários", value: medication.timesDescription)
                Toggle("Lembretes ativos", isOn: $medication.isActive)
                    .onChange(of: medication.isActive) {
                        MedicationActions.saveAndReschedule(context)
                    }
            }

            if !medication.notes.isEmpty {
                Section("Observações") {
                    Text(medication.notes)
                }
            }

            Section("Últimas doses") {
                let recent = (medication.logs ?? [])
                    .sorted { $0.scheduledAt > $1.scheduledAt }
                    .prefix(20)
                if recent.isEmpty {
                    Text("Nada registrado ainda.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(recent)) { log in
                        HStack {
                            Image(systemName: log.status == .taken ? "checkmark.circle.fill" : "minus.circle.fill")
                                .foregroundStyle(log.status == .taken ? .green : .gray)
                            Text(log.scheduledAt, format: .dateTime.weekday(.abbreviated).day().month().hour().minute())
                            Spacer()
                            Text(log.status == .taken ? "Tomado" : "Pulado")
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button("Apagar", role: .destructive) {
                                MedicationActions.undo(log, in: context)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Apagar remédio", role: .destructive) {
                    showingDelete = true
                }
            }
        }
        .navigationTitle(medication.name)
        .toolbar {
            Button("Editar") { showingEdit = true }
        }
        .sheet(isPresented: $showingEdit) {
            MedicationEditView(medication: medication)
        }
        .alert("Comprei mais", isPresented: $showingRestock) {
            TextField("Quantidade", text: $unitsText)
                .keyboardType(.decimalPad)
            Button("Salvar") {
                if let units = parse(unitsText), units > 0 {
                    MedicationActions.restock(medication, adding: units, in: context)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Quantos \(medication.unitName)(s) vieram? Vou somar ao que ainda sobra.")
        }
        .alert("Corrigir quantidade", isPresented: $showingCount) {
            TextField("Quantidade", text: $unitsText)
                .keyboardType(.decimalPad)
            Button("Salvar") {
                if let units = parse(unitsText), units >= 0 {
                    MedicationActions.setStock(medication, to: units, in: context)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Quantos \(medication.unitName)(s) você tem agora?")
        }
        .confirmationDialog("Apagar \(medication.name)?", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("Apagar", role: .destructive) {
                dismiss()
                // Espera a tela fechar antes de apagar, para ela não mostrar um remédio que não existe mais.
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    MedicationActions.delete(medication, in: context)
                }
            }
        } message: {
            Text("O histórico de doses também será apagado.")
        }
    }

    private func parse(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces))
    }
}

#Preview {
    let container = DataStore.preview
    let medication = try! container.mainContext.fetch(FetchDescriptor<Medication>()).first!
    return NavigationStack {
        MedicationDetailView(medication: medication)
    }
    .modelContainer(container)
}
