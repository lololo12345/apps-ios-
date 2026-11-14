import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The same IslaDisplay drawn in every place the system can show it.
struct IslaLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IslaAttributes.self) { context in
            LockScreenView(attributes: context.attributes, display: context.state.display)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let display = context.state.display
            let kind = context.attributes.kind
            let session = context.attributes.sessionID
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        ToolGlyph(kind: kind, display: display, size: 18)
                        Text(context.attributes.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    MainValue(display: display, font: .title2)
                        .foregroundStyle(kind.tint)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(display.headline)
                            .font(.headline)
                            .lineLimit(2)
                        if let detail = display.detail {
                            Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        if let progress = display.progress {
                            ProgressBar(progress: progress, tint: kind.tint)
                        }
                        ActionRow(buttons: display.buttons, session: session, tint: kind.tint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                ToolGlyph(kind: kind, display: display, size: 16)
            } compactTrailing: {
                MainValue(display: display, font: .caption.weight(.semibold), compact: true)
                    .foregroundStyle(kind.tint)
                    .frame(maxWidth: 64)
            } minimal: {
                if let timer = display.timer, timer.frozen == nil, timer.countsDown {
                    ProgressView(timerInterval: timer.start...timer.end, countsDown: true) {
                        EmptyView()
                    } currentValueLabel: {
                        Image(systemName: display.symbol ?? kind.symbol).font(.system(size: 9))
                    }
                    .progressViewStyle(.circular)
                    .tint(kind.tint)
                } else {
                    ToolGlyph(kind: kind, display: display, size: 14)
                }
            }
            .keylineTint(kind.tint)
            .widgetURL(URL(string: "isla://session/\(session)"))
        }
    }
}

/// Tool symbol, or a rotated arrow (back to the car).
struct ToolGlyph: View {
    let kind: ToolKind
    let display: IslaDisplay
    let size: CGFloat

    var body: some View {
        Image(systemName: display.symbol ?? kind.symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(kind.tint)
            .rotationEffect(.degrees(display.rotation ?? 0))
    }
}

/// Timer (animated by the system), or the big value.
struct MainValue: View {
    let display: IslaDisplay
    let font: Font
    var compact = false

    var body: some View {
        Group {
            if let timer = display.timer {
                if let frozen = timer.frozen {
                    Text(Self.clock(frozen))
                } else {
                    Text(timerInterval: timer.start...timer.end, countsDown: timer.countsDown, showsHours: true)
                }
            } else if let value = display.value {
                Text(value)
            } else if display.finished {
                Image(systemName: "checkmark.circle.fill")
            } else {
                Text(display.headline)
            }
        }
        .font(font.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .multilineTextAlignment(.trailing)
        .contentTransition(.numericText())
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
    }
}

struct ProgressBar: View {
    let progress: IslaProgress
    let tint: Color

    var body: some View {
        switch progress {
        case .value(let value):
            ProgressView(value: min(1, max(0, value))).tint(tint)
        case .timer(let start, let end):
            if end > start {
                ProgressView(timerInterval: start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .tint(tint)
            }
        }
    }
}

/// Up to three buttons that run without opening the app.
struct ActionRow: View {
    let buttons: [IslaButton]
    let session: String
    let tint: Color

    var body: some View {
        if !buttons.isEmpty {
            HStack(spacing: 8) {
                ForEach(buttons.prefix(3)) { button in
                    Button(intent: IslaActionIntent(session: session, action: button.id)) {
                        Label(button.title, systemImage: button.symbol)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(button.prominent ? tint : Color.white.opacity(0.18))
                    .foregroundStyle(button.prominent ? Color.black : Color.white)
                }
            }
        }
    }
}

struct LockScreenView: View {
    let attributes: IslaAttributes
    let display: IslaDisplay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ToolGlyph(kind: attributes.kind, display: display, size: 24)
                    .frame(width: 40, height: 40)
                    .background(attributes.kind.tint.opacity(0.18), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(display.headline).font(.headline).lineLimit(1)
                    Text(display.detail ?? attributes.title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)
                MainValue(display: display, font: .title2.weight(.semibold))
                    .foregroundStyle(attributes.kind.tint)
                    .frame(maxWidth: 130, alignment: .trailing)
            }
            if let progress = display.progress {
                ProgressBar(progress: progress, tint: attributes.kind.tint)
            }
            ActionRow(buttons: display.buttons, session: attributes.sessionID, tint: attributes.kind.tint)
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}
