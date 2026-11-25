import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(PartySession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @AppStorage("haptics") private var haptics = true
    @State private var confirmAgeReset = false

    var body: some View {
        @Bindable var session = session
        NavigationStack {
            Form {
                Section {
                    AppearancePicker(selection: $session.appearance)
                } header: {
                    Text("Apariencia")
                } footer: {
                    Text("Oscuro para la noche, claro para una tarde en la terraza, o automático como el iPhone.")
                }

                Section {
                    Toggle(isOn: $session.soberPreference) {
                        Label("Modo sin alcohol", systemImage: "star.fill")
                    }
                    .disabled(session.ageStatus == .minor)
                    .accessibilityIdentifier("settings.sober")
                    Picker(selection: $session.waterEvery) {
                        Text("Nunca").tag(0)
                        Text("Cada 5 cartas").tag(5)
                        Text("Cada 10 cartas").tag(10)
                        Text("Cada 15 cartas").tag(15)
                    } label: {
                        Label("Rondas de agua", systemImage: "drop.fill")
                    }
                    .disabled(session.soberMode)
                } header: {
                    Text("Juego")
                } footer: {
                    Text(session.ageStatus == .minor
                         ? "Como eres menor, Ronda funciona siempre en modo sin alcohol: los sorbos son puntos."
                         : "En modo sin alcohol los sorbos se convierten en puntos y prendas. Las rondas de agua aparecen cada pocas cartas para que la noche dure.")
                }

                Section("Contenido") {
                    NavigationLink {
                        CustomCardsView()
                    } label: {
                        Label("Mis cartas", systemImage: "square.and.pencil")
                    }
                    .accessibilityIdentifier("settings.customCards")
                    Toggle(isOn: $haptics) {
                        Label("Vibraciones", systemImage: "iphone.radiowaves.left.and.right")
                    }
                }

                Section {
                    Button {
                        confirmAgeReset = true
                    } label: {
                        Label("Cambiar la confirmación de edad", systemImage: "person.badge.shield.checkmark")
                    }
                    Label("Bebe con responsabilidad. Si vas a conducir, no bebas. Nadie está obligado a beber ni a hacer ningún reto.", systemImage: "heart.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Responsabilidad")
                }
            }
            .scrollContentBackground(.hidden)
            .background(NightBackground(colors: [Neon.violet, Neon.cyan]))
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .confirmationDialog("¿Volver a preguntar la edad?", isPresented: $confirmAgeReset, titleVisibility: .visible) {
                Button("Volver a preguntar") {
                    dismiss()
                    session.hotUnlocked = false
                    session.ageStatus = nil
                }
            }
        }
        .presentationBackground(Neon.canvas)
        // A sheet already on screen does not pick up the app's new colour scheme by itself: switching
        // Apariencia here must repaint the sheet too, not only the screen behind it.
        .preferredColorScheme(session.appearance.colorScheme)
    }
}

struct CustomCardsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomCard.createdAt, order: .reverse) private var cards: [CustomCard]
    @Environment(PartySession.self) private var session

    @State private var game: GameKind = .neverHave
    @State private var mode: PartyMode = .normal
    @State private var draft = ""

    private var editableGames: [GameKind] {
        mode == .hot ? [.neverHave, .mostLikely, .truthOrDrink, .dares] : [.neverHave, .mostLikely, .truthOrDrink]
    }

    var body: some View {
        let filtered = cards.filter { $0.game == game && $0.mode == mode }
        List {
            Section {
                if session.canUseHot {
                    Picker("Apartado", selection: $mode) {
                        ForEach(PartyMode.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Picker("Juego", selection: $game) {
                    ForEach(editableGames) { Text($0.title).tag($0) }
                }
                HStack {
                    TextField(placeholder, text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .accessibilityIdentifier("custom.field")
                    Button("Añadir") { add() }
                        .disabled(CustomCardRules.normalize(draft, for: game) == nil)
                        .accessibilityIdentifier("custom.add")
                }
            } footer: {
                Text(game == .dares
                     ? "Usa {1} y {2} para que la app ponga nombres de jugadores. Ejemplo: «{1}, cántale una canción a {2}»."
                     : "Tus cartas se mezclan con las de la app. Ideal para bromas internas del grupo.")
            }

            Section("\(filtered.count) cartas tuyas") {
                ForEach(filtered) { card in
                    Text(card.text)
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(filtered[index]) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(NightBackground(colors: [Neon.magenta, Neon.violet]))
        .navigationTitle("Mis cartas")
        .onChange(of: mode) {
            if !editableGames.contains(game) { game = .neverHave }
        }
    }

    private var placeholder: String {
        switch game {
        case .neverHave: "Yo nunca he…"
        case .mostLikely: "¿Quién es más probable que…?"
        case .truthOrDrink: "Escribe una pregunta"
        default: "Escribe un reto"
        }
    }

    private func add() {
        guard let text = CustomCardRules.normalize(draft, for: game) else { return }
        context.insert(CustomCard(game: game, mode: mode, text: text))
        draft = ""
        Haptics.success()
    }
}
