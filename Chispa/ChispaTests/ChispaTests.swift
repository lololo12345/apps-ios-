import Foundation
import SwiftData
import Testing
@testable import Chispa

@Suite("Contenido")
struct ContentTests {
    @Test func riddlesAndTriviaCoverAYear() {
        #expect(RiddleBank.all.count >= 365)
        #expect(TriviaBank.all.count >= 365)
        // Every handwritten line parsed.
        #expect(RiddleBank.all.count == riddlesA.count + riddlesB.count + riddlesC.count + riddlesD.count)
        #expect(trivia.compactMap(QuizItem.init(line:)).count == trivia.count)
    }

    @Test func everyQuizItemHasFourDistinctOptions() {
        for item in RiddleBank.all + TriviaBank.all {
            let options = [item.answer] + item.wrong
            #expect(Set(options).count == 4, "\(item.question)")
            #expect(options.allSatisfy { !$0.isEmpty }, "\(item.question)")
            #expect(!item.explanation.isEmpty, "\(item.question)")
        }
    }

    @Test func noRepeatedQuestions() {
        let questions = (RiddleBank.all + TriviaBank.all).map(\.question)
        #expect(Set(questions).count == questions.count)
    }

    @Test func riddleDoesNotRepeatWithinAYear() {
        let prompts = (1...365).map { DailySet.challenge(.riddle, for: ChallengeDay(number: $0)).prompt }
        #expect(Set(prompts).count == 365)
        let trivia = (1...365).map { DailySet.challenge(.trivia, for: ChallengeDay(number: $0)).prompt }
        #expect(Set(trivia).count == 365)
    }

    @Test func generatedChallengesAreValidForYears() {
        for number in 1...1500 {
            for challenge in DailySet.challenges(for: ChallengeDay(number: number)) {
                switch challenge.body {
                case .choice(let options, let answer):
                    #expect(options.count == 4 && Set(options).count == 4 && options.indices.contains(answer), "\(challenge.id) \(challenge.prompt)")
                case .number(let answer):
                    #expect(answer >= 0, "\(challenge.id) \(challenge.prompt)")
                case .memory(let board):
                    #expect(Set(board.targets).count == board.targets.count && board.targets.allSatisfy { $0 < board.cellCount })
                }
                #expect(!challenge.explanation.isEmpty)
            }
        }
    }
}

@Suite("Días y niveles")
struct DayTests {
    @Test func sameDaySameChallengesEverywhere() {
        let day = ChallengeDay(number: 684)
        #expect(DailySet.challenges(for: day) == DailySet.challenges(for: day))
        #expect(DailySet.challenges(for: day) != DailySet.challenges(for: day.adding(1)))
    }

    @Test func dayNumbersAndWeekdays() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12))!
        let day = ChallengeDay(date: date, calendar: calendar)
        #expect(day.number == 684)
        #expect(day.weekdayIndex == 6) // domingo
        #expect(day.level == .boss)
        #expect(day.adding(1).level == .easy)
        #expect(day.adding(3).level == .medium)
        #expect(day.adding(5).level == .hard)
        #expect(ChallengeDay(number: 1).weekdayIndex == 2) // 1 de enero de 2025, miércoles
        #expect(day.weekStart.number == 678)
        #expect(day.adding(1).weekNumber == day.weekNumber + 1)
    }

    @Test func rotationVisitsEveryItemOncePerCycle() {
        let picks = (1...50).map { Rotation.index(for: ChallengeDay(number: $0), poolSize: 50, salt: 9) }
        #expect(Set(picks).count == 50)
    }
}

@Suite("Puntuación")
struct ScoringTests {
    @Test func fastCorrectAnswerEarnsTheBonus() {
        #expect(Scoring.points(fraction: 1, seconds: 5, usedHint: false, level: .easy) == 150)
        #expect(Scoring.points(fraction: 1, seconds: 90, usedHint: false, level: .easy) == 100)
        #expect(Scoring.points(fraction: 1, seconds: 50, usedHint: false, level: .easy) == 125)
    }

    @Test func hintsAndLevels() {
        #expect(Scoring.points(fraction: 1, seconds: 5, usedHint: true, level: .easy) == 120)
        #expect(Scoring.points(fraction: 1, seconds: 5, usedHint: false, level: .boss) == 300)
        #expect(Scoring.points(fraction: 0, seconds: 5, usedHint: false, level: .boss) == 0)
        #expect(Scoring.points(fraction: 0.5, seconds: 5, usedHint: false, level: .easy) == 50)
        #expect(Scoring.maxPoints(level: .boss) == 1500)
    }

    @Test func outcomes() {
        #expect(Scoring.outcome(fraction: 1, usedHint: false) == .perfect)
        #expect(Scoring.outcome(fraction: 1, usedHint: true) == .assisted)
        #expect(Scoring.outcome(fraction: 0.6, usedHint: false) == .assisted)
        #expect(Scoring.outcome(fraction: 0.2, usedHint: false) == .wrong)
    }

    @Test func memoryStopsAtTheFirstMistake() {
        let ordered = MemoryBoard(columns: 4, rows: 4, targets: [3, 7, 1], ordered: true)
        #expect(MemoryGenerator.fraction(board: ordered, taps: [3, 7, 1]) == 1)
        #expect(MemoryGenerator.fraction(board: ordered, taps: [3, 1, 7]) == 1.0 / 3)
        #expect(MemoryGenerator.isMistake(board: ordered, taps: [3], next: 1))
        let free = MemoryBoard(columns: 4, rows: 4, targets: [3, 7, 1], ordered: false)
        #expect(MemoryGenerator.fraction(board: free, taps: [1, 3, 7]) == 1)
        #expect(MemoryGenerator.fraction(board: free, taps: [1, 9, 7]) == 1.0 / 3)
    }

    @Test func fiftyFiftyKeepsTheAnswer() {
        for number in 1...60 {
            let challenge = DailySet.challenge(.trivia, for: ChallengeDay(number: number))
            guard case .choice(_, let answer) = challenge.body else { continue }
            #expect(challenge.fiftyFiftyRemoved.count == 2)
            #expect(!challenge.fiftyFiftyRemoved.contains(answer))
        }
    }
}

@Suite("Rachas")
struct StreakTests {
    @Test func unfinishedTodayDoesNotBreakTheStreak() {
        #expect(Streaks.compute(completed: [10, 11, 12], today: 13).current == 3)
        #expect(Streaks.compute(completed: [10, 11, 12], today: 14).current == 0)
    }

    @Test func shieldSavesAMissedDay() {
        let state = Streaks.compute(completed: Set(1...7).union([9, 10]), today: 10)
        #expect(state.current == 9)
        #expect(state.savedDays == [8])
        #expect(state.shields == 0)
        #expect(state.best == 9)
    }

    @Test func shieldsAreCappedAndResetWhenTheStreakBreaks() {
        let long = Streaks.compute(completed: Set(1...30), today: 30)
        #expect(long.shields == Streaks.maxShields)
        let broken = Streaks.compute(completed: Set(1...7).union([11]), today: 11)
        #expect(broken.current == 1)
        #expect(broken.shields == 0)
        #expect(broken.best == 7)
    }

    @Test func clockGuard() {
        let now = Date.now
        #expect(!ClockGuard.isClockBehind(now: now, latestSeen: nil))
        #expect(!ClockGuard.isClockBehind(now: now, latestSeen: now.addingTimeInterval(3600)))
        #expect(ClockGuard.isClockBehind(now: now, latestSeen: now.addingTimeInterval(86_400)))
    }
}

@Suite("Códigos de la liga")
struct ShareCodeTests {
    let card = LeagueCard(playerID: "abc123", name: "Lola", week: 97, days: [320, -1, 410, -1, -1, -1, -1], streak: 5,
                          day: 680, grid: "🟩🟨🟥🟩🟩")

    @Test func roundTripInsideAMessage() throws {
        let message = ShareCode.message(for: card, level: .medium)
        #expect(message.contains("Chispa #680"))
        #expect(try ShareCode.decode("Mira esto:\n" + message + "\n¡Gánale!") == card)
        #expect(card.weekTotal == 730)
    }

    @Test func editedCodesAreRejected() {
        let code = ShareCode.encode(card)
        let parts = code.split(separator: ".").map(String.init)
        var forged = card
        forged.days[0] = 9_999
        let forgedPayload = ShareCode.encode(forged).split(separator: ".").map(String.init)[1]
        #expect(throws: ShareCodeError.tampered) { try ShareCode.decode("CH1.\(forgedPayload).\(parts[2])") }
        #expect(throws: ShareCodeError.notFound) { try ShareCode.decode("hola") }
    }
}

@Suite("Partida")
@MainActor
struct StoreTests {
    private func makeStore(now: Date = .now) throws -> GameStore {
        let schema = Schema([ChallengeRecord.self, FriendRecord.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
        let suite = "chispa.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = GameStore(context: ModelContext(container), defaults: defaults, now: now)
        store.playerName = "Test"
        return store
    }

    @Test func oneAttemptPerChallenge() throws {
        let store = try makeStore()
        let challenge = store.todayChallenges[0]
        let start = Date.now
        let record = try #require(store.start(challenge, now: start))
        // Starting again resumes the same attempt.
        #expect(store.start(challenge, now: start.addingTimeInterval(30))?.startedAt == record.startedAt)
        let first = try #require(store.finish(challenge, fraction: 1, usedHint: false, now: start.addingTimeInterval(5)))
        #expect(first.points == Scoring.points(fraction: 1, seconds: 5, usedHint: false, level: challenge.level))
        // A second answer cannot change the result.
        let second = try #require(store.finish(challenge, fraction: 0, usedHint: false, now: start.addingTimeInterval(9)))
        #expect(second.points == first.points)
    }

    @Test func hintCostsEvenIfTheAnswerComesLater() throws {
        let store = try makeStore()
        let challenge = store.todayChallenges[1]
        let start = Date.now
        store.start(challenge, now: start)
        store.markHint(challenge)
        let result = try #require(store.finish(challenge, fraction: 1, usedHint: false, now: start.addingTimeInterval(5)))
        #expect(result.usedHint)
    }

    @Test func completingTheDayUpdatesStreakAndCard() throws {
        let store = try makeStore()
        let start = Date.now
        for challenge in store.todayChallenges {
            store.start(challenge, now: start)
            store.finish(challenge, fraction: 1, usedHint: false, now: start.addingTimeInterval(4))
        }
        #expect(store.todayDone)
        #expect(store.streak.current == 1)
        #expect(store.todayGrid == "🟩🟩🟩🟩🟩")
        let card = store.myCard()
        #expect(card.days[store.today.weekdayIndex] == store.todayPoints)
        #expect(card.grid == store.todayGrid)
    }

    @Test func friendsJoinTheLeagueButNotYourself() throws {
        let store = try makeStore()
        #expect(throws: ImportError.self) { try store.importFriend(from: store.shareMessage) }
        let friendCard = LeagueCard(playerID: "friend-1", name: "Marta", week: store.today.weekNumber,
                                    days: [900, 800, -1, -1, -1, -1, -1], streak: 3, day: store.today.number, grid: "🟩🟩🟩🟩🟩")
        let friend = try store.importFriend(from: ShareCode.message(for: friendCard, level: .easy))
        #expect(friend.name == "Marta")
        #expect(store.leagueRows.count == 2)
        #expect(store.leagueRows.first?.name == "Marta")
        // An older code does not overwrite newer data.
        var old = friendCard
        old.day -= 1
        old.days = [10, -1, -1, -1, -1, -1, -1]
        try store.importFriend(from: ShareCode.encode(old))
        #expect(store.friends.count == 1)
        #expect(store.friends.first?.days.first == 900)
    }
}
