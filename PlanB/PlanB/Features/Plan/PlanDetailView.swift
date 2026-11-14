import SwiftUI

struct PlanDetailView: View {
    let plan: Plan
    var onChoose: (() -> Void)?

    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var showDone = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack {
                        LinearGradient(colors: plan.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                        Text(plan.emoji).font(.system(size: 96))
                    }
                    .frame(height: 200)
                    .clipShape(.rect(cornerRadius: Metrics.radius))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(plan.title)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .accessibilityIdentifier("detail.title")
                        PlanTagsRow(plan: plan)
                        Text(plan.summary)
                            .font(.body)
                    }

                    infoRow("Cuánto cuesta", plan.budget.detail, symbol: "eurosign.circle.fill")
                    infoRow("Cuándo", plan.times.count == 3 ? "Cuando queráis" : TimeOfDay.allCases.filter { plan.times.contains($0) }.map(\.label).joined(separator: " o "), symbol: "calendar")
                    if !plan.needs.isEmpty {
                        infoRow("Qué necesitáis", plan.needs, symbol: "bag.fill")
                    }
                    if !plan.tip.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Para hacerlo especial", systemImage: "sparkles")
                                .font(.headline)
                                .gradientText(plan.colors)
                            Text(plan.tip)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .glassEffect(.regular.tint(plan.colors.first?.opacity(0.2)), in: .rect(cornerRadius: 20))
                    }
                }
                .padding(Metrics.gutter)
            }
            .background(WarmBackground(colors: plan.colors))
            .safeAreaInset(edge: .bottom) { buttons }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
            }
            .sheet(isPresented: $showDone) {
                DoneSheet(plan: plan) { dismiss() }
            }
        }
    }

    private var isActive: Bool { state.activePlanID == plan.id }

    private var buttons: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    state.toggleSaved(plan)
                    Haptics.select()
                } label: {
                    Image(systemName: state.isSaved(plan) ? "bookmark.fill" : "bookmark")
                        .font(.title3.weight(.semibold))
                        .frame(width: 30, height: 30)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel(state.isSaved(plan) ? "Quitar de guardados" : "Guardar")
                .accessibilityIdentifier("detail.save")

                if isActive {
                    Button {
                        showDone = true
                    } label: {
                        Label("¡Lo hemos hecho!", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("detail.done")
                } else {
                    Button {
                        state.choose(plan)
                        Haptics.success()
                        onChoose?()
                        dismiss()
                    } label: {
                        Label("¡Este!", systemImage: "heart.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("detail.choose")
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 8)
        }
    }

    private func infoRow(_ title: String, _ value: String, symbol: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(plan.colors.first ?? Palette.coral)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(value).font(.body)
            }
        }
    }
}
