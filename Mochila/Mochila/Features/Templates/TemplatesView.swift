import SwiftData
import SwiftUI

/// Ready-made lists by kind of trip, plus the lists the user saved.
struct TemplatesView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedTemplate.createdAt, order: .reverse) private var saved: [SavedTemplate]
    @State private var startFrom: SavedTemplate?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Tus listas", subtitle: saved.isEmpty
                                      ? "Desde un viaje, toca ⋯ → «Guardar como plantilla» y aparecerá aquí."
                                      : "Toca una para empezar un viaje con ella.")
                        ForEach(saved) { template in
                            Button {
                                startFrom = template
                            } label: {
                                savedRow(template)
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityIdentifier("template.saved.\(template.name)")
                            .contextMenu {
                                Button("Borrar plantilla", systemImage: "trash", role: .destructive) {
                                    withAnimation(.smooth) { context.delete(template) }
                                    try? context.save()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Listas de Mochila", subtitle: "Se adaptan a los días y a tus planes.")
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(TripType.allCases) { type in
                                Button {
                                    model.startNewTrip(type)
                                } label: {
                                    typeTile(type)
                                }
                                .buttonStyle(PressableStyle())
                                .accessibilityIdentifier("template.type.\(type.rawValue)")
                            }
                        }
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 24)
            }
            .screenBackground(glow: Palette.secondary)
            .navigationTitle("Plantillas")
            .sheet(item: $startFrom) { template in
                NewTripView(template: template)
            }
        }
    }

    private func savedRow(_ template: SavedTemplate) -> some View {
        HStack(spacing: 12) {
            TypeBadge(type: template.type, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name).font(.headline).foregroundStyle(.primary)
                Text("\(template.entries.filter { !$0.isTask }.count) cosas · \(template.type.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
        }
        .card(tint: template.type.tint)
        .contentShape(.rect)
    }

    private func typeTile(_ type: TripType) -> some View {
        let sample = PackingGenerator.items(for: type, options: TripOptions(days: 3, climate: type.suggestedClimate))
        return VStack(alignment: .leading, spacing: 10) {
            TypeBadge(type: type, size: 42)
            Spacer(minLength: 0)
            Text(type.title)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
            Text("\(sample.filter { !$0.isTask }.count) cosas para 3 días")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .card(tint: type.tint)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
