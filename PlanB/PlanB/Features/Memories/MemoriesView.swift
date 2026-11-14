import SwiftData
import SwiftUI
import UIKit

struct MemoriesView: View {
    @Query(sort: \Memory.doneAt, order: .reverse) private var memories: [Memory]
    @State private var selected: Memory?

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground(colors: [Palette.rose, Palette.gold])
                if memories.isEmpty {
                    ContentUnavailableView {
                        Label("Vuestro diario está vacío", systemImage: "heart.text.square")
                    } description: {
                        Text("Cuando hagáis un plan, pulsad «¡Hecho!» y aparecerá aquí con su foto y su nota.")
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 18) {
                            stats
                            if let index = MemoryStats.onThisDay(memories.map(\.doneAt), now: .now) {
                                onThisDay(memories[index])
                            }
                            LazyVStack(spacing: 14) {
                                ForEach(memories) { memory in
                                    Button { selected = memory } label: { MemoryCard(memory: memory) }
                                        .buttonStyle(PressableStyle())
                                }
                            }
                        }
                        .padding(Metrics.gutter)
                    }
                }
            }
            .navigationTitle("Recuerdos")
            .sheet(item: $selected) { MemoryDetailView(memory: $0) }
        }
    }

    private var stats: some View {
        let streak = MemoryStats.weeklyStreak(memories.map(\.doneAt), now: .now)
        let average = MemoryStats.averageRating(memories.map(\.rating))
        return GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                statTile("\(memories.count)", memories.count == 1 ? "plan hecho" : "planes hechos", symbol: "checkmark.seal.fill", tint: Palette.mint)
                statTile("\(streak)", streak == 1 ? "semana seguida" : "semanas seguidas", symbol: "flame.fill", tint: Palette.coral)
                statTile(average.map { String(format: "%.1f", $0).replacingOccurrences(of: ".", with: ",") } ?? "—", "de media", symbol: "heart.fill", tint: Palette.rose)
            }
        }
        .accessibilityIdentifier("memories.stats")
    }

    private func statTile(_ value: String, _ label: String, symbol: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }

    private func onThisDay(_ memory: Memory) -> some View {
        let years = max(1, Calendar.current.component(.year, from: .now) - Calendar.current.component(.year, from: memory.doneAt))
        return HStack(spacing: 14) {
            Text(memory.emoji).font(.system(size: 40))
            VStack(alignment: .leading, spacing: 4) {
                Text(years == 1 ? "Hace un año…" : "Hace \(years) años…")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Palette.gold)
                Text("hicisteis «\(memory.title)»")
                    .font(.headline)
                if !memory.note.isEmpty {
                    Text(memory.note).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glassEffect(.regular.tint(Palette.gold.opacity(0.25)), in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("memories.onThisDay")
    }
}

struct MemoryCard: View {
    let memory: Memory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let data = memory.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: memory.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    Text(memory.emoji).font(.system(size: 56))
                }
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(memory.title).font(.headline).lineLimit(1)
                    Spacer()
                    if memory.rating > 0 {
                        Text(String(repeating: "♥︎", count: memory.rating))
                            .font(.caption)
                            .foregroundStyle(Palette.rose)
                    }
                }
                Text(memory.doneAt.formatted(.dateTime.day().month(.wide).year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !memory.note.isEmpty {
                    Text(memory.note).font(.callout).lineLimit(2)
                }
            }
            .padding(14)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

struct MemoryDetailView: View {
    let memory: Memory
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MemoryCard(memory: memory)
                    if let data = memory.photo, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 22))
                    }
                }
                .padding(Metrics.gutter)
            }
            .background(WarmBackground(colors: memory.colors))
            .navigationTitle(memory.emoji)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Borrar", systemImage: "trash", role: .destructive) { confirmDelete = true }
                }
            }
            .confirmationDialog("¿Borrar este recuerdo?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    context.delete(memory)
                    try? context.save()
                    dismiss()
                }
            }
        }
    }
}
