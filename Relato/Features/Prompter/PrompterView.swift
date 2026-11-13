import SwiftData
import SwiftUI
import UIKit

/// Full-screen teleprompter. In record mode the front camera fills the screen and the script scrolls
/// near the top edge, so your eyes stay close to the lens.
struct PrompterView: View {
    let story: Story

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage(PrefKey.wordsPerMinute) private var wordsPerMinute = PrefDefault.wordsPerMinute
    @AppStorage(PrefKey.prompterFontSize) private var fontSize = PrefDefault.prompterFontSize
    @AppStorage(PrefKey.prompterMirror) private var mirror = false
    @AppStorage(PrefKey.prompterCountdown) private var countdownEnabled = true
    @AppStorage(PrefKey.prompterSpeed) private var speed = PrefDefault.prompterSpeed

    @State private var mode: PrompterMode
    @State private var segments: [ScriptSegment] = []
    @State private var segmentSeconds: [Double] = []
    @State private var segmentOffsets: [Int: CGFloat] = [:]
    @State private var columnHeight: CGFloat = 0
    @State private var engine = PrompterEngine()
    @State private var recorder = RecorderModel()
    @State private var countdownValue: Int?
    @State private var countdownTask: Task<Void, Never>?
    @State private var dragAnchor: (time: Double, offset: Double, wasRunning: Bool)?
    @State private var reviewedTake: Take?
    @State private var showSettings = false

    init(story: Story, mode: PrompterMode) {
        self.story = story
        _mode = State(initialValue: mode)
    }

    private var pacing: PrompterPacing? {
        guard !segments.isEmpty, segmentOffsets.count == segments.count, columnHeight > 0 else { return nil }
        let offsets = (0..<segments.count).map { Double(segmentOffsets[$0] ?? 0) }
        return PrompterPacing(segmentSeconds: segmentSeconds, segmentOffsets: offsets, endOffset: Double(columnHeight))
    }

    var body: some View {
        let pacing = pacing
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.top, 8)

                scriptArea(pacing: pacing)
                    .padding(.top, 10)

                Spacer(minLength: 12)

                if case .unavailable(let message) = recorder.phase, mode == .record {
                    unavailableCard(message)
                        .padding(.horizontal, Metrics.gutter)
                        .padding(.bottom, 16)
                } else if let error = recorder.lastError, mode == .record {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.tint(Palette.crimson.opacity(0.3)), in: .capsule)
                        .padding(.bottom, 10)
                } else if engine.didReachEnd {
                    Label(mode == .record && recorder.isRecording ? "Fin del guion · detén cuando termines" : "Fin del guion", systemImage: "flag.checkered")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.bottom, 10)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                controls
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 10)
            }

            if let countdownValue {
                Text("\(countdownValue)")
                    .font(.system(size: 140, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 20)
                    .contentTransition(.numericText(countsDown: true))
                    .transition(.scale.combined(with: .opacity))
                    .id(countdownValue)
                    .accessibilityLabel("Empieza en \(countdownValue)")
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .animation(.smooth(duration: 0.25), value: engine.didReachEnd)
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.3), value: countdownValue)
        .onAppear(perform: setUp)
        .onDisappear(perform: tearDown)
        .onChange(of: speed) { engine.setSpeed(speed) }
        .onChange(of: scenePhase) { _, phase in handleScenePhase(phase) }
        .onChange(of: recorder.finishedClip) { _, clip in
            if let clip { store(clip) }
        }
        .sheet(item: $reviewedTake) { take in
            TakeReviewView(take: take, isFreshRecording: true)
        }
        .sheet(isPresented: $showSettings) {
            PrompterSettingsSheet(fontSize: $fontSize, speed: $speed, mirror: $mirror, countdown: $countdownEnabled)
                .presentationDetents([.height(360)])
                .presentationBackground(.thinMaterial)
        }
    }

    // MARK: - Layers

    @ViewBuilder
    private var background: some View {
        if mode == .record, recorder.phase == .ready || recorder.phase == .recording || recorder.phase == .finishing {
            CameraPreview(session: recorder.camera.session)
                .ignoresSafeArea()
                .overlay {
                    // Scrim keeps text legible over any background.
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(0.78), location: 0),
                            .init(color: .black.opacity(0.55), location: 0.45),
                            .init(color: .black.opacity(0), location: 0.7),
                            .init(color: .black.opacity(0.35), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
                .transition(.opacity)
        } else {
            ZStack {
                Color.black
                AuroraBackground(intensity: 0.8)
                    .environment(\.colorScheme, .dark)
            }
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .disabled(recorder.isRecording)
            .accessibilityLabel("Cerrar teleprompter")

            Spacer()

            TimelineView(.periodic(from: .now, by: 0.25)) { context in
                hud(at: context.date)
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "textformat.size")
                    .font(.headline)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Ajustes del teleprompter")
        }
    }

    private func hud(at date: Date) -> some View {
        let elapsed = engine.elapsed(at: date)
        let index = pacing?.segmentIndex(at: elapsed) ?? 0
        let kind = segments.indices.contains(index) ? segments[index].kind : .free
        return HStack(spacing: 10) {
            if mode == .record, recorder.isRecording, let start = recorder.recordingStartedAt {
                Circle().fill(Palette.record).frame(width: 9, height: 9)
                    .opacity(Int(date.timeIntervalSince(start) * 2) % 2 == 0 ? 1 : 0.35)
                Text(ScriptMetrics.clock(date.timeIntervalSince(start)))
                    .font(.subheadline.monospacedDigit().weight(.bold))
            } else {
                Image(systemName: kind.symbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(kind.tint)
                Text(kind.title)
                    .font(.subheadline.weight(.semibold))
                Text("\(ScriptMetrics.clock(elapsed / max(engine.speed, 0.1)))/\(ScriptMetrics.clock(engine.totalTime / max(engine.speed, 0.1)))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .glassEffect(.regular, in: .capsule)
        .accessibilityElement(children: .combine)
    }

    private func scriptArea(pacing: PrompterPacing?) -> some View {
        GeometryReader { proxy in
            let readingLine = proxy.size.height * 0.24
            ZStack(alignment: .topLeading) {
                TimelineView(.animation(minimumInterval: nil, paused: !engine.isRunning)) { context in
                    let elapsed = engine.elapsed(at: context.date)
                    let offset = pacing?.offset(at: elapsed) ?? 0
                    let active = pacing?.segmentIndex(at: elapsed) ?? 0
                    PrompterColumn(
                        segments: segments,
                        fontSize: fontSize,
                        activeIndex: active,
                        onMeasure: { index, minY in segmentOffsets[index] = minY },
                        onHeight: { columnHeight = $0 }
                    )
                    .equatable()
                    .frame(width: proxy.size.width - 2 * Metrics.gutter - 18, alignment: .leading)
                    .offset(x: Metrics.gutter + 18, y: readingLine - offset)
                }

                // Reading line marker.
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ember)
                    .offset(x: Metrics.gutter - 4, y: readingLine + fontSize * 0.35)
                    .accessibilityHidden(true)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .scaleEffect(x: mirror ? -1 : 1, y: 1)
            .clipped()
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.1),
                        .init(color: .black, location: 0.78),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard countdownValue == nil else { return }
                // Tapping the script pauses or resumes reading; it never starts or stops a recording.
                if mode == .rehearse || recorder.isRecording {
                    engine.toggle()
                    Haptics.tap()
                }
            }
            .gesture(scrubGesture(pacing: pacing))
            .accessibilityElement()
            .accessibilityLabel("Guion")
            .accessibilityValue(segments.map(\.text).joined(separator: " "))
            .accessibilityHint("Toca dos veces para pausar o continuar")
            .accessibilityAction { engine.toggle() }
        }
        .frame(maxHeight: .infinity)
        .layoutPriority(1)
    }

    private func scrubGesture(pacing: PrompterPacing?) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard let pacing else { return }
                if dragAnchor == nil {
                    let wasRunning = engine.isRunning
                    engine.pause()
                    let time = engine.baseElapsed
                    dragAnchor = (time, pacing.offset(at: time), wasRunning)
                }
                guard let anchor = dragAnchor else { return }
                let newOffset = anchor.offset - value.translation.height
                engine.seek(to: pacing.time(atOffset: newOffset))
            }
            .onEnded { _ in
                if dragAnchor?.wasRunning == true { engine.play() }
                dragAnchor = nil
            }
    }

    private var controls: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(spacing: 14) {
                Button {
                    engine.restart()
                    Haptics.tap()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title3)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .disabled(recorder.isRecording)
                .accessibilityLabel("Volver al principio")

                speedControl

                primaryButton
            }
        }
    }

    private var speedControl: some View {
        HStack(spacing: 2) {
            Button {
                speed = max(PrefDefault.prompterSpeedRange.lowerBound, (speed - 0.1).rounded(toPlaces: 1))
                Haptics.selection()
            } label: {
                Image(systemName: "minus").frame(width: 30, height: 30)
            }
            .accessibilityLabel("Más lento")
            Text(String(format: "%.1f×", speed))
                .font(.subheadline.monospacedDigit().weight(.bold))
                .frame(minWidth: 44)
                .contentTransition(.numericText(value: speed))
                .accessibilityLabel("Velocidad \(String(format: "%.1f", speed))")
            Button {
                speed = min(PrefDefault.prompterSpeedRange.upperBound, (speed + 0.1).rounded(toPlaces: 1))
                Haptics.selection()
            } label: {
                Image(systemName: "plus").frame(width: 30, height: 30)
            }
            .accessibilityLabel("Más rápido")
        }
        .buttonStyle(.plain)
        .font(.headline)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    @ViewBuilder
    private var primaryButton: some View {
        switch mode {
        case .rehearse:
            Button {
                primaryAction()
            } label: {
                Image(systemName: engine.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(width: 44, height: 44)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.circle)
            .tint(Palette.ember)
            .accessibilityLabel(engine.isRunning ? "Pausar" : "Empezar")
            .accessibilityIdentifier("prompter.play")
        case .record:
            Button {
                primaryAction()
            } label: {
                ZStack {
                    Circle().strokeBorder(.white.opacity(0.9), lineWidth: 4)
                    RoundedRectangle(cornerRadius: recorder.isRecording ? 6 : 30, style: .continuous)
                        .fill(Palette.record)
                        .frame(width: recorder.isRecording ? 26 : 50, height: recorder.isRecording ? 26 : 50)
                }
                .frame(width: 64, height: 64)
                .animation(.spring(duration: 0.3, bounce: 0.25), value: recorder.isRecording)
            }
            .buttonStyle(.plain)
            .disabled(recorder.phase != .ready && recorder.phase != .recording)
            .opacity(recorder.phase == .ready || recorder.phase == .recording ? 1 : 0.4)
            .accessibilityLabel(recorder.isRecording ? "Detener grabación" : "Grabar")
            .accessibilityIdentifier("prompter.record")
        }
    }

    private func unavailableCard(_ message: String) -> some View {
        VStack(spacing: 12) {
            Label(message, systemImage: "video.slash.fill")
                .font(.subheadline)
                .multilineTextAlignment(.leading)
            HStack {
                if message.contains("Ajustes") {
                    Button("Abrir Ajustes") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .buttonStyle(.glass)
                }
                Button("Ensayar sin grabar") {
                    withAnimation(.smooth) { mode = .rehearse }
                }
                .buttonStyle(.glassProminent)
                .tint(Palette.ember)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    // MARK: - Actions

    private func primaryAction() {
        if countdownValue != nil {
            cancelCountdown()
            return
        }
        switch mode {
        case .rehearse:
            if engine.isRunning {
                engine.pause()
                Haptics.tap()
            } else {
                withCountdown { engine.play() }
            }
        case .record:
            if recorder.isRecording {
                engine.pause()
                recorder.stopRecording()
                Haptics.tap(.heavy)
            } else if recorder.phase == .ready {
                if engine.didReachEnd || engine.baseElapsed >= engine.totalTime { engine.restart() }
                withCountdown {
                    recorder.startRecording()
                    engine.play()
                    Haptics.tap(.heavy)
                }
            }
        }
    }

    private func withCountdown(_ action: @escaping @MainActor () -> Void) {
        guard countdownEnabled else {
            action()
            return
        }
        countdownTask?.cancel()
        countdownTask = Task {
            for value in stride(from: 3, through: 1, by: -1) {
                countdownValue = value
                Haptics.tap(.medium)
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled {
                    return
                }
            }
            countdownValue = nil
            action()
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
        countdownValue = nil
    }

    private func setUp() {
        UIApplication.shared.isIdleTimerDisabled = true
        segments = story.segments.filter { ScriptMetrics.wordCount($0.text) > 0 }
        segmentSeconds = segments.map { ScriptMetrics.spokenSeconds($0.text, wordsPerMinute: wordsPerMinute) }
        let total = PrompterPacing(segmentSeconds: segmentSeconds, segmentOffsets: segmentSeconds.map { _ in 0 }, endOffset: 0).totalTime
        engine.configure(totalTime: total, speed: speed)
        if mode == .record {
            Task { await recorder.prepare() }
        }
    }

    private func tearDown() {
        cancelCountdown()
        engine.pause()
        if recorder.isRecording { recorder.stopRecording() }
        recorder.shutdown()
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if mode == .record { recorder.resume() }
        case .inactive:
            cancelCountdown()
            engine.pause()
        case .background:
            if recorder.isRecording { recorder.stopRecording() }
            recorder.shutdown()
        @unknown default:
            break
        }
    }

    private func store(_ clip: RecordedClip) {
        recorder.finishedClip = nil
        let take = Take(fileName: clip.url.lastPathComponent, durationSeconds: clip.duration)
        context.insert(take)
        take.story = story
        StoryActions.markRecorded(story)
        try? context.save()
        Haptics.success()
        engine.restart()
        reviewedTake = take
    }
}

// MARK: - Column

/// The scrolling script. Equatable so per-frame offset updates never re-run its body:
/// only the active beat, font size or content trigger a re-render.
private struct PrompterColumn: View, Equatable {
    let segments: [ScriptSegment]
    let fontSize: Double
    let activeIndex: Int
    let onMeasure: (Int, CGFloat) -> Void
    let onHeight: (CGFloat) -> Void

    nonisolated static func == (lhs: PrompterColumn, rhs: PrompterColumn) -> Bool {
        lhs.segments == rhs.segments && lhs.fontSize == rhs.fontSize && lhs.activeIndex == rhs.activeIndex
    }

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.9) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                VStack(alignment: .leading, spacing: 6) {
                    Label(segment.kind.title.uppercased(), systemImage: segment.kind.symbol)
                        .font(.caption.weight(.heavy))
                        .tracking(0.8)
                        .foregroundStyle(segment.kind.tint)
                    Text(segment.text)
                        .font(.system(size: fontSize, weight: .bold))
                        .lineSpacing(fontSize * 0.16)
                        .foregroundStyle(.white.opacity(index == activeIndex ? 1 : 0.42))
                        .fixedSize(horizontal: false, vertical: true)
                        .animation(.smooth(duration: 0.4), value: activeIndex)
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .named("prompterColumn")).minY
                } action: { minY in
                    onMeasure(index, minY)
                }
            }
            // Room so the last line can scroll past the reading line.
            Color.clear.frame(height: 40)
        }
        .coordinateSpace(.named("prompterColumn"))
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height - 40
        } action: { height in
            onHeight(height)
        }
    }
}

// MARK: - Settings sheet

private struct PrompterSettingsSheet: View {
    @Binding var fontSize: Double
    @Binding var speed: Double
    @Binding var mirror: Bool
    @Binding var countdown: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Teleprompter")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Tamaño", systemImage: "textformat.size")
                    Spacer()
                    Text("\(Int(fontSize)) pt").monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $fontSize, in: PrefDefault.prompterFontRange, step: 2)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("Velocidad", systemImage: "speedometer")
                    Spacer()
                    Text(String(format: "%.1f×", speed)).monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $speed, in: PrefDefault.prompterSpeedRange, step: 0.1)
            }

            Toggle(isOn: $countdown) { Label("Cuenta atrás", systemImage: "timer") }
            Toggle(isOn: $mirror) { Label("Espejo", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") }
        }
        .padding(.horizontal, 24)
        .tint(Palette.ember)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let factor = pow(10, Double(places))
        return (self * factor).rounded() / factor
    }
}
