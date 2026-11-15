import SwiftUI
import WidgetKit

/// Today's challenge number, difficulty and a live countdown to the next one.
/// (The widget cannot read the app's data without an App Group, which sideloading does not keep,
/// so it shows what is the same for everyone.)
struct DayEntry: TimelineEntry {
    let date: Date
    let day: ChallengeDay
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry { DayEntry(date: .now, day: .today()) }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: .now, day: .today()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let today = ChallengeDay.today()
        let entries = [DayEntry(date: .now, day: today), DayEntry(date: today.endDate(), day: today.adding(1))]
        completion(Timeline(entries: entries, policy: .after(today.adding(1).endDate())))
    }
}

struct DayWidgetView: View {
    let entry: DayEntry
    @Environment(\.widgetFamily) private var family

    private var spark: LinearGradient {
        LinearGradient(colors: [Color(red: 1, green: 0.84, blue: 0.35), Color(red: 1, green: 0.37, blue: 0.23)], startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        let level = entry.day.level
        Group {
            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "sparkle").font(.title2.weight(.bold)).foregroundStyle(spark)
                        Spacer()
                        Text("#\(entry.day.number)").font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer(minLength: 0)
                    Text(level == .boss ? "Reto jefe ×2" : "Nivel \(level.label.lowercased())")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                    Text("Nuevo en").font(.caption2).foregroundStyle(.white.opacity(0.7))
                    Text(timerInterval: entry.date...max(entry.day.endDate(), entry.date.addingTimeInterval(1)), countsDown: true)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(spark)
                }
            } else {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkle").foregroundStyle(spark)
                            Text("Chispa #\(entry.day.number)").font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.8))
                        }
                        Text(level == .boss ? "Hoy: reto jefe ×2" : "Hoy: nivel \(level.label.lowercased()) \(level.multiplierLabel)")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                        Spacer(minLength: 0)
                        Text("Próximo reto en").font(.caption2).foregroundStyle(.white.opacity(0.7))
                        Text(timerInterval: entry.date...max(entry.day.endDate(), entry.date.addingTimeInterval(1)), countsDown: true)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(spark)
                    }
                    Spacer(minLength: 0)
                    VStack(spacing: 6) {
                        ForEach(ChallengeKind.allCases) { kind in
                            HStack(spacing: 6) {
                                Image(systemName: kind.symbol)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Color(hex: kind.tintHex), in: .rect(cornerRadius: 6))
                                Text(kind.title).font(.caption2.weight(.semibold)).foregroundStyle(.white.opacity(0.9))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(width: 128)
                }
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(hex: 0x2A1B5E), Color(hex: 0x120C2E)], startPoint: .top, endPoint: .bottom)
        }
        .widgetURL(URL(string: "chispa://today"))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

struct ChispaDayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.chispa.daily.today", provider: DayProvider()) { entry in
            DayWidgetView(entry: entry)
        }
        .configurationDisplayName("Reto de hoy")
        .description("El número del reto, su dificultad y cuánto falta para el siguiente.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ChispaWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChispaDayWidget()
    }
}
