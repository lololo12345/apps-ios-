import SwiftUI

struct SettingsView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        @Bindable var store = store
        NavigationStack {
            Form {
                Section("Tu nombre en la liga") {
                    TextField("Nombre", text: $store.playerName)
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier("nameField")
                }
                Section {
                    Toggle("Recordatorio diario", isOn: $store.reminderOn)
                        .accessibilityIdentifier("reminderToggle")
                    if store.reminderOn {
                        DatePicker("Hora", selection: $store.reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Avisos")
                } footer: {
                    Text("Si ya has completado el reto del día, ese día no te avisamos.")
                }
                Section("Sonido y vibración") {
                    Toggle("Sonidos", isOn: $store.soundOn)
                    Toggle("Vibración", isOn: $store.hapticsOn)
                }
                Section("Cómo se puntúa") {
                    LabeledContent("Acierto", value: "\(Int(Scoring.base)) puntos")
                    LabeledContent("Rapidez", value: "hasta +\(Int(Scoring.maxTimeBonus))")
                    LabeledContent("Ayuda", value: "−\(Int(Scoring.hintCost))")
                    LabeledContent("Lunes y martes", value: "×1")
                    LabeledContent("Miércoles y jueves", value: "×1,25")
                    LabeledContent("Viernes y sábado", value: "×1,5")
                    LabeledContent("Domingo (reto jefe)", value: "×2")
                    Text("Cada 7 días seguidos ganas un protector de racha (máximo \(Streaks.maxShields)). Si un día no juegas, se gasta solo y tu racha sigue viva.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Ranking mundial") {
                    Text(GameCenter.isEnabled
                         ? "Game Center está activado: tus puntos semanales se envían a la clasificación mundial."
                         : "La clasificación mundial con Game Center necesita publicar la app con una cuenta de desarrollador de Apple. Mientras tanto, compite con tus amigos en la Liga.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Borrar todo mi progreso", role: .destructive) { confirmReset = true }
                } footer: {
                    Text("Chispa · \(RiddleBank.all.count) acertijos y \(TriviaBank.all.count) preguntas de cultura; matemáticas, memoria y lógica se generan cada día. Todo se guarda solo en este iPhone.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(NightBackground())
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo", systemImage: "checkmark") { dismiss() }
                        .accessibilityIdentifier("closeSettings")
                }
            }
            .confirmationDialog("¿Borrar todo tu progreso?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Borrar racha, resultados y amigos", role: .destructive) { store.resetAll() }
            } message: {
                Text("No se puede deshacer.")
            }
        }
    }
}

struct OnboardingView: View {
    @Environment(GameStore.self) private var store
    @State private var name = ""
    @State private var appeared = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            NightBackground()
            VStack(spacing: 22) {
                Spacer(minLength: 20)
                Image(systemName: "sparkle")
                    .font(.system(size: 84, weight: .bold))
                    .sparkText()
                    .shadow(color: Palette.ember.opacity(0.6), radius: 26)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .rotationEffect(.degrees(appeared ? 0 : -60))
                VStack(spacing: 8) {
                    Text("Chispa")
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                    Text("Un minuto de cerebro al día")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.muted)
                }
                VStack(alignment: .leading, spacing: 14) {
                    feature("square.stack.3d.up.fill", "Cinco retos nuevos cada día", "Acertijo, cultura, cálculo, memoria y lógica.")
                    feature("flame.fill", "Una oportunidad y una racha", "Vuelve mañana para no perderla.")
                    feature("trophy.fill", "Liga con tus amigos", "Compartid vuestros códigos y a ver quién gana la semana.")
                }
                .card()
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                Spacer(minLength: 10)
                TextField("¿Cómo te llamas?", text: $name)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.go)
                    .focused($focused)
                    .onSubmit(start)
                    .padding(14)
                    .glassEffect(.regular, in: .capsule)
                    .accessibilityIdentifier("onboardingName")
                Button(action: start) {
                    Text("Empezar a jugar")
                        .font(.title3.weight(.heavy))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.ember)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityIdentifier("onboardingStart")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .onAppear { withAnimation(.spring(duration: 0.8, bounce: 0.4)) { appeared = true } }
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Palette.amber)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(Palette.muted)
            }
        }
    }

    private func start() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        focused = false
        store.playerName = String(trimmed.prefix(20))
    }
}
