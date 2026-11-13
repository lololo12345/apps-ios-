import SwiftData
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let tint: Color
        let eyebrow: String
        let title: String
        let message: String
    }

    private let pages: [Page] = [
        Page(id: 0, symbol: "bolt.fill", tint: Palette.ember, eyebrow: "Los primeros 3 segundos",
             title: "Ganchos que no se deslizan",
             message: "Relato puntúa tu gancho mientras escribes y te dice exactamente cómo hacerlo más potente."),
        Page(id: 1, symbol: "timer", tint: Palette.violet, eyebrow: "Estructura y tiempo",
             title: "Cada segundo, bajo control",
             message: "Escribe por bloques narrativos y ve la duración real hablada. Si es larga, la dividimos en partes con cliffhanger."),
        Page(id: 2, symbol: "video.badge.waveform.fill", tint: Palette.magenta, eyebrow: "Teleprompter",
             title: "Graba sin olvidar nada",
             message: "El guion avanza al ritmo al que hablas, junto a la cámara frontal. Tus tomas quedan guardadas con cada historia."),
    ]

    var body: some View {
        ZStack {
            AuroraBackground(intensity: 1.3)

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(pages) { item in
                        pageView(item).tag(item.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                    .padding(.bottom, 24)

                controls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
        }
        .sensoryFeedback(.selection, trigger: page)
    }

    private func pageView(_ item: Page) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 20)
            ZStack {
                Circle()
                    .fill(item.tint.gradient)
                    .frame(width: 190, height: 190)
                    .blur(radius: 60)
                    .opacity(0.7)
                Image(systemName: item.symbol)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(item.tint.gradient)
                    .symbolEffect(.bounce, options: .nonRepeating, value: page == item.id && !reduceMotion)
                    .frame(width: 150, height: 150)
                    .glassEffect(.regular.tint(item.tint.opacity(0.12)), in: .circle)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(item.eyebrow.uppercased())
                    .font(.footnote.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(item.tint)
                Text(item.title)
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(item.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 32)
            Spacer(minLength: 20)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages) { item in
                Capsule()
                    .fill(item.id == page ? AnyShapeStyle(Palette.ember) : AnyShapeStyle(Color.primary.opacity(0.18)))
                    .frame(width: item.id == page ? 26 : 8, height: 8)
            }
        }
        .animation(.snappy, value: page)
        .accessibilityElement()
        .accessibilityLabel("Página \(page + 1) de \(pages.count)")
    }

    @ViewBuilder
    private var controls: some View {
        if page < pages.count - 1 {
            HStack {
                Button("Saltar") { page = pages.count - 1 }
                    .buttonStyle(.glass)
                Spacer()
                Button {
                    withAnimation(.smooth) { page += 1 }
                } label: {
                    Label("Siguiente", systemImage: "arrow.right")
                        .font(.headline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
            }
        } else {
            VStack(spacing: 12) {
                Button {
                    // Replaying the intro from Settings must not duplicate the examples.
                    if ((try? context.fetchCount(FetchDescriptor<Story>())) ?? 0) == 0 {
                        SampleContent.insert(into: context)
                    }
                    Haptics.success()
                    onFinish()
                } label: {
                    Text("Empezar con historias de ejemplo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("onboarding.samples")

                Button {
                    Haptics.tap()
                    onFinish()
                } label: {
                    Text("Empezar en blanco")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("onboarding.blank")
            }
        }
    }
}
