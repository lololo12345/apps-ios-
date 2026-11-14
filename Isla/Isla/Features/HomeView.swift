import ActivityKit
import SwiftUI
import UIKit

struct HomeView: View {
    @Binding var showFavorites: Bool
    @Environment(AppModel.self) private var model
    @State private var search = ""
    @State private var editingFavorites = false

    private var filtered: [ToolKind] {
        let text = search.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return ToolKind.allCases }
        return ToolKind.allCases.filter { $0.title.localizedStandardContains(text) || $0.summary.localizedStandardContains(text) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !model.liveActivitiesEnabled && !LaunchOptions.isUITesting {
                    Label("Activa las Actividades en vivo de Isla en Ajustes del iPhone para verlas en la isla.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .padding(14)
                        .glassEffect(.regular.tint(.orange.opacity(0.3)), in: .rect(cornerRadius: 18))
                }

                if !model.sessions.isEmpty {
                    section("En la isla ahora", trailing: model.sessions.count > 1 ? "Quitar todo" : nil, action: { withAnimation { model.endAll() } }) {
                        VStack(spacing: 12) {
                            ForEach(model.sessions) { session in
                                SessionCard(session: session)
                                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                            }
                        }
                    }
                }

                if !model.favorites.isEmpty && search.isEmpty {
                    section("Favoritos", trailing: editingFavorites ? "Listo" : "Editar", action: { editingFavorites.toggle() }) {
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(model.favorites) { favorite in
                                    FavoriteChip(favorite: favorite, editing: editingFavorites)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .scrollIndicators(.hidden)
                    }
                    .id("favorites")
                }

                ForEach(ToolCategory.allCases) { category in
                    let tools = filtered.filter { $0.category == category }
                    if !tools.isEmpty {
                        section(category.title) {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(tools) { kind in
                                    NavigationLink(value: kind) { ToolTile(kind: kind) }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("tool.\(kind.rawValue)")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .animation(.snappy, value: model.sessions.map(\.id))
        }
        .background(Background())
        .navigationTitle("Isla")
        .searchable(text: $search, prompt: "Buscar herramienta")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Ajustes")
            }
        }
        .sheet(isPresented: $showFavorites) { FavoritesSheet() }
    }

    private func section<Content: View>(_ title: String, trailing: String? = nil, action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.title3.weight(.bold))
                Spacer()
                if let trailing, let action {
                    Button(trailing, action: action).font(.subheadline)
                }
            }
            content()
        }
    }
}

struct Background: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [Color(hex: 0xFF9F0A).opacity(0.22), .clear], center: .topLeading, startRadius: 0, endRadius: 500)
            RadialGradient(colors: [Color(hex: 0xBF5AF2).opacity(0.18), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 520)
        }
        .ignoresSafeArea()
    }
}

struct ToolTile: View {
    let kind: ToolKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: kind.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(kind.tint)
                .frame(width: 40, height: 40)
                .background(kind.tint.opacity(0.16), in: .rect(cornerRadius: 12))
            Text(kind.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(kind.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
    }
}

struct FavoriteChip: View {
    let favorite: Favorite
    let editing: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        Button {
            if editing {
                withAnimation { model.removeFavorites([favorite.id]) }
            } else {
                withAnimation { model.start(favorite) }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: editing ? "minus.circle.fill" : favorite.kind.symbol)
                    .foregroundStyle(editing ? .red : favorite.kind.tint)
                Text(favorite.name).font(.subheadline.weight(.semibold)).lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .buttonStyle(.glass)
        .accessibilityIdentifier("favorite.\(favorite.name)")
    }
}

struct FavoritesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(model.favorites) { favorite in
                Button {
                    model.start(favorite)
                    dismiss()
                } label: {
                    Label(favorite.name, systemImage: favorite.kind.symbol)
                }
            }
            .navigationTitle("Favoritos")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}
