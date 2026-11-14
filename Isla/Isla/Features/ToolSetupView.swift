import MapKit
import SwiftUI
import UIKit

/// One setup screen for every tool: the fields depend on the kind.
struct ToolSetupView: View {
    let kind: ToolKind
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var minutes: Double = 10
    @State private var note = ""
    @State private var lines = ""
    @State private var number = 4
    @State private var number2 = 60
    @State private var amount: Double = 1
    @State private var goal: Double = 0
    @State private var toggle = false
    @State private var date = Date.now.addingTimeInterval(3600)
    @State private var nameA = "Nosotros"
    @State private var nameB = "Ellos"
    @State private var pattern: BreathPattern = .calm
    @State private var city = WorldCities.all[0]
    @State private var target: CLLocationCoordinate2D?
    @State private var photo: Data?
    @State private var showCamera = false
    @State private var saveAsFavorite = false
    @State private var errorText: String?

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: kind.symbol)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(kind.tint)
                        .frame(width: 56, height: 56)
                        .background(kind.tint.opacity(0.16), in: .rect(cornerRadius: 16))
                    Text(kind.summary).font(.subheadline).foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }
            fields
            Section {
                Toggle("Guardar también en favoritos", isOn: $saveAsFavorite)
            } footer: {
                if let errorText { Text(errorText).foregroundStyle(.red) }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Background())
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await start() }
            } label: {
                Label("Empezar en la isla", systemImage: "capsule.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(kind.tint)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .accessibilityIdentifier("setup.start")
        }
        .onAppear(perform: applyDefaults)
        .sheet(isPresented: $showCamera) { CameraPicker(data: $photo).ignoresSafeArea() }
    }

    // MARK: Fields per kind

    @ViewBuilder
    private var fields: some View {
        switch kind {
        case .timer, .appliance, .nap, .movie, .parking, .pill, .charging, .presentation:
            Section("Nombre") { TextField(namePlaceholder, text: $title).accessibilityIdentifier("setup.title") }
            Section(kind == .pill ? "Cada cuánto" : (kind == .movie ? "Cuánto le queda" : "Duración")) {
                PresetRow(values: presets, unit: "min", selection: $minutes)
                Stepper(value: $minutes, in: 1...1440, step: minutes < 10 ? 1 : 5) {
                    Text(durationText(minutes)).monospacedDigit()
                }
            }
            if kind == .charging {
                Section("Batería") {
                    Stepper("Ahora: \(number) %", value: $number, in: 0...95, step: 5)
                    Stepper("Hasta: \(number2) %", value: $number2, in: 10...100, step: 5)
                }
            }
            if kind == .presentation {
                Section("Partes") { Stepper("\(number) partes", value: $number, in: 2...20) }
            }
            if kind == .parking || kind == .timer || kind == .appliance {
                Section("Nota") { TextField(kind == .parking ? "Calle, planta, plaza…" : "Opcional", text: $note) }
            }
        case .flight:
            Section("Vuelo o tren") {
                TextField("Ej. IB3456 a Roma", text: $title)
                DatePicker("Embarque", selection: $date, in: Date.now..., displayedComponents: [.date, .hourAndMinute])
                TextField("Puerta y asiento (ej. Puerta B12 · 14A)", text: $note)
            }
        case .pomodoro:
            Section("Minutos") {
                Stepper("Foco: \(Int(minutes)) min", value: $minutes, in: 5...90, step: 5)
                Stepper("Descanso: \(number) min", value: $number, in: 1...30)
                Stepper("Descanso largo: \(number2) min", value: $number2, in: 5...60, step: 5)
            }
        case .stopwatch, .speed:
            Section("Nombre") { TextField(kind == .speed ? "Correr, bici, paseo…" : "Cronómetro", text: $title) }
        case .sinceLast:
            Section("Qué cuentas") {
                TextField("Toma del bebé, último café…", text: $title).accessibilityIdentifier("setup.title")
                DatePicker("Última vez", selection: $date, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
            }
        case .fasting:
            Section("Plan") {
                Picker("Objetivo", selection: $number) {
                    ForEach([12, 14, 16, 18, 20, 24], id: \.self) { Text("\($0) horas").tag($0) }
                }
                DatePicker("Empezaste", selection: $date, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
            }
        case .counter:
            Section("Contador") {
                TextField("Vasos de agua, cafés, series…", text: $title).accessibilityIdentifier("setup.title")
                Stepper("De \(Fmt.number(amount, money: false)) en \(Fmt.number(amount, money: false))", value: $amount, in: 1...100)
                Stepper(goal == 0 ? "Sin objetivo" : "Objetivo: \(Fmt.number(goal, money: false))", value: $goal, in: 0...10000)
            }
        case .expense:
            Section("Gasto") {
                TextField("Viaje a Lisboa, la noche…", text: $title)
                Stepper(goal == 0 ? "Sin presupuesto" : "Presupuesto: \(Fmt.number(goal, money: true))", value: $goal, in: 0...10000, step: 10)
                TextField("Cantidades rápidas (ej. 5, 10, 20)", text: $lines)
            }
        case .shopping, .task, .recipe, .flashcards, .workout:
            if kind == .workout {
                Section("Series") {
                    Stepper("\(number) series por ejercicio", value: $number, in: 1...10)
                    Stepper("Descanso: \(number2) s", value: $number2, in: 0...300, step: 15)
                }
            }
            Section {
                TextField(listPlaceholder, text: $lines, axis: .vertical)
                    .lineLimit(5...14)
                    .accessibilityIdentifier("setup.lines")
            } header: {
                Text(listHeader)
            } footer: {
                Text(listFooter)
            }
        case .score:
            Section("Equipos") {
                TextField("Equipo A", text: $nameA).accessibilityIdentifier("setup.nameA")
                TextField("Equipo B", text: $nameB).accessibilityIdentifier("setup.nameB")
                Toggle("Pádel o tenis (15-30-40)", isOn: $toggle)
                if toggle { Stepper("Al mejor de \(number * 2 - 1) sets", value: $number, in: 1...3) }
            }
        case .turnClock, .referee:
            Section("Jugadores") {
                TextField("Ana, Leo, Sara…", text: $lines)
                if kind == .turnClock { Stepper("\(Int(minutes)) min cada uno", value: $minutes, in: 1...120) }
            }
        case .postIt:
            Section("Qué quieres tener a la vista") {
                TextField("Pedido 4512, puerta B12, matrícula…", text: $title, axis: .vertical).lineLimit(1...3)
            }
        case .worldClock:
            Section("Ciudad") {
                Picker("Ciudad", selection: $city) {
                    ForEach(WorldCities.all, id: \.self) { Text($0.name).tag($0) }
                }
            }
        case .busStop:
            Section {
                TextField("Nombre de la parada", text: $title)
                MapPicker(target: $target).frame(height: 260).listRowInsets(EdgeInsets())
                Stepper("Avísame a \(number2) m", value: $number2, in: 100...2000, step: 100)
            } header: {
                Text("Toca el mapa en tu parada")
            }
        case .backToCar:
            Section {
                TextField("Planta, plaza, calle…", text: $note)
                Button(photo == nil ? "Hacer una foto del sitio" : "Repetir foto", systemImage: "camera.fill") { showCamera = true }
                if let photo, let image = UIImage(data: photo) {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 160).clipShape(.rect(cornerRadius: 12))
                }
            } header: {
                Text("Se guarda la posición actual del coche")
            }
        case .breathing:
            Section("Respiración") {
                Picker("Ritmo", selection: $pattern) { ForEach(BreathPattern.allCases) { Text($0.title).tag($0) } }
                Stepper("\(Int(minutes)) minutos", value: $minutes, in: 1...20)
            }
        case .nextEvent:
            Section {
                Text("Isla lee tu próxima cita del calendario (en los próximos 7 días) y la cuenta atrás aparece en la isla.")
                    .font(.callout)
            }
        }
    }

    // MARK: Defaults and texts

    private func applyDefaults() {
        guard title.isEmpty && lines.isEmpty else { return }
        switch kind {
        case .timer: minutes = 10
        case .nap: minutes = 20; title = "Siesta"
        case .appliance: minutes = 59; title = "Lavadora"
        case .movie: minutes = 45
        case .parking: minutes = 60; title = "Zona azul"
        case .pill: minutes = 8 * 60
        case .charging: minutes = 90; number = 20; number2 = 80; title = "Coche"
        case .presentation: minutes = 15; number = 5; title = "Presentación"
        case .pomodoro: minutes = 25; number = 5; number2 = 15
        case .fasting: number = 16; date = .now
        case .sinceLast: date = .now
        case .turnClock: minutes = 5
        case .workout: number = 4; number2 = 90
        case .breathing: minutes = 3
        case .flight: date = .now.addingTimeInterval(2 * 3600)
        default: break
        }
    }

    private var presets: [Double] {
        switch kind {
        case .nap: [10, 20, 30, 90]
        case .appliance: [30, 45, 59, 120]
        case .parking: [30, 60, 90, 120]
        case .pill: [240, 360, 480, 720]
        case .movie: [25, 45, 90, 120]
        case .presentation: [5, 10, 15, 30]
        case .charging: [30, 60, 90, 240]
        default: [3, 5, 9, 15, 30]
        }
    }

    private var namePlaceholder: String {
        switch kind {
        case .timer: "Pasta, horno, huevos…"
        case .appliance: "Lavadora, lavavajillas…"
        case .pill: "Ibuprofeno, vitamina D…"
        case .movie: "Nombre de la peli o serie"
        case .charging: "Coche, patinete…"
        default: kind.title
        }
    }

    private var listHeader: String {
        switch kind {
        case .shopping: "Productos (uno por línea)"
        case .recipe: "Pasos (uno por línea)"
        case .flashcards: "Tarjetas"
        case .workout: "Ejercicios (uno por línea)"
        default: "Tareas (una por línea)"
        }
    }

    private var listPlaceholder: String {
        switch kind {
        case .shopping: "Leche\nPan\nTomates"
        case .recipe: "Hervir agua\nCocer la pasta | 9\nSaltear el ajo | 2"
        case .flashcards: "Capital de Italia = Roma\nApple en inglés = manzana"
        case .workout: "Sentadillas\nFlexiones\nPlancha"
        default: "Llamar al dentista\nMandar el informe"
        }
    }

    private var listFooter: String {
        switch kind {
        case .recipe: "Añade «| minutos» a un paso para tener su propio temporizador en la isla."
        case .flashcards: "Escribe «pregunta = respuesta» en cada línea."
        default: "Una por línea. Desde la isla vas pasando a la siguiente."
        }
    }

    private func durationText(_ minutes: Double) -> String {
        let m = Int(minutes)
        return m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min"
    }

    private var listItems: [String] {
        lines.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var people: [String] {
        lines.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    // MARK: Start

    @MainActor
    private func start() async {
        errorText = nil
        let now = Date.now
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let state = await buildState(now: now) else { return }
        let session = model.start(kind, title: name.isEmpty ? defaultTitle : name, state: state)
        if saveAsFavorite { model.addFavorite(name: session.title, kind: kind, state: state) }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }

    private var defaultTitle: String {
        switch kind {
        case .speed: "Actividad"
        case .backToCar: "Tu coche"
        default: kind.title
        }
    }

    @MainActor
    private func buildState(now: Date) async -> ToolState? {
        switch kind {
        case .timer, .appliance, .nap, .movie, .parking, .pill:
            var c = CountdownState(total: minutes * 60, now: now, note: note)
            c.repeats = kind == .pill
            return .countdown(c)
        case .charging:
            var c = CountdownState(total: minutes * 60, now: now)
            c.batteryFrom = number
            c.batteryTo = max(number2, number + 5)
            return .countdown(c)
        case .presentation:
            var c = CountdownState(total: minutes * 60, now: now)
            c.parts = number
            return .countdown(c)
        case .flight:
            guard date > now else { errorText = "La hora de embarque tiene que ser futura."; return nil }
            var c = CountdownState(total: date.timeIntervalSince(now), now: now, note: note)
            c.end = date
            return .countdown(c)
        case .pomodoro:
            return .pomodoro(PomodoroState(work: minutes * 60, shortBreak: Double(number) * 60, longBreak: Double(number2) * 60, phaseEnd: now.addingTimeInterval(minutes * 60)))
        case .stopwatch:
            return .stopwatch(StopwatchState(start: now))
        case .sinceLast:
            return .countUp(CountUpState(start: min(date, now)))
        case .fasting:
            return .countUp(CountUpState(start: min(date, now), goalHours: Double(number)))
        case .counter:
            return .counter(CounterState(value: 0, step: amount, goal: goal))
        case .expense:
            let amounts = lines.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) }
            return .counter(CounterState(value: 0, step: 1, goal: goal, money: true, amounts: amounts.isEmpty ? [5, 10] : amounts))
        case .shopping, .task, .recipe, .flashcards, .workout:
            let items: [StepItem] = listItems.map { line in
                switch kind {
                case .flashcards:
                    let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                    return StepItem(text: parts[0], detail: parts.count > 1 ? parts[1] : "")
                case .recipe:
                    let parts = line.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                    return StepItem(text: parts[0], minutes: parts.count > 1 ? Double(parts[1].replacingOccurrences(of: ",", with: ".")) ?? 0 : 0)
                default:
                    return StepItem(text: line)
                }
            }
            guard !items.isEmpty else { errorText = "Escribe al menos una línea."; return nil }
            var s = StepsState(items: items)
            if kind == .workout { s.sets = number; s.rest = Double(number2) }
            return .steps(s)
        case .score:
            var s = ScoreState(names: [nameA.isEmpty ? "A" : nameA, nameB.isEmpty ? "B" : nameB], racket: toggle)
            s.match.setsToWin = number == 1 ? 1 : (number == 3 ? 3 : 2)
            return .score(s)
        case .turnClock:
            let players = people.count >= 2 ? people : ["Jugador 1", "Jugador 2"]
            return .turnClock(TurnClockState(players: players, remaining: Array(repeating: minutes * 60, count: players.count), turnStart: now))
        case .referee:
            return .referee(RefereeState(players: people))
        case .postIt:
            guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { errorText = "Escribe lo que quieres tener a la vista."; return nil }
            return .note(title)
        case .worldClock:
            title = city.name
            return .worldClock(WorldClockState(timeZone: city.zone, city: city.name))
        case .busStop:
            guard let target else { errorText = "Toca el mapa para marcar tu parada."; return nil }
            model.location?.requestPermission()
            return .location(LocationState(targetLat: target.latitude, targetLon: target.longitude, targetName: title.isEmpty ? "tu parada" : title,
                                           radius: Double(number2), started: now))
        case .backToCar:
            model.location?.requestPermission()
            var state = LocationState(targetName: note, started: now, photo: photo)
            if let here = model.location?.current {
                state.targetLat = here.coordinate.latitude
                state.targetLon = here.coordinate.longitude
            }
            return .location(state)
        case .speed:
            model.location?.requestPermission()
            return .location(LocationState(started: now))
        case .breathing:
            return .breathing(BreathingState(pattern: pattern, start: now, minutes: minutes))
        case .nextEvent:
            guard await CalendarService.requestAccess(), let event = await CalendarService.nextEvent(after: now) else {
                errorText = "No hay citas en los próximos 7 días (o falta permiso del calendario)."
                return nil
            }
            title = event.title
            return .event(event)
        }
    }
}

struct PresetRow: View {
    let values: [Double]
    let unit: String
    @Binding var selection: Double

    var body: some View {
        HStack(spacing: 8) {
            ForEach(values, id: \.self) { value in
                Button {
                    selection = value
                } label: {
                    Text(value >= 60 && value.truncatingRemainder(dividingBy: 60) == 0 ? "\(Int(value / 60)) h" : "\(Int(value)) \(unit)")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .tint(selection == value ? .orange : nil)
            }
        }
    }
}

/// Tap the map to drop the target.
struct MapPicker: View {
    @Binding var target: CLLocationCoordinate2D?
    @State private var position: MapCameraPosition = .userLocation(fallback: .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 40.4168, longitude: -3.7038), span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))))

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                UserAnnotation()
                if let target { Marker("Parada", systemImage: "bus.fill", coordinate: target).tint(.green) }
            }
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) { target = coordinate }
            }
        }
    }
}

struct City: Hashable {
    let name: String
    let zone: String
}

enum WorldCities {
    static let all: [City] = [
        City(name: "Nueva York", zone: "America/New_York"), City(name: "Londres", zone: "Europe/London"),
        City(name: "Madrid", zone: "Europe/Madrid"), City(name: "Canarias", zone: "Atlantic/Canary"),
        City(name: "París", zone: "Europe/Paris"), City(name: "Roma", zone: "Europe/Rome"), City(name: "Berlín", zone: "Europe/Berlin"),
        City(name: "Lisboa", zone: "Europe/Lisbon"), City(name: "Atenas", zone: "Europe/Athens"), City(name: "Estambul", zone: "Europe/Istanbul"),
        City(name: "Moscú", zone: "Europe/Moscow"), City(name: "Dubái", zone: "Asia/Dubai"), City(name: "Bombay", zone: "Asia/Kolkata"),
        City(name: "Bangkok", zone: "Asia/Bangkok"), City(name: "Pekín", zone: "Asia/Shanghai"), City(name: "Tokio", zone: "Asia/Tokyo"),
        City(name: "Seúl", zone: "Asia/Seoul"), City(name: "Sídney", zone: "Australia/Sydney"), City(name: "Auckland", zone: "Pacific/Auckland"),
        City(name: "Los Ángeles", zone: "America/Los_Angeles"), City(name: "Ciudad de México", zone: "America/Mexico_City"),
        City(name: "Bogotá", zone: "America/Bogota"), City(name: "Lima", zone: "America/Lima"), City(name: "Caracas", zone: "America/Caracas"),
        City(name: "Santiago de Chile", zone: "America/Santiago"), City(name: "Buenos Aires", zone: "America/Argentina/Buenos_Aires"),
        City(name: "São Paulo", zone: "America/Sao_Paulo"), City(name: "Miami", zone: "America/New_York"), City(name: "Toronto", zone: "America/Toronto"),
        City(name: "El Cairo", zone: "Africa/Cairo"), City(name: "Marrakech", zone: "Africa/Casablanca"), City(name: "Johannesburgo", zone: "Africa/Johannesburg"),
    ]
}

/// Minimal camera wrapper for the parking photo.
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var data: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                let scale = min(1, 1200 / max(image.size.width, image.size.height))
                let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                parent.data = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }.jpegData(compressionQuality: 0.75)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
