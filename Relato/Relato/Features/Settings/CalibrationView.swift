import SwiftUI

/// Read a known paragraph aloud while a timer runs; the result becomes the app-wide speaking rate.
/// No microphone needed: the word count is known and the person marks start and end.
struct CalibrationView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PrefKey.wordsPerMinute) private var wordsPerMinute = PrefDefault.wordsPerMinute

    private enum Phase: Equatable {
        case ready
        case reading(started: Date)
        case result(SpeechCalibration.Outcome, seconds: Double)
    }

    @State private var phase: Phase = .ready
    private let wordCount = ScriptMetrics.wordCount(SpeechCalibration.sampleText)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(instructions)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(SpeechCalibration.sampleText)
                        .font(.system(.title3, design: .serif, weight: .medium))
                        .lineSpacing(6)
                        .opacity(isReading ? 1 : 0.55)
                        .surfaceCard()
                        .animation(.smooth(duration: 0.3), value: isReading)
                        .accessibilityLabel("Texto para leer en voz alta")
                        .accessibilityValue(SpeechCalibration.sampleText)

                    statusView
                }
                .padding(Metrics.gutter)
            }
            .background { AuroraBackground(intensity: 0.5) }
            .safeAreaInset(edge: .bottom) {
                actionButtons
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.bottom, 8)
            }
            .navigationTitle("Mide tu velocidad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var isReading: Bool {
        if case .reading = phase { return true }
        return false
    }

    private var instructions: String {
        switch phase {
        case .ready: "Pulsa «Empezar» y lee el texto en voz alta, a tu ritmo natural, como si estuvieras grabando. Pulsa «Terminé» al acabar."
        case .reading: "Lee en voz alta… Pulsa «Terminé» cuando digas la última palabra."
        case .result: "Puedes repetir la medición tantas veces como quieras."
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch phase {
        case .ready:
            Label("Ahora usas \(Int(wordsPerMinute)) palabras por minuto.", systemImage: "speedometer")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        case .reading(let started):
            TimelineView(.periodic(from: started, by: 0.1)) { context in
                Text(String(format: "%.1f s", context.date.timeIntervalSince(started)))
                    .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
            }
            .accessibilityLabel("Cronómetro en marcha")
        case .result(let outcome, let seconds):
            resultCard(outcome, seconds: seconds)
        }
    }

    @ViewBuilder
    private func resultCard(_ outcome: SpeechCalibration.Outcome, seconds: Double) -> some View {
        switch outcome {
        case .measured(let rate):
            VStack(spacing: 6) {
                Text("\(Int(rate))")
                    .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.ember)
                Text("palabras por minuto")
                    .font(.headline)
                Text("Has tardado \(String(format: "%.1f", seconds)) s en \(wordCount) palabras.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .surfaceCard()
            .accessibilityElement(children: .combine)
        case .tooFast:
            Label("Ha sido demasiado rápido. ¿Has leído el texto entero en voz alta?", systemImage: "hare.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.amber)
        case .implausible:
            Label("El resultado no parece real. Puede que se te olvidara pulsar «Terminé». Prueba otra vez.", systemImage: "exclamationmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.amber)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        switch phase {
        case .ready:
            Button {
                Haptics.tap(.medium)
                withAnimation(.smooth) { phase = .reading(started: .now) }
            } label: {
                Label("Empezar", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("calibration.start")
        case .reading(let started):
            Button {
                let seconds = Date.now.timeIntervalSince(started)
                let outcome = SpeechCalibration.evaluate(wordCount: wordCount, seconds: seconds)
                if case .measured = outcome { Haptics.success() } else { Haptics.warning() }
                withAnimation(.smooth) { phase = .result(outcome, seconds: seconds) }
            } label: {
                Label("Terminé", systemImage: "stop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(Palette.record)
            .accessibilityIdentifier("calibration.stop")
        case .result(let outcome, _):
            HStack(spacing: 10) {
                Button {
                    withAnimation(.smooth) { phase = .ready }
                } label: {
                    Text("Repetir")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glass)

                if case .measured(let rate) = outcome {
                    Button {
                        wordsPerMinute = rate
                        Haptics.success()
                        dismiss()
                    } label: {
                        Text("Usar \(Int(rate)) ppm")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .accessibilityIdentifier("calibration.save")
                }
            }
        }
    }
}
