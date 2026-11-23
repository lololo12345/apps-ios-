import SwiftData
import SwiftUI

/// The packing list of one trip.
struct TripView: View {
    @Bindable var trip: Trip
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var showAdd = false
    @State private var showSaveTemplate = false
    @State private var templateName = ""
    @State private var celebrate = false
    @State private var confirmDelete = false
    @State private var checks = 0
    @State private var refreshing = false
    @State private var weatherMessage: String?
    @State private var suggestions: [PackEntry] = []

    private var tint: Color { trip.type.tint }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                weatherSection
                modePicker
                filterRow
                let sections = visibleSections
                if sections.isEmpty {
                    emptyFiltered
                } else {
                    ForEach(sections, id: \.category) { section in
                        categoryCard(section.category, items: section.items, all: section.all)
                    }
                }
                addButton
                // Last thing before leaving: close the windows, take out the rubbish…
                if !trip.returnMode && !trip.tasks.isEmpty && search.isEmpty {
                    tasksCard
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 32)
            .animation(.smooth(duration: 0.35), value: model.hidePacked)
            .animation(.smooth(duration: 0.35), value: trip.returnMode)
            .animation(.smooth(duration: 0.35), value: suggestions)
        }
        .screenBackground(glow: tint)
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Buscar en la lista")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Compartir la lista")
                .accessibilityIdentifier("shareList")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Guardar como plantilla", systemImage: "square.stack.3d.up.fill") {
                        templateName = "Mi lista de \(trip.type.title.lowercased())"
                        showSaveTemplate = true
                    }
                    Button("Duplicar viaje", systemImage: "plus.square.on.square") {
                        TripFactory.duplicate(trip, in: context)
                    }
                    Button("Desmarcar todo", systemImage: "arrow.counterclockwise") { uncheckAll() }
                    Divider()
                    Button("Borrar viaje", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Más opciones")
                .accessibilityIdentifier("tripMenu")
            }
        }
        .sheet(isPresented: $showAdd) {
            AddItemSheet(trip: trip)
                .presentationDetents([.medium])
        }
        .alert("Guardar como plantilla", isPresented: $showSaveTemplate) {
            TextField("Nombre", text: $templateName)
            Button("Guardar") {
                TripFactory.saveTemplate(from: trip, name: templateName.isEmpty ? trip.name : templateName, in: context)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("La encontrarás en Plantillas para tu próximo viaje.")
        }
        .confirmationDialog("¿Borrar «\(trip.name)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Borrar viaje y su lista", role: .destructive) {
                dismiss()
                context.delete(trip)
                try? context.save()
            }
        }
        .overlay {
            if celebrate {
                ReadyCelebration(
                    title: trip.returnMode ? "¡Todo de vuelta!" : "¡Mochila lista!",
                    subtitle: trip.returnMode ? "No te dejas nada. Buen regreso a casa." : "Tienes todo lo de \(trip.name). ¡Buen viaje!"
                ) {
                    withAnimation(.smooth) { celebrate = false }
                }
                .transition(.opacity)
            }
        }
        .sensoryFeedback(.selection, trigger: checks) { _, _ in model.hapticsOn }
        .sensoryFeedback(.success, trigger: celebrate) { _, new in new && model.hapticsOn }
    }

    // MARK: Header

    private var header: some View {
        let progress = trip.progress
        return HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    TypeBadge(type: trip.type, size: 40)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trip.type.title).font(.caption.weight(.heavy)).foregroundStyle(tint)
                        Text(trip.dateText).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(trip.countdown)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text(statusText(progress))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("tripStatus")
            }
            Spacer(minLength: 8)
            ProgressRing(progress: progress, tint: tint, size: 84, lineWidth: 9)
                .accessibilityIdentifier("tripProgress")
        }
        .card(tint: tint)
        .padding(.top, 4)
    }

    // MARK: Weather

    @ViewBuilder
    private var weatherSection: some View {
        if let weather = trip.weather {
            WeatherPanel(weather: weather, tint: tint, refreshing: refreshing) { Task { await refreshWeather() } }
                .accessibilityIdentifier("tripWeather")
        } else if !trip.isOver {
            Button {
                Task { await refreshWeather() }
            } label: {
                Label(refreshing ? "Mirando el tiempo…" : "¿Qué tiempo hará en \(trip.name)?", systemImage: "cloud.sun.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .disabled(refreshing)
            .accessibilityIdentifier("refreshWeather")
        }
        if let weatherMessage {
            Label(weatherMessage, systemImage: "info.circle.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .transition(.opacity)
        }
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Con este tiempo te sugiero añadir", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Palette.secondary)
                Text(suggestions.map(\.label).joined(separator: ", "))
                    .font(.subheadline)
                HStack {
                    Button("Ahora no") { withAnimation(.smooth) { suggestions = [] } }
                        .buttonStyle(.glass)
                    Button("Añadir \(suggestions.count)") {
                        TripFactory.addEntries(suggestions, to: trip, in: context)
                        withAnimation(.smooth) { suggestions = [] }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(Palette.secondary)
                    .accessibilityIdentifier("addSuggestions")
                }
            }
            .card(tint: Palette.secondary)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func refreshWeather() async {
        refreshing = true
        defer { refreshing = false }
        do {
            let summary = try await WeatherService.lookup(trip.weather?.place.name ?? trip.name, start: trip.startDate, days: trip.days)
            let missing = TripFactory.updateWeather(trip, with: summary)
            try? context.save()
            withAnimation(.smooth) {
                suggestions = missing
                weatherMessage = missing.isEmpty ? "Tu lista ya está preparada para este tiempo." : nil
            }
        } catch WeatherService.Failure.notFound {
            withAnimation(.smooth) { weatherMessage = "No encuentro «\(trip.name)» en el mapa: el tiempo no se puede consultar." }
        } catch {
            withAnimation(.smooth) { weatherMessage = "No he podido consultar el tiempo. Inténtalo con conexión." }
        }
    }

    private func statusText(_ progress: PackProgress) -> String {
        if trip.returnMode {
            return progress.isComplete ? "Todo de vuelta en la maleta." : "Vuelta a casa: te quedan \(progress.remaining) por recoger."
        }
        if progress.isComplete { return "¡Mochila lista!" }
        return "Te \(progress.remaining == 1 ? "falta" : "faltan") \(progress.remaining) \(progress.remaining == 1 ? "cosa" : "cosas") de \(progress.total)."
    }

    private var modePicker: some View {
        HStack(spacing: 8) {
            GlassChip(title: "Ida", systemImage: "suitcase.rolling.fill", selected: !trip.returnMode, tint: tint) {
                trip.returnMode = false
            }
            .accessibilityIdentifier("mode.going")
            GlassChip(title: "Vuelta", systemImage: "house.fill", selected: trip.returnMode, tint: tint) {
                trip.returnMode = true
            }
            .accessibilityIdentifier("mode.return")
        }
    }

    private var filterRow: some View {
        @Bindable var model = model
        return Toggle(isOn: $model.hidePacked) {
            Label("Ocultar lo guardado", systemImage: "eye.slash")
                .font(.subheadline.weight(.medium))
        }
        .tint(tint)
        .padding(.horizontal, 4)
        .accessibilityIdentifier("hidePacked")
    }

    // MARK: Lists

    private struct CategoryGroup {
        let category: PackCategory
        let items: [PackItem]
        let all: [PackItem]
    }

    private var visibleSections: [CategoryGroup] {
        let query = search.trimmingCharacters(in: .whitespaces)
        let grouped = Dictionary(grouping: trip.things, by: \.category)
        return PackCategory.allCases.compactMap { category in
            guard let all = grouped[category] else { return nil }
            let shown = all.filter { item in
                (query.isEmpty || item.name.localizedStandardContains(query))
                    && !(model.hidePacked && isDone(item))
            }
            return shown.isEmpty ? nil : CategoryGroup(category: category, items: shown, all: all)
        }
    }

    private func isDone(_ item: PackItem) -> Bool { trip.returnMode ? item.packedBack : item.packed }

    private func categoryCard(_ category: PackCategory, items: [PackItem], all: [PackItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(category.title, systemImage: category.symbol)
                    .font(.headline)
                    .foregroundStyle(tint)
                Spacer()
                Text("\(all.filter(isDone).count)/\(all.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)
            ForEach(items) { item in
                ItemRow(item: item, done: isDone(item), tint: tint) { toggle(item) }
                    .contextMenu {
                        Button("Borrar de la lista", systemImage: "trash", role: .destructive) {
                            withAnimation(.smooth) { context.delete(item) }
                            try? context.save()
                        }
                    }
                if item.id != items.last?.id { Divider().opacity(0.5) }
            }
        }
        .card()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var tasksCard: some View {
        let tasks = trip.tasks
        let progress = trip.tasksProgress
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(PackCategory.beforeLeaving.title, systemImage: PackCategory.beforeLeaving.symbol)
                    .font(.headline)
                    .foregroundStyle(Palette.secondary)
                Spacer()
                Text(progress.text)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 4)
            ForEach(tasks.filter { !(model.hidePacked && $0.packed) }) { task in
                ItemRow(item: task, done: task.packed, tint: Palette.secondary, isTask: true) {
                    task.packed.toggle()
                    checks += 1
                    try? context.save()
                }
                if task.id != tasks.last?.id { Divider().opacity(0.5) }
            }
        }
        .card(tint: Palette.secondary)
    }

    private var emptyFiltered: some View {
        VStack(spacing: 8) {
            Image(systemName: search.isEmpty ? "checkmark.circle.fill" : "magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(tint)
            Text(search.isEmpty ? "Todo guardado" : "No hay nada con «\(search)»")
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var addButton: some View {
        Button {
            showAdd = true
        } label: {
            Label("Añadir algo a la lista", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glass)
        .accessibilityIdentifier("addItem")
    }

    // MARK: Actions

    private func toggle(_ item: PackItem) {
        let wasComplete = trip.progress.isComplete
        withAnimation(.snappy(duration: 0.25)) {
            if trip.returnMode { item.packedBack.toggle() } else { item.packed.toggle() }
        }
        checks += 1
        try? context.save()
        if !wasComplete && trip.progress.isComplete {
            withAnimation(.spring(duration: 0.5)) { celebrate = true }
        }
    }

    private func uncheckAll() {
        withAnimation(.smooth) {
            for item in trip.items {
                if trip.returnMode { item.packedBack = false } else { item.packed = false }
            }
        }
        try? context.save()
    }

    private var shareText: String {
        PackingShare.text(
            title: trip.name,
            subtitle: "\(trip.type.title) · \(trip.dateText)",
            entries: trip.sortedItems.map { ($0.entry, trip.returnMode ? $0.packedBack : $0.packed) }
        )
    }
}

/// One line: big check, name, note and quantity.
struct ItemRow: View {
    let item: PackItem
    let done: Bool
    let tint: Color
    var isTask = false
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: done ? (isTask ? "checkmark.square.fill" : "checkmark.circle.fill") : (isTask ? "square" : "circle"))
                    .font(.title2)
                    .foregroundStyle(done ? tint : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .strikethrough(done, color: .secondary)
                        .foregroundStyle(done ? .secondary : .primary)
                    if let note = item.note, !done {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                if let quantity = item.quantity {
                    Text("×\(quantity)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.tint(tint.opacity(done ? 0.1 : 0.25)), in: .capsule)
                        .opacity(done ? 0.6 : 1)
                }
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityValue(done ? "Hecho" : "Pendiente")
        .accessibilityIdentifier("item.\(item.name)")
    }
}

/// Add something that is not on the list.
struct AddItemSheet: View {
    let trip: Trip
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: PackCategory = .extras
    @State private var quantity = 1
    @State private var counts = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("¿Qué quieres añadir?", text: $name)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .accessibilityIdentifier("newItemName")
                Picker("Categoría", selection: $category) {
                    ForEach(PackCategory.allCases.filter { $0 != .beforeLeaving }) { item in
                        Label(item.title, systemImage: item.symbol).tag(item)
                    }
                    Label(PackCategory.beforeLeaving.title, systemImage: PackCategory.beforeLeaving.symbol).tag(PackCategory.beforeLeaving)
                }
                Toggle("Llevar varios", isOn: $counts)
                if counts {
                    Stepper("Cantidad: \(quantity)", value: $quantity, in: 1...30)
                }
            }
            .navigationTitle("Añadir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Añadir", systemImage: "checkmark", action: add)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("confirmAddItem")
                }
            }
            .onAppear { focused = true }
        }
    }

    private func add() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        TripFactory.addItem(PackEntry(String(trimmed.prefix(60)), category, quantity: counts ? quantity : nil), to: trip, in: context)
        dismiss()
    }
}
