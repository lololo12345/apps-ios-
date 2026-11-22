import SwiftUI

struct PlayersView: View {
    var isFirstRun = false

    @Environment(PartySession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var rejected = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ZStack {
            NightBackground(colors: [Neon.violet, Neon.cyan])
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if isFirstRun {
                            Text("¿Quién juega?")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                        }
                        Text("Escribid los nombres en el orden en el que estáis sentados: así la app sabe quién está a la izquierda y a la derecha de cada uno.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    HStack(spacing: 10) {
                        TextField("Nombre", text: $draft)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .focused($fieldFocused)
                            .onSubmit { add() }
                            .padding(.vertical, 12)
                            .padding(.leading, 16)
                            .accessibilityIdentifier("players.field")
                        Button {
                            add()
                        } label: {
                            Image(systemName: "plus").font(.headline).frame(width: 22, height: 22)
                        }
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(6)
                        .accessibilityLabel("Añadir jugador")
                        .accessibilityIdentifier("players.add")
                    }
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: Metrics.gutter, bottom: 8, trailing: Metrics.gutter))

                    if rejected {
                        Text("Ese nombre ya está o no es válido.")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Neon.orange)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }

                Section {
                    ForEach(Array(session.players.enumerated()), id: \.element.id) { index, player in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.heavy).monospacedDigit())
                                .foregroundStyle(.black)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Neon.lime))
                            Text(player.name)
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.white.opacity(0.07))
                    }
                    .onDelete { offsets in
                        for index in offsets { session.removePlayer(session.players[index]) }
                    }
                    .onMove { source, destination in
                        session.movePlayers(from: source, to: destination)
                    }
                } header: {
                    if !session.players.isEmpty {
                        Text("\(session.players.count) jugadores · arrastra para cambiar el orden")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(session.players.count > 1 ? .active : .inactive))
        }
        .navigationTitle(isFirstRun ? "" : "Jugadores")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if isFirstRun {
                BigButton(title: session.players.count < 2 ? "Añade al menos 2 jugadores" : "¡A jugar!", symbol: "party.popper.fill", tint: Neon.magenta, identifier: "players.start") {
                    Haptics.success()
                    session.setupDone = true
                }
                .disabled(session.players.count < 2)
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 8)
            }
        }
        .onAppear { fieldFocused = session.players.isEmpty }
    }

    private func add() {
        if session.addPlayer(named: draft) {
            draft = ""
            rejected = false
            Haptics.tap()
        } else if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
            rejected = true
            Haptics.warning()
        }
        fieldFocused = true
    }
}
