import SwiftData
import SwiftUI

/// Home: upcoming trips first, finished ones below.
struct TripsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.startDate) private var trips: [Trip]
    @State private var confirmDelete: Trip?

    private var upcoming: [Trip] { trips.filter { !$0.isOver } }
    private var finished: [Trip] { trips.filter(\.isOver).reversed() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if trips.isEmpty {
                        emptyState
                    } else {
                        if !upcoming.isEmpty {
                            section("Próximos viajes", trips: upcoming)
                        }
                        if !finished.isEmpty {
                            section("Ya viajaste", trips: finished)
                        }
                        tipCard
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 24)
                .animation(.smooth, value: trips.map(\.id))
            }
            .screenBackground()
            .navigationTitle("Mochila")
            .navigationDestination(for: UUID.self) { id in
                if let trip = trips.first(where: { $0.id == id }) {
                    TripView(trip: trip)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Nuevo viaje", systemImage: "plus") { model.startNewTrip() }
                        .accessibilityIdentifier("newTripButton")
                }
            }
            .confirmationDialog("¿Borrar «\(confirmDelete?.name ?? "")»?", isPresented: Binding(
                get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }
            ), titleVisibility: .visible) {
                Button("Borrar viaje y su lista", role: .destructive) {
                    if let trip = confirmDelete {
                        withAnimation(.smooth) { context.delete(trip) }
                        try? context.save()
                    }
                    confirmDelete = nil
                }
            }
        }
    }

    private func section(_ title: String, trips: [Trip]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .padding(.top, 4)
            ForEach(trips) { trip in
                NavigationLink(value: trip.id) {
                    TripCard(trip: trip)
                }
                .buttonStyle(PressableStyle())
                .accessibilityIdentifier("trip.\(trip.name)")
                .contextMenu {
                    Button("Duplicar", systemImage: "plus.square.on.square") {
                        withAnimation(.smooth) { _ = TripFactory.duplicate(trip, in: context) }
                    }
                    Button("Borrar", systemImage: "trash", role: .destructive) { confirmDelete = trip }
                }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "suitcase.rolling.fill")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(LinearGradient(colors: Palette.brand, startPoint: .top, endPoint: .bottom))
                .padding(.top, 40)
                .symbolEffect(.breathe)
            Text("¿A dónde te vas?")
                .font(.system(.title, design: .rounded, weight: .heavy))
            Text("Dime el tipo de viaje y los días, y te preparo la lista para no olvidar nada.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Preparar mi mochila", systemImage: "plus") { model.startNewTrip() }
                .accessibilityIdentifier("startFirstTrip")
            tipCard
        }
        .frame(maxWidth: .infinity)
    }

    private var tipCard: some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text("Consejo del día").font(.caption.weight(.heavy)).foregroundStyle(Palette.secondary)
                Text(TravelTips.tip()).font(.subheadline)
            }
        } icon: {
            Image(systemName: "lightbulb.max.fill").foregroundStyle(Palette.secondary)
        }
        .card(tint: Palette.secondary)
    }
}

struct TripCard: View {
    let trip: Trip

    var body: some View {
        let progress = trip.progress
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                TypeBadge(type: trip.type)
                VStack(alignment: .leading, spacing: 3) {
                    Text(trip.name)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(trip.type.title) · \(trip.shortDateText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(trip.countdown)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular.tint(trip.type.tint.opacity(0.25)), in: .capsule)
            }
            HStack(spacing: 10) {
                ProgressBar(progress: progress, tint: trip.type.tint)
                Text(progress.isComplete ? "¡Lista!" : progress.text)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(progress.isComplete ? trip.type.tint : .secondary)
                    .frame(minWidth: 56, alignment: .trailing)
            }
        }
        .card(tint: trip.type.tint)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
