import SwiftUI
import UIKit

/// Splits a long story into a numbered series and checks every cut for a cliffhanger.
struct PartsView: View {
    let story: Story

    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrefKey.wordsPerMinute) private var wordsPerMinute = PrefDefault.wordsPerMinute
    @AppStorage(PrefKey.partLength) private var partLength = PrefDefault.partLength
    @State private var copiedPart: Int?

    private let lengths = [30, 60, 90, 180]

    var body: some View {
        let parts = PartSplitter.split(story.segments, maxSeconds: Double(partLength), wordsPerMinute: wordsPerMinute)
        let cuts = parts.filter { $0.ending != .finale }
        let strongCuts = cuts.filter { $0.ending == .cliffhanger }.count

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        SectionTitle(title: "Duración máxima por parte")
                        Picker("Duración por parte", selection: $partLength) {
                            ForEach(lengths, id: \.self) { Text(TargetDuration.label($0)).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    summary(parts: parts, cuts: cuts.count, strongCuts: strongCuts)

                    if parts.isEmpty {
                        ContentUnavailableView(
                            "Aún no hay guion",
                            systemImage: "scissors",
                            description: Text("Escribe tu historia y aquí verás cómo se divide en partes.")
                        )
                    } else {
                        ForEach(parts) { part in
                            PartCard(
                                part: part,
                                total: parts.count,
                                maxSeconds: Double(partLength),
                                shareText: ScriptExporter.partText(title: story.displayTitle, part: part, totalParts: parts.count),
                                isCopied: copiedPart == part.number,
                                onCopy: { copy(part, total: parts.count) }
                            )
                        }
                    }
                }
                .padding(Metrics.gutter)
                .animation(.smooth(duration: 0.3), value: partLength)
            }
            .background { AuroraBackground(intensity: 0.6) }
            .navigationTitle("Dividir en partes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func summary(parts: [StoryPart], cuts: Int, strongCuts: Int) -> some View {
        HStack(spacing: 10) {
            StatTile(value: "\(parts.count)", label: parts.count == 1 ? "Parte" : "Partes", symbol: "square.stack.3d.up.fill", tint: Palette.violet)
            StatTile(
                value: cuts == 0 ? "—" : "\(strongCuts)/\(cuts)",
                label: "Cortes con gancho",
                symbol: "arrow.turn.down.right",
                tint: cuts > 0 && strongCuts == cuts ? Palette.mint : Palette.amber
            )
        }
    }

    private func copy(_ part: StoryPart, total: Int) {
        UIPasteboard.general.string = ScriptExporter.partText(title: story.displayTitle, part: part, totalParts: total)
        Haptics.success()
        withAnimation(.snappy) { copiedPart = part.number }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) { if copiedPart == part.number { copiedPart = nil } }
        }
    }
}

private struct PartCard: View {
    let part: StoryPart
    let total: Int
    let maxSeconds: Double
    let shareText: String
    let isCopied: Bool
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Parte \(part.number)")
                    .font(.system(.title3, design: .serif, weight: .bold))
                Text("de \(total)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(ScriptMetrics.clock(part.seconds))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(part.exceedsLimit ? Palette.crimson : .secondary)
            }

            HStack(spacing: 4) {
                ForEach(part.kinds) { kind in
                    Label(kind.title, systemImage: kind.symbol)
                        .labelStyle(.iconOnly)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(kind.tint))
                }
            }
            .accessibilityElement()
            .accessibilityLabel("Bloques: " + part.kinds.map(\.title).joined(separator: ", "))

            VStack(alignment: .leading, spacing: 8) {
                quote(part.firstLine, label: "Empieza")
                if part.sentences.count > 1 {
                    quote(part.lastLine, label: "Termina")
                }
            }

            endingBadge

            if part.exceedsLimit {
                Label("Hay una frase más larga que \(TargetDuration.label(Int(maxSeconds))). Divídela en dos.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(Palette.crimson)
            }

            HStack(spacing: 10) {
                Button(action: onCopy) {
                    Label(isCopied ? "Copiado" : "Copiar", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                ShareLink(item: shareText) {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .font(.subheadline.weight(.semibold))
        }
        .surfaceCard()
    }

    private func quote(_ text: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(3)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var endingBadge: some View {
        switch part.ending {
        case .finale:
            Label("Final de la serie", systemImage: "flag.checkered")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.sky)
        case .cliffhanger:
            Label("Corte con cliffhanger: querrán ver la parte \(part.number + 1)", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.mint)
        case .flat:
            Label("Este corte no deja tensión. Termina con una pregunta o una revelación a medias.", systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.amber)
        }
    }
}
