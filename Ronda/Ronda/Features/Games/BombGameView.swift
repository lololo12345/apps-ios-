import SwiftUI

/// Hot potato with categories: the phone ticks faster and faster and explodes at a random moment.
struct BombGameView: View {
    let mode: PartyMode

    @Environment(PartySession.self) private var session
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: Equatable {
        case ready
        case burning
        case exploded
    }

    @State private var categories = ShuffledDeck<String>([])
    @State private var category = ""
    @State private var phase: Phase = .ready
    @State private var ticks = 0
    @State private var heat: Double = 0
    @State private var holder: Set<UUID> = []
    @State private var fuseTask: Task<Void, Never>?
    @State private var shakes: CGFloat = 0
    @State private var flash = false

    private var colors: [Color] { GameKind.bomb.gradient(for: mode) }
    private var penalty: Int { PromptDecks.penalty(for: .bomb, mode: mode) }

    var body: some View {
        GameScaffold(game: .bomb, mode: mode) {
            VStack(spacing: 22) {
                Spacer(minLength: 0)
                VStack(spacing: 8) {
                    Text("CATEGORÍA")
                        .font(.footnote.weight(.heavy))
                        .tracking(1.2)
                        .gradientText(colors)
                    Text(category)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .id(category)
                        .transition(.opacity)
                        .accessibilityIdentifier("bomb.category")
                }
                .frame(maxWidth: .infinity)
                .neonCard(colors)

                bomb
                    .frame(height: 230)

                Text(statusText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .animation(.smooth(duration: 0.3), value: category)
        } controls: {
            controls
        }
        .modifier(ShakeEffect(shakes: shakes, amplitude: reduceMotion ? 0 : 14))
        .overlay {
            // Explosion flash.
            Color.white
                .opacity(flash ? 0.55 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            guard category.isEmpty else { return }
            categories = ShuffledDeck(PromptDecks.prompts(for: .bomb, mode: mode, intensity: session.intensity))
            category = categories.draw() ?? ""
            Haptics.prepare()
        }
        .onDisappear { fuseTask?.cancel() }
    }

    private var statusText: String {
        switch phase {
        case .ready: "Encended la mecha y pasad el móvil diciendo una palabra cada uno."
        case .burning: "¡Rápido! Di una palabra y pásala."
        case .exploded: "¡BOOM! Quien tenga el móvil en la mano, pierde."
        }
    }

    private var bomb: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Neon.orange.opacity(0.2 + heat * 0.6), Neon.crimson.opacity(heat * 0.25), .clear], center: .center, startRadius: 10, endRadius: 170))
                .scaleEffect(0.9 + heat * 0.3)
                .animation(.easeInOut(duration: 0.4), value: heat)
            Text(phase == .exploded ? "💥" : "💣")
                .font(.system(size: phase == .exploded ? 150 : 120))
                .scaleEffect(phase == .burning && ticks.isMultiple(of: 2) && !reduceMotion ? 1.12 : 1)
                .rotationEffect(.degrees(phase == .burning && !reduceMotion ? (ticks.isMultiple(of: 2) ? -4 : 4) : 0))
                .animation(.spring(duration: 0.18, bounce: 0.5), value: ticks)
                .animation(.spring(duration: 0.4, bounce: 0.4), value: phase)
                .accessibilityLabel(phase == .exploded ? "La bomba ha explotado" : "Bomba")
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch phase {
        case .ready:
            VStack(spacing: 10) {
                BigButton(title: "Encender la mecha", symbol: "flame.fill", tint: Neon.orange, identifier: "bomb.start") {
                    light()
                }
                BigButton(title: "Otra categoría", symbol: "shuffle", tint: Neon.orange, prominent: false, identifier: "bomb.skip") {
                    withAnimation { category = categories.draw() ?? category }
                    Haptics.select()
                }
            }
        case .burning:
            Text("No toques nada: solo pásala 🔥")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
        case .exploded:
            VStack(spacing: 12) {
                Text("¿Quién la tenía?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                PlayerPicker(players: session.players, selection: $holder, single: true, accent: Neon.orange)
                BigButton(title: holder.isEmpty ? "Elige a quien perdió" : session.lexicon.drink(penalty).capitalizedFirst, symbol: "arrow.right", tint: Neon.orange, identifier: "bomb.next") {
                    session.give(penalty, to: holder)
                    holder = []
                    session.registerRound()
                    withAnimation(.smooth) {
                        phase = .ready
                        heat = 0
                        category = categories.draw() ?? category
                    }
                }
                .disabled(holder.isEmpty)
            }
        }
    }

    private func light() {
        var generator = SystemRandomNumberGenerator()
        let fuse = BombFuse(using: &generator)
        phase = .burning
        ticks = 0
        Haptics.tap(.heavy)
        fuseTask?.cancel()
        fuseTask = Task {
            let start = Date.now
            while !Task.isCancelled {
                let elapsed = Date.now.timeIntervalSince(start)
                if fuse.hasExploded(elapsed: elapsed) { break }
                ticks += 1
                heat = min(1, elapsed / fuse.duration)
                if heat > 0.7 { Haptics.tap(.heavy) } else { Haptics.tick(intensity: min(1, 0.4 + heat)) }
                try? await Task.sleep(for: .seconds(fuse.tickInterval(elapsed: elapsed)))
            }
            guard !Task.isCancelled else { return }
            Haptics.boom()
            withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                phase = .exploded
                heat = 1
            }
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 0.55)) { shakes += 1 }
            flash = true
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.easeOut(duration: 0.6)) { flash = false }
        }
    }
}

extension String {
    /// "bebe 2 sorbos" → "Bebe 2 sorbos"
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
