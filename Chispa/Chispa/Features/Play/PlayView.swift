import SwiftUI

enum PlayMode {
    case daily, practice
}

struct PlayView: View {
    let challenge: Challenge
    let mode: PlayMode
    /// Called when the screen closes; carries the next daily challenge if the player chose to continue.
    var onClose: (Challenge?) -> Void

    @Environment(GameStore.self) private var store
    @State private var phase: Phase = .intro
    @State private var startedAt = Date.now
    @State private var usedHint = false
    @State private var result: ResultSummary?
    @State private var resumed = false
    @State private var burst = 0
    @State private var shake = 0

    enum Phase: Equatable { case intro, playing, result }

    var body: some View {
        ZStack {
            NightBackground(glow: challenge.kind.tint)
            switch phase {
            case .intro: intro.transition(.opacity.combined(with: .scale(scale: 0.96)))
            case .playing: playing.transition(.opacity.combined(with: .move(edge: .trailing)))
            case .result: resultView.transition(.opacity.combined(with: .scale(scale: 1.04)))
            }
            SparkBurst(trigger: burst)
        }
        .animation(.smooth(duration: 0.4), value: phase)
        .sensoryFeedback(.success, trigger: burst) { _, _ in store.hapticsOn }
        .sensoryFeedback(.error, trigger: shake) { _, _ in store.hapticsOn }
        .onAppear(perform: restore)
    }

    // MARK: Phases

    private func restore() {
        guard mode == .daily, let record = store.record(for: challenge) else { return }
        startedAt = record.startedAt
        usedHint = record.usedHint
        if record.isFinished {
            result = record.summary
            phase = .result
        } else {
            resumed = true
            phase = .playing
        }
    }

    private func begin() {
        if mode == .daily {
            guard let record = store.start(challenge) else { return }
            startedAt = record.startedAt
        } else {
            startedAt = .now
        }
        phase = .playing
    }

    private func useHint() {
        guard !usedHint else { return }
        usedHint = true
        if mode == .daily { store.markHint(challenge) }
    }

    private func complete(fraction: Double) {
        let summary: ResultSummary?
        if mode == .daily {
            summary = store.finish(challenge, fraction: fraction, usedHint: usedHint)
        } else {
            let seconds = Date.now.timeIntervalSince(startedAt)
            summary = ResultSummary(day: challenge.day.number, kind: challenge.kind, fraction: fraction,
                                    points: Scoring.points(fraction: fraction, seconds: seconds, usedHint: usedHint, level: challenge.level),
                                    seconds: seconds, usedHint: usedHint)
        }
        result = summary
        let correct = fraction >= 1
        Sounds.play(correct: correct, enabled: store.soundOn)
        if correct { burst += 1 } else { shake += 1 }
        phase = .result
    }

    // MARK: Intro

    private var intro: some View {
        VStack(spacing: 22) {
            closeBar
            Spacer()
            KindIcon(kind: challenge.kind, size: 96)
                .shadow(color: challenge.kind.tint.opacity(0.6), radius: 24)
            VStack(spacing: 8) {
                Text(challenge.kind.title)
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                Text(mode == .daily ? "Chispa #\(challenge.day.number)" : "Práctica · \(challenge.day.formatted(.dateTime.day().month(.wide)))")
                    .foregroundStyle(Palette.muted)
                LevelPill(level: challenge.level)
            }
            VStack(alignment: .leading, spacing: 10) {
                if mode == .daily {
                    Label("Solo tienes una oportunidad.", systemImage: "1.circle.fill")
                    Label("El tiempo corre aunque salgas de la app.", systemImage: "timer")
                } else {
                    Label("Modo práctica: no cuenta para la racha ni la liga.", systemImage: "dumbbell.fill")
                }
                Label("Ayuda «\(challenge.hintLabel)»: −\(Int(Scoring.hintCost)) puntos.", systemImage: "lightbulb.fill")
            }
            .font(.subheadline.weight(.medium))
            .card()
            Spacer()
            Button {
                begin()
            } label: {
                Text("Empezar")
                    .font(.title3.weight(.heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.ember)
            .disabled(mode == .daily && store.clockBehind)
            .accessibilityIdentifier("startChallenge")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var closeBar: some View {
        HStack {
            Button {
                onClose(nil)
            } label: {
                Image(systemName: "xmark").font(.headline).frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Cerrar")
            .accessibilityIdentifier("closeChallenge")
            Spacer()
            if phase == .playing {
                TimelineView(.periodic(from: startedAt, by: 0.1)) { context in
                    Text(max(0, context.date.timeIntervalSince(startedAt)).secondsText)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .glassEffect(.regular, in: .capsule)
                }
                .accessibilityIdentifier("timer")
            }
        }
        .padding(.top, 8)
    }

    // MARK: Playing

    private var playing: some View {
        VStack(spacing: 16) {
            closeBar
            HStack(spacing: 10) {
                KindIcon(kind: challenge.kind, size: 34)
                Text(challenge.kind.title).font(.headline)
                Spacer()
                hintButton
            }
            ScrollView {
                VStack(spacing: 18) {
                    Text(challenge.prompt)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(tint: challenge.kind.tint, radius: 26)
                        .accessibilityIdentifier("prompt")
                    challengeBody(for: challenge.body)
                }
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func challengeBody(for body: Challenge.Body) -> some View {
        switch body {
        case .choice(let options, let answer):
            ChoiceBody(options: options, answer: answer, removed: usedHint ? challenge.fiftyFiftyRemoved : [],
                       sound: store.soundOn) { correct in complete(fraction: correct ? 1 : 0) }
        case .number(let answer):
            NumberBody(answer: answer, hint: usedHint ? challenge.hint : nil, sound: store.soundOn) { value in
                complete(fraction: value == answer ? 1 : 0)
            }
        case .memory(let board):
            MemoryBody(board: board, skipPreview: resumed, replayToken: usedHint, sound: store.soundOn) { fraction in
                complete(fraction: fraction)
            }
        }
    }

    private var hintButton: some View {
        Button {
            withAnimation(.smooth) { useHint() }
        } label: {
            Label(challenge.hintLabel, systemImage: usedHint ? "lightbulb.slash.fill" : "lightbulb.fill")
                .font(.subheadline.weight(.bold))
        }
        .buttonStyle(.glass)
        .disabled(usedHint)
        .accessibilityIdentifier("hintButton")
    }

    // MARK: Result

    private var resultView: some View {
        let summary = result
        let outcome = summary?.outcome ?? .wrong
        return VStack(spacing: 18) {
            closeBar
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: outcome == .wrong ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 76, weight: .bold))
                        .foregroundStyle(outcome.color)
                        .symbolEffect(.bounce, value: phase)
                        .padding(.top, 8)
                    Text(title(for: summary))
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("resultTitle")
                    if let summary {
                        Text("\(summary.points) puntos")
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .sparkText()
                            .monospacedDigit()
                            .accessibilityIdentifier("resultPoints")
                        breakdown(summary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Respuesta").font(.caption.weight(.heavy)).foregroundStyle(Palette.muted)
                        Text(challenge.answerText).font(.headline)
                        Divider().overlay(.white.opacity(0.2))
                        Text(challenge.explanation).font(.body)
                    }
                    .card()
                    .accessibilityIdentifier("explanation")
                }
            }
            .scrollIndicators(.hidden)
            footerButtons
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private func title(for summary: ResultSummary?) -> String {
        guard let summary else { return "Fin" }
        switch summary.outcome {
        case .perfect: return summary.seconds < 10 ? "¡Rapidísimo!" : "¡Correcto!"
        case .assisted: return summary.isCorrect ? "¡Correcto!" : "¡Casi!"
        case .wrong: return "Esta vez no"
        }
    }

    private func breakdown(_ summary: ResultSummary) -> some View {
        let base = Int(Scoring.base * summary.fraction)
        let bonus = summary.isCorrect ? Int(Scoring.timeBonus(seconds: summary.seconds).rounded()) : 0
        return VStack(spacing: 8) {
            row("Acierto", "+\(base)")
            row("Rapidez (\(summary.seconds.secondsText))", "+\(bonus)")
            if summary.usedHint { row("Ayuda", "−\(Int(Scoring.hintCost))") }
            row("Dificultad \(challenge.level.label.lowercased())", challenge.level.multiplierLabel)
        }
        .font(.subheadline)
        .card()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(Palette.muted)
            Spacer()
            Text(value).fontWeight(.bold).monospacedDigit()
        }
    }

    @ViewBuilder
    private var footerButtons: some View {
        if mode == .daily, let next = store.nextUnplayed {
            Button {
                onClose(next)
            } label: {
                Label("Siguiente: \(next.kind.title)", systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.ember)
            .accessibilityIdentifier("nextChallenge")
        } else {
            Button {
                onClose(nil)
            } label: {
                Text(mode == .daily ? "Ver el resumen del día" : "Volver")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.ember)
            .accessibilityIdentifier("finishChallenge")
        }
    }
}
