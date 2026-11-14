import SwiftUI

/// Surprise mode: one partner picks a plan in secret; the other only gets clues until the reveal.
struct SurpriseView: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var candidates: [Plan] = []
    @State private var index = 0
    @State private var handOver = false
    @State private var confirmReveal = false

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground(colors: [Palette.gold, Palette.rose])
                Group {
                    if let surprise = state.surprise, let plan = state.plan(id: surprise.planID) {
                        if handOver {
                            handOverView
                        } else {
                            clues(surprise, plan: plan)
                        }
                    } else {
                        picker
                    }
                }
                .padding(Metrics.gutter)
            }
            .navigationTitle("Plan sorpresa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
            .confirmationDialog("¿Revelar el plan?", isPresented: $confirmReveal, titleVisibility: .visible) {
                Button("Sí, revelar") { reveal() }
            } message: {
                Text("Se acabó el misterio: veréis cuál es.")
            }
        }
        .onAppear {
            if candidates.isEmpty { candidates = state.randomPlans(30) }
        }
    }

    // MARK: Step 1 — pick in secret

    private var picker: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                Text("🎁").font(.system(size: 56))
                Text("Elige un plan a escondidas")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Que no mire tu pareja. Tú eliges; a la otra persona solo le llegarán pistas.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if candidates.isEmpty {
                ContentUnavailableView("Sin planes", systemImage: "gift", description: Text("Quita algún filtro en Descubrir."))
            } else {
                let plan = candidates[index % candidates.count]
                PlanCardView(plan: plan)
                    .frame(maxHeight: 380)
                    .id(plan.id)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
                Spacer(minLength: 0)
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(duration: 0.35)) { index += 1 }
                            Haptics.tap()
                        } label: {
                            Label("Otro", systemImage: "arrow.right").frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.glass)
                        .accessibilityIdentifier("surprise.next")
                        Button {
                            state.surprise = Surprise(planID: plan.id)
                            Haptics.success()
                            withAnimation { handOver = true }
                        } label: {
                            Label("Este será", systemImage: "gift.fill").frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("surprise.pick")
                    }
                    .font(.headline)
                }
            }
        }
    }

    private var handOverView: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("🤫").font(.system(size: 72))
            Text("¡Sorpresa preparada!")
                .font(.system(.title, design: .rounded, weight: .bold))
            Text("Ahora pásale el móvil a tu pareja: podrá ver las pistas, pero no el plan.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                withAnimation { handOver = false }
            } label: {
                Label("Ver las pistas", systemImage: "eye.fill").frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .font(.headline)
            .accessibilityIdentifier("surprise.clues")
        }
    }

    // MARK: Step 2 — clues and reveal

    private func clues(_ surprise: Surprise, plan: Plan) -> some View {
        let hints = SurpriseHints.hints(for: plan)
        return VStack(spacing: 18) {
            if surprise.revealed {
                Text("¡Este es el plan!")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                PlanCardView(plan: plan)
                    .frame(maxHeight: 380)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                    .accessibilityIdentifier("surprise.plan")
                Spacer(minLength: 0)
                Button {
                    state.choose(plan)
                    state.surprise = nil
                    Haptics.success()
                    dismiss()
                } label: {
                    Label("¡Vamos!", systemImage: "heart.fill").frame(maxWidth: .infinity).padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .font(.headline)
                .accessibilityIdentifier("surprise.go")
            } else {
                VStack(spacing: 6) {
                    Text("🎁").font(.system(size: 56))
                    Text("Tenéis un plan sorpresa")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                }
                VStack(spacing: 10) {
                    ForEach(Array(hints.prefix(surprise.revealedHints).enumerated()), id: \.offset) { offset, hint in
                        HStack(spacing: 12) {
                            Text("\(offset + 1)")
                                .font(.headline.monospacedDigit())
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(Palette.gold.opacity(0.3)))
                            Text(hint)
                                .font(.body.weight(.medium))
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .accessibilityIdentifier("surprise.hints")
                Spacer(minLength: 0)
                GlassEffectContainer(spacing: 12) {
                    HStack(spacing: 12) {
                        if surprise.revealedHints < hints.count {
                            Button {
                                withAnimation(.spring(duration: 0.4)) { state.surprise?.revealedHints += 1 }
                                Haptics.tap()
                            } label: {
                                Label("Otra pista", systemImage: "lightbulb.fill").frame(maxWidth: .infinity).padding(.vertical, 8)
                            }
                            .buttonStyle(.glass)
                            .accessibilityIdentifier("surprise.hint")
                        }
                        Button {
                            confirmReveal = true
                        } label: {
                            Label("Revelar", systemImage: "sparkles").frame(maxWidth: .infinity).padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("surprise.reveal")
                    }
                    .font(.headline)
                }
                Button("Cancelar la sorpresa", role: .destructive) {
                    withAnimation { state.surprise = nil }
                }
                .font(.footnote)
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.25), value: surprise)
    }

    private func reveal() {
        Haptics.success()
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) { state.surprise?.revealed = true }
    }
}
