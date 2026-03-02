import SwiftUI

// MARK: - Plan Editor ViewModel

@MainActor
final class PlanEditorViewModel: ObservableObject {
    // MARK: - Basic Info
    @Published var name: String = ""
    @Published var isWalkingWorkout: Bool = false

    // MARK: - Series
    @Published var seriesCount: Int = 4
    @Published var isProgressive: Bool = false

    // MARK: - Simple Plan Fields
    @Published var workDurationMinutes: Int = 3
    @Published var workDurationSeconds: Int = 0
    @Published var restDurationMinutes: Int = 3
    @Published var restDurationSeconds: Int = 0
    @Published var workCadence: Int = 170  // SPM
    @Published var workTargetPaceMin: Int = 0   // min/km (0 = no target)
    @Published var workTargetPaceSec: Int = 0
    @Published var restCadence: Int = 150

    // MARK: - Progressive Blocks
    @Published var blocks: [WorkBlockEdit] = []

    // MARK: - Walking Duration
    @Published var walkingDurationMinutes: Int = 50

    // MARK: - Warmup / Cooldown
    @Published var hasWarmup: Bool = true
    @Published var warmupMinutes: Int = 5
    @Published var hasCooldown: Bool = true
    @Published var cooldownMinutes: Int = 5

    // MARK: - State
    @Published var isSaving: Bool = false
    @Published var error: String?

    private var originalId: UUID?
    private var originalIsDefault: Bool = false
    private let repository: PlanRepositoryProtocol
    var onSave: ((TrainingPlan) -> Void)?

    var isNew: Bool { originalId == nil }

    // MARK: - Init
    init(plan: TrainingPlan? = nil, repository: PlanRepositoryProtocol) {
        self.repository = repository
        if let plan = plan {
            load(from: plan)
        } else {
            // Default to one simple block for new plans
            blocks = [WorkBlockEdit()]
        }
    }

    private func load(from plan: TrainingPlan) {
        originalId = plan.id
        originalIsDefault = plan.isDefault
        name = plan.name

        let isWalk = plan.seriesCount == 1 && plan.restDuration == 0 && plan.warmupDuration == nil
        isWalkingWorkout = isWalk

        if isWalk {
            walkingDurationMinutes = Int(plan.workDuration) / 60
        } else {
            seriesCount = plan.seriesCount
            if let wb = plan.workBlocks, !wb.isEmpty {
                isProgressive = true
                blocks = wb.map { WorkBlockEdit(from: $0) }
            } else {
                isProgressive = false
                let wd = Int(plan.workDuration)
                workDurationMinutes = wd / 60; workDurationSeconds = wd % 60
                let rd = Int(plan.restDuration)
                restDurationMinutes = rd / 60; restDurationSeconds = rd % 60
                workCadence = plan.workZone.targetBPM
                restCadence = plan.restZone.targetBPM
                if let tp = plan.workZone.targetPace {
                    workTargetPaceMin = Int(tp) / 60
                    workTargetPaceSec = Int(tp) % 60
                }
            }
            hasWarmup = plan.warmupDuration != nil
            warmupMinutes = Int(plan.warmupDuration ?? 300) / 60
            hasCooldown = plan.cooldownDuration != nil
            cooldownMinutes = Int(plan.cooldownDuration ?? 300) / 60
        }
    }

    // MARK: - Build plan from form fields
    func buildPlan() -> TrainingPlan {
        let id = originalId ?? UUID()
        let warmup: TimeInterval? = hasWarmup && !isWalkingWorkout ? TimeInterval(warmupMinutes * 60) : nil
        let cooldown: TimeInterval? = hasCooldown && !isWalkingWorkout ? TimeInterval(cooldownMinutes * 60) : nil
        let warmupZone = HeartRateZone(targetBPM: 140, toleranceBPM: 10, targetPace: 480, paceTolerance: 60)

        if isWalkingWorkout {
            let workZone = HeartRateZone(targetBPM: workCadence, toleranceBPM: 10, targetPace: nil, paceTolerance: 25)
            return TrainingPlan(
                id: id, name: name.isEmpty ? "Mi caminata" : name,
                workZone: workZone, restZone: workZone,
                workDuration: TimeInterval(walkingDurationMinutes * 60), restDuration: 0,
                seriesCount: 1, warmupDuration: nil, warmupZone: nil,
                cooldownDuration: nil, cooldownZone: nil,
                createdAt: Date(), isDefault: originalIsDefault
            )
        }

        let targetPace: TimeInterval? = workTargetPaceMin > 0 || workTargetPaceSec > 0
            ? TimeInterval(workTargetPaceMin * 60 + workTargetPaceSec) : nil

        if isProgressive && !blocks.isEmpty {
            let workBlocks = blocks.map { $0.toWorkBlock(defaultRestCadence: restCadence) }
            return TrainingPlan(
                id: id, name: name.isEmpty ? "Mi entreno" : name,
                workBlocks: workBlocks, seriesCount: seriesCount,
                warmupDuration: warmup, warmupZone: warmup != nil ? warmupZone : nil,
                cooldownDuration: cooldown, cooldownZone: cooldown != nil ? warmupZone : nil,
                createdAt: Date(), isDefault: originalIsDefault
            )
        } else {
            let workZone = HeartRateZone(targetBPM: workCadence, toleranceBPM: 5, targetPace: targetPace)
            let restZone = HeartRateZone(targetBPM: restCadence, toleranceBPM: 10)
            return TrainingPlan(
                id: id, name: name.isEmpty ? "Mi entreno" : name,
                workZone: workZone, restZone: restZone,
                workDuration: TimeInterval(workDurationMinutes * 60 + workDurationSeconds),
                restDuration: TimeInterval(restDurationMinutes * 60 + restDurationSeconds),
                seriesCount: seriesCount,
                warmupDuration: warmup, warmupZone: warmup != nil ? warmupZone : nil,
                cooldownDuration: cooldown, cooldownZone: cooldown != nil ? warmupZone : nil,
                createdAt: Date(), isDefault: originalIsDefault
            )
        }
    }

    func save() async {
        isSaving = true
        error = nil
        let plan = buildPlan()
        do {
            try await repository.save(plan)
            onSave?(plan)
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Block management
    func addBlock() {
        blocks.append(WorkBlockEdit())
    }

    func deleteBlocks(at offsets: IndexSet) {
        blocks.remove(atOffsets: offsets)
    }
}

// MARK: - WorkBlockEdit

struct WorkBlockEdit: Identifiable {
    var id = UUID()
    var workMinutes: Int = 3
    var workSeconds: Int = 0
    var restMinutes: Int = 3
    var restSeconds: Int = 0
    var cadence: Int = 170
    var targetPaceMin: Int = 0
    var targetPaceSec: Int = 0

    init() {}

    init(from block: WorkBlock) {
        workMinutes = Int(block.workDuration) / 60
        workSeconds = Int(block.workDuration) % 60
        restMinutes = Int(block.restDuration) / 60
        restSeconds = Int(block.restDuration) % 60
        cadence = block.workZone.targetBPM
        if let tp = block.workZone.targetPace {
            targetPaceMin = Int(tp) / 60
            targetPaceSec = Int(tp) % 60
        }
    }

    func toWorkBlock(defaultRestCadence: Int) -> WorkBlock {
        let targetPace: TimeInterval? = targetPaceMin > 0 || targetPaceSec > 0
            ? TimeInterval(targetPaceMin * 60 + targetPaceSec) : nil
        return WorkBlock(
            workZone: HeartRateZone(targetBPM: cadence, toleranceBPM: 5, targetPace: targetPace),
            workDuration: TimeInterval(workMinutes * 60 + workSeconds),
            restZone: HeartRateZone(targetBPM: defaultRestCadence, toleranceBPM: 10),
            restDuration: TimeInterval(restMinutes * 60 + restSeconds)
        )
    }
}

// MARK: - PlanEditorView

struct PlanEditorView: View {
    @StateObject var viewModel: PlanEditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                if isWalkingWorkout {
                    walkingSection
                } else {
                    intervalsSection
                    warmupSection
                }
            }
            .navigationTitle(viewModel.isNew ? "Nuevo entreno" : "Editar entreno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task { await viewModel.save(); if viewModel.error == nil { dismiss() } }
                    }
                    .disabled(viewModel.isSaving || viewModel.name.isEmpty)
                }
            }
            .alert("Error al guardar", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error ?? "")
            }
        }
    }

    private var isWalkingWorkout: Bool { viewModel.isWalkingWorkout }

    // MARK: - Sections

    private var basicSection: some View {
        Section("Información básica") {
            TextField("Nombre del entreno", text: $viewModel.name)
            Picker("Tipo", selection: $viewModel.isWalkingWorkout) {
                Text("Carrera").tag(false)
                Text("Caminata").tag(true)
            }
            .pickerStyle(.segmented)
        }
    }

    private var walkingSection: some View {
        Section("Duración de la caminata") {
            HStack {
                Text("Duración")
                Spacer()
                Stepper("\(viewModel.walkingDurationMinutes) min",
                        value: $viewModel.walkingDurationMinutes, in: 10...120, step: 5)
            }
            HStack {
                Text("Cadencia objetivo")
                Spacer()
                Stepper("\(viewModel.workCadence) SPM",
                        value: $viewModel.workCadence, in: 80...140, step: 5)
            }
        }
    }

    private var intervalsSection: some View {
        Group {
            Section("Configuración de series") {
                HStack {
                    Text("Número de series")
                    Spacer()
                    Stepper("\(viewModel.seriesCount)", value: $viewModel.seriesCount, in: 1...20)
                }
                Toggle("Plan progresivo (bloques distintos)", isOn: $viewModel.isProgressive)
            }

            if viewModel.isProgressive {
                progressiveBlocksSection
            } else {
                simplePlanSection
            }
        }
    }

    private var simplePlanSection: some View {
        Group {
            Section("Intervalo de trabajo") {
                DurationPicker(label: "Duración", minutes: $viewModel.workDurationMinutes,
                               seconds: $viewModel.workDurationSeconds)
                CadencePicker(label: "Cadencia", cadence: $viewModel.workCadence)
                PacePicker(label: "Ritmo objetivo (0 = sin objetivo)",
                           minutes: $viewModel.workTargetPaceMin, seconds: $viewModel.workTargetPaceSec)
            }
            Section("Descanso") {
                DurationPicker(label: "Duración", minutes: $viewModel.restDurationMinutes,
                               seconds: $viewModel.restDurationSeconds)
                CadencePicker(label: "Cadencia descanso", cadence: $viewModel.restCadence)
            }
        }
    }

    private var progressiveBlocksSection: some View {
        Section {
            ForEach($viewModel.blocks) { $block in
                BlockEditorRow(block: $block, index: viewModel.blocks.firstIndex(where: { $0.id == block.id }) ?? 0)
            }
            .onDelete { viewModel.deleteBlocks(at: $0) }
            Button {
                viewModel.addBlock()
            } label: {
                Label("Añadir bloque", systemImage: "plus.circle")
            }

            CadencePicker(label: "Cadencia descanso (todos los bloques)", cadence: $viewModel.restCadence)
        } header: {
            Text("Bloques (\(viewModel.blocks.count))")
        }
    }

    private var warmupSection: some View {
        Section("Calentamiento y enfriamiento") {
            Toggle("Calentamiento", isOn: $viewModel.hasWarmup)
            if viewModel.hasWarmup {
                HStack {
                    Text("Duración")
                    Spacer()
                    Stepper("\(viewModel.warmupMinutes) min",
                            value: $viewModel.warmupMinutes, in: 1...20)
                }
            }
            Toggle("Enfriamiento", isOn: $viewModel.hasCooldown)
            if viewModel.hasCooldown {
                HStack {
                    Text("Duración")
                    Spacer()
                    Stepper("\(viewModel.cooldownMinutes) min",
                            value: $viewModel.cooldownMinutes, in: 1...20)
                }
            }
        }
    }
}

// MARK: - Block Editor Row

struct BlockEditorRow: View {
    @Binding var block: WorkBlockEdit
    let index: Int
    @State private var isExpanded = true

    var body: some View {
        DisclosureGroup("Bloque \(index + 1) — \(block.cadence) SPM", isExpanded: $isExpanded) {
            DurationPicker(label: "Trabajo", minutes: $block.workMinutes, seconds: $block.workSeconds)
            DurationPicker(label: "Descanso", minutes: $block.restMinutes, seconds: $block.restSeconds)
            CadencePicker(label: "Cadencia", cadence: $block.cadence)
            PacePicker(label: "Ritmo objetivo (0 = sin objetivo)",
                       minutes: $block.targetPaceMin, seconds: $block.targetPaceSec)
        }
    }
}

// MARK: - Reusable Input Components

struct DurationPicker: View {
    let label: String
    @Binding var minutes: Int
    @Binding var seconds: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 4) {
                Picker("", selection: $minutes) {
                    ForEach(0..<60) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 60)
                .clipped()

                Text(":")
                    .font(.title3.bold())

                Picker("", selection: $seconds) {
                    ForEach([0, 15, 30, 45], id: \.self) { Text("\(String(format: "%02d", $0)) s").tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(width: 80, height: 60)
                .clipped()
            }
        }
    }
}

struct CadencePicker: View {
    let label: String
    @Binding var cadence: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Stepper("\(cadence) SPM", value: $cadence, in: 80...220, step: 5)
        }
    }
}

struct PacePicker: View {
    let label: String
    @Binding var minutes: Int
    @Binding var seconds: Int

    private var total: Int { minutes * 60 + seconds }

    private var displayText: String {
        total == 0 ? "Sin objetivo" : "\(minutes):\(String(format: "%02d", seconds)) /km"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Stepper(displayText, onIncrement: {
                let next = total + 15
                guard next <= 14 * 60 + 45 else { return }
                minutes = next / 60
                seconds = next % 60
            }, onDecrement: {
                guard total > 0 else { return }
                let prev = max(0, total - 15)
                minutes = prev / 60
                seconds = prev % 60
            })
        }
    }
}
