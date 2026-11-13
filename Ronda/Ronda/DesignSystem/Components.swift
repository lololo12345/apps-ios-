import SwiftUI

/// Frame shared by every game: glowing background, glass top bar (close, title, how to play)
/// and a bottom area for the controls.
struct GameScaffold<Content: View, Controls: View>: View {
    let game: GameKind
    let mode: PartyMode
    @ViewBuilder let content: Content
    @ViewBuilder let controls: Controls

    @Environment(\.dismiss) private var dismiss
    @Environment(PartySession.self) private var session
    @State private var showRules = false

    var body: some View {
        let colors = game.gradient(for: mode)
        ZStack {
            NightBackground(colors: colors)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark").font(.headline).frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Salir del juego")
                    .accessibilityIdentifier("game.close")

                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: game.symbol)
                        Text(game.title)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if mode == .hot {
                            Image(systemName: "flame.fill").foregroundStyle(Neon.crimson)
                        }
                    }
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .glassEffect(.regular, in: .capsule)
                    Spacer()

                    Button {
                        showRules = true
                    } label: {
                        Image(systemName: "questionmark").font(.headline).frame(width: 24, height: 24)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Cómo se juega")
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 8)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, Metrics.gutter)

                controls
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showRules) {
            RulesSheet(game: game, colors: colors)
                .presentationDetents([.medium])
        }
        .overlay {
            if let message = session.pendingWaterBreak {
                WaterBreakOverlay(message: message) {
                    withAnimation(.smooth) { session.pendingWaterBreak = nil }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.smooth(duration: 0.3), value: session.pendingWaterBreak)
    }
}

struct RulesSheet: View {
    let game: GameKind
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(game.title, systemImage: game.symbol)
                .font(.title2.weight(.bold))
                .gradientText(colors)
            Text(game.howToPlay)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Label("Siempre puedes pasar: nadie está obligado a nada.", systemImage: "hand.raised.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .presentationBackground(Neon.surface)
    }
}

/// Big prompt card in the middle of the screen.
struct PromptCardView: View {
    let text: String
    let colors: [Color]
    var eyebrow: String?

    var body: some View {
        VStack(spacing: 16) {
            if let eyebrow {
                Text(eyebrow.uppercased())
                    .font(.footnote.weight(.heavy))
                    .tracking(1.2)
                    .gradientText(colors)
            }
            Text(text)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .contentTransition(.opacity)
                .id(text)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .neonCard(colors, padding: 26)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("prompt.card")
    }
}

/// "Bebe 2 sorbos" pill.
struct SipBadge: View {
    let count: Int
    let lexicon: Lexicon
    var prefix: String?

    var body: some View {
        Label((prefix.map { $0 + " " } ?? "") + lexicon.sips(count), systemImage: lexicon.drinkSymbol)
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .glassEffect(.regular.tint(Neon.amber.opacity(0.25)), in: .capsule)
    }
}

/// Multi-select player chips ("¿Quién ha bebido?").
struct PlayerPicker: View {
    let players: [Player]
    @Binding var selection: Set<UUID>
    var single = false
    var accent: Color = Neon.violet

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(players) { player in
                let isOn = selection.contains(player.id)
                Button {
                    if single {
                        selection = isOn ? [] : [player.id]
                    } else if isOn {
                        selection.remove(player.id)
                    } else {
                        selection.insert(player.id)
                    }
                    Haptics.select()
                } label: {
                    Text(player.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isOn ? Color.black : Color.white)
                        .background {
                            Capsule().fill(isOn ? AnyShapeStyle(accent) : AnyShapeStyle(Neon.surfaceRaised))
                        }
                        .overlay { Capsule().strokeBorder(isOn ? .clear : Neon.hairline) }
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(isOn ? .isSelected : [])
                .accessibilityIdentifier("pick.\(player.name)")
            }
        }
        .animation(.snappy(duration: 0.2), value: selection)
    }
}

/// Main call-to-action button.
struct BigButton: View {
    let title: String
    var symbol: String?
    var tint: Color = Neon.violet
    var prominent = true
    var identifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let symbol { Image(systemName: symbol) }
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .modifier(BigButtonStyle(prominent: prominent))
        .tint(tint)
        .accessibilityIdentifier(identifier ?? title)
    }
}

private struct BigButtonStyle: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if prominent {
            content.buttonStyle(.glassProminent)
        } else {
            content.buttonStyle(.glass)
        }
    }
}

struct WaterBreakOverlay: View {
    let message: String
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(Neon.cyan)
                Text(message)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                BigButton(title: "¡Hecho!", symbol: "checkmark", tint: Neon.cyan, identifier: "water.done", action: onDone)
            }
            .neonCard([Neon.cyan, Neon.violet])
            .padding(32)
        }
        .accessibilityIdentifier("water.break")
    }
}

/// Spanish playing card face.
struct SpanishCardView: View {
    let card: SpanishCard
    var size: CGFloat = 170

    private var tint: Color {
        switch card.suit {
        case .oros: Neon.amber
        case .copas: Neon.crimson
        case .espadas: Neon.cyan
        case .bastos: Neon.lime
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                .fill(Color(hex: 0xFBF7EE))
            RoundedRectangle(cornerRadius: size * 0.1, style: .continuous)
                .strokeBorder(tint, lineWidth: 4)
                .padding(6)
            VStack(spacing: 4) {
                Text(card.shortRank)
                    .font(.system(size: size * 0.42, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: 0x1A1726))
                Text(card.suit.glyph)
                    .font(.system(size: size * 0.24))
                Text(card.rankName.uppercased())
                    .font(.system(size: size * 0.08, weight: .heavy, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Color(hex: 0x1A1726).opacity(0.6))
            }
        }
        .frame(width: size, height: size * 1.45)
        .shadow(color: tint.opacity(0.5), radius: 22, y: 8)
        .accessibilityElement()
        .accessibilityLabel(card.fullName)
    }
}
