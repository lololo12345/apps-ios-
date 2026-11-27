import SpriteKit
import SwiftUI

/// The game: the SpriteKit world full screen, with the HUD and panels on top in SwiftUI glass.
struct GameScreen: View {
    @Environment(AppModel.self) private var app
    @Bindable var game: GameModel
    @State private var scene: WorldScene?
    @State private var zoneBanner: Zone?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let scene {
                    SpriteView(scene: scene, isPaused: game.panel != nil || !game.started,
                               preferredFramesPerSecond: 120, options: [.ignoresSiblingOrder])
                        .id(game.generation)
                        .ignoresSafeArea()
                        .accessibilityHidden(true)
                }
                if game.started {
                    Joystick(game: game)
                    HUD(game: game)
                        .transition(.opacity)
                    if let zoneBanner {
                        ZoneBanner(zone: zoneBanner)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                } else {
                    TitleScreen(game: game)
                        .transition(.opacity)
                }
                if let panel = game.panel {
                    PanelHost(game: game, panel: panel)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
                if let celebration = game.celebration {
                    CelebrationCard(celebration: celebration) {
                        withAnimation(.smooth) { game.celebration = nil }
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .onAppear {
                if scene == nil { scene = WorldScene(model: game, size: proxy.size) }
            }
            .onChange(of: game.generation) {
                scene = WorldScene(model: game, size: proxy.size)
            }
        }
        .animation(.smooth(duration: 0.3), value: game.panel)
        .animation(.smooth(duration: 0.35), value: game.started)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: game.hapticsTick) { _, _ in app.hapticsOn }
        .sensoryFeedback(.impact(weight: .heavy), trigger: game.hurtTick) { _, _ in app.hapticsOn }
        .onChange(of: game.zone) { _, zone in
            withAnimation(.spring(duration: 0.5)) { zoneBanner = zone }
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                withAnimation(.smooth) { if zoneBanner == zone { zoneBanner = nil } }
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

// MARK: - Joystick

/// Floating stick: touch anywhere on the left of the screen, the stick appears under the thumb.
struct Joystick: View {
    let game: GameModel
    @State private var origin: CGPoint?
    @State private var knob: CGSize = .zero
    private let radius: CGFloat = 54

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(.rect)
                .frame(width: proxy.size.width * 0.45, height: proxy.size.height * 0.72)
                .position(x: proxy.size.width * 0.225, y: proxy.size.height * 0.64)
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("stick"))
                        .onChanged { value in
                            if origin == nil { origin = value.startLocation }
                            var dx = value.translation.width, dy = value.translation.height
                            let length = hypot(dx, dy)
                            if length > radius { dx *= radius / length; dy *= radius / length }
                            knob = CGSize(width: dx, height: dy)
                            game.stick = CGVector(dx: dx / radius, dy: -dy / radius)
                        }
                        .onEnded { _ in
                            withAnimation(.snappy(duration: 0.2)) { knob = .zero; origin = nil }
                            game.stick = .zero
                        }
                )
            // Resting hint where the thumb usually goes; follows the thumb while dragging.
            let center = origin ?? CGPoint(x: 110, y: proxy.size.height - 96)
            ZStack {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: radius * 2 + 20, height: radius * 2 + 20)
                    .glassEffect(.regular, in: .circle)
                Circle()
                    .fill(LinearGradient(colors: [.white.opacity(0.95), Palette.accentSoft], startPoint: .top, endPoint: .bottom))
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                    .offset(knob)
            }
            .position(center)
            .opacity(origin == nil ? 0.55 : 1)
            .allowsHitTesting(false)
        }
        .coordinateSpace(name: "stick")
        .accessibilityElement()
        .accessibilityLabel("Joystick")
    }
}

// MARK: - HUD

struct HUD: View {
    @Bindable var game: GameModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    StatusPill(game: game)
                    ToastStack(toasts: game.toasts)
                }
                Spacer(minLength: 8)
                VStack(spacing: 8) {
                    QuestCard(game: game)
                    if let raid = game.raid { RaidBar(raid: raid) }
                    if let boss = game.boss { BossBar(boss: boss) }
                }
                .frame(maxWidth: 250)
                Spacer(minLength: 8)
                TopRight(game: game)
            }
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                Spacer()
                VStack(alignment: .trailing, spacing: 12) {
                    ContextButtons(game: game)
                    HeavyButton(game: game)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .animation(.snappy, value: game.place)
        .animation(.smooth, value: game.raid?.enemies)
        .animation(.smooth, value: game.boss?.health)
    }
}

struct StatusPill: View {
    let game: GameModel

    var body: some View {
        let state = game.state
        HStack(spacing: 12) {
            Label {
                Text(state.coins.grouped).contentTransition(.numericText()).monospacedDigit().lineLimit(1)
            } icon: {
                Text("🪙")
            }
            .font(.system(.headline, design: .rounded, weight: .heavy))
            // Never squeezed: in landscape the notch margins leave little room for the top bar.
            .fixedSize()
            .layoutPriority(2)
            .accessibilityIdentifier("hud.coins")

            VStack(alignment: .leading, spacing: 3) {
                Label("\(state.carried)/\(state.capacity)", systemImage: "backpack.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(state.isFull ? Palette.gold : .primary)
                    .contentTransition(.numericText())
                Meter(fraction: Double(state.carried) / Double(state.capacity), colors: state.isFull ? [Palette.gold, .orange] : [Palette.accentSoft, Palette.accent])
            }
            .frame(width: 64)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("hud.backpack")

            VStack(alignment: .leading, spacing: 3) {
                Label("\(game.health)", systemImage: "heart.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Palette.bad)
                    .contentTransition(.numericText())
                Meter(fraction: Double(game.health) / Double(max(state.maxHealth, 1)), colors: [Color(hex: 0xFF8A8A), Palette.bad])
            }
            .frame(width: 56)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassEffect(.regular.tint(Palette.background.opacity(0.25)), in: .capsule)
        .animation(.snappy, value: state.coins)
        .animation(.snappy, value: game.health)
    }
}

struct Meter: View {
    let fraction: Double
    let colors: [Color]

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.25))
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(proxy.size.width * min(max(fraction, 0), 1), 4))
            }
        }
        .frame(height: 6)
        .animation(.smooth(duration: 0.3), value: fraction)
    }
}

struct QuestCard: View {
    let game: GameModel

    var body: some View {
        Button {
            game.panel = .journal
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Palette.accent.gradient))
                VStack(alignment: .leading, spacing: 3) {
                    if let quest = game.state.currentQuest {
                        Text(quest.title)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Meter(fraction: game.state.progress(quest.goal), colors: [Palette.accentSoft, Palette.accent])
                    } else {
                        Text("¡Todas las misiones cumplidas!")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(Palette.background.opacity(0.25)), in: .capsule)
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier("hud.quest")
    }
}

struct RaidBar: View {
    let raid: (enemies: Int, campfire: Int, max: Int)

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars.fill").foregroundStyle(Palette.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text("Asalto · quedan \(raid.enemies)")
                    .font(.caption.weight(.heavy))
                    .contentTransition(.numericText())
                Meter(fraction: Double(raid.campfire) / Double(max(raid.max, 1)), colors: [Color(hex: 0xFFE27A), Color(hex: 0xFF9A3C)])
            }
            Image(systemName: "flame.fill").foregroundStyle(.orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .glassEffect(.regular.tint(Color(hex: 0x3B2E7A).opacity(0.45)), in: .capsule)
        .accessibilityIdentifier("hud.raid")
    }
}

struct BossBar: View {
    let boss: (health: Int, max: Int)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Gran Lobo de Humo", systemImage: "crown.fill")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color(hex: 0xFF8A8A))
            Meter(fraction: Double(boss.health) / Double(max(boss.max, 1)), colors: [Color(hex: 0xFF6B7D), Color(hex: 0xC8203A)])
                .frame(height: 9)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(Color(hex: 0x6A1022).opacity(0.4)), in: .capsule)
        .accessibilityIdentifier("hud.boss")
    }
}

struct TopRight: View {
    @Bindable var game: GameModel

    var body: some View {
        HStack(spacing: 8) {
            let minutes = game.secondsToChange / 60, seconds = game.secondsToChange % 60
            Label {
                Text("\(minutes):\(String(format: "%02d", seconds))")
                    .monospacedDigit()
                    .lineLimit(1)
            } icon: {
                Image(systemName: game.isNight ? "moon.stars.fill" : "sun.max.fill")
                    .foregroundStyle(game.isNight ? Palette.secondary : Palette.gold)
                    .symbolEffect(.bounce, value: game.isNight)
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .glassEffect(.regular.tint(Palette.background.opacity(0.25)), in: .capsule)
            .fixedSize()
            .accessibilityLabel("\(game.isNight ? "Amanece" : "Anochece") en \(minutes) minutos y \(seconds) segundos")
            .accessibilityIdentifier("hud.clock")

            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    if game.dailyRewardAvailable {
                        GlassIconButton(systemImage: "gift.fill", label: "Regalo del día") { game.claimDailyReward() }
                            .tint(Palette.gold)
                            .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 2)))
                            .accessibilityIdentifier("hud.gift")
                    }
                    GlassIconButton(systemImage: "book.fill", label: "Diario") { game.panel = .journal }
                        .accessibilityIdentifier("hud.journal")
                    GlassIconButton(systemImage: "gearshape.fill", label: "Ajustes") { game.panel = .settings }
                        .accessibilityIdentifier("hud.settings")
                }
            }
        }
    }
}

struct ContextButtons: View {
    @Bindable var game: GameModel

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            switch game.place {
            case .base:
                HStack(spacing: 8) {
                    if game.state.level(.garden) > 0 && game.state.gardenStock > 0 {
                        action("Huerto · \(game.state.gardenStock)", "leaf.fill", "hud.garden", Palette.accent) { game.harvestGarden() }
                    }
                    action("Mercado", "cart.fill", "hud.market", Palette.gold) { game.panel = .market }
                    action("Taller", "hammer.fill", "hud.workshop", Color(hex: 0xC48A4F)) { game.panel = .workshop }
                    action("Equipo", "shield.lefthalf.filled", "hud.upgrades", Palette.sky) { game.panel = .upgrades }
                    action("Tablón", "list.clipboard.fill", "hud.board", Palette.secondary) { game.panel = .board }
                }
            case .bridge(let id):
                action(game.state.bridges.contains(id) ? "Puente" : "Construir puente", "hammer.circle.fill", "hud.bridge", Palette.gold) {
                    game.panel = .bridge(id)
                }
            case nil:
                EmptyView()
            }
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    private func action(_ title: String, _ symbol: String, _ id: String, _ tint: Color, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: 3) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(tint.gradient))
                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1))
                    .shadow(color: tint.opacity(0.5), radius: 6, y: 3)
                Text(title)
                    .font(.caption2.weight(.heavy))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .glassEffect(.regular, in: .capsule)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityIdentifier(id)
    }
}

struct HeavyButton: View {
    let game: GameModel

    var body: some View {
        Button {
            game.heavyRequested = true
        } label: {
            Image(systemName: "bolt.fill")
                .font(.system(size: 30, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 78, height: 78)
                .background(Circle().fill(LinearGradient(colors: [Color(hex: 0xFF8A5B), Color(hex: 0xE5532D)], startPoint: .top, endPoint: .bottom)))
                .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2))
                .shadow(color: Color(hex: 0xE5532D).opacity(0.5), radius: 10, y: 4)
                .opacity(game.heavyReady ? 1 : 0.45)
                .scaleEffect(game.heavyReady ? 1 : 0.92)
                .animation(.snappy, value: game.heavyReady)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Golpe fuerte")
        .accessibilityIdentifier("hud.heavy")
    }
}

struct ToastStack: View {
    let toasts: [Toast]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(toasts) { toast in
                Label(toast.text, systemImage: toast.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(toast.tint.opacity(0.55)))
                    .glassEffect(.regular, in: .capsule)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
    }
}

struct ZoneBanner: View {
    let zone: Zone

    var body: some View {
        VStack(spacing: 4) {
            Text(zone == .clearing ? "Hogar" : zone == .oldForest ? "Zona nueva" : "En la Niebla")
                .font(.caption.weight(.heavy))
                .textCase(.uppercase)
                .tracking(2)
                .foregroundStyle(.white.opacity(0.85))
            Text(zone.name)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 3)
        }
        .padding(.top, 60)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct CelebrationCard: View {
    let celebration: Celebration
    let close: () -> Void
    @State private var pop = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: close)
            VStack(spacing: 12) {
                Image(systemName: celebration.symbol)
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 86, height: 86)
                    .background(Circle().fill(celebration.tint.gradient))
                    .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 2))
                    .shadow(color: celebration.tint.opacity(0.6), radius: 16)
                    .symbolEffect(.bounce, value: pop)
                Text(celebration.title)
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .multilineTextAlignment(.center)
                Text(celebration.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "¡Genial!", systemImage: "checkmark", action: close)
                    .frame(maxWidth: 220)
                    .accessibilityIdentifier("celebration.ok")
            }
            .padding(24)
            .frame(maxWidth: 420)
            .heroCard(tint: celebration.tint)
            .scaleEffect(pop ? 1 : 0.85)
        }
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.4)) { pop = true } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("celebration")
    }
}

// MARK: - Title and first steps

struct TitleScreen: View {
    let game: GameModel
    @State private var showTips = false
    @State private var float = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0F2418).opacity(0.75), Color(hex: 0x0F2418).opacity(0.25), Color(hex: 0x0F2418).opacity(0.8)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if showTips {
                Tips {
                    game.state.tutorialDone = true
                    game.save()
                    game.started = true
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                HStack(spacing: 32) {
                    Image(decorative: Art.brote(frame: 0).cgImage(), scale: 2)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 150, height: 172)
                        .offset(y: float ? -8 : 8)
                        .shadow(color: Palette.accent.opacity(0.5), radius: 30)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bastión")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.white, Palette.accentSoft], startPoint: .top, endPoint: .bottom))
                            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                        Text("El valle de la Niebla")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                        Text("Recoge, vende, construye puentes y devuelve la luz al valle.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                        PrimaryButton(title: game.state.tutorialDone ? "Continuar" : "Jugar", systemImage: "play.fill") {
                            if game.state.tutorialDone {
                                game.started = true
                            } else {
                                withAnimation(.smooth) { showTips = true }
                            }
                        }
                        .frame(maxWidth: 260)
                        .padding(.top, 6)
                        .accessibilityIdentifier("title.play")
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever()) { float = true } }
    }
}

struct Tips: View {
    let start: () -> Void

    private let tips: [(String, String, String, Color)] = [
        ("hand.draw.fill", "Muévete", "Toca la izquierda de la pantalla y arrastra. Tu Brote recoge solo lo que tiene cerca.", Palette.accent),
        ("cart.fill", "Vende y mejora", "Vuelve a la base: se guarda todo. Vende en el mercado, fabrica en el taller y mejora tu equipo.", Palette.gold),
        ("moon.stars.fill", "Defiende la hoguera", "De noche la Niebla ataca. Tu Brote pelea solo; ⚡ es el golpe fuerte.", Palette.secondary),
    ]

    var body: some View {
        VStack(spacing: 18) {
            Text("Cómo se juega")
                .font(.system(.title, design: .rounded, weight: .black))
                .foregroundStyle(.white)
            HStack(alignment: .top, spacing: 14) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    VStack(alignment: .leading, spacing: 10) {
                        IconBadge(systemImage: tip.0, tint: tip.3, size: 48)
                        Text(tip.1).font(.system(.headline, design: .rounded, weight: .bold))
                        Text(tip.2).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(tint: tip.3)
                    .appearAnimation(order: index)
                }
            }
            .frame(maxWidth: 760)
            PrimaryButton(title: "¡A la aventura!", systemImage: "leaf.fill", action: start)
                .frame(maxWidth: 280)
                .accessibilityIdentifier("tutorial.start")
        }
        .padding(24)
    }
}
