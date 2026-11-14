import SwiftUI

struct SavedView: View {
    @Environment(AppState.self) private var state
    @State private var detail: Plan?

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()
                if state.savedPlans.isEmpty {
                    ContentUnavailableView {
                        Label("Aún no hay planes guardados", systemImage: "bookmark")
                    } description: {
                        Text("En Descubrir, desliza una carta a la derecha o pulsa el marcador para guardarla aquí.")
                    }
                } else {
                    List {
                        ForEach(state.savedPlans) { plan in
                            Button { detail = plan } label: { row(plan) }
                                .buttonStyle(.plain)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets(top: 6, leading: Metrics.gutter, bottom: 6, trailing: Metrics.gutter))
                                .accessibilityIdentifier("saved.\(plan.id)")
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { state.savedPlans[$0].id }
                            withAnimation { state.unsave(ids: ids) }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Guardados")
            .sheet(item: $detail) { PlanDetailView(plan: $0) }
        }
    }

    private func row(_ plan: Plan) -> some View {
        HStack(spacing: 14) {
            Text(plan.emoji)
                .font(.system(size: 34))
                .frame(width: 60, height: 60)
                .background(LinearGradient(colors: plan.colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.title).font(.headline).lineLimit(2)
                Text("\(plan.budget.label) · \(plan.duration.label) · \(plan.place.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if state.activePlanID == plan.id {
                Image(systemName: "heart.fill").foregroundStyle(Palette.rose)
            }
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .contentShape(.rect)
    }
}
