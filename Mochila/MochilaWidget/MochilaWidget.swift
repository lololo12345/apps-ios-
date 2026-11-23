import SwiftUI
import WidgetKit

/// Packing tip of the day and a shortcut to start a new trip.
/// (The widget cannot read the app's trips: that needs an App Group, which sideloading does not keep.)
struct TipEntry: TimelineEntry {
    let date: Date
    let tip: String
}

struct TipProvider: TimelineProvider {
    func placeholder(in context: Context) -> TipEntry { TipEntry(date: .now, tip: TravelTips.all[0]) }

    func getSnapshot(in context: Context, completion: @escaping (TipEntry) -> Void) {
        completion(TipEntry(date: .now, tip: TravelTips.tip()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TipEntry>) -> Void) {
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        completion(Timeline(entries: [TipEntry(date: .now, tip: TravelTips.tip())], policy: .after(tomorrow)))
    }
}

struct MochilaWidgetView: View {
    let entry: TipEntry
    @Environment(\.widgetFamily) private var family

    private let accent = Color(red: 0.169, green: 0.702, blue: 0.639)
    private let sunset = Color(red: 1, green: 0.71, blue: 0.278)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "suitcase.rolling.fill").foregroundStyle(accent)
                Text("Mochila").font(.caption.weight(.heavy)).foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill").foregroundStyle(accent)
            }
            Text("Consejo del día")
                .font(.caption2.weight(.heavy))
                .foregroundStyle(sunset)
            Text(entry.tip)
                .font(family == .systemSmall ? .caption : .subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(family == .systemSmall ? 5 : 4)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(colors: [Color(red: 0.043, green: 0.114, blue: 0.18), Color(red: 0.024, green: 0.059, blue: 0.098)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [accent.opacity(0.35), .clear], center: .topTrailing, startRadius: 0, endRadius: 160)
                RadialGradient(colors: [sunset.opacity(0.22), .clear], center: .bottomLeading, startRadius: 0, endRadius: 140)
            }
        }
        .widgetURL(URL(string: "mochila://new"))
    }
}

struct MochilaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "app.mochila.travel.widget.tip", provider: TipProvider()) { entry in
            MochilaWidgetView(entry: entry)
        }
        .configurationDisplayName("Mochila")
        .description("Un consejo para hacer la maleta cada día. Tócalo para preparar un viaje.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct MochilaWidgetBundle: WidgetBundle {
    var body: some Widget {
        MochilaWidget()
    }
}
