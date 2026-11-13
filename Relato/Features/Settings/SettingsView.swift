import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @Environment(AppRouter.self) private var router

    @AppStorage(PrefKey.wordsPerMinute) private var wordsPerMinute = PrefDefault.wordsPerMinute
    @AppStorage(PrefKey.defaultTarget) private var defaultTarget = PrefDefault.defaultTarget
    @AppStorage(PrefKey.prompterFontSize) private var fontSize = PrefDefault.prompterFontSize
    @AppStorage(PrefKey.prompterMirror) private var mirror = false
    @AppStorage(PrefKey.prompterCountdown) private var countdown = true
    @AppStorage(PrefKey.haptics) private var haptics = true
    @AppStorage(PrefKey.reminderEnabled) private var reminderEnabled = false
    @AppStorage(PrefKey.reminderHour) private var reminderHour = PrefDefault.reminderHour
    @AppStorage(PrefKey.reminderMinute) private var reminderMinute = PrefDefault.reminderMinute
    @AppStorage(PrefKey.onboardingCompleted) private var onboardingCompleted = true

    @State private var showNotificationsDenied = false
    @State private var showDeleteAll = false
    @State private var samplesAdded = false

    var body: some View {
        NavigationStack {
            Form {
                speechSection
                prompterSection
                reminderSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background { AuroraBackground(intensity: 0.5) }
            .navigationTitle("Ajustes")
            .alert("Notificaciones desactivadas", isPresented: $showNotificationsDenied) {
                Button("Abrir Ajustes") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("Ahora no", role: .cancel) {}
            } message: {
                Text("Para recibir el recordatorio diario, permite las notificaciones de Relato en Ajustes.")
            }
            .confirmationDialog("¿Borrar todas tus historias, ideas y tomas?", isPresented: $showDeleteAll, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) {
                    router.storyPath = []
                    StoryActions.deleteEverything(in: context)
                    Haptics.warning()
                }
            } message: {
                Text("Esta acción no se puede deshacer. Las tomas guardadas en Fotos no se borran.")
            }
        }
    }

    // MARK: - Sections

    private var speechSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Velocidad al hablar")
                    Spacer()
                    Text("\(Int(wordsPerMinute)) ppm")
                        .font(.body.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Palette.ember)
                        .contentTransition(.numericText(value: wordsPerMinute))
                }
                Slider(value: $wordsPerMinute, in: ScriptMetrics.wordsPerMinuteRange, step: 5) {
                    Text("Palabras por minuto")
                } minimumValueLabel: {
                    Image(systemName: "tortoise.fill").foregroundStyle(.secondary)
                } maximumValueLabel: {
                    Image(systemName: "hare.fill").foregroundStyle(.secondary)
                }
                Text("Un guion de 150 palabras te durará unos \(ScriptMetrics.clock(150 / wordsPerMinute * 60)).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)

            Picker("Duración por defecto", selection: $defaultTarget) {
                ForEach(TargetDuration.presets, id: \.self) { Text(TargetDuration.label($0)).tag($0) }
            }
        } header: {
            Text("Guion")
        } footer: {
            Text("Relato usa tu velocidad para calcular la duración y para mover el teleprompter a tu ritmo. Hablando natural, la mayoría estamos entre 140 y 170 ppm.")
        }
    }

    private var prompterSection: some View {
        Section("Teleprompter") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tamaño del texto")
                    Spacer()
                    Text("\(Int(fontSize)) pt").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $fontSize, in: PrefDefault.prompterFontRange, step: 2) {
                    Text("Tamaño del texto")
                }
                Text("Así se verá tu guion")
                    .font(.system(size: fontSize * 0.6, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                    .animation(.snappy, value: fontSize)
            }
            .padding(.vertical, 4)
            Toggle("Cuenta atrás de 3 s", isOn: $countdown)
            Toggle(isOn: $mirror) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Texto en espejo")
                    Text("Para teleprompters con cristal reflectante.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Toggle("Vibraciones", isOn: $haptics)
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle(isOn: Binding(get: { reminderEnabled }, set: setReminder)) {
                Label("Recordatorio diario", systemImage: "bell.badge.fill")
            }
            if reminderEnabled {
                DatePicker("Hora", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
        } header: {
            Text("Constancia")
        } footer: {
            Text("Publicar a diario es lo que más hace crecer una cuenta de historias. Te avisaremos a la hora que elijas.")
        }
    }

    private var dataSection: some View {
        Section("Datos") {
            Button {
                SampleContent.insert(into: context)
                Haptics.success()
                withAnimation { samplesAdded = true }
            } label: {
                Label(samplesAdded ? "Ejemplos añadidos" : "Añadir historias de ejemplo", systemImage: samplesAdded ? "checkmark" : "sparkles")
            }
            .disabled(samplesAdded)

            Button {
                onboardingCompleted = false
            } label: {
                Label("Ver la introducción", systemImage: "play.rectangle")
            }

            Button(role: .destructive) {
                showDeleteAll = true
            } label: {
                Label("Borrar todo", systemImage: "trash")
                    .foregroundStyle(Palette.crimson)
            }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Versión")
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            Label("Tus guiones y tomas se guardan solo en este iPhone.", systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("Relato")
        }
    }

    // MARK: - Reminder

    private var reminderTime: Binding<Date> {
        Binding {
            Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? .now
        } set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminderHour = parts.hour ?? PrefDefault.reminderHour
            reminderMinute = parts.minute ?? PrefDefault.reminderMinute
            Task { await ReminderScheduler.schedule(hour: reminderHour, minute: reminderMinute) }
        }
    }

    private func setReminder(_ enabled: Bool) {
        guard enabled else {
            reminderEnabled = false
            ReminderScheduler.cancel()
            return
        }
        Task {
            if await ReminderScheduler.requestAuthorization() {
                await ReminderScheduler.schedule(hour: reminderHour, minute: reminderMinute)
                withAnimation { reminderEnabled = true }
                Haptics.success()
            } else {
                reminderEnabled = false
                showNotificationsDenied = true
            }
        }
    }
}
