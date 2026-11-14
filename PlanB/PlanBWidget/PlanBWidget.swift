import SwiftUI
import WidgetKit

/// "Plan del día": the same plan the app would suggest today; refreshes at midnight.
struct DailyPlanEntry: TimelineEntry {
    let date: Date
    let plan: Plan
}

struct DailyPlanProvider: TimelineProvider {
    private static let fallback = PlanCatalog.all[0]

    func placeholder(in context: Context) -> DailyPlanEntry {
        DailyPlanEntry(date: .now, plan: Self.fallback)
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyPlanEntry) -> Void) {
        completion(entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyPlanEntry>) -> Void) {
        let now = Date.now
        let tomorrow = Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now)
        completion(Timeline(entries: [entry(for: now)], policy: .after(tomorrow)))
    }

    private func entry(for date: Date) -> DailyPlanEntry {
        DailyPlanEntry(date: date, plan: DailyPlan.pick(for: date, from: PlanCatalog.all) ?? Self.fallback)
    }
}

struct DailyPlanWidgetView: View {
    let entry: DailyPlanEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let plan = entry.plan
        Group {
            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.emoji).font(.system(size: 40))
                    Spacer(minLength: 0)
                    Text("PLAN DEL DÍA")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(plan.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    Text(plan.emoji).font(.system(size: 54))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PLAN DEL DÍA")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(plan.title)
                            .font(.system(.headline, design: .rounded, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(plan.summary)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.9))
                            .lineLimit(3)
                        Spacer(minLength: 0)
                        Text("\(plan.budget.label) · \(plan.duration.label) · \(plan.place.label)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: plan.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .widgetURL(URL(string: "planb://plan/\(plan.id)"))
    }
}

struct DailyPlanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.planb.couple.daily", provider: DailyPlanProvider()) { entry in
            DailyPlanWidgetView(entry: entry)
        }
        .configurationDisplayName("Plan del día")
        .description("Una idea nueva cada día para hacer juntos.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PlanBWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyPlanWidget()
    }
}
