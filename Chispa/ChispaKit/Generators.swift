import Foundation

// MARK: - Maths

enum MathGenerator {
    static func make(day: ChallengeDay, random: inout SeededRandom) -> Challenge {
        let level = day.level
        typealias Maker = (inout SeededRandom) -> (String, Int, String, String)
        let makers: [Maker]
        switch level {
        case .easy: makers = [addition, subtraction, smallProduct, half]
        case .medium: makers = [precedence, percentage, product, story]
        case .hard: makers = [bigPrecedence, percentage, square, story, division]
        case .boss: makers = [chain, bigPercentage, bigProduct, story, square]
        }
        let maker = makers[random.int(0...(makers.count - 1))]
        let (prompt, answer, hint, explanation) = maker(&random)
        return Challenge(day: day, kind: .math, prompt: prompt, body: .number(answer: answer), hint: hint, explanation: explanation)
    }

    private static func addition(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let a = r.int(18...79), b = r.int(14...68)
        return ("¿Cuánto es \(a) + \(b)?", a + b,
                "Suma primero las decenas: \(a / 10 * 10) + \(b / 10 * 10) = \(a / 10 * 10 + b / 10 * 10).",
                "\(a) + \(b) = \(a + b).")
    }

    private static func subtraction(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let a = r.int(61...140), b = r.int(17...58)
        return ("¿Cuánto es \(a) − \(b)?", a - b,
                "Resta \(b / 10 * 10) y después \(b % 10).",
                "\(a) − \(b) = \(a - b).")
    }

    private static func smallProduct(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let a = r.int(6...9), b = r.int(6...12)
        return ("¿Cuánto es \(a) × \(b)?", a * b,
                "\(a) × \(b) es lo mismo que \(a) × \(b - 1) + \(a).",
                "\(a) × \(b) = \(a * b).")
    }

    private static func half(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let n = r.int(31...99) * 2
        return ("¿Cuál es la mitad de \(n)?", n / 2,
                "Parte \(n) en \(n / 10 * 10) y \(n % 10).",
                "\(n) ÷ 2 = \(n / 2).")
    }

    private static func precedence(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let a = r.int(5...30), b = r.int(3...9), c = r.int(3...9)
        return ("¿Cuánto es \(a) + \(b) × \(c)?", a + b * c,
                "Primero la multiplicación: \(b) × \(c).",
                "Se multiplica antes de sumar: \(b) × \(c) = \(b * c), y \(a) + \(b * c) = \(a + b * c).")
    }

    private static func percentage(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let pct = r.pick([10, 20, 25, 50, 75])
        let base = r.int(2...24) * 20
        let answer = base * pct / 100
        return ("¿Cuánto es el \(pct) % de \(base)?", answer,
                "El 10 % de \(base) es \(base / 10).",
                "\(base) × \(pct) ÷ 100 = \(answer).")
    }

    private static func product(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let a = r.int(13...39), b = r.int(3...9)
        return ("¿Cuánto es \(a) × \(b)?", a * b,
                "Descompón: \(a / 10 * 10) × \(b) + \(a % 10) × \(b).",
                "\(a / 10 * 10) × \(b) = \(a / 10 * 10 * b) y \(a % 10) × \(b) = \(a % 10 * b); en total \(a * b).")
    }

    private static func division(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let b = r.int(6...14), q = r.int(12...31)
        return ("¿Cuánto es \(b * q) ÷ \(b)?", q,
                "¿Qué número multiplicado por \(b) da \(b * q)?",
                "\(b) × \(q) = \(b * q), así que \(b * q) ÷ \(b) = \(q).")
    }

    private static func square(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let n = r.int(13...29)
        return ("¿Cuánto es \(n)²?", n * n,
                "\(n)² = \(n) × \(n) = \(n) × \(n / 10 * 10) + \(n) × \(n % 10).",
                "\(n) × \(n) = \(n * n).")
    }

    private static func bigPrecedence(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let a = r.int(4...12), b = r.int(3...9), c = r.int(2...9), d = r.int(2...6)
        let answer = (a + b) * c - d * c
        guard answer >= 0 else { return precedence(&r) }
        return ("¿Cuánto es (\(a) + \(b)) × \(c) − \(d) × \(c)?", answer,
                "Primero el paréntesis y las multiplicaciones; la resta, al final.",
                "(\(a) + \(b)) × \(c) = \((a + b) * c); \(d) × \(c) = \(d * c); \((a + b) * c) − \(d * c) = \(answer).")
    }

    private static func bigPercentage(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let pct = r.pick([15, 35, 45, 60, 85])
        let base = r.int(3...19) * 40
        let answer = base * pct / 100
        return ("¿Cuánto es el \(pct) % de \(base)?", answer,
                "Calcula el 10 % (\(base / 10)) y el 5 % (\(base / 20)) y combínalos.",
                "\(base) × \(pct) ÷ 100 = \(answer).")
    }

    private static func bigProduct(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let a = r.int(21...49), b = r.int(11...19)
        return ("¿Cuánto es \(a) × \(b)?", a * b,
                "\(a) × \(b) = \(a) × 10 + \(a) × \(b - 10).",
                "\(a) × 10 = \(a * 10) y \(a) × \(b - 10) = \(a * (b - 10)); en total \(a * b).")
    }

    private static func chain(_ r: inout SeededRandom) -> (String, Int, String, String) {
        let start = r.int(4...15), add = r.int(3...12), mul = r.int(2...4), sub = r.int(5...20)
        let answer = (start + add) * mul - sub
        return ("Piensa en \(start). Súmale \(add), multiplica por \(mul) y réstale \(sub). ¿Qué número te queda?", answer,
                "Ve paso a paso: \(start) + \(add) = \(start + add).",
                "\(start) + \(add) = \(start + add); × \(mul) = \((start + add) * mul); − \(sub) = \(answer).")
    }

    private static func story(_ r: inout SeededRandom) -> (String, Int, String, String) {
        switch r.int(0...3) {
        case 0:
            let price = r.int(3...9), count = r.int(3...8), paid = 50
            let change = paid - price * count
            guard change >= 0 else { return product(&r) }
            return ("Compras \(count) entradas de \(price) € y pagas con un billete de \(paid) €. ¿Cuántos euros te devuelven?", change,
                    "Primero calcula cuánto cuestan las \(count) entradas.",
                    "\(count) × \(price) = \(price * count) €; \(paid) − \(price * count) = \(change) €.")
        case 1:
            let speed = r.pick([60, 80, 90, 100, 120]), hours = r.int(2...5)
            return ("Un coche va a \(speed) km/h durante \(hours) horas y media. ¿Cuántos kilómetros recorre?", speed * hours + speed / 2,
                    "Media hora a \(speed) km/h son \(speed / 2) km.",
                    "\(speed) × \(hours) = \(speed * hours) km, más \(speed / 2) km de la media hora: \(speed * hours + speed / 2) km.")
        case 2:
            let total = r.int(4...12) * 6
            let third = total / 3
            let gift = r.int(2...5)
            return ("Tienes \(total) caramelos, regalas un tercio y después te comes \(gift). ¿Cuántos te quedan?", total - third - gift,
                    "Un tercio de \(total) es \(third).",
                    "\(total) − \(third) = \(total - third); − \(gift) = \(total - third - gift).")
        default:
            let age = r.int(8...16), diff = r.int(20...34), years = r.int(3...9)
            return ("Lucía tiene \(age) años y su madre \(diff) más. ¿Cuántos años sumarán entre las dos dentro de \(years) años?", 2 * age + diff + 2 * years,
                    "Las dos cumplen \(years) años más.",
                    "Hoy: \(age) + \(age + diff) = \(2 * age + diff). Dentro de \(years) años, cada una tiene \(years) más: \(2 * age + diff + 2 * years).")
        }
    }
}

// MARK: - Logic

enum LogicGenerator {
    static func make(day: ChallengeDay, random: inout SeededRandom) -> Challenge {
        let level = day.level
        var builders: [(inout SeededRandom, Level) -> (String, [String], Int, String)] = [sequence, sequence, weekday, oddOneOut, ranking, clock]
        if level == .easy { builders = [sequence, weekday, oddOneOut, clock] }
        let builder = builders[random.int(0...(builders.count - 1))]
        let (prompt, options, answer, explanation) = builder(&random, level)
        return Challenge(day: day, kind: .logic, prompt: prompt, body: .choice(options: options, answer: answer), hint: "", explanation: explanation)
    }

    /// Places `correct` among three distinct distractors in a shuffled order.
    static func options(correct: String, distractors: [String], random: inout SeededRandom) -> ([String], Int) {
        var unique: [String] = []
        for item in distractors where item != correct && !unique.contains(item) { unique.append(item) }
        let all = random.shuffled([correct] + unique.prefix(3))
        return (all, all.firstIndex(of: correct) ?? 0)
    }

    private static func numberOptions(_ answer: Int, near: [Int], random: inout SeededRandom) -> ([String], Int) {
        var pool = near.filter { $0 != answer && $0 >= 0 }
        var step = 1
        while Set(pool).count < 3 {
            pool.append(answer + step); pool.append(answer - step)
            pool = pool.filter { $0 != answer && $0 >= 0 }
            step += 1
        }
        var seen = Set<Int>()
        let distinct = pool.filter { seen.insert($0).inserted }
        return options(correct: "\(answer)", distractors: distinct.map(String.init), random: &random)
    }

    private static func sequence(_ r: inout SeededRandom, _ level: Level) -> (String, [String], Int, String) {
        var kinds = [0, 1, 2]
        if level.rawValue >= 2 { kinds += [3, 4] }
        if level.rawValue >= 3 { kinds += [5, 6] }
        var terms: [Int] = []
        var answer = 0
        var rule = ""
        switch r.pick(kinds) {
        case 0:
            let start = r.int(2...30), step = r.int(3...12)
            terms = (0..<5).map { start + $0 * step }
            answer = start + 5 * step
            rule = "Cada número suma \(step) al anterior."
        case 1:
            let start = r.int(80...150), step = r.int(4...11)
            terms = (0..<5).map { start - $0 * step }
            answer = start - 5 * step
            rule = "Cada número resta \(step) al anterior."
        case 2:
            let start = r.int(1...5), ratio = r.int(2...3)
            terms = (0..<5).map { start * Int(pow(Double(ratio), Double($0))) }
            answer = start * Int(pow(Double(ratio), 5))
            rule = "Cada número se multiplica por \(ratio)."
        case 3:
            let start = r.int(1...10), step = r.int(1...3)
            var value = start
            for i in 0..<5 { terms.append(value); value += step * (i + 1) }
            answer = value
            rule = "La diferencia crece: +\(step), +\(2 * step), +\(3 * step)… y toca +\(5 * step)."
        case 4:
            let a = r.int(3...9), b = r.int(1...4)
            var value = r.int(1...10)
            for i in 0..<5 { terms.append(value); value += i % 2 == 0 ? a : -b }
            answer = value
            rule = "Se alterna: +\(a), −\(b), +\(a), −\(b)… y ahora toca +\(a)."
        case 5:
            let offset = r.int(1...6)
            terms = (1...5).map { ($0 + offset) * ($0 + offset) }
            answer = (6 + offset) * (6 + offset)
            rule = "Son cuadrados seguidos: \(1 + offset)², \(2 + offset)², \(3 + offset)²… y sigue \(6 + offset)²."
        default:
            let a = r.int(1...4), b = r.int(2...6)
            terms = [a, b]
            while terms.count < 6 { terms.append(terms[terms.count - 1] + terms[terms.count - 2]) }
            answer = terms[5]
            terms = Array(terms.prefix(5))
            rule = "Cada número es la suma de los dos anteriores."
        }
        let last = terms[terms.count - 1], previous = terms[terms.count - 2]
        let (options, index) = numberOptions(answer, near: [answer + 1, answer - 2, last + (last - previous), answer + (last - previous), answer * 2 - last], random: &r)
        let shown = terms.map(String.init).joined(separator: ", ")
        return ("¿Qué número sigue?\n\(shown), …", options, index, rule + " El siguiente es \(answer).")
    }

    static let weekdays = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]

    private static func weekday(_ r: inout SeededRandom, _ level: Level) -> (String, [String], Int, String) {
        let pasts: [(String, Int)] = [("ayer", -1), ("anteayer", -2), ("hace tres días", -3)]
        let futures: [(String, Int)] = [("mañana", 1), ("pasado mañana", 2), ("dentro de cuatro días", 4), ("dentro de una semana", 7), ("dentro de diez días", 10)]
        let (pastText, pastOffset) = r.pick(level == .easy ? Array(pasts.prefix(2)) : pasts)
        let (futureText, futureOffset) = r.pick(level == .easy ? Array(futures.prefix(2)) : futures)
        let pastDay = r.int(0...6)
        let today = ((pastDay - pastOffset) % 7 + 7) % 7
        let answerDay = (today + futureOffset) % 7
        let correct = weekdays[answerDay]
        let distractors = [weekdays[(answerDay + 1) % 7], weekdays[(answerDay + 6) % 7], weekdays[today], weekdays[(answerDay + 2) % 7]]
        let (options, index) = options(correct: correct.capitalized, distractors: distractors.map(\.capitalized), random: &r)
        return ("Si \(pastText) fue \(weekdays[pastDay]), ¿qué día será \(futureText)?", options, index,
                "Si \(pastText) fue \(weekdays[pastDay]), hoy es \(weekdays[today]); \(futureText) será \(correct).")
    }

    private static func oddOneOut(_ r: inout SeededRandom, _ level: Level) -> (String, [String], Int, String) {
        switch r.int(0...3) {
        case 0:
            let m = r.int(6...9)
            var multiples = Set<Int>()
            while multiples.count < 3 { multiples.insert(m * r.int(3...13)) }
            var odd = m * r.int(4...12) + r.int(1...(m - 1))
            while odd % m == 0 { odd += 1 }
            let (options, index) = options(correct: "\(odd)", distractors: multiples.sorted().map(String.init), random: &r)
            return ("¿Qué número no encaja con los demás?", options, index, "Todos son múltiplos de \(m) menos \(odd).")
        case 1:
            let squares = r.shuffled([16, 25, 36, 49, 64, 81, 100, 121, 144]).prefix(3)
            let odd = r.pick([18, 27, 32, 45, 50, 63, 72, 90, 98])
            let (options, index) = options(correct: "\(odd)", distractors: squares.map(String.init), random: &r)
            return ("¿Qué número no encaja con los demás?", options, index, "Todos son cuadrados perfectos menos \(odd).")
        case 2:
            let primes = r.shuffled([11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47]).prefix(3)
            let odd = r.pick([15, 21, 27, 33, 39, 49, 51, 57])
            let (options, index) = options(correct: "\(odd)", distractors: primes.map(String.init), random: &r)
            return ("¿Qué número no encaja con los demás?", options, index, "Todos son números primos menos \(odd), que se puede dividir.")
        default:
            let groups: [([String], String, String)] = [
                (["Marte", "Venus", "Júpiter", "Saturno"], "Luna", "Todos son planetas; la Luna es un satélite."),
                (["Violín", "Viola", "Violonchelo", "Contrabajo"], "Trompeta", "Todos son instrumentos de cuerda menos la trompeta."),
                (["Ballena", "Delfín", "Orca", "Foca"], "Tiburón", "Todos son mamíferos; el tiburón es un pez."),
                (["Rojo", "Azul", "Amarillo"], "Verde", "Rojo, azul y amarillo son los colores primarios tradicionales."),
                (["Cuadrado", "Rombo", "Rectángulo", "Trapecio"], "Triángulo", "Todos tienen cuatro lados menos el triángulo."),
                (["Madrid", "Lisboa", "Roma", "Berlín"], "Barcelona", "Todas son capitales de país menos Barcelona."),
                (["Hierro", "Cobre", "Oro", "Plata"], "Oxígeno", "Todos son metales menos el oxígeno."),
                (["Pingüino", "Avestruz", "Kiwi", "Emú"], "Halcón", "Todas son aves que no vuelan menos el halcón."),
                (["Tomate", "Pepino", "Calabaza", "Pimiento"], "Zanahoria", "Botánicamente, todos son frutos menos la zanahoria, que es una raíz."),
                (["Mercurio", "Venus", "Tierra", "Marte"], "Neptuno", "Todos son planetas rocosos menos Neptuno, que es gaseoso."),
                (["Euro", "Dólar", "Yen", "Libra"], "Bolsa", "Todos son monedas menos la bolsa."),
                (["Agosto", "Enero", "Marzo", "Julio"], "Junio", "Todos tienen 31 días menos junio, que tiene 30."),
            ]
            let (members, odd, why) = r.pick(groups)
            let (options, index) = options(correct: odd, distractors: Array(r.shuffled(members).prefix(3)), random: &r)
            return ("¿Cuál no encaja con los demás?", options, index, why)
        }
    }

    private static func ranking(_ r: inout SeededRandom, _ level: Level) -> (String, [String], Int, String) {
        let names = r.shuffled(["Ana", "Bruno", "Carla", "Dani", "Elena", "Fran", "Gala", "Hugo"])
        let count = level == .boss ? 5 : 4
        let order = Array(names.prefix(count)) // tallest first
        let traits = r.pick([("alto", "alta", "más alto", "altura"), ("rápido", "rápida", "más rápido", "velocidad")])
        func adjective(_ name: String) -> String { ["Ana", "Carla", "Elena", "Gala"].contains(name) ? traits.1 : traits.0 }
        var facts: [String] = []
        for i in 0..<(count - 1) {
            let a = order[i], b = order[i + 1]
            if r.chance(0.5) {
                facts.append("\(a) es más \(adjective(a)) que \(b).")
            } else {
                facts.append("\(b) es menos \(adjective(b)) que \(a).")
            }
        }
        let shuffledFacts = r.shuffled(facts).joined(separator: " ")
        let askSecond = r.chance(0.5)
        let target = askSecond ? 1 : count - 2
        let question = askSecond ? "¿Quién es el segundo en \(traits.3)?" : "¿Quién es el penúltimo en \(traits.3)?"
        let (options, index) = options(correct: order[target], distractors: order.filter { $0 != order[target] }, random: &r)
        return ("\(shuffledFacts)\n\(question)", options, index, "De más a menos: \(order.joined(separator: " > ")).")
    }

    private static func clock(_ r: inout SeededRandom, _ level: Level) -> (String, [String], Int, String) {
        let hour = r.int(6...22), minute = r.int(0...11) * 5
        let add = level == .easy ? r.int(2...9) * 10 : r.int(9...40) * 5
        let total = (hour * 60 + minute + add) % (24 * 60)
        func format(_ m: Int) -> String { String(format: "%d:%02d", ((m % 1440) + 1440) % 1440 / 60, ((m % 1440) + 1440) % 1440 % 60) }
        let correct = format(total)
        let distractors = [format(total + 10), format(total - 10), format(total + 60), format(total - 60), format(total + 30)]
        let (options, index) = options(correct: correct, distractors: r.shuffled(distractors), random: &r)
        let start = format(hour * 60 + minute)
        let duration = add >= 60 ? "\(add / 60) h \(add % 60) min" : "\(add) min"
        return ("Son las \(start). ¿Qué hora será dentro de \(add) minutos?", options, index, "\(add) minutos son \(duration): \(start) + \(duration) = \(correct).")
    }
}

// MARK: - Memory

enum MemoryGenerator {
    static func make(day: ChallengeDay, random: inout SeededRandom) -> Challenge {
        let (columns, rows, count, ordered): (Int, Int, Int, Bool)
        switch day.level {
        case .easy: (columns, rows, count, ordered) = (4, 4, 5, false)
        case .medium: (columns, rows, count, ordered) = (4, 5, 7, false)
        case .hard: (columns, rows, count, ordered) = (4, 5, 5, true)
        case .boss: (columns, rows, count, ordered) = (5, 5, 7, true)
        }
        let targets = Array(random.shuffled(Array(0..<(columns * rows))).prefix(count))
        let board = MemoryBoard(columns: columns, rows: rows, targets: targets, ordered: ordered)
        let prompt = ordered
            ? "Se encenderán \(count) casillas una tras otra. Tócalas en el mismo orden."
            : "Memoriza las \(count) casillas que se iluminan y tócalas cuando se apaguen."
        return Challenge(day: day, kind: .memory, prompt: prompt, body: .memory(board), hint: "",
                         explanation: ordered ? "El orden contaba: un fallo termina el reto." : "Un fallo termina el reto; cada casilla acertada suma.")
    }

    /// Fraction of the pattern reproduced: taps stop at the first mistake.
    static func fraction(board: MemoryBoard, taps: [Int]) -> Double {
        var correct = 0
        var remaining = Set(board.targets)
        for (i, tap) in taps.enumerated() {
            if board.ordered {
                guard i < board.targets.count, board.targets[i] == tap else { break }
            } else {
                guard remaining.contains(tap) else { break }
                remaining.remove(tap)
            }
            correct += 1
        }
        return Double(correct) / Double(board.targets.count)
    }

    /// Whether a tap is a mistake given the previous (correct) taps.
    static func isMistake(board: MemoryBoard, taps: [Int], next: Int) -> Bool {
        if board.ordered { return taps.count >= board.targets.count || board.targets[taps.count] != next }
        return !board.targets.contains(next) || taps.contains(next)
    }
}

// MARK: - Daily set

enum DailySet {
    static func challenges(for day: ChallengeDay) -> [Challenge] {
        ChallengeKind.allCases.map { challenge($0, for: day) }
    }

    static func challenge(_ kind: ChallengeKind, for day: ChallengeDay) -> Challenge {
        var random = SeededRandom(seed: day.seed ^ UInt64(kind.rawValue.hashValueStable))
        switch kind {
        case .riddle: return RiddleBank.challenge(for: day, random: &random)
        case .trivia: return TriviaBank.challenge(for: day, random: &random)
        case .math: return MathGenerator.make(day: day, random: &random)
        case .memory: return MemoryGenerator.make(day: day, random: &random)
        case .logic: return LogicGenerator.make(day: day, random: &random)
        }
    }
}

extension String {
    /// FNV-1a: unlike `hashValue`, the same on every launch and every device.
    var hashValueStable: UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
        return hash
    }
}

/// A multiple-choice item written by hand (riddles and trivia).
struct QuizItem: Sendable, Hashable {
    let question: String
    let answer: String
    let wrong: [String]
    let explanation: String

    /// "pregunta|correcta|mala|mala|mala|explicación"
    init?(line: String) {
        let parts = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 6 else { return nil }
        question = parts[0]; answer = parts[1]; wrong = Array(parts[2...4]); explanation = parts[5]
    }

    init(question: String, answer: String, wrong: [String], explanation: String) {
        self.question = question; self.answer = answer; self.wrong = wrong; self.explanation = explanation
    }

    func challenge(kind: ChallengeKind, day: ChallengeDay, random: inout SeededRandom) -> Challenge {
        let options = random.shuffled([answer] + wrong)
        return Challenge(day: day, kind: kind, prompt: question,
                         body: .choice(options: options, answer: options.firstIndex(of: answer) ?? 0),
                         hint: "", explanation: explanation)
    }
}

enum RiddleBank {
    static let all: [QuizItem] = (riddlesA + riddlesB + riddlesC + riddlesD).compactMap(QuizItem.init(line:))

    static func challenge(for day: ChallengeDay, random: inout SeededRandom) -> Challenge {
        all[Rotation.index(for: day, poolSize: all.count, salt: 0xA11CE)].challenge(kind: .riddle, day: day, random: &random)
    }
}

enum TriviaBank {
    static let all: [QuizItem] = trivia.compactMap(QuizItem.init(line:)) + TriviaTables.generated

    static func challenge(for day: ChallengeDay, random: inout SeededRandom) -> Challenge {
        all[Rotation.index(for: day, poolSize: all.count, salt: 0x7121A)].challenge(kind: .trivia, day: day, random: &random)
    }
}
