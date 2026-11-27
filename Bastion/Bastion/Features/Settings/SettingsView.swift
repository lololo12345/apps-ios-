import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmReset = false

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            ScrollView {
                GlassEffectContainer(spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Apariencia", subtitle: "Claro, oscuro o como tengas el iPhone.")
                            AppearancePicker(selection: $model.appearance)
                        }
                        .card()

                        VStack(alignment: .leading, spacing: 8) {
                            SectionHeader(title: "Preferencias")
                            GlassRow(title: "Vibración", systemImage: "iphone.radiowaves.left.and.right") {
                                Toggle("Vibración", isOn: $model.hapticsOn)
                                    .labelsHidden()
                                    .accessibilityIdentifier("hapticsToggle")
                            }
                        }
                        .card()

                        Button(role: .destructive) {
                            confirmReset = true
                        } label: {
                            Label("Restablecer ajustes", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glass)

                        Text("Bastión · versión \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"). Todo se guarda solo en este iPhone.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Ajustes")
            .sensoryFeedback(.selection, trigger: model.appearance) { _, _ in model.hapticsOn }
            .confirmationDialog("¿Restablecer los ajustes?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Restablecer", role: .destructive) { model.reset() }
            }
        }
    }
}

/// Three tiles with a small preview of each mode; the accent ring slides to the chosen one.
struct AppearancePicker: View {
    @Binding var selection: Appearance
    @Namespace private var ring

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Appearance.allCases) { option in
                let selected = selection == option
                Button {
                    withAnimation(.snappy(duration: 0.3)) { selection = option }
                } label: {
                    VStack(spacing: 8) {
                        preview(option)
                            .frame(height: 64)
                            .clipShape(.rect(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                            }
                            .overlay {
                                if selected {
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(Palette.accent, lineWidth: 2.5)
                                        .padding(-4)
                                        .matchedGeometryEffect(id: "ring", in: ring)
                                }
                            }
                        Label(option.title, systemImage: option.symbol)
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(selected ? AnyShapeStyle(Palette.accent.ink) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.vertical, 4)
                    .contentShape(.rect)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("appearance.\(option.rawValue)")
            }
        }
    }

    /// Mini screen: light, dark, or half and half for «Automático».
    @ViewBuilder
    private func preview(_ option: Appearance) -> some View {
        switch option {
        case .light: miniScreen(dark: false)
        case .dark: miniScreen(dark: true)
        case .system:
            HStack(spacing: 0) {
                miniScreen(dark: false)
                miniScreen(dark: true)
            }
        }
    }

    private func miniScreen(dark: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: dark ? [Palette.background, Palette.backgroundDeep] : [Palette.lightTop, Palette.lightBottom],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Palette.accent.opacity(0.45), .clear], center: .topTrailing, startRadius: 0, endRadius: 60)
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(dark ? Color.white.opacity(0.85) : Color.black.opacity(0.7)).frame(width: 24, height: 4)
                RoundedRectangle(cornerRadius: 4).fill(dark ? Color.white.opacity(0.16) : Color.white.opacity(0.8)).frame(height: 14)
                RoundedRectangle(cornerRadius: 4).fill(dark ? Color.white.opacity(0.1) : Color.white.opacity(0.6)).frame(height: 10)
            }
            .padding(8)
        }
    }
}
