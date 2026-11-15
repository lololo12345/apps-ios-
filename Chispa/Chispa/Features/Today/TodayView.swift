import SwiftUI

struct TodayView: View {
    @Environment(GameStore.self) private var store
    @State private var playing: Challenge?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if store.clockBehind { clockWarning }
                    if store.todayDone { DaySummaryCard() }
                    VStack(spacing: 12) {
                        ForEach(Array(store.todayChallenges.enumerated()), id: \.element.id) { index, challenge in
                            Button {
                                playing = challenge
                            } label: {
                                ChallengeRow(challenge: challenge, record: store.record(for: challenge))
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityIdentifier("challenge-\(challenge.kind.rawValue)")
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.smooth(duration: 0.45).delay(Double(index) * 0.04), value: store.today)
                        }
                    }
                    if !store.todayDone {
                        CountdownLabel(target: store.today.endDate(), prefix: "Quedan")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 4)
                    }
                    rulesFooter
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(NightBackground())
            .navigationTitle("Chispa #\(store.today.number)")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajustes", systemImage: "gearshape.fill") { showSettings = true }
                        .accessibilityIdentifier("settingsButton")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .fullScreenCover(item: $playing) { challenge in
                DailyPlayFlow(first: challenge) { playing = nil }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.today.formatted().sentenceCased)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.muted)
                LevelPill(level: store.today.level)
            }
            Spacer()
            StreakChip(streak: store.streak)
        }
        .padding(.top, 4)
    }

    private var clockWarning: some View {
        Label("La hora del iPhone parece haber retrocedido. Ponla en automático para seguir jugando.", systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.semibold))
            .card(tint: Palette.bad)
    }

    private var rulesFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Una sola oportunidad por reto. El tiempo empieza al pulsar «Empezar».", systemImage: "1.circle.fill")
            Label("Rapidez = puntos extra. Las pistas restan \(Int(Scoring.hintCost)).", systemImage: "bolt.fill")
            Label("Los retos son los mismos para todo el mundo.", systemImage: "globe")
        }
        .font(.footnote)
        .foregroundStyle(Palette.muted)
        .padding(.top, 8)
    }
}

struct LevelPill: View {
    let level: Level

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: level == .boss ? "crown.fill" : "speedometer")
            Text(level.label)
            Text(level.multiplierLabel).foregroundStyle(Palette.amber)
        }
        .font(.caption.weight(.bold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .glassEffect(.regular.tint(level == .boss ? Palette.ember.opacity(0.35) : .clear), in: .capsule)
        .accessibilityIdentifier("levelPill")
    }
}

struct ChallengeRow: View {
    let challenge: Challenge
    let record: ChallengeRecord?

    var body: some View {
        HStack(spacing: 14) {
            KindIcon(kind: challenge.kind, size: 48)
            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.kind.title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                Text(challenge.kind.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            status
        }
        .card(tint: record?.isFinished == true ? record.map { $0.summary.outcome.color } : nil, radius: 26)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        if let record, record.isFinished {
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.summary.outcome.emoji).font(.title3)
                Text("\(record.points) pts")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        } else if record != nil {
            Text("Continuar")
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Palette.ember, in: .capsule)
                .foregroundStyle(.white)
        } else {
            Text("Jugar")
                .font(.subheadline.weight(.bold))
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(LinearGradient(colors: Palette.spark, startPoint: .leading, endPoint: .trailing), in: .capsule)
                .foregroundStyle(Color(hex: 0x2A1300))
        }
    }
}

struct DaySummaryCard: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("¡Reto completado!")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .sparkText()
                Spacer()
                Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Palette.good)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(store.todayPoints)")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("todayPoints")
                Text("de \(Scoring.maxPoints(level: store.today.level)) puntos")
                    .foregroundStyle(Palette.muted)
            }
            Text(store.todayGrid)
                .font(.system(size: 30))
                .accessibilityLabel("Resultado de hoy")
            CountdownLabel(target: store.today.endDate())
            ShareLink(item: store.shareMessage) {
                Label("Compartir resultado", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("shareResult")
        }
        .card(tint: Palette.amber, radius: 28)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}

/// Plays today's challenges one after another inside a single full-screen cover.
struct DailyPlayFlow: View {
    let onDone: () -> Void
    @State private var current: Challenge

    init(first: Challenge, onDone: @escaping () -> Void) {
        self.onDone = onDone
        _current = State(initialValue: first)
    }

    var body: some View {
        ZStack {
            PlayView(challenge: current, mode: .daily) { next in
                if let next {
                    withAnimation(.smooth(duration: 0.45)) { current = next }
                } else {
                    onDone()
                }
            }
            .id(current.id)
            .transition(.push(from: .trailing))
        }
    }
}
