import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// What a friend sees of you: your name, your points this week and today's grid.
struct LeagueCard: Codable, Sendable, Equatable {
    /// Random id created on first launch, so a friend who changes name keeps the same row.
    var playerID: String
    var name: String
    /// Week identifier (`ChallengeDay.weekNumber`).
    var week: Int
    /// Points Monday…Sunday; -1 = not played.
    var days: [Int]
    var streak: Int
    /// Day the card was made and its grid ("🟩🟨🟥…").
    var day: Int
    var grid: String

    var weekTotal: Int { days.filter { $0 > 0 }.reduce(0, +) }

    enum CodingKeys: String, CodingKey {
        case playerID = "i", name = "n", week = "w", days = "d", streak = "s", day = "k", grid = "g"
    }
}

enum ShareCodeError: Error, Equatable {
    case notFound, damaged, tampered
}

/// Codes look like `CH1.<datos>.<firma>`: the data travel in base64 and a signature stops anyone from editing
/// their points by hand. (It is not unbreakable: the key ships inside the app.)
enum ShareCode {
    static let prefix = "CH1"
    private static let key = Array("chispa·liga·amigos·2026·🔥".utf8)

    static func encode(_ card: LeagueCard) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = (try? encoder.encode(card)) ?? Data()
        let payload = base64URL(data)
        return "\(prefix).\(payload).\(signature(payload))"
    }

    /// Finds a code anywhere in a pasted message and checks it.
    static func decode(_ text: String) throws -> LeagueCard {
        guard let range = text.range(of: #"CH1\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+"#, options: .regularExpression) else {
            throw ShareCodeError.notFound
        }
        let parts = text[range].split(separator: ".").map(String.init)
        guard parts.count == 3 else { throw ShareCodeError.damaged }
        guard signature(parts[1]) == parts[2] else { throw ShareCodeError.tampered }
        guard let data = fromBase64URL(parts[1]), let card = try? JSONDecoder().decode(LeagueCard.self, from: data),
              card.days.count == 7, !card.name.isEmpty else { throw ShareCodeError.damaged }
        return card
    }

    /// Message for WhatsApp & co.: readable on top, code at the end.
    static func message(for card: LeagueCard, level: Level) -> String {
        let today = card.day
        let todayPoints = card.days[ChallengeDay(number: today).weekdayIndex]
        var lines = ["⚡ Chispa #\(today) · \(level.label)", card.grid]
        if todayPoints >= 0 { lines.append("\(todayPoints) puntos hoy · \(card.weekTotal) esta semana") }
        if card.streak > 0 { lines.append("🔥 Racha de \(card.streak) \(card.streak == 1 ? "día" : "días")") }
        lines.append("")
        lines.append("Añádeme a tu liga en Chispa pegando este código:")
        lines.append(encode(card))
        return lines.joined(separator: "\n")
    }

    static func signature(_ payload: String) -> String {
        #if canImport(CryptoKit)
        let mac = HMAC<SHA256>.authenticationCode(for: Array(payload.utf8), using: SymmetricKey(data: key))
        return base64URL(Data(Array(mac).prefix(9)))
        #else
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in key + Array(payload.utf8) { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        return base64URL(withUnsafeBytes(of: hash.bigEndian) { Data($0) })
        #endif
    }

    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func fromBase64URL(_ text: String) -> Data? {
        var base = text.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base.count % 4 != 0 { base += "=" }
        return Data(base64Encoded: base)
    }
}
