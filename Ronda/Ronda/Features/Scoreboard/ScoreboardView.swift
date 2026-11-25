import SwiftUI

struct ScoreboardView: View {
    @Environment(PartySession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var confirmReset = false
    @State private var grown = false

    var body: some View {
        let standings = session.ledger.standings(for: session.players)
        NavigationStack {
            ZStack {
                NightBackground(colors: [Neon.amber, Neon.magenta])
                ScrollView {
                    VStack(spacing: 22) {
                        if session.ledger.total(for: session.players) == 0 {
                            ContentUnavailableView(
                                "Aún no hay marcador",
                                systemImage: "trophy",
                                description: Text("Jugad un poco: cada vez que alguien \(session.lexicon.soberMode ? "sume puntos" : "beba"), aparecerá aquí.")
                            )
                            .padding(.top, 40)
                        } else {
                            podium(Array(standings.prefix(3)))
                            VStack(spacing: 8) {
                                ForEach(standings, id: \.player.id) { standing in
                                    row(standing, max: standings.first?.sips ?? 1)
                                }
                            }
                            Text(summary(standings))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(Metrics.gutter)
                }
            }
            .navigationTitle("Marcador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Reiniciar", role: .destructive) { confirmReset = true }
                        .disabled(session.ledger.total(for: session.players) == 0)
                }
            }
            .confirmationDialog("¿Reiniciar el marcador?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reiniciar", role: .destructive) {
                    session.resetLedger()
                    Haptics.warning()
                }
            }
        }
        .presentationBackground(Neon.canvas)
        .onAppear {
            guard !grown else { return }
            withAnimation(reduceMotion ? nil : .spring(duration: 0.7, bounce: 0.25).delay(0.15)) { grown = true }
        }
    }

    private func podium(_ top: [SipLedger.Standing]) -> some View {
        // Classic podium order: 2nd, 1st, 3rd.
        let order = [1, 0, 2].filter { top.indices.contains($0) }
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(order, id: \.self) { index in
                let standing = top[index]
                // Ties share a step: medal and height follow the ranking position, not the slot.
                let rank = min(max(standing.position - 1, 0), 2)
                let height: CGFloat = grown ? [150, 110, 80][rank] : 28
                VStack(spacing: 6) {
                    Text(["🥇", "🥈", "🥉"][rank]).font(.largeTitle)
                    Text(standing.player.name)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [Neon.amber, Neon.magenta], startPoint: .top, endPoint: .bottom).opacity(1 - Double(rank) * 0.25))
                        .frame(height: height)
                        .overlay(alignment: .top) {
                            Text("\(standing.sips)")
                                .font(.title.weight(.black).monospacedDigit())
                                .foregroundStyle(Neon.ink)
                                .padding(.top, 10)
                                .opacity(grown ? 1 : 0)
                        }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.top, 10)
    }

    private func row(_ standing: SipLedger.Standing, max: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(standing.position)")
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .frame(width: 26)
                .foregroundStyle(.secondary)
            Text(standing.player.name).font(.headline)
            Spacer()
            GeometryReader { proxy in
                Capsule()
                    .fill(Neon.amber.gradient)
                    .frame(width: max > 0 && grown ? proxy.size.width * CGFloat(standing.sips) / CGFloat(max) : 0)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(width: 90, height: 8)
            Text("\(standing.sips)")
                .font(.headline.monospacedDigit())
                .frame(minWidth: 30, alignment: .trailing)
                .contentTransition(.numericText(value: Double(standing.sips)))
            Button {
                withAnimation(.snappy) { session.undoSip(for: standing.player) }
                Haptics.select()
            } label: {
                Image(systemName: "minus")
                    .font(.footnote.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(standing.sips == 0)
            .accessibilityLabel("Quitar 1 a \(standing.player.name)")
            .accessibilityIdentifier("undo.\(standing.player.name)")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Neon.surface.opacity(0.9)))
    }

    private func summary(_ standings: [SipLedger.Standing]) -> String {
        let unit = session.lexicon.unitTitle.lowercased()
        let free = standings.filter { $0.sips == 0 }.map(\.player.name)
        var text = "Total de la noche: \(session.ledger.total(for: session.players)) \(unit)."
        if !free.isEmpty {
            text += " Se han librado: \(free.joined(separator: ", "))."
        }
        if !session.soberMode {
            text += "\nBebed agua y volved a casa con alguien de confianza. 💧"
        }
        return text
    }
}
