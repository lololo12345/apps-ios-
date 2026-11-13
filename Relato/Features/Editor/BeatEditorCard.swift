import SwiftData
import SwiftUI

struct BeatEditorCard: View {
    @Bindable var beat: Beat
    let position: Int
    let count: Int
    let wordsPerMinute: Double
    var focusedBeat: FocusState<UUID?>.Binding
    let onEdit: () -> Void
    let onMove: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        let seconds = ScriptMetrics.spokenSeconds(beat.text, wordsPerMinute: wordsPerMinute)
        let isFocused = focusedBeat.wrappedValue == beat.id

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    Picker("Tipo de bloque", selection: $beat.kind) {
                        ForEach(BeatKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.symbol).tag(kind)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: beat.kind.symbol)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(beat.kind.tint.gradient))
                        Text(beat.kind.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityLabel("Tipo de bloque: \(beat.kind.title)")

                Spacer()

                Text(seconds > 0 ? ScriptMetrics.shortDuration(seconds) : "—")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.surfaceSunken))
                    .accessibilityLabel(seconds > 0 ? "\(Int(seconds.rounded())) segundos" : "Vacío")

                Menu {
                    Button { onMove(-1) } label: { Label("Subir", systemImage: "arrow.up") }
                        .disabled(position == 0)
                    Button { onMove(1) } label: { Label("Bajar", systemImage: "arrow.down") }
                        .disabled(position == count - 1)
                    Divider()
                    Button(role: .destructive, action: onDelete) {
                        Label("Eliminar bloque", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Opciones del bloque")
            }

            TextField(
                "",
                text: $beat.text,
                prompt: Text(beat.placeholder).foregroundStyle(.tertiary),
                axis: .vertical
            )
            .font(.body)
            .lineSpacing(3)
            .lineLimit(2...)
            .focused(focusedBeat, equals: beat.id)
            .onChange(of: beat.text) { onEdit() }
            .accessibilityLabel(beat.kind.title)
            .accessibilityIdentifier("beat.\(position)")
        }
        .padding(16)
        .padding(.leading, 6)
        .background {
            RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                .fill(Palette.surface)
                .overlay(alignment: .leading) {
                    // Narrative-role accent strip.
                    Capsule()
                        .fill(beat.kind.tint.gradient)
                        .frame(width: 4)
                        .padding(.vertical, 18)
                        .padding(.leading, 7)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                        .strokeBorder(isFocused ? beat.kind.tint.opacity(0.6) : Palette.hairline, lineWidth: isFocused ? 1.5 : 1)
                }
                .shadow(color: .black.opacity(isFocused ? 0.08 : 0.04), radius: isFocused ? 16 : 10, y: 6)
        }
        .animation(.smooth(duration: 0.2), value: isFocused)
    }
}

// MARK: - Takes

struct TakesStrip: View {
    let takes: [Take]
    let onSelect: (Take) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(title: "Tomas", trailing: "\(takes.count)")
            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(takes) { take in
                        Button { onSelect(take) } label: {
                            TakeThumbnail(take: take)
                        }
                        .buttonStyle(PressableCardStyle())
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }
}

struct TakeThumbnail: View {
    let take: Take
    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .fill(Palette.surfaceSunken)
                .overlay {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .transition(.opacity)
                    } else {
                        Image(systemName: "video.fill")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 2) {
                Text(ScriptMetrics.clock(take.durationSeconds))
                    .font(.caption.monospacedDigit().weight(.bold))
                Text(take.createdAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.caption2)
                    .opacity(0.85)
            }
            .foregroundStyle(.white)
            .padding(10)

            if take.savedToPhotos {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white, Palette.mint)
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .accessibilityLabel("Guardada en Fotos")
            }
        }
        .frame(width: 112, height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Toma de \(Int(take.durationSeconds.rounded())) segundos")
        .task(id: take.fileName) {
            if let cached = ThumbnailCache.shared.cached(take.fileName) {
                image = cached
                return
            }
            let generated = await ThumbnailCache.shared.thumbnail(for: take.fileName)
            withAnimation(.smooth(duration: 0.25)) { image = generated }
        }
    }
}
