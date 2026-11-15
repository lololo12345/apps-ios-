import SwiftUI

/// Challenges from earlier days, to play without points.
struct PracticeView: View {
    @Environment(GameStore.self) private var store
    @State private var playing: Challenge?
    @State private var filter: ChallengeKind?

    private let daysBack = 30

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Los retos de los últimos \(daysBack) días, para entrenar sin presión. No cuentan para la racha ni para la liga.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.muted)
                    filters
                    ForEach(1...daysBack, id: \.self) { back in
                        dayCard(store.today.adding(-back))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(NightBackground(glow: Color(hex: 0x4DA3FF)))
            .navigationTitle("Práctica")
            .fullScreenCover(item: $playing) { challenge in
                PlayView(challenge: challenge, mode: .practice) { _ in playing = nil }
            }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(nil, "Todos")
                ForEach(ChallengeKind.allCases) { kind in chip(kind, kind.title) }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ kind: ChallengeKind?, _ title: String) -> some View {
        Button {
            withAnimation(.snappy) { filter = kind }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
        }
        .buttonStyle(.glass)
        .tint(filter == kind ? (kind?.tint ?? Palette.amber) : nil)
        .accessibilityAddTraits(filter == kind ? .isSelected : [])
    }

    private func dayCard(_ day: ChallengeDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("#\(day.number)").font(.headline.weight(.heavy)).sparkText()
                Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(day.level.label).font(.caption.weight(.bold)).foregroundStyle(Palette.muted)
            }
            HStack(spacing: 10) {
                ForEach(ChallengeKind.allCases.filter { filter == nil || $0 == filter }) { kind in
                    Button {
                        playing = DailySet.challenge(kind, for: day)
                    } label: {
                        VStack(spacing: 4) {
                            KindIcon(kind: kind, size: 42)
                            Text(store.summaries.contains { $0.day == day.number && $0.kind == kind } ? "Jugado" : " ")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(kind.title) del \(day.formatted(.dateTime.day().month(.wide)))")
                    .accessibilityIdentifier("practice-\(day.number)-\(kind.rawValue)")
                }
                Spacer(minLength: 0)
            }
        }
        .card(radius: 22)
    }
}
