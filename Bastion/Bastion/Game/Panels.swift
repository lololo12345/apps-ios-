import SwiftUI

/// Every panel shares the same frame: dimmed world, a wide glass card, header and close button.
struct PanelHost: View {
    @Bindable var game: GameModel
    let panel: Panel

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea().onTapGesture { close() }
            VStack(spacing: 12) {
                header
                ScrollView {
                    content
                        .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 6)
            .frame(maxWidth: 720, maxHeight: .infinity)
            .heroCard(tint: tint)
            .padding(.vertical, 14)
            .padding(.horizontal, 24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("panel")
    }

    private func close() {
        game.panel = nil
        game.save()
    }

    private var info: (String, String, String) {
        switch panel {
        case .market:
            let star = Market.starItem(day: game.day)
            return ("Mercado", "cart.fill", "Hoy se paga muy bien: \(star.emoji) \(star.name)")
        case .workshop: return ("Taller", "hammer.fill", "Construye edificios y fabrica productos que valen más")
        case .upgrades: return ("Equipo", "shield.lefthalf.filled", "Mejor equipo: recoges más rápido y peleas mejor")
        case .board: return ("Tablón del pueblo", "list.clipboard.fill", "Encargos de los vecinos: pagan más que el mercado")
        case .bridge(let id): return ("Puente hacia \(WorldMap.bridges[id].opens.name)", "road.lanes", "Aporta materiales y monedas poco a poco")
        case .journal: return ("Diario", "book.fill", "Misiones y logros")
        case .settings: return ("Ajustes", "gearshape.fill", "Apariencia, vibración y partida")
        }
    }

    private var tint: Color {
        switch panel {
        case .market: Palette.gold
        case .workshop: Color(hex: 0xC48A4F)
        case .upgrades: Palette.sky
        case .board, .journal: Palette.secondary
        case .bridge: Palette.gold
        case .settings: Palette.accent
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            IconBadge(systemImage: info.1, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.0).font(.system(.title3, design: .rounded, weight: .black))
                Text(info.2).font(.subheadline).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Label(game.state.coins.grouped, systemImage: "circle.fill")
                .labelStyle(CoinLabel())
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .contentTransition(.numericText())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .glassEffect(.regular.tint(Palette.gold.opacity(0.25)), in: .capsule)
            Button { close() } label: {
                Image(systemName: "xmark").font(.headline).frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Cerrar")
            .accessibilityIdentifier("panel.close")
        }
        .animation(.snappy, value: game.state.coins)
    }

    @ViewBuilder
    private var content: some View {
        switch panel {
        case .market: MarketPanel(game: game)
        case .workshop: WorkshopPanel(game: game)
        case .upgrades: UpgradesPanel(game: game)
        case .board: BoardPanel(game: game)
        case .bridge(let id): BridgePanel(game: game, id: id)
        case .journal: JournalPanel(game: game)
        case .settings: SettingsPanel(game: game)
        }
    }
}

struct CoinLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            Text("🪙")
            configuration.title.monospacedDigit()
        }
    }
}

/// "🪙 120 · 🪵 30/40" with what is missing in red.
struct CostView: View {
    let cost: Cost
    let state: GameState

    var body: some View {
        HStack(spacing: 10) {
            Text("🪙 \(cost.coins.grouped)")
                .foregroundStyle(state.coins >= cost.coins ? AnyShapeStyle(HierarchicalShapeStyle.primary) : AnyShapeStyle(Palette.bad))
            ForEach(cost.items.sorted { $0.key.basePrice < $1.key.basePrice }, id: \.key) { item, n in
                let have = state.storage[item, default: 0]
                Text("\(item.emoji) \(min(have, n))/\(n)")
                    .foregroundStyle(have >= n ? AnyShapeStyle(HierarchicalShapeStyle.primary) : AnyShapeStyle(Palette.bad))
            }
        }
        .font(.caption.weight(.bold))
        .monospacedDigit()
    }
}

// MARK: - Market

struct MarketPanel: View {
    let game: GameModel
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 10)]

    var body: some View {
        let state = game.state
        let goods = Item.allCases.filter { state.storage[$0, default: 0] > 0 }
        if goods.isEmpty {
            EmptyState(systemImage: "shippingbox", title: "El almacén está vacío",
                       message: "Sal a recoger madera, bayas o piedra y vuelve a la base: se guarda sola.")
        } else {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(goods) { item in
                    let star = Market.starItem(day: game.day) == item
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.emoji).font(.largeTitle)
                            Spacer()
                            if star {
                                Label("Estrella", systemImage: "star.fill")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(Palette.gold.ink)
                            }
                        }
                        Text(item.name).font(.system(.headline, design: .rounded, weight: .bold))
                        Text("Tienes \(state.storage[item, default: 0]) · \(Market.price(item, day: game.day)) 🪙 c/u")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                        HStack(spacing: 6) {
                            Button("Vender 10") { game.sell(item, all: false) }
                                .buttonStyle(.glass)
                                .accessibilityIdentifier("sell.\(item.rawValue)")
                            Button("Todo") { game.sell(item, all: true) }
                                .buttonStyle(.glassProminent)
                                .tint(Palette.gold)
                                .accessibilityIdentifier("sellAll.\(item.rawValue)")
                        }
                        .font(.caption.weight(.bold))
                    }
                    .card(tint: star ? Palette.gold : nil, padding: 12)
                }
            }
        }
    }
}

// MARK: - Workshop

struct WorkshopPanel: View {
    let game: GameModel

    var body: some View {
        let state = game.state
        VStack(alignment: .leading, spacing: 14) {
            if !state.jobs.isEmpty {
                SectionHeader(title: "En marcha")
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 8) {
                        ForEach(state.jobs) { job in
                            let left = max(0, Int(job.finish.timeIntervalSince(context.date).rounded(.up)))
                            HStack {
                                Text("\(job.item.emoji) \(job.count) \(job.item.name.lowercased())")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(left == 0 ? "¡Listo!" : "\(left) s").font(.caption.weight(.bold)).monospacedDigit()
                            }
                        }
                    }
                    .card(padding: 12)
                }
            }
            SectionHeader(title: "Fabricar", subtitle: "Lo fabricado va al almacén y se vende más caro.")
            ForEach(Recipe.all) { recipe in
                let built = state.level(recipe.station) > 0
                let most = state.maxCraftable(recipe)
                HStack(spacing: 10) {
                    Text(recipe.inputs.sorted { $0.key.basePrice < $1.key.basePrice }.map { "\($0.value)\($0.key.emoji)" }.joined(separator: " + "))
                        .font(.subheadline.weight(.bold))
                    Image(systemName: "arrow.right").font(.caption.weight(.black)).foregroundStyle(.secondary)
                    Text("\(recipe.output.emoji) \(recipe.output.name)").font(.subheadline.weight(.bold))
                    Spacer(minLength: 6)
                    if built {
                        ForEach([1, 5], id: \.self) { n in
                            Button("×\(n)") { game.craft(recipe, count: n) }
                                .buttonStyle(.glass)
                                .disabled(most < n)
                        }
                        Button("Máx \(most)") { game.craft(recipe, count: most) }
                            .buttonStyle(.glassProminent)
                            .tint(Color(hex: 0xC48A4F))
                            .disabled(most == 0)
                            .accessibilityIdentifier("craft.\(recipe.output.rawValue)")
                    } else {
                        Text("Necesita \(recipe.station.name.lowercased())").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .font(.caption.weight(.bold))
                .card(padding: 12)
            }
            SectionHeader(title: "Edificios")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
                ForEach(Building.allCases) { building in
                    BuildingCard(game: game, building: building)
                }
            }
        }
    }
}

struct BuildingCard: View {
    let game: GameModel
    let building: Building

    var body: some View {
        let state = game.state
        let level = state.level(building)
        let cost = building.cost(from: level)
        HStack(alignment: .top, spacing: 12) {
            IconBadge(systemImage: building.symbol, tint: level > 0 ? Palette.accent : .gray, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(building.name).font(.system(.headline, design: .rounded, weight: .bold))
                    if level > 0 { Text("Nv \(level)").font(.caption.weight(.heavy)).foregroundStyle(Palette.accent.ink) }
                }
                Text(building.summary).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if let cost {
                    CostView(cost: cost, state: state)
                    Button(level == 0 ? "Construir" : "Mejorar a nv \(level + 1)") { game.build(building) }
                        .buttonStyle(.glassProminent)
                        .tint(Palette.accent)
                        .disabled(!state.canPay(cost))
                        .font(.caption.weight(.bold))
                        .accessibilityIdentifier("build.\(building.rawValue)")
                } else {
                    Label("Nivel máximo", systemImage: "checkmark.seal.fill").font(.caption.weight(.bold)).foregroundStyle(Palette.accent.ink)
                }
            }
        }
        .card(padding: 12)
    }
}

// MARK: - Gear

struct UpgradesPanel: View {
    let game: GameModel

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 10)], spacing: 10) {
            ForEach(Gear.allCases) { gear in
                let state = game.state
                let level = state.level(gear)
                let cost = gear.cost(from: level)
                HStack(alignment: .top, spacing: 12) {
                    IconBadge(systemImage: gear.symbol, tint: Palette.sky, size: 42)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 4) {
                            Text(gear.name).font(.system(.headline, design: .rounded, weight: .bold))
                            Spacer()
                            ForEach(1...gear.maxLevel, id: \.self) { i in
                                Circle().fill(i <= level ? AnyShapeStyle(Palette.sky.gradient) : AnyShapeStyle(.quaternary)).frame(width: 7, height: 7)
                            }
                        }
                        Text(level < gear.maxLevel ? "\(gear.effect(at: level)) → \(gear.effect(at: level + 1))" : gear.effect(at: level))
                            .font(.caption).foregroundStyle(.secondary)
                        if let cost {
                            CostView(cost: cost, state: state)
                            Button("Mejorar") { game.upgrade(gear) }
                                .buttonStyle(.glassProminent)
                                .tint(Palette.sky)
                                .disabled(!state.canPay(cost))
                                .font(.caption.weight(.bold))
                                .accessibilityIdentifier("upgrade.\(gear.rawValue)")
                        }
                    }
                }
                .card(tint: Palette.sky, padding: 12)
            }
        }
    }
}

// MARK: - Notice board

struct BoardPanel: View {
    let game: GameModel

    var body: some View {
        let state = game.state
        VStack(alignment: .leading, spacing: 12) {
            if game.dailyRewardAvailable {
                HStack {
                    IconBadge(systemImage: "gift.fill", tint: Palette.gold, size: 40)
                    Text("Tu regalo de hoy te espera").font(.headline)
                    Spacer()
                    Button("Abrir") { game.claimDailyReward() }.buttonStyle(.glassProminent).tint(Palette.gold)
                }
                .card(tint: Palette.gold, padding: 12)
            }
            ForEach(Array(game.requests.enumerated()), id: \.element.id) { index, request in
                let have = state.storage[request.item, default: 0]
                let done = state.completedRequests.contains(request.id)
                HStack(spacing: 12) {
                    Text(request.item.emoji).font(.largeTitle)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(request.neighbour) necesita \(request.amount) \(request.item.name.lowercased())")
                            .font(.system(.headline, design: .rounded, weight: .bold))
                        Meter(fraction: done ? 1 : Double(have) / Double(request.amount), colors: [Palette.secondary.opacity(0.7), Palette.secondary])
                            .frame(maxWidth: 220)
                        Text(done ? "Entregado" : "Tienes \(min(have, request.amount))/\(request.amount) · paga \(request.reward) 🪙")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if done {
                        Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Palette.accent)
                    } else {
                        Button("Entregar") { game.fulfil(request) }
                            .buttonStyle(.glassProminent)
                            .tint(Palette.secondary)
                            .disabled(have < request.amount)
                            .accessibilityIdentifier("request.\(index)")
                    }
                }
                .card(padding: 12)
            }
            Text("Mañana habrá encargos nuevos.").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Bridge

struct BridgePanel: View {
    let game: GameModel
    let id: Int

    var body: some View {
        let site = WorldMap.bridges[id]
        let state = game.state
        VStack(alignment: .leading, spacing: 14) {
            if site.opens.comingSoon {
                EmptyState(systemImage: "cloud.fog.fill", title: "La Cantera sigue en la Niebla",
                           message: state.counters.bossesDefeated.contains(.boss)
                               ? "Has vencido al Gran Lobo. Este puente abrirá en la próxima actualización."
                               : "Primero vence al Gran Lobo de Humo, que guarda este río.")
            } else {
                HStack(alignment: .center, spacing: 16) {
                    ProgressRing(fraction: state.bridgeFraction(id), tint: Palette.gold, size: 86)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Lleva madera, piedra y monedas. Puedes aportar poco a poco: no se pierde nada.")
                            .font(.subheadline).foregroundStyle(.secondary)
                        ForEach(site.cost.items.sorted { $0.key.basePrice < $1.key.basePrice }, id: \.key) { item, needed in
                            let paid = state.bridgeProgress[id, default: [:]][item, default: 0]
                            row("\(item.emoji) \(item.name)", paid: paid, needed: needed, stored: state.storage[item, default: 0])
                        }
                        row("🪙 Monedas", paid: state.bridgeCoins[id, default: 0], needed: site.cost.coins, stored: state.coins)
                    }
                }
                .card(tint: Palette.gold)
                PrimaryButton(title: "Aportar lo que tengo", systemImage: "hammer.fill") { game.contribute(toBridge: id) }
                    .accessibilityIdentifier("bridge.contribute")
            }
        }
    }

    private func row(_ title: String, paid: Int, needed: Int, stored: Int) -> some View {
        HStack {
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            Text("\(paid)/\(needed)").font(.subheadline.weight(.bold)).monospacedDigit()
                .foregroundStyle(paid >= needed ? AnyShapeStyle(Palette.accent.ink) : AnyShapeStyle(HierarchicalShapeStyle.primary))
            Text("(tienes \(stored))").font(.caption).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Journal

struct JournalPanel: View {
    let game: GameModel
    @State private var tab = 0

    var body: some View {
        let state = game.state
        VStack(alignment: .leading, spacing: 12) {
            Picker("Sección", selection: $tab) {
                Text("Misiones").tag(0)
                Text("Logros · \(state.achievements.count)/\(Achievement.all.count)").tag(1)
            }
            .pickerStyle(.segmented)
            if tab == 0 {
                ForEach(Quests.all) { quest in
                    let done = quest.id < state.questIndex
                    let current = quest.id == state.questIndex
                    HStack(spacing: 12) {
                        Image(systemName: done ? "checkmark.circle.fill" : current ? "flag.checkered.circle.fill" : "lock.circle.fill")
                            .font(.title2)
                            .foregroundStyle(done ? Palette.accent : current ? Palette.gold : .secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(quest.title).font(.system(.headline, design: .rounded, weight: .bold))
                            if current {
                                Text(quest.hint).font(.caption).foregroundStyle(.secondary)
                                Meter(fraction: state.progress(quest.goal), colors: [Palette.accentSoft, Palette.accent]).frame(maxWidth: 260)
                            }
                        }
                        Spacer()
                        Text("+\(quest.reward) 🪙").font(.caption.weight(.heavy)).foregroundStyle(done ? .secondary : .primary)
                    }
                    .opacity(done || current ? 1 : 0.55)
                    .card(tint: current ? Palette.gold : nil, padding: 12)
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(Achievement.all) { medal in
                        let got = state.achievements.contains(medal.id)
                        VStack(spacing: 6) {
                            IconBadge(systemImage: medal.symbol, tint: got ? Palette.gold : .gray, size: 46)
                            Text(medal.title).font(.system(.subheadline, design: .rounded, weight: .bold))
                            Text(medal.detail).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(got ? 1 : 0.5)
                        .card(tint: got ? Palette.gold : nil, padding: 12)
                    }
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsPanel: View {
    @Environment(AppModel.self) private var app
    let game: GameModel
    @State private var confirmReset = false

    var body: some View {
        @Bindable var app = app
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Apariencia", subtitle: "Los paneles y botones; el valle tiene su propio día y noche.")
                AppearancePicker(selection: $app.appearance)
            }
            .card()
            VStack(alignment: .leading, spacing: 8) {
                GlassRow(title: "Vibración", systemImage: "iphone.radiowaves.left.and.right") {
                    Toggle("Vibración", isOn: $app.hapticsOn).labelsHidden().accessibilityIdentifier("hapticsToggle")
                }
            }
            .card()
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Tu partida", subtitle: "Noche \(game.state.night) · \(game.state.counters.enemiesDefeated) criaturas vencidas · \(game.state.achievements.count) logros")
                Button(role: .destructive) { confirmReset = true } label: {
                    Label("Empezar una partida nueva", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .card()
            Text("Bastión · todo se guarda solo en este iPhone, sin cuentas.").font(.footnote).foregroundStyle(.secondary)
        }
        .confirmationDialog("¿Borrar la partida y empezar de cero?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Borrar y empezar", role: .destructive) { game.resetGame() }
        }
    }
}
