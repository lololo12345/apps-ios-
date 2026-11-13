import SwiftUI

struct AgeGateView: View {
    @Environment(PartySession.self) private var session

    var body: some View {
        ZStack {
            NightBackground(colors: [Neon.magenta, Neon.cyan])
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 10) {
                    Text("Ronda")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .gradientText([Neon.magenta, Neon.violet, Neon.cyan])
                        .shadow(color: Neon.magenta.opacity(0.6), radius: 24)
                    Text("Juegos para la previa")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    Text("¿Tienes 18 años o más?")
                        .font(.title2.weight(.bold))
                    Text("Ronda incluye juegos con alcohol. Si eres menor, puedes jugar en modo sin alcohol: los sorbos se convierten en puntos.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .neonCard([Neon.magenta, Neon.cyan])

                Spacer()

                VStack(spacing: 12) {
                    BigButton(title: "Sí, tengo 18 o más", symbol: "checkmark", tint: Neon.magenta, identifier: "age.adult") {
                        Haptics.success()
                        session.ageStatus = .adult
                    }
                    BigButton(title: "No, soy menor", tint: Neon.cyan, prominent: false, identifier: "age.minor") {
                        session.ageStatus = .minor
                    }
                }
                Text("Bebe con responsabilidad. Si vas a conducir, no bebas.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }
}
