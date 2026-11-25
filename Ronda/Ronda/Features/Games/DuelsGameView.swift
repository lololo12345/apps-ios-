import SwiftUI

struct DuelsGameView: View {
    @Environment(PartySession.self) private var session

    /// Chosen fighters in tap order; picking a third replaces the oldest pick.
    @State private var picked: [UUID] = []
    @State private var kind: Duel.Kind = .reflex
    @State private var fighters: (top: Player, bottom: Player)?
    @State private var lastResult: String?

    private let colors = GameKind.duels.gradient(for: .normal)
    private var penalty: Int { PromptDecks.penalty(for: .duels, mode: .normal) }

    var body: some View {
        GameScaffold(game: .duels, mode: .normal) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Elige dos jugadores")
                        .font(.headline)
                    PlayerPicker(players: session.players, selection: limitedSelection, accent: colors.first ?? Neon.magenta)

                    Text("Elige el duelo")
                        .font(.headline)
                    ForEach(Duel.Kind.allCases) { item in
                        Button {
                            kind = item
                            Haptics.select()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.symbol)
                                    .font(.title2)
                                    .frame(width: 36)
                                    .gradientText(colors)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.title).font(.headline).foregroundStyle(.primary)
                                    Text(item.instructions).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: kind == item ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(kind == item ? (colors.first ?? .white) : .secondary)
                            }
                            .neonCard(kind == item ? colors : [Neon.hairline, Neon.hairline], radius: 18, padding: 14)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityIdentifier("duel.kind.\(item.rawValue)")
                    }

                    if let lastResult {
                        Label(lastResult, systemImage: "trophy.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Neon.amber)
                            .id(lastResult)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.vertical, 12)
                .animation(.snappy(duration: 0.25), value: kind)
                .animation(.smooth, value: lastResult)
            }
            .scrollIndicators(.hidden)
        } controls: {
            BigButton(title: "¡A luchar!", symbol: "bolt.fill", tint: colors.first ?? Neon.magenta, identifier: "duel.start") {
                startDuel()
            }
            .disabled(picked.count != 2)
        }
        .fullScreenCover(isPresented: Binding(get: { fighters != nil }, set: { if !$0 { fighters = nil } })) {
            if let fighters {
                DuelArena(kind: kind, top: fighters.top, bottom: fighters.bottom) { result in
                    finish(result, top: fighters.top, bottom: fighters.bottom)
                }
            }
        }
    }

    /// Picker binding that never holds more than two players.
    private var limitedSelection: Binding<Set<UUID>> {
        Binding {
            Set(picked)
        } set: { newValue in
            picked.removeAll { !newValue.contains($0) }
            for id in newValue where !picked.contains(id) { picked.append(id) }
            while picked.count > 2 { picked.removeFirst() }
        }
    }

    private func startDuel() {
        let chosen = picked.compactMap { id in session.players.first { $0.id == id } }
        guard chosen.count == 2 else { return }
        Haptics.tap(.heavy)
        fighters = (chosen[0], chosen[1])
    }

    private func finish(_ result: Duel.Result, top: Player, bottom: Player) {
        switch result {
        case .winner(let side):
            let loser = side == .top ? bottom : top
            let winner = side == .top ? top : bottom
            session.give(penalty, to: loser)
            lastResult = "Ganó \(winner.name). \(loser.name) \(session.lexicon.drink(penalty))."
        case .tie:
            session.give(1, to: [top.id, bottom.id])
            lastResult = "Empate: \(top.name) y \(bottom.name) \(session.lexicon.soberMode ? "suman 1" : "beben 1")."
        }
        session.registerRound()
    }
}

/// Face-to-face arena: the top half is rotated so each player reads their side.
struct DuelArena: View {
    let kind: Duel.Kind
    let top: Player
    let bottom: Player
    let onResult: (Duel.Result) -> Void

    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case countdown(Int)
        case waiting
        case live
        case finished(Duel.Result)
    }

    @State private var phase: Phase = .countdown(3)
    @State private var taps = (top: 0, bottom: 0)
    @State private var rounds: [Duel.ColorRound] = []
    @State private var roundIndex = 0
    @State private var task: Task<Void, Never>?
    @State private var tapsRemaining: Double = Duel.tapDuration

    var body: some View {
        ZStack {
            Neon.ink.ignoresSafeArea()
            VStack(spacing: 0) {
                half(.top, player: top)
                    .rotationEffect(.degrees(180))
                Rectangle()
                    .fill(LinearGradient(colors: [Neon.magenta, Neon.orange], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 3)
                half(.bottom, player: bottom)
            }
            .ignoresSafeArea()

            if case .finished = phase {
                HStack(spacing: 10) {
                    BigButton(title: "Volver", symbol: "arrow.uturn.left", tint: Neon.magenta, prominent: false, identifier: "duel.back") {
                        dismiss()
                    }
                    BigButton(title: "Revancha", symbol: "arrow.counterclockwise", tint: Neon.magenta, identifier: "duel.rematch") {
                        rematch()
                    }
                }
                .padding(.horizontal, 32)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .statusBarHidden()
        // The duel arena is always dark: two players face each other over full-screen colour flashes.
        .environment(\.colorScheme, .dark)
        .onAppear(perform: begin)
        .onDisappear { task?.cancel() }
    }

    // MARK: - Halves

    private func half(_ side: Duel.Side, player: Player) -> some View {
        ZStack {
            background(for: side)
            VStack(spacing: 10) {
                Text(player.name)
                    .font(.title2.weight(.black))
                content(for: side)
            }
            .foregroundStyle(.white)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { tapped(side) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("duel.half.\(side == .top ? "top" : "bottom")")
    }

    private func background(for side: Duel.Side) -> some View {
        let color: Color = switch phase {
        case .live where kind == .reflex: Neon.lime.opacity(0.85)
        case .finished(.winner(let winner)): winner == side ? Neon.lime.opacity(0.35) : Neon.crimson.opacity(0.35)
        case .finished(.tie): Neon.amber.opacity(0.3)
        default: Neon.surface
        }
        return color.animation(.easeOut(duration: 0.12), value: phase)
    }

    @ViewBuilder
    private func content(for side: Duel.Side) -> some View {
        switch phase {
        case .countdown(let value):
            Text("\(value)")
                .font(.system(size: 80, weight: .black, design: .rounded))
                .contentTransition(.numericText(countsDown: true))
        case .waiting:
            Text(kind == .reflex ? "Espera al verde…" : "¡Atento!")
                .font(.title3.weight(.semibold))
        case .live:
            switch kind {
            case .reflex:
                Text("¡TOCA!").font(.system(size: 56, weight: .black, design: .rounded)).foregroundStyle(Neon.ink)
            case .taps:
                VStack(spacing: 4) {
                    Text("\(side == .top ? taps.top : taps.bottom)")
                        .font(.system(size: 72, weight: .black, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(String(format: "%.1f s", tapsRemaining)).font(.headline.monospacedDigit()).foregroundStyle(.secondary)
                }
            case .colors:
                if rounds.indices.contains(roundIndex) {
                    let round = rounds[roundIndex]
                    Text(Duel.ColorRound.palette[round.word])
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(inkColor(round.ink))
                        .id(roundIndex)
                }
            }
        case .finished(let result):
            Text(resultText(result, side: side))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
        }
    }

    private func inkColor(_ index: Int) -> Color {
        [Color.red, Color.blue, Color.green, Color.yellow][index]
    }

    private func resultText(_ result: Duel.Result, side: Duel.Side) -> String {
        switch result {
        case .tie: "Empate"
        case .winner(let winner): winner == side ? "¡Ganas! 🏆" : "Pierdes 🍻"
        }
    }

    // MARK: - Flow

    private func rematch() {
        task?.cancel()
        taps = (0, 0)
        roundIndex = 0
        tapsRemaining = Duel.tapDuration
        withAnimation(.smooth(duration: 0.25)) { phase = .countdown(3) }
        begin()
    }

    private func begin() {
        Haptics.prepare()
        var generator = SystemRandomNumberGenerator()
        rounds = Duel.colorRounds(using: &generator)
        task = Task {
            for value in stride(from: 3, through: 1, by: -1) {
                phase = .countdown(value)
                Haptics.tap(.medium)
                try? await Task.sleep(for: .milliseconds(700))
                if Task.isCancelled { return }
            }
            switch kind {
            case .reflex:
                phase = .waiting
                try? await Task.sleep(for: .seconds(Double.random(in: 1.5...4.5)))
                if Task.isCancelled || phase != .waiting { return }
                phase = .live
                Haptics.tap(.heavy)
            case .taps:
                phase = .live
                let start = Date.now
                while !Task.isCancelled {
                    let remaining = Duel.tapDuration - Date.now.timeIntervalSince(start)
                    if remaining <= 0 { break }
                    tapsRemaining = remaining
                    try? await Task.sleep(for: .milliseconds(100))
                }
                if Task.isCancelled { return }
                finish(Duel.resolveTaps(top: taps.top, bottom: taps.bottom))
            case .colors:
                phase = .live
                for index in rounds.indices {
                    roundIndex = index
                    try? await Task.sleep(for: .milliseconds(1100))
                    if Task.isCancelled || phase != .live { return }
                }
                // Nobody tapped on a match: both drink.
                finish(.tie)
            }
        }
    }

    private func tapped(_ side: Duel.Side) {
        switch phase {
        case .waiting where kind == .reflex:
            finish(Duel.resolveReflex(tap: side, beforeGo: true))
        case .live:
            switch kind {
            case .reflex:
                finish(Duel.resolveReflex(tap: side, beforeGo: false))
            case .taps:
                if side == .top { taps.top += 1 } else { taps.bottom += 1 }
                Haptics.tap()
            case .colors:
                guard rounds.indices.contains(roundIndex) else { return }
                finish(Duel.resolveColorTap(side: side, round: rounds[roundIndex]))
            }
        default:
            break
        }
    }

    private func finish(_ result: Duel.Result) {
        guard !isFinished else { return }
        task?.cancel()
        Haptics.boom()
        withAnimation(.spring(duration: 0.35)) { phase = .finished(result) }
        onResult(result)
    }

    private var isFinished: Bool {
        if case .finished = phase { return true }
        return false
    }
}
