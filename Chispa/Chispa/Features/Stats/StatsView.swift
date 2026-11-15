import SwiftUI

struct StatsView: View {
    @Environment(GameStore.self) private var store
    @State private var month = 0

    var body: some View {
        let stats = store.stats
        let streak = store.streak
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryGrid(stats: stats, streak: streak)
                    if let strong = stats.strongest {
                        strengths(strong: strong, weak: stats.weakest)
                    }
                    kinds(stats)
                    CalendarCard(monthOffset: $month)
                    badges
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(NightBackground(glow: Palette.good))
            .navigationTitle("Progreso")
        }
    }

    private func summaryGrid(stats: PlayerStats, streak: StreakState) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile("Racha actual", "\(streak.current)", "flame.fill", Palette.ember)
            tile("Mejor racha", "\(streak.best)", "trophy.fill", Palette.amber)
            tile("Aciertos", "\(Int((stats.accuracy * 100).rounded())) %", "target", Palette.good)
            tile("Puntos totales", stats.totalPoints.formatted(), "sparkles", Color(hex: 0xA77BFF))
            tile("Días jugados", "\(stats.daysPlayed)", "calendar", Color(hex: 0x4DA3FF))
            tile("Protectores", "\(streak.shields) de \(Streaks.maxShields)", "shield.fill", Color(hex: 0x7FD3FF))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("statsSummary")
    }

    private func tile(_ title: String, _ value: String, _ symbol: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol).foregroundStyle(color).font(.headline)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .heavy))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
        }
        .card(radius: 22)
        .accessibilityElement(children: .combine)
    }

    private func strengths(strong: KindStats, weak: KindStats?) -> some View {
        HStack(spacing: 12) {
            strengthTile("Tu punto fuerte", strong, Palette.good)
            if let weak { strengthTile("A mejorar", weak, Palette.bad) }
        }
    }

    private func strengthTile(_ title: String, _ kind: KindStats, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption.weight(.heavy)).foregroundStyle(color)
            HStack(spacing: 8) {
                KindIcon(kind: kind.kind, size: 30)
                Text(kind.kind.title).font(.subheadline.weight(.bold)).lineLimit(2).minimumScaleFactor(0.8)
            }
            Text("\(Int((kind.accuracy * 100).rounded())) % de aciertos").font(.caption).foregroundStyle(Palette.muted)
        }
        .card(tint: color, radius: 22)
    }

    private func kinds(_ stats: PlayerStats) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Por tipo de reto").font(.headline)
            ForEach(stats.kinds) { kind in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        KindIcon(kind: kind.kind, size: 26)
                        Text(kind.kind.title).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(kind.played == 0 ? "—" : "\(kind.correct)/\(kind.played) · \(kind.averageSeconds.secondsText)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(Palette.muted)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.08))
                            Capsule().fill(kind.kind.tint).frame(width: proxy.size.width * kind.accuracy)
                        }
                    }
                    .frame(height: 8)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .card()
    }

    private var badges: some View {
        VStack(alignment: .leading, spacing: 12) {
            let all = store.badges
            Text("Insignias · \(all.filter(\.earned).count) de \(all.count)").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(all) { badge in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .trim(from: 0, to: badge.progress)
                                .stroke(Palette.amber, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Image(systemName: badge.symbol)
                                .font(.title2)
                                .foregroundStyle(badge.earned ? AnyShapeStyle(LinearGradient(colors: Palette.spark, startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Palette.muted.opacity(0.5)))
                        }
                        .frame(width: 54, height: 54)
                        Text(badge.title).font(.caption.weight(.bold)).multilineTextAlignment(.center).lineLimit(2)
                        Text(badge.detail).font(.caption2).foregroundStyle(Palette.muted).multilineTextAlignment(.center).lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)
                    .glassEffect(.regular.tint(badge.earned ? Palette.amber.opacity(0.18) : .clear), in: .rect(cornerRadius: 18))
                    .opacity(badge.earned ? 1 : 0.75)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(badge.title), \(badge.earned ? "conseguida" : "pendiente")")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("badges")
    }
}

/// Month view of played days, coloured by points.
struct CalendarCard: View {
    @Environment(GameStore.self) private var store
    @Binding var monthOffset: Int

    var body: some View {
        let calendar = ChallengeDay.calendar
        let base = calendar.date(byAdding: .month, value: monthOffset, to: store.today.startDate()) ?? .now
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: base)) ?? base
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
        let lead = ChallengeDay(date: monthStart).weekdayIndex
        let firstNumber = ChallengeDay(date: monthStart).number
        let summaries = store.summaries
        let completed = DayProgress.completedDays(summaries)
        let saved = Set(store.streak.savedDays)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(monthStart.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "es_ES"))).sentenceCased)
                    .font(.headline)
                Spacer()
                Button { withAnimation(.smooth) { monthOffset -= 1 } } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Mes anterior")
                Button { withAnimation(.smooth) { monthOffset += 1 } } label: { Image(systemName: "chevron.right") }
                    .disabled(monthOffset >= 0)
                    .accessibilityLabel("Mes siguiente")
            }
            .buttonStyle(.glass)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(["L", "M", "X", "J", "V", "S", "D"], id: \.self) { letter in
                    Text(letter).font(.caption2.weight(.bold)).foregroundStyle(Palette.muted)
                }
                // Negative ids so the leading blanks never collide with the day cells (0, 1, 2…).
                ForEach((0..<lead).map { -1 - $0 }, id: \.self) { _ in Color.clear.frame(height: 34) }
                ForEach(0..<daysInMonth, id: \.self) { offset in
                    let number = firstNumber + offset
                    let points = DayProgress.points(on: number, summaries)
                    ZStack {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(color(points: points, done: completed.contains(number), saved: saved.contains(number)))
                        if saved.contains(number) {
                            Image(systemName: "shield.fill").font(.caption2).foregroundStyle(.white)
                        } else {
                            Text("\(offset + 1)")
                                .font(.caption.weight(number == store.today.number ? .heavy : .medium))
                                .foregroundStyle(number > store.today.number ? Palette.muted.opacity(0.4) : .white)
                        }
                    }
                    .frame(height: 34)
                    .overlay {
                        if number == store.today.number {
                            RoundedRectangle(cornerRadius: 9).stroke(Palette.amber, lineWidth: 2)
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                legend(Palette.amber.opacity(0.9), "Día completo")
                legend(Color(hex: 0x7FD3FF).opacity(0.6), "Salvado")
                legend(.white.opacity(0.07), "Sin jugar")
            }
            .font(.caption2)
            .foregroundStyle(Palette.muted)
        }
        .card()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("calendar")
    }

    private func color(points: Int, done: Bool, saved: Bool) -> Color {
        if saved { return Color(hex: 0x7FD3FF).opacity(0.6) }
        if done { return Palette.amber.opacity(0.35 + 0.6 * min(Double(points) / 900, 1)) }
        if points > 0 { return Palette.amber.opacity(0.2) }
        return .white.opacity(0.07)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text)
        }
    }
}
