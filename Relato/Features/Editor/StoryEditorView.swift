import SwiftData
import SwiftUI

enum PrompterMode: String, Identifiable {
    case rehearse
    case record
    var id: String { rawValue }
}

struct StoryEditorView: View {
    @Bindable var story: Story

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrefKey.wordsPerMinute) private var wordsPerMinute = PrefDefault.wordsPerMinute

    @FocusState private var focusedBeat: UUID?
    @State private var showingParts = false
    @State private var prompterMode: PrompterMode?
    @State private var beatPendingDeletion: Beat?
    @State private var reviewedTake: Take?
    @State private var showingDeleteStory = false

    var body: some View {
        let segments = story.segments
        let total = ScriptMetrics.spokenSeconds(segments, wordsPerMinute: wordsPerMinute)
        let hasScript = ScriptMetrics.wordCount(segments) > 0
        let beats = story.orderedBeats

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                DurationCard(story: story, segments: segments, total: total, wordsPerMinute: wordsPerMinute)

                if beats.contains(where: { $0.kind == .hook }) {
                    HookCoachCard(report: HookAnalyzer.analyze(story.hookText, wordsPerMinute: wordsPerMinute))
                }

                SectionTitle(title: "Guion", trailing: "\(beats.count) bloques")
                    .padding(.top, 4)

                ForEach(Array(beats.enumerated()), id: \.element.id) { index, beat in
                    BeatEditorCard(
                        beat: beat,
                        position: index,
                        count: beats.count,
                        wordsPerMinute: wordsPerMinute,
                        focusedBeat: $focusedBeat,
                        onEdit: { story.touch() },
                        onMove: { delta in
                            withAnimation(.smooth(duration: 0.3)) { story.move(beat, by: delta) }
                            Haptics.tap()
                        },
                        onDelete: {
                            if ScriptMetrics.wordCount(beat.text) > 0 {
                                beatPendingDeletion = beat
                            } else {
                                withAnimation(.smooth) { StoryActions.delete(beat, from: story, in: context) }
                            }
                        }
                    )
                    .transition(.asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
                }

                addBeatMenu

                if !(story.takes ?? []).isEmpty {
                    TakesStrip(takes: story.orderedTakes) { reviewedTake = $0 }
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AuroraBackground(intensity: 0.6) }
        .navigationBarTitleDisplayMode(.inline)
        // The editor owns the bottom edge (Ensayar / Grabar), so the tab bar steps aside.
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom) {
            if focusedBeat == nil {
                EditorActionBar(
                    isEnabled: hasScript,
                    onParts: { showingParts = true },
                    onRehearse: { prompterMode = .rehearse },
                    onRecord: { prompterMode = .record }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.25), value: focusedBeat == nil)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: ScriptExporter.plainText(title: story.displayTitle, segments: segments, wordsPerMinute: wordsPerMinute),
                    subject: Text(story.displayTitle)
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Compartir guion")
                .disabled(!hasScript)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        story.isPinned.toggle()
                    } label: {
                        Label(story.isPinned ? "Desfijar" : "Fijar arriba", systemImage: story.isPinned ? "pin.slash" : "pin")
                    }
                    Button {
                        StoryActions.duplicate(story, in: context)
                        Haptics.success()
                    } label: {
                        Label("Duplicar", systemImage: "plus.square.on.square")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showingDeleteStory = true
                    } label: {
                        Label("Eliminar historia", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Más opciones")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") { focusedBeat = nil }
                    .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showingParts) {
            PartsView(story: story)
        }
        .sheet(item: $reviewedTake) { take in
            TakeReviewView(take: take, isFreshRecording: false)
        }
        .fullScreenCover(item: $prompterMode) { mode in
            PrompterView(story: story, mode: mode)
        }
        .confirmationDialog("¿Eliminar este bloque?", isPresented: Binding(
            get: { beatPendingDeletion != nil },
            set: { if !$0 { beatPendingDeletion = nil } }
        ), titleVisibility: .visible) {
            Button("Eliminar bloque", role: .destructive) {
                if let beat = beatPendingDeletion {
                    withAnimation(.smooth) { StoryActions.delete(beat, from: story, in: context) }
                    Haptics.warning()
                }
                beatPendingDeletion = nil
            }
        } message: {
            Text("Se perderá el texto que has escrito en él.")
        }
        .confirmationDialog("¿Eliminar «\(story.displayTitle)»?", isPresented: $showingDeleteStory, titleVisibility: .visible) {
            Button("Eliminar historia y tomas", role: .destructive) {
                dismiss()
                // Delete after the pop so the editor never renders a deleted model.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    StoryActions.delete(story, in: context)
                }
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Título de la historia", text: $story.title, axis: .vertical)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .lineLimit(1...3)
                .submitLabel(.done)
                .onChange(of: story.title) { story.touch() }
                .accessibilityIdentifier("editor.title")

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Menu {
                        Picker("Género", selection: $story.genre) {
                            ForEach(StoryGenre.allCases) { genre in
                                Label(genre.title, systemImage: genre.symbol).tag(genre)
                            }
                        }
                    } label: {
                        Chip(title: story.genre.title, symbol: story.genre.symbol)
                    }

                    Menu {
                        Picker("Duración", selection: $story.targetSeconds) {
                            ForEach(TargetDuration.presets, id: \.self) { seconds in
                                Text(TargetDuration.label(seconds)).tag(seconds)
                            }
                        }
                    } label: {
                        Chip(title: TargetDuration.label(story.targetSeconds), symbol: "timer")
                    }

                    Menu {
                        Picker("Estado", selection: $story.status) {
                            ForEach(StoryStatus.allCases) { status in
                                Label(status.title, systemImage: status.symbol).tag(status)
                            }
                        }
                    } label: {
                        Chip(title: story.status.title, symbol: story.status.symbol)
                    }
                }
                .padding(.vertical, 2)
                .buttonStyle(.plain)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    private var addBeatMenu: some View {
        Menu {
            ForEach(BeatKind.allCases) { kind in
                Button {
                    let beat = withAnimation(.smooth) { story.appendBeat(kind) }
                    Haptics.tap()
                    focusedBeat = beat.id
                } label: {
                    Label(kind.title, systemImage: kind.symbol)
                }
            }
        } label: {
            Label("Añadir bloque", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("editor.addBeat")
    }
}

// MARK: - Duration

private struct DurationCard: View {
    let story: Story
    let segments: [ScriptSegment]
    let total: Double
    let wordsPerMinute: Double

    var body: some View {
        let target = Double(story.targetSeconds)
        let delta = total - target
        let words = ScriptMetrics.wordCount(segments)
        let allWritten = !segments.isEmpty && segments.allSatisfy { ScriptMetrics.wordCount($0.text) > 0 }

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text(ScriptMetrics.clock(total))
                    .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText(value: total))
                    .animation(.snappy, value: Int(total.rounded()))
                Text("/ \(ScriptMetrics.clock(target))")
                    .font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(status(delta: delta, total: total))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(delta > 2 ? Palette.crimson : (total == 0 ? Color.secondary : Palette.mint))
                    Text("\(words) palabras · \(Int(wordsPerMinute)) ppm")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TimingBar(
                slices: segments.map { .init(id: $0.id, seconds: ScriptMetrics.spokenSeconds($0.text, wordsPerMinute: wordsPerMinute), tint: $0.kind.tint) },
                targetSeconds: target
            )

            if story.status == .draft, allWritten, delta <= 2 {
                Button {
                    withAnimation(.smooth) { story.status = .ready }
                    Haptics.success()
                } label: {
                    Label("Marcar como lista para grabar", systemImage: "checkmark.seal.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .tint(Palette.mint)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .surfaceCard()
        .accessibilityElement(children: .contain)
    }

    private func status(delta: Double, total: Double) -> String {
        if total == 0 { return "Empieza a escribir" }
        if delta > 2 { return "Te sobran \(ScriptMetrics.shortDuration(delta))" }
        if delta < -2 { return "Margen de \(ScriptMetrics.shortDuration(-delta))" }
        return "Duración perfecta"
    }
}

// MARK: - Hook coach

private struct HookCoachCard: View {
    let report: HookReport
    @State private var expanded = true

    private var tint: Color {
        switch report.grade {
        case .empty: Palette.slate
        case .weak: Palette.crimson
        case .decent: Palette.amber
        case .strong: Palette.mint
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                withAnimation(.smooth(duration: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 14) {
                    ScoreRing(score: report.score, tint: tint)
                        .frame(width: 54, height: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Coach de gancho")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(report.grade.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(tint)
                            .contentTransition(.interpolate)
                        if report.seconds > 0 {
                            Text("Se dice en \(ScriptMetrics.shortDuration(report.seconds))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(expanded ? 0 : -90))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Coach de gancho: \(report.grade.title), \(report.score) puntos")
            .accessibilityHint(expanded ? "Oculta los consejos" : "Muestra los consejos")

            if expanded {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(report.insights) { insight in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: insight.isPositive ? "checkmark.circle.fill" : "arrow.up.forward.circle.fill")
                                .foregroundStyle(insight.isPositive ? Palette.mint : Palette.amber)
                                .font(.subheadline)
                            Text(insight.message)
                                .font(.subheadline)
                                .foregroundStyle(.primary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .surfaceCard()
        .animation(.smooth(duration: 0.3), value: report.insights.map(\.id))
    }
}

// MARK: - Action bar

private struct EditorActionBar: View {
    let isEnabled: Bool
    let onParts: () -> Void
    let onRehearse: () -> Void
    let onRecord: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                Button(action: onParts) {
                    Label("Partes", systemImage: "scissors")
                        .labelStyle(.iconOnly)
                        .font(.title3.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Dividir en partes")
                .accessibilityIdentifier("editor.parts")

                Button(action: onRehearse) {
                    Label("Ensayar", systemImage: "text.viewfinder")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("editor.rehearse")

                Button(action: onRecord) {
                    Label("Grabar", systemImage: "record.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.record)
                .accessibilityIdentifier("editor.record")
            }
        }
        .disabled(!isEnabled)
        .padding(.horizontal, Metrics.gutter)
        .padding(.bottom, 8)
    }
}
