import SwiftData
import SwiftUI

/// New trip: name, kind, dates and the details that change the list.
struct NewTripView: View {
    /// Pre-selected kind (from a template or the widget).
    var preset: TripType?
    var template: SavedTemplate?

    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedTemplate.createdAt, order: .reverse) private var templates: [SavedTemplate]

    @State private var name = ""
    @State private var type: TripType = .beach
    @State private var start = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @State private var options = TripOptions()
    @State private var chosenTemplate: SavedTemplate?
    @State private var appeared = false
    @State private var weather: WeatherSummary?
    @State private var weatherState: WeatherState = .idle
    @FocusState private var nameFocused: Bool

    enum WeatherState: Equatable {
        case idle, loading, notFound, unavailable
    }

    /// Changes in destination, date or length trigger a new lookup.
    private var lookupKey: String {
        "\(name.trimmingCharacters(in: .whitespaces).lowercased())|\(Calendar.current.startOfDay(for: start).timeIntervalSince1970)|\(options.days)"
    }

    private let typeColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    nameCard
                    weatherCard
                    typeGrid
                    datesCard
                    climateCard
                    optionsCard
                    if !templates.isEmpty { templateCard }
                    preview
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground(glow: type.tint)
            .navigationTitle("Nuevo viaje")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                        .accessibilityIdentifier("cancelNewTrip")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear", systemImage: "checkmark") { create() }
                        .buttonStyle(.glassProminent)
                        .tint(type.tint)
                        .accessibilityIdentifier("createTrip")
                }
            }
            .animation(.smooth(duration: 0.3), value: type)
            .animation(.smooth(duration: 0.3), value: options)
            .animation(.smooth(duration: 0.3), value: weatherState)
            .animation(.smooth(duration: 0.3), value: weather)
            .task(id: lookupKey) { await lookUpWeather() }
        }
        .onAppear {
            guard !appeared else { return }
            appeared = true
            if let template {
                apply(template)
            } else if let preset {
                choose(preset)
            } else {
                options.climate = type.suggestedClimate
            }
        }
    }

    // MARK: Sections

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "¿A dónde vas?")
            TextField("Ej.: Cádiz, Roma, casa de los abuelos…", text: $name)
                .font(.title3.weight(.semibold))
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($nameFocused)
                .onSubmit { nameFocused = false }
                .padding(12)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .accessibilityIdentifier("tripName")
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var weatherCard: some View {
        let destination = name.trimmingCharacters(in: .whitespaces)
        switch weatherState {
        case .idle where weather == nil:
            if destination.isEmpty {
                Label("Escribe el destino y miro qué tiempo hará para ajustar la lista.", systemImage: "cloud.sun")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        case .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text("Mirando el tiempo en \(destination)…").font(.subheadline)
            }
            .card()
        case .notFound:
            Label("No encuentro «\(destination)». Elige tú el tiempo más abajo.", systemImage: "mappin.slash")
                .font(.subheadline)
                .card(tint: Palette.secondary)
        case .unavailable:
            Label("No he podido consultar el tiempo (¿sin conexión?). Elige tú el tiempo más abajo.", systemImage: "wifi.slash")
                .font(.subheadline)
                .card(tint: Palette.secondary)
        default:
            if let weather {
                WeatherPanel(weather: weather, tint: type.tint, note: "Ya he ajustado la lista a este tiempo.")
                    .accessibilityIdentifier("weatherCard")
            }
        }
    }

    private var typeGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Tipo de viaje")
            LazyVGrid(columns: typeColumns, spacing: 10) {
                ForEach(TripType.allCases) { item in
                    let selected = item == type
                    Button {
                        choose(item)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(selected ? .white : item.tint)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(selected ? AnyShapeStyle(item.tint.gradient) : AnyShapeStyle(item.tint.opacity(0.15))))
                            Text(item.title)
                                .font(.caption.weight(selected ? .bold : .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .glassEffect(selected ? .regular.tint(item.tint.opacity(0.3)) : .regular, in: .rect(cornerRadius: 18))
                        .contentShape(.rect)
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("type.\(item.rawValue)")
                }
            }
        }
    }

    private var datesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            DatePicker("Salida", selection: $start, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "es_ES"))
                .accessibilityIdentifier("startDate")
            Divider()
            HStack {
                Text("Días")
                Spacer()
                Button {
                    options.days = max(1, options.days - 1)
                } label: { Image(systemName: "minus").frame(width: 22, height: 22) }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .disabled(options.days <= 1)
                    .accessibilityLabel("Un día menos")
                    .accessibilityIdentifier("daysMinus")
                Text("\(options.days)")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(minWidth: 44)
                    .accessibilityIdentifier("daysValue")
                Button {
                    options.days = min(TripOptions.maxDays, options.days + 1)
                } label: { Image(systemName: "plus").frame(width: 22, height: 22) }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .disabled(options.days >= TripOptions.maxDays)
                    .accessibilityLabel("Un día más")
                    .accessibilityIdentifier("daysPlus")
            }
        }
        .card()
    }

    private var climateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "¿Qué tiempo hará?")
            HStack(spacing: 8) {
                ForEach(Climate.allCases) { climate in
                    GlassChip(title: climate.title, systemImage: climate.symbol, selected: options.climate == climate, tint: type.tint) {
                        options.climate = climate
                    }
                    .accessibilityIdentifier("climate.\(climate.rawValue)")
                }
            }
        }
    }

    private var optionsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Detalles", subtitle: "Cambian lo que hay que meter.")
            toggle("Voy en avión", "airplane", $options.flying, id: "option.flying")
            if options.flying {
                toggle("Solo equipaje de mano", "carry.on.bag.fill", $options.carryOnOnly, id: "option.carryOn")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            toggle("Puede llover", "cloud.rain.fill", $options.rain, id: "option.rain")
            toggle("Vienen niños", "figure.and.child.holdinghands", $options.kids, id: "option.kids")
            toggle("Viene mi mascota", "pawprint.fill", $options.pet, id: "option.pet")
            toggle("Tendré lavadora", "washer.fill", $options.laundry, id: "option.laundry")
        }
        .card()
    }

    private func toggle(_ title: String, _ symbol: String, _ value: Binding<Bool>, id: String) -> some View {
        GlassRow(title: title, systemImage: symbol) {
            Toggle(title, isOn: value)
                .labelsHidden()
                .tint(type.tint)
                .accessibilityIdentifier(id)
        }
    }

    private var templateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Empezar desde una plantilla", subtitle: "Usa una lista que guardaste.")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    chip("Lista nueva", selected: chosenTemplate == nil) { chosenTemplate = nil }
                    ForEach(templates) { saved in
                        chip(saved.name, selected: chosenTemplate?.id == saved.id) { apply(saved) }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundStyle(selected ? .white : .primary)
                .background { if selected { Capsule().fill(type.tint.gradient) } }
                .glassEffect(.regular, in: .capsule)
        }
        .buttonStyle(PressableStyle())
    }

    private var preview: some View {
        let entries = chosenTemplate?.entries ?? PackingGenerator.items(for: type, options: options)
        let things = entries.filter { !$0.isTask }
        let tasks = entries.count - things.count
        return Label {
            Text("Tu lista tendrá **\(things.count) cosas** y **\(tasks) tareas** antes de salir de casa.")
                .font(.subheadline)
                .contentTransition(.numericText())
        } icon: {
            Image(systemName: "checklist").foregroundStyle(type.tint)
        }
        .card(tint: type.tint)
        .accessibilityIdentifier("listPreview")
    }

    // MARK: Actions

    private func choose(_ item: TripType) {
        type = item
        if let weather {
            options = weather.apply(to: options)
        } else {
            options.climate = item.suggestedClimate
        }
    }

    private func lookUpWeather() async {
        let destination = name.trimmingCharacters(in: .whitespaces)
        guard destination.count >= 2 else {
            weather = nil
            weatherState = .idle
            return
        }
        // Wait until the user stops typing.
        try? await Task.sleep(for: .milliseconds(LaunchOptions.isUITesting ? 100 : 700))
        guard !Task.isCancelled else { return }
        weatherState = .loading
        do {
            let summary = try await WeatherService.lookup(destination, start: start, days: options.days)
            guard !Task.isCancelled else { return }
            weather = summary
            options = summary.apply(to: options)
            weatherState = .idle
        } catch WeatherService.Failure.notFound {
            guard !Task.isCancelled else { return }
            weather = nil
            weatherState = .notFound
        } catch {
            guard !Task.isCancelled else { return }
            weather = nil
            weatherState = .unavailable
        }
    }

    private func apply(_ saved: SavedTemplate) {
        chosenTemplate = saved
        type = saved.type
        var copy = saved.options
        copy.days = options.days
        options = copy
        if name.isEmpty { name = saved.name }
    }

    private func create() {
        TripFactory.makeTrip(name: name, type: type, start: start, options: options, entries: chosenTemplate?.entries,
                             weather: weather, in: context)
        model.pendingNewTrip = nil
        dismiss()
    }
}
