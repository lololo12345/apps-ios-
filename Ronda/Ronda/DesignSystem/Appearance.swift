import SwiftUI

/// Light or dark, or whatever the iPhone uses. Ronda starts dark (it is played at night), but the group
/// can switch to light for an afternoon on the terrace. Chosen in Ajustes → Apariencia.
enum Appearance: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    static let standard: Appearance = .dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Automático"
        case .light: "Claro"
        case .dark: "Oscuro"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    /// nil = follow the iPhone.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Three tiles with a mini preview of each mode; the neon ring slides to the chosen one.
struct AppearancePicker: View {
    @Binding var selection: Appearance
    @Namespace private var ring

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Appearance.allCases) { option in
                let selected = selection == option
                Button {
                    withAnimation(.snappy(duration: 0.3)) { selection = option }
                    Haptics.select()
                } label: {
                    VStack(spacing: 8) {
                        preview(option)
                            .frame(height: 62)
                            .clipShape(.rect(cornerRadius: 14, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Neon.hairline, lineWidth: 1)
                            }
                            .overlay {
                                if selected {
                                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                                        .strokeBorder(LinearGradient(colors: [Neon.magenta, Neon.cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                                                      lineWidth: 2.5)
                                        .padding(-4)
                                        .matchedGeometryEffect(id: "ring", in: ring)
                                }
                            }
                        Label(option.title, systemImage: option.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selected ? AnyShapeStyle(HierarchicalShapeStyle.primary) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(.vertical, 6)
                    .contentShape(.rect)
                }
                // A non-default style keeps each tile tappable on its own inside a Form row.
                .buttonStyle(PressableStyle())
                .accessibilityLabel(option.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("appearance.\(option.rawValue)")
            }
        }
    }

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
            (dark ? Neon.night : Neon.dawn)
            RadialGradient(colors: [Neon.violet.opacity(dark ? 0.6 : 0.35), .clear], center: .topLeading, startRadius: 0, endRadius: 60)
            RadialGradient(colors: [Neon.cyan.opacity(dark ? 0.45 : 0.3), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 50)
            VStack(alignment: .leading, spacing: 4) {
                Capsule().fill(LinearGradient(colors: [Neon.magenta, Neon.cyan], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 26, height: 5)
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4).fill(dark ? Color.white.opacity(0.14) : Color.white.opacity(0.85))
                    RoundedRectangle(cornerRadius: 4).fill(dark ? Color.white.opacity(0.14) : Color.white.opacity(0.85))
                }
                .frame(height: 20)
            }
            .padding(8)
        }
    }
}
