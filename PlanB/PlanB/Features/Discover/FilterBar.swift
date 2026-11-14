import SwiftUI

/// Glass chips that open a menu each. Tinted when a filter is active.
struct FilterBar: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    chip("Presupuesto", value: state.filter.maxBudget.map(budgetLabel), symbol: "eurosign.circle", id: "filter.budget") {
                        option("Da igual", selected: state.filter.maxBudget == nil) { state.filter.maxBudget = nil }
                        ForEach([Budget.free, .low, .mid], id: \.self) { budget in
                            option(budgetLabel(budget), selected: state.filter.maxBudget == budget) { state.filter.maxBudget = budget }
                        }
                    }
                    chip("Dónde", value: state.filter.place?.label, symbol: "mappin.circle", id: "filter.place") {
                        option("Da igual", selected: state.filter.place == nil) { state.filter.place = nil }
                        ForEach(Place.allCases) { place in
                            option(place.label, selected: state.filter.place == place) { state.filter.place = place }
                        }
                    }
                    chip("Tiempo", value: state.filter.maxDuration?.label, symbol: "clock", id: "filter.time") {
                        option("Da igual", selected: state.filter.maxDuration == nil) { state.filter.maxDuration = nil }
                        ForEach(Duration.allCases) { duration in
                            option(duration.label, selected: state.filter.maxDuration == duration) { state.filter.maxDuration = duration }
                        }
                    }
                    chip("Momento", value: state.filter.time?.label, symbol: "sun.horizon", id: "filter.moment") {
                        option("Da igual", selected: state.filter.time == nil) { state.filter.time = nil }
                        ForEach(TimeOfDay.allCases) { time in
                            option(time.label, selected: state.filter.time == time) { state.filter.time = time }
                        }
                    }
                    chip("Ambiente", value: moodValue, symbol: "sparkles", id: "filter.mood", keepOpen: true) {
                        option("Cualquiera", selected: state.filter.moods.isEmpty) { state.filter.moods = [] }
                        ForEach(Mood.allCases) { mood in
                            option(mood.label, selected: state.filter.moods.contains(mood)) {
                                if state.filter.moods.contains(mood) { state.filter.moods.remove(mood) } else { state.filter.moods.insert(mood) }
                            }
                        }
                    }
                    if !state.filter.isEmpty {
                        Button {
                            withAnimation(.snappy) { state.filter = PlanFilter() }
                            Haptics.select()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.subheadline.weight(.bold))
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .accessibilityLabel("Quitar filtros")
                        .accessibilityIdentifier("filter.clear")
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.vertical, 2)
            }
        }
        .scrollIndicators(.hidden)
        .animation(.snappy(duration: 0.25), value: state.filter)
    }

    private var moodValue: String? {
        let moods = Mood.allCases.filter { state.filter.moods.contains($0) }
        guard let first = moods.first else { return nil }
        return moods.count == 1 ? first.label : "\(first.label) +\(moods.count - 1)"
    }

    private func budgetLabel(_ budget: Budget) -> String {
        budget == .free ? "Gratis" : "Hasta \(budget.label)"
    }

    private func option(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.select()
        } label: {
            if selected { Label(title, systemImage: "checkmark") } else { Text(title) }
        }
    }

    private func chip<Content: View>(_ title: String, value: String?, symbol: String, id: String, keepOpen: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        Menu {
            content()
                // Several moods can be ticked without the menu closing each time.
                .menuActionDismissBehavior(keepOpen ? .disabled : .enabled)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: value == nil ? symbol : symbol + ".fill")
                Text(value ?? title)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .opacity(0.6)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(value == nil ? Color.primary : Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            // Non-interactive glass: an interactive one would take the tap away from the Menu.
            .glassEffect(value == nil ? .regular : .regular.tint(Palette.coral), in: .capsule)
            .contentShape(.capsule)
        }
        .accessibilityIdentifier(id)
    }
}
