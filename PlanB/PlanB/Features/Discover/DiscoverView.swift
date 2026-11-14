import SwiftUI

struct DiscoverView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Live drag of the top card.
    @State private var drag: CGSize = .zero
    /// The card currently flying off screen (kept off screen while it is removed).
    @State private var flying: (id: String, offset: CGSize)?
    @State private var detail: Plan?
    @State private var donePlan: Plan?
    @State private var showRoulette = false
    @State private var showSurprise = false
    @State private var confetti = 0
    @State private var toast: String?

    private let swipeThreshold: CGFloat = 110

    var body: some View {
        @Bindable var state = state
        NavigationStack {
            ZStack {
                WarmBackground(colors: state.section == .intimate ? [Palette.ember, Palette.plum] : Palette.brand)
                    .animation(.smooth(duration: 0.5), value: state.section)
                VStack(spacing: 14) {
                    header
                    if let active = state.activePlan {
                        activeBanner(active)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    if state.intimateUnlocked {
                        Picker("Apartado", selection: $state.section) {
                            ForEach(DeckSection.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, Metrics.gutter)
                        .accessibilityIdentifier("discover.section")
                    }
                    FilterBar()
                    cardStack
                        .padding(.horizontal, Metrics.gutter)
                    actions
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.bottom, 8)
                }
                ConfettiBurst(trigger: confetti)
                if let toast {
                    Text(toast)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 4)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityIdentifier("discover.toast")
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.2), value: state.activePlanID)
            .animation(.smooth(duration: 0.3), value: toast)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSurprise = true
                    } label: {
                        Image(systemName: state.surprise == nil ? "gift" : "gift.fill")
                    }
                    .accessibilityLabel("Plan sorpresa")
                    .accessibilityIdentifier("discover.surprise")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRoulette = true
                    } label: {
                        Image(systemName: "dice.fill")
                    }
                    .accessibilityLabel("Decide por nosotros")
                    .accessibilityIdentifier("discover.roulette")
                }
            }
            .sheet(item: $detail) { plan in
                PlanDetailView(plan: plan, onChoose: { celebrate(plan) })
            }
            .sheet(item: $donePlan) { plan in
                DoneSheet(plan: plan) { celebrate(nil, message: "Guardado en vuestros recuerdos 💞") }
            }
            .sheet(isPresented: $showRoulette) {
                RouletteView { plan in celebrate(plan) }
            }
            .sheet(isPresented: $showSurprise) {
                SurpriseView()
            }
            .onAppear { Haptics.prepare() }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("¿Qué os apetece hoy?")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(state.coupleName) · \(state.matchingPlans.count) planes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.snappy, value: state.matchingPlans.count)
                .accessibilityIdentifier("discover.count")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.gutter)
    }

    private func activeBanner(_ plan: Plan) -> some View {
        HStack(spacing: 12) {
            Text(plan.emoji).font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text("Plan elegido")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
                Text(plan.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button("¡Hecho!") { donePlan = plan }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("active.done")
            Button {
                withAnimation { state.clearActive() }
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Descartar plan elegido")
        }
        .padding(12)
        .glassEffect(.regular.tint(plan.colors.first?.opacity(0.25)), in: .rect(cornerRadius: 22))
        .padding(.horizontal, Metrics.gutter)
        .contentShape(.rect)
        .onTapGesture { detail = plan }
        .accessibilityIdentifier("active.banner")
    }

    // MARK: Cards

    private var cardStack: some View {
        let upcoming = state.deck.upcoming(3)
        return ZStack {
            if upcoming.isEmpty {
                ContentUnavailableView {
                    Label("No hay planes así", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Ningún plan cumple todos los filtros. Prueba a quitar alguno.")
                } actions: {
                    Button("Quitar filtros") { state.filter = PlanFilter() }
                        .buttonStyle(.glassProminent)
                }
            }
            ForEach(Array(upcoming.enumerated()).reversed(), id: \.element.id) { index, plan in
                let isTop = index == 0
                let offset = flying?.id == plan.id ? flying!.offset : (isTop ? drag : .zero)
                PlanCardView(plan: plan)
                    .overlay { if isTop { swipeStamp } }
                    .scaleEffect(1 - CGFloat(index) * 0.05)
                    .offset(y: CGFloat(index) * 14)
                    .offset(offset)
                    .rotationEffect(.degrees(Double(offset.width) / 22), anchor: .bottom)
                    .zIndex(Double(10 - index))
                    .allowsHitTesting(isTop && flying == nil)
                    .gesture(dragGesture(plan), isEnabled: isTop)
                    .onTapGesture { if isTop { detail = plan } }
                    .accessibilityAddTraits(isTop ? .isButton : [])
                    .accessibilityHidden(!isTop)
                    .accessibilityIdentifier(isTop ? "card.top" : "card.\(index)")
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
            }
        }
        .frame(maxHeight: .infinity)
        .animation(.spring(duration: 0.4, bounce: 0.2), value: upcoming.map(\.id))
    }

    /// "GUARDAR" / "PASAR" stamp that fades in while dragging.
    private var swipeStamp: some View {
        let progress = min(1, abs(drag.width) / swipeThreshold)
        let saving = drag.width > 0
        return Text(saving ? "GUARDAR" : "PASAR")
            .font(.system(.title, design: .rounded, weight: .black))
            .foregroundStyle(saving ? Palette.mint : Palette.coral)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(lineWidth: 4).foregroundStyle(saving ? Palette.mint : Palette.coral) }
            .rotationEffect(.degrees(saving ? -12 : 12))
            .opacity(progress)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: saving ? .topLeading : .topTrailing)
            .padding(24)
            .allowsHitTesting(false)
    }

    private func dragGesture(_ plan: Plan) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let crossed = abs(value.translation.width) > swipeThreshold
                if crossed != (abs(drag.width) > swipeThreshold) { Haptics.tick(0.6) }
                drag = value.translation
            }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.width
                if value.translation.width > swipeThreshold || predicted > swipeThreshold * 2.4 {
                    swipe(plan, save: true)
                } else if value.translation.width < -swipeThreshold || predicted < -swipeThreshold * 2.4 {
                    swipe(plan, save: false)
                } else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.35)) { drag = .zero }
                }
            }
    }

    // MARK: Actions

    private var actions: some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    if let plan = state.deck.current { swipe(plan, save: false) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Pasar")
                .accessibilityIdentifier("deck.pass")

                Button {
                    if let plan = state.deck.current { celebrate(plan) }
                } label: {
                    Label("¡Este!", systemImage: "heart.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("deck.choose")

                Button {
                    if let plan = state.deck.current { swipe(plan, save: true) }
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.title2.weight(.bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Guardar")
                .accessibilityIdentifier("deck.save")
            }
        }
        .disabled(state.deck.isEmpty || flying != nil)
    }

    private func swipe(_ plan: Plan, save: Bool) {
        guard flying == nil else { return }
        if save {
            if !state.isSaved(plan) { state.toggleSaved(plan) }
            Haptics.thump()
            show("Guardado 🔖")
        } else {
            Haptics.tap()
        }
        let direction: CGFloat = save ? 1 : -1
        let start = drag
        flying = (plan.id, start)
        drag = .zero
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeIn(duration: 0.22)) {
            flying = (plan.id, CGSize(width: direction * 620, height: start.height + 40))
        }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 220))
            state.nextCard()
            try? await Task.sleep(for: .milliseconds(300))
            flying = nil
        }
    }

    /// "¡Este!": the plan becomes the plan in progress, with confetti.
    private func celebrate(_ plan: Plan?, message: String? = nil) {
        if let plan {
            state.choose(plan)
            show("¡Plan elegido! A disfrutar 🎉")
        } else if let message {
            show(message)
        }
        Haptics.success()
        confetti += 1
    }

    private func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            if toast == message { toast = nil }
        }
    }
}
