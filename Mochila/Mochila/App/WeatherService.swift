import Foundation

/// Looks up the weather at the destination for the trip dates (Open-Meteo, free and without an account).
/// Only the place name and dates are sent; nothing else leaves the iPhone.
enum WeatherService {
    enum Failure: Error, Equatable {
        case notFound, unavailable
    }

    static func lookup(_ destination: String, start: Date, days: Int) async throws -> WeatherSummary {
        let name = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.count >= 2 else { throw Failure.notFound }
        if LaunchOptions.isUITesting { return stub(name) }
        guard let geocoding = OpenMeteo.geocodingURL(name: name) else { throw Failure.notFound }
        let (placeData, _) = try await URLSession.shared.data(from: geocoding)
        guard let place = OpenMeteo.parsePlace(placeData) else { throw Failure.notFound }
        guard let (url, source) = OpenMeteo.weatherURL(place: place, start: start, days: days) else { throw Failure.unavailable }
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let summary = OpenMeteo.parseWeather(data, place: place, source: source) else { throw Failure.unavailable }
        return summary
    }

    /// UI tests never touch the network: Cádiz is hot, everything else is cold and rainy.
    private static func stub(_ name: String) -> WeatherSummary {
        let hot = name.localizedCaseInsensitiveContains("cádiz") || name.localizedCaseInsensitiveContains("cadiz")
        let place = Place(name: hot ? "Cádiz" : name.capitalized, country: hot ? "España" : "", latitude: 36.5, longitude: -6.3)
        return hot
            ? WeatherSummary(place: place, minTemp: 19, maxTemp: 28, rainChance: 5, rainMillimetres: 0, source: .forecast, fetchedAt: .now)
            : WeatherSummary(place: place, minTemp: -2, maxTemp: 7, rainChance: 70, rainMillimetres: 12, source: .lastYear, fetchedAt: .now)
    }
}
