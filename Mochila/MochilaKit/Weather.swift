import Foundation

/// A place found by name ("Roma" → Roma, Italia, 41.89, 12.48).
struct Place: Codable, Sendable, Equatable {
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double

    var title: String { country.isEmpty ? name : "\(name), \(country)" }
}

/// Weather expected during the trip.
struct WeatherSummary: Codable, Sendable, Equatable {
    enum Source: String, Codable, Sendable {
        /// Real forecast (trip within the next 16 days).
        case forecast
        /// What the weather was on the same dates last year (trip further ahead).
        case lastYear
    }

    let place: Place
    let minTemp: Double
    let maxTemp: Double
    /// Highest daily chance of rain (0…100), when the forecast gives it.
    let rainChance: Int?
    /// Total rain over the trip in millimetres.
    let rainMillimetres: Double
    let source: Source
    let fetchedAt: Date

    /// Climate the list should be packed for.
    var climate: Climate {
        let average = (minTemp + maxTemp) / 2
        if maxTemp <= 13 || average <= 9 { return .cold }
        if maxTemp >= 26 || average >= 21 { return .hot }
        return .mild
    }

    var rainLikely: Bool { (rainChance ?? 0) >= 40 || rainMillimetres >= 5 }
    var freezing: Bool { minTemp <= 2 }

    /// "18–27 °C · lluvia 10 %"
    var text: String {
        var parts = ["\(Int(minTemp.rounded()))–\(Int(maxTemp.rounded())) °C"]
        if let rainChance {
            parts.append("lluvia \(rainChance) %")
        } else if rainMillimetres >= 1 {
            parts.append("\(Int(rainMillimetres.rounded())) mm de lluvia")
        } else {
            parts.append("sin lluvia")
        }
        return parts.joined(separator: " · ")
    }

    var sourceText: String {
        switch source {
        case .forecast: "Previsión para tus fechas"
        case .lastYear: "Lo normal: el tiempo de estas fechas el año pasado"
        }
    }

    /// SF Symbol for the weather (rain wins over temperature).
    var symbol: String {
        if rainLikely { return climate == .cold ? "cloud.sleet.fill" : "cloud.rain.fill" }
        return climate.symbol
    }

    /// Where the trip's temperatures sit on a −10…40 °C scale (0…1), for the range bar.
    var rangeOnScale: ClosedRange<Double> {
        func position(_ value: Double) -> Double { min(max((value + 10) / 50, 0), 1) }
        let low = position(minTemp), high = position(maxTemp)
        return min(low, high)...max(low, high)
    }

    /// Short advice for the header ("Hará frío: lleva abrigo").
    var advice: String {
        switch (climate, rainLikely) {
        case (.cold, true): freezing ? "Frío y lluvia, y puede helar: abrígate bien." : "Frío y lluvia: abrigo y chubasquero."
        case (.cold, false): freezing ? "Hará mucho frío y puede helar." : "Hará frío: lleva abrigo."
        case (.mild, true): "Templado con lluvia: no olvides el paraguas."
        case (.mild, false): "Tiempo agradable: lleva una chaqueta ligera."
        case (.hot, true): "Calor con algún chaparrón."
        case (.hot, false): "Hará calor: crema solar y ropa fresca."
        }
    }

    /// Applies the weather to the options (the user can still change them afterwards).
    func apply(to options: TripOptions) -> TripOptions {
        var copy = options
        copy.climate = climate
        copy.rain = rainLikely
        copy.freezing = freezing
        return copy
    }
}

/// Open-Meteo (free, no account): place search, forecast and past weather. Only URLs and parsing here,
/// so it can be tested without network.
enum OpenMeteo {
    /// Forecasts reach 16 days ahead.
    static let forecastDays = 16

    static func geocodingURL(name: String) -> URL? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "es"),
            URLQueryItem(name: "format", value: "json"),
        ]
        return components?.url
    }

    /// Daily weather between two dates: the forecast if they are close, otherwise the same dates a year earlier.
    static func weatherURL(place: Place, start: Date, days: Int, now: Date = .now, calendar: Calendar = .current) -> (URL, WeatherSummary.Source)? {
        let first = calendar.startOfDay(for: start)
        let last = calendar.date(byAdding: .day, value: max(days, 1) - 1, to: first) ?? first
        let today = calendar.startOfDay(for: now)
        let limit = calendar.date(byAdding: .day, value: forecastDays - 1, to: today) ?? today
        let useForecast = first <= limit && last >= today
        let from = useForecast ? max(first, today) : (calendar.date(byAdding: .year, value: -1, to: first) ?? first)
        let to = useForecast ? min(last, limit) : (calendar.date(byAdding: .year, value: -1, to: last) ?? last)
        let host = useForecast ? "https://api.open-meteo.com/v1/forecast" : "https://archive-api.open-meteo.com/v1/archive"
        var daily = "temperature_2m_max,temperature_2m_min,precipitation_sum"
        if useForecast { daily += ",precipitation_probability_max" }
        var components = URLComponents(string: host)
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", place.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", place.longitude)),
            URLQueryItem(name: "daily", value: daily),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "start_date", value: dayString(from, calendar: calendar)),
            URLQueryItem(name: "end_date", value: dayString(to, calendar: calendar)),
        ]
        guard let url = components?.url else { return nil }
        return (url, useForecast ? .forecast : .lastYear)
    }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 2000, parts.month ?? 1, parts.day ?? 1)
    }

    static func parsePlace(_ data: Data) -> Place? {
        struct Response: Decodable {
            struct Result: Decodable {
                let name: String
                let country: String?
                let latitude: Double
                let longitude: Double
            }
            let results: [Result]?
        }
        guard let first = (try? JSONDecoder().decode(Response.self, from: data))?.results?.first else { return nil }
        return Place(name: first.name, country: first.country ?? "", latitude: first.latitude, longitude: first.longitude)
    }

    static func parseWeather(_ data: Data, place: Place, source: WeatherSummary.Source, now: Date = .now) -> WeatherSummary? {
        struct Response: Decodable {
            struct Daily: Decodable {
                let temperature_2m_max: [Double?]
                let temperature_2m_min: [Double?]
                let precipitation_sum: [Double?]?
                let precipitation_probability_max: [Int?]?
            }
            let daily: Daily?
        }
        guard let daily = (try? JSONDecoder().decode(Response.self, from: data))?.daily else { return nil }
        let highs = daily.temperature_2m_max.compactMap { $0 }
        let lows = daily.temperature_2m_min.compactMap { $0 }
        guard let high = highs.max(), let low = lows.min() else { return nil }
        let rain = (daily.precipitation_sum ?? []).compactMap { $0 }.reduce(0, +)
        let chance = (daily.precipitation_probability_max ?? []).compactMap { $0 }.max()
        return WeatherSummary(place: place, minTemp: low, maxTemp: high, rainChance: chance,
                              rainMillimetres: rain, source: source, fetchedAt: now)
    }
}
