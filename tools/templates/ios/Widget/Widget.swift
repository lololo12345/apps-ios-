import SwiftUI
import WidgetKit

struct __name__Entry: TimelineEntry {
    let date: Date
}

struct __name__Provider: TimelineProvider {
    func placeholder(in context: Context) -> __name__Entry { __name__Entry(date: .now) }

    func getSnapshot(in context: Context, completion: @escaping (__name__Entry) -> Void) {
        completion(__name__Entry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<__name__Entry>) -> Void) {
        let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        completion(Timeline(entries: [__name__Entry(date: .now)], policy: .after(tomorrow)))
    }
}

struct __name__WidgetView: View {
    let entry: __name__Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("__display__")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
            Text(entry.date, format: .dateTime.weekday(.wide).day())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color(red: __acc_r__, green: __acc_g__, blue: __acc_b__), Color(red: __bg_r__, green: __bg_g__, blue: __bg_b__)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .widgetURL(URL(string: "__scheme__://home"))
    }
}

struct __name__Widget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "__bundle__.widget.main", provider: __name__Provider()) { entry in
            __name__WidgetView(entry: entry)
        }
        .configurationDisplayName("__display__")
        .description("__summary__")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct __name__WidgetBundle: WidgetBundle {
    var body: some Widget {
        __name__Widget()
    }
}
