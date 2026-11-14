import SwiftUI
import UIKit

/// In-app mirror of what the island shows, with the same buttons.
struct SessionCard: View {
    let session: ToolSession
    @Environment(AppModel.self) private var model

    var body: some View {
        let display = session.display()
        let tint = session.kind.tint
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: display.symbol ?? session.kind.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .rotationEffect(.degrees(display.rotation ?? 0))
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.16), in: .circle)
                VStack(alignment: .leading, spacing: 3) {
                    Text(display.headline).font(.headline).lineLimit(2)
                    Text(display.detail ?? session.title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 8)
                value(display)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .accessibilityIdentifier("session.value.\(session.kind.rawValue)")
            }
            if let progress = display.progress {
                switch progress {
                case .value(let v): ProgressView(value: min(1, max(0, v))).tint(tint)
                case .timer(let start, let end):
                    if end > start { ProgressView(timerInterval: start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }.tint(tint) }
                }
            }
            if case .location(let l) = session.state, let data = l.photo, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill().frame(height: 120).clipShape(.rect(cornerRadius: 14))
            }
            HStack(spacing: 8) {
                ForEach(display.buttons) { button in
                    Button {
                        withAnimation(.snappy) { model.perform(button.id, on: session.id) }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(button.title, systemImage: button.symbol)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glass)
                    .tint(button.prominent ? tint : nil)
                    .accessibilityIdentifier("action.\(session.kind.rawValue).\(button.id)")
                }
                if !display.buttons.contains(where: { $0.id == "stop" }) {
                    Button {
                        withAnimation { model.end(session.id) }
                    } label: {
                        Image(systemName: "xmark").frame(width: 22, height: 22)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Quitar de la isla")
                    .accessibilityIdentifier("end.\(session.kind.rawValue)")
                }
            }
        }
        .padding(16)
        .glassEffect(.regular.tint(tint.opacity(0.12)), in: .rect(cornerRadius: 26))
        // `.contain` keeps the buttons' own identifiers.
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("session.\(session.kind.rawValue)")
    }

    @ViewBuilder
    private func value(_ display: IslaDisplay) -> some View {
        if let timer = display.timer {
            if let frozen = timer.frozen {
                Text(Fmt.clock(frozen))
            } else {
                Text(timerInterval: timer.start...timer.end, countsDown: timer.countsDown)
            }
        } else if let value = display.value {
            Text(value).contentTransition(.numericText())
        }
    }
}
