import CoreLocation
import EventKit
import Foundation
import UserNotifications

/// Background location for «Avísame en mi parada», «Volver al coche» and «Velocidad y distancia».
@MainActor
final class LocationTracker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private weak var model: AppModel?
    private var tracked: Set<UUID> = []
    private var lastLocation: CLLocation?
    private(set) var current: CLLocation?

    init(model: AppModel) {
        self.model = model
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        for session in model.sessions { if case .location = session.state { tracked.insert(session.id) } }
        if !tracked.isEmpty { run() }
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func begin(_ id: UUID) {
        tracked.insert(id)
        run()
    }

    func end(_ id: UUID) {
        tracked.remove(id)
        if tracked.isEmpty {
            manager.stopUpdatingLocation()
            manager.stopUpdatingHeading()
        }
    }

    private func run() {
        manager.requestAlwaysAuthorization()
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.allowsBackgroundLocationUpdates = true
            manager.showsBackgroundLocationIndicator = true
        }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.apply(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in self.applyHeading(heading) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in if !self.tracked.isEmpty { self.run() } }
    }

    private func apply(_ location: CLLocation) {
        guard let model, location.horizontalAccuracy >= 0, location.horizontalAccuracy < 100 else { return }
        let step = lastLocation.map { location.distance(from: $0) } ?? 0
        lastLocation = location
        current = location
        for id in tracked {
            model.update(id) { session in
                guard case .location(var l) = session.state else { return }
                if session.kind == .backToCar && l.targetLat == nil {
                    l.targetLat = location.coordinate.latitude
                    l.targetLon = location.coordinate.longitude
                }
                if step < 200 { l.travelled += step }
                l.speed = max(0, location.speed)
                if let lat = l.targetLat, let lon = l.targetLon {
                    l.distance = Geo.distance(location.coordinate.latitude, location.coordinate.longitude, lat, lon)
                    l.bearing = Geo.bearing(location.coordinate.latitude, location.coordinate.longitude, lat, lon)
                    if session.kind == .busStop, !l.alerted, let distance = l.distance, distance <= l.radius {
                        l.alerted = true
                        Notifier.now("¡Tu parada!", "Estás a \(Geo.format(distance)) de \(l.targetName). Prepárate para bajar.")
                    }
                }
                session.state = .location(l)
            }
        }
    }

    private func applyHeading(_ heading: Double) {
        guard let model else { return }
        for id in tracked where model.session(id)?.kind == .backToCar {
            model.update(id) { session in
                guard case .location(var l) = session.state else { return }
                // Only refresh the arrow when it turned noticeably (Live Activity updates are budgeted).
                if let old = l.heading, abs(old - heading) < 15 { return }
                l.heading = heading
                session.state = .location(l)
            }
        }
    }
}

enum Notifier {
    /// Immediate time-sensitive notification (e.g. arriving at your stop).
    static func now(_ title: String, _ body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}

/// Next calendar events for «Próxima cita».
enum CalendarService {
    static func requestAccess() async -> Bool {
        (try? await EKEventStore().requestFullAccessToEvents()) ?? false
    }

    static func nextEvent(after date: Date) async -> EventState? {
        let store = EKEventStore()
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return nil }
        let end = Calendar.current.date(byAdding: .day, value: 7, to: date) ?? date
        let predicate = store.predicateForEvents(withStart: date.addingTimeInterval(1), end: end, calendars: nil)
        let event = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.startDate > date }
            .sorted { $0.startDate < $1.startDate }
            .first
        return event.map { EventState(title: $0.title ?? "Cita", start: $0.startDate, location: $0.location ?? "", identifier: $0.eventIdentifier ?? "") }
    }
}
