import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var state
    @State private var nameA = ""
    @State private var nameB = ""
    @FocusState private var focus: Int?

    private var ready: Bool {
        !AppState.cleanName(nameA).isEmpty && !AppState.cleanName(nameB).isEmpty
    }

    var body: some View {
        ZStack {
            WarmBackground()
            VStack(spacing: 28) {
                Spacer()
                VStack(spacing: 10) {
                    Text("💞")
                        .font(.system(size: 72))
                    Text("Plan B")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .gradientText(Palette.brand)
                    Text("Planes para dos, para cuando no sabéis qué hacer.")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Text("¿Cómo os llamáis?")
                        .font(.headline)
                    nameField("Tu nombre", text: $nameA, id: "onboarding.nameA", index: 0)
                    nameField("El nombre de tu pareja", text: $nameB, id: "onboarding.nameB", index: 1)
                }
                .padding(20)
                .glassEffect(.regular, in: .rect(cornerRadius: Metrics.radius))

                Spacer()

                Button {
                    Haptics.success()
                    state.setNames(nameA, nameB)
                } label: {
                    Label("Empezar", systemImage: "heart.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .disabled(!ready)
                .accessibilityIdentifier("onboarding.start")

                Text("Todo se guarda solo en este iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .onAppear { focus = 0 }
    }

    private func nameField(_ placeholder: String, text: Binding<String>, id: String, index: Int) -> some View {
        TextField(placeholder, text: text)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .submitLabel(index == 0 ? .next : .done)
            .focused($focus, equals: index)
            .onSubmit { focus = index == 0 ? 1 : nil }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.background.opacity(0.6), in: .rect(cornerRadius: 16))
            .accessibilityIdentifier(id)
    }
}
