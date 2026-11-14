import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var context
    @Query private var memories: [Memory]
    @State private var nameA = ""
    @State private var nameB = ""
    @State private var showConsent = false
    @State private var confirmErase = false
    @State private var notificationsDenied = false

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            Form {
                Section("Vosotros") {
                    TextField("Tu nombre", text: $nameA)
                        .onSubmit(saveNames)
                    TextField("Tu pareja", text: $nameB)
                        .onSubmit(saveNames)
                }

                Section {
                    Toggle(isOn: $state.reminder.enabled) {
                        Label("Recordatorio semanal", systemImage: "bell.badge.fill")
                    }
                    .accessibilityIdentifier("settings.reminder")
                    if state.reminder.enabled {
                        Picker("Día", selection: $state.reminder.weekday) {
                            ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                                Text(ReminderSettings.weekdayNames[day - 1].capitalized).tag(day)
                            }
                        }
                        DatePicker("Hora", selection: reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Noche de cita")
                } footer: {
                    Text(notificationsDenied
                         ? "Activa las notificaciones de Plan B en Ajustes del iPhone para recibir el recordatorio."
                         : "Un aviso cada semana para que no se os pase hacer algo juntos.")
                }

                Section {
                    Toggle(isOn: intimateBinding) {
                        Label("Apartado íntimo", systemImage: "flame.fill")
                    }
                    .accessibilityIdentifier("settings.intimate")
                } header: {
                    Text("+18")
                } footer: {
                    Text("Planes subidos de tono, nunca explícitos. Solo se activa si los dos estáis de acuerdo.")
                }

                Section("Contenido") {
                    NavigationLink {
                        CustomPlansView()
                    } label: {
                        Label("Vuestros planes", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("settings.custom")
                }

                Section {
                    Button("Borrar todos los recuerdos", role: .destructive) { confirmErase = true }
                        .disabled(memories.isEmpty)
                } header: {
                    Text("Datos")
                } footer: {
                    Text("Todo se guarda solo en este iPhone: sin cuentas y sin enviar nada a ningún sitio.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(WarmBackground())
            .navigationTitle("Ajustes")
            .onAppear {
                nameA = state.nameA
                nameB = state.nameB
            }
            .onDisappear(perform: saveNames)
            .onChange(of: state.reminder) { scheduleReminder() }
            .sheet(isPresented: $showConsent) {
                IntimateConsentView { state.intimateUnlocked = true }
                    .presentationDetents([.medium, .large])
            }
            .confirmationDialog("¿Borrar todos los recuerdos?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Borrar \(memories.count) recuerdos", role: .destructive) {
                    for memory in memories { context.delete(memory) }
                    try? context.save()
                }
            } message: {
                Text("No se puede deshacer.")
            }
        }
    }

    private var intimateBinding: Binding<Bool> {
        Binding {
            state.intimateUnlocked
        } set: { on in
            if on { showConsent = true } else { state.intimateUnlocked = false }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: state.reminder.hour, minute: state.reminder.minute)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            state.reminder.hour = parts.hour ?? 19
            state.reminder.minute = parts.minute ?? 0
        }
    }

    private func saveNames() {
        let a = AppState.cleanName(nameA), b = AppState.cleanName(nameB)
        guard !a.isEmpty, !b.isEmpty, a != state.nameA || b != state.nameB else { return }
        state.setNames(a, b)
    }

    private func scheduleReminder() {
        guard !LaunchOptions.isUITesting else { return }
        let settings = state.reminder
        let names = state.coupleName
        Task {
            let ok = await ReminderScheduler.apply(settings, names: names)
            notificationsDenied = !ok
        }
    }
}

/// Both partners confirm before the +18 section appears.
struct IntimateConsentView: View {
    var onAccept: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Antes de activarlo", systemImage: "flame.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(Palette.ember)
            line("person.2.fill", "Los dos sois mayores de edad.")
            line("hand.thumbsup.fill", "Los dos queréis ver este apartado.")
            line("hand.raised.fill", "Cualquiera puede decir que no a un plan en cualquier momento, sin dar explicaciones.")
            Spacer(minLength: 0)
            Button {
                Haptics.success()
                onAccept()
                dismiss()
            } label: {
                Label("Lo confirmamos los dos", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.ember)
            .accessibilityIdentifier("intimate.confirm")
            Button("Ahora no") { dismiss() }
                .frame(maxWidth: .infinity)
        }
        .padding(24)
        .presentationBackground(.regularMaterial)
    }

    private func line(_ symbol: String, _ text: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(Palette.rose)
        }
        .font(.body)
    }
}

/// Plans written by the couple; they mix into the deck like any other.
struct CustomPlansView: View {
    @Environment(AppState.self) private var state
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomPlanRecord.createdAt, order: .reverse) private var records: [CustomPlanRecord]
    @State private var emoji = ""
    @State private var title = ""
    @State private var summary = ""
    @State private var tip = ""
    @State private var budget: Budget = .free
    @State private var place: Place = .home
    @State private var duration: Duration = .evening
    @State private var mood: Mood = .romantic
    @State private var intimate = false

    private var canAdd: Bool {
        CustomPlanRules.clean(title, max: CustomPlanRules.maxTitle) != nil
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 10) {
                    TextField("😀", text: $emoji)
                        .frame(width: 44)
                        .multilineTextAlignment(.center)
                    TextField("Título del plan", text: $title)
                        .accessibilityIdentifier("custom.title")
                }
                TextField("De qué va", text: $summary, axis: .vertical)
                    .lineLimit(2...4)
                TextField("Un truco para hacerlo especial (opcional)", text: $tip, axis: .vertical)
                    .lineLimit(1...3)
                Picker("Presupuesto", selection: $budget) { ForEach(Budget.allCases) { Text($0.detail).tag($0) } }
                Picker("Dónde", selection: $place) { ForEach(Place.allCases) { Text($0.label).tag($0) } }
                Picker("Duración", selection: $duration) { ForEach(Duration.allCases) { Text($0.label).tag($0) } }
                Picker("Ambiente", selection: $mood) { ForEach(Mood.allCases) { Text($0.label).tag($0) } }
                if state.intimateUnlocked {
                    Toggle("Del apartado íntimo", isOn: $intimate)
                }
                Button("Añadir plan", systemImage: "plus.circle.fill", action: add)
                    .disabled(!canAdd)
                    .accessibilityIdentifier("custom.add")
            } header: {
                Text("Nuevo plan")
            } footer: {
                Text("Vuestros planes aparecen en Descubrir, la ruleta y el plan sorpresa.")
            }

            if !records.isEmpty {
                Section("\(records.count) planes vuestros") {
                    ForEach(records) { record in
                        HStack(spacing: 12) {
                            Text(record.emoji).font(.title2)
                            VStack(alignment: .leading) {
                                Text(record.title).font(.headline)
                                if !record.summary.isEmpty {
                                    Text(record.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(records[index]) }
                        try? context.save()
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(WarmBackground())
        .navigationTitle("Vuestros planes")
    }

    private func add() {
        guard let cleanTitle = CustomPlanRules.clean(title, max: CustomPlanRules.maxTitle) else { return }
        let record = CustomPlanRecord(
            emoji: CustomPlanRules.emoji(emoji), title: cleanTitle,
            summary: CustomPlanRules.clean(summary, max: CustomPlanRules.maxSummary) ?? "",
            tip: CustomPlanRules.clean(tip, max: CustomPlanRules.maxSummary) ?? "",
            budget: budget, place: place, duration: duration, mood: mood, intimate: intimate && state.intimateUnlocked
        )
        context.insert(record)
        try? context.save()
        emoji = ""; title = ""; summary = ""; tip = ""
        Haptics.success()
    }
}
