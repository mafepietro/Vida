import SwiftUI
import SwiftData

struct MedicationListView: View {
    @Query(sort: \Medication.name) private var medications: [Medication]
    @State private var showingNew = DemoMode.isOn && DemoMode.screen == "novo"
    @State private var path: [Medication] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if medications.isEmpty {
                    ContentUnavailableView {
                        Label("Nenhum remédio", systemImage: "pills")
                    } description: {
                        Text("Cadastre seus remédios para receber lembretes e saber quando pedir uma nova receita.")
                    } actions: {
                        Button("Adicionar remédio") { showingNew = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List(medications) { medication in
                        NavigationLink(value: medication) {
                            MedicationRow(medication: medication)
                        }
                    }
                }
            }
            .navigationTitle("Remédios")
            .navigationDestination(for: Medication.self) { medication in
                MedicationDetailView(medication: medication)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingNew = true
                    } label: {
                        Label("Adicionar", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNew) {
                MedicationEditView(medication: nil)
            }
            .onAppear {
                if DemoMode.isOn, DemoMode.screen == "detalhe", path.isEmpty,
                   let first = medications.first(where: { $0.name == "Sertralina" }) ?? medications.first {
                    path = [first]
                }
            }
        }
    }
}

struct MedicationRow: View {
    let medication: Medication

    var body: some View {
        let status = medication.stockStatus
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(medication.name)
                    .font(.headline)
                if !medication.isActive {
                    Text("Pausado")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.gray.opacity(0.2), in: Capsule())
                }
            }
            Text(medication.timesDescription)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            StockBadge(status: status, requested: medication.refillAlreadyRequested)
        }
        .padding(.vertical, 2)
    }
}

struct StockBadge: View {
    let status: StockStatus
    let requested: Bool

    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }

    private var text: String {
        if status.isOut { return "Acabou" }
        let days = status.daysRemaining == 1 ? "1 dia" : "\(status.daysRemaining) dias"
        if status.needsRefill { return requested ? "Restam \(days) · receita pedida" : "Restam \(days) · pedir receita" }
        return "Restam \(days)"
    }

    private var icon: String {
        if status.isOut { return "xmark.octagon.fill" }
        if status.needsRefill { return requested ? "checkmark.seal.fill" : "exclamationmark.triangle.fill" }
        return "calendar"
    }

    private var color: Color {
        if status.isOut { return .red }
        if status.needsRefill { return requested ? .blue : .orange }
        return .green
    }
}

#Preview {
    MedicationListView()
        .modelContainer(DataStore.preview)
}
