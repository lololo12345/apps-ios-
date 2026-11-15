import Foundation
import Testing
@testable import Isla

private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

private func session(_ kind: ToolKind, _ state: ToolState, title: String = "Prueba") -> ToolSession {
    ToolSession(kind: kind, title: title, state: state)
}

@Suite("Catálogo")
struct CatalogTests {
    @Test func thirtyToolsWithEverythingFilledIn() {
        #expect(ToolKind.allCases.count == 30)
        for kind in ToolKind.allCases {
            #expect(!kind.title.isEmpty && !kind.summary.isEmpty && !kind.symbol.isEmpty, "\(kind)")
        }
        #expect(Set(ToolKind.allCases.map(\.title)).count == 30)
        for category in ToolCategory.allCases {
            #expect(ToolKind.allCases.contains { $0.category == category }, "\(category)")
        }
    }
}

@Suite("Temporizadores")
struct CountdownTests {
    @Test func pauseResumeAndPlusOne() {
        var s = session(.timer, .countdown(CountdownState(total: 600, now: t0)))
        #expect(s.display(now: t0.addingTimeInterval(60)).timer?.end == t0.addingTimeInterval(600))
        _ = s.handle("pause", now: t0.addingTimeInterval(100))
        #expect(s.display(now: t0.addingTimeInterval(400)).timer?.frozen == 500)
        _ = s.handle("resume", now: t0.addingTimeInterval(400))
        guard case .countdown(var c) = s.state else { Issue.record("state"); return }
        #expect(c.end == t0.addingTimeInterval(900))
        _ = s.handle("plus1", now: t0.addingTimeInterval(400))
        guard case .countdown(let c2) = s.state else { return }
        c = c2
        #expect(c.end == t0.addingTimeInterval(960))
        #expect(c.total == 660)
    }

    @Test func finishedTimerOffersRestart() {
        var s = session(.timer, .countdown(CountdownState(total: 60, now: t0)), title: "Pasta")
        let done = s.display(now: t0.addingTimeInterval(61))
        #expect(done.finished && done.headline == "Se acabó el tiempo" && done.detail == "Pasta")
        #expect(done.buttons.map(\.id) == ["restart", "stop"])
        _ = s.handle("restart", now: t0.addingTimeInterval(70))
        #expect(!s.display(now: t0.addingTimeInterval(80)).finished)
        let keepsRunning = s.handle("stop", now: t0)
        #expect(!keepsRunning)
    }

    @Test func pillRestartsWhenTaken() {
        var s = session(.pill, .countdown(CountdownState(total: 8 * 3600, now: t0)))
        _ = s.handle("taken", now: t0.addingTimeInterval(9 * 3600))
        guard case .countdown(let c) = s.state else { return }
        #expect(c.end == t0.addingTimeInterval(17 * 3600))
    }

    @Test func presentationPace() {
        var c = CountdownState(total: 600, now: t0)
        c.parts = 5
        var s = session(.presentation, .countdown(c))
        #expect(s.display(now: t0.addingTimeInterval(300)).detail?.contains("deberías ir por la 3") == true)
        _ = s.handle("nextPart", now: t0); _ = s.handle("nextPart", now: t0)
        #expect(s.display(now: t0.addingTimeInterval(300)).detail?.contains("vas bien") == true)
    }

    @Test func parkingWarnsTenMinutesBefore() {
        let s = session(.parking, .countdown(CountdownState(total: 3600, now: t0)))
        #expect(s.alertDate(now: t0)?.date == t0.addingTimeInterval(3000))
    }
}

@Suite("Foco, cronómetro y contadores")
struct OtherToolsTests {
    @Test func pomodoroCyclesWithLongBreakEveryFour() {
        var p = PomodoroState(phaseEnd: t0.addingTimeInterval(1500))
        var phases: [PomodoroState.Phase] = []
        for _ in 0..<8 {
            p.advance(now: t0)
            phases.append(p.phase)
        }
        #expect(phases == [.shortBreak, .work, .shortBreak, .work, .shortBreak, .work, .longBreak, .work])
        #expect(p.completed == 4)
        // Ended while the app was closed: the island offers the next phase.
        let ended = session(.pomodoro, .pomodoro(PomodoroState(phaseEnd: t0)))
        #expect(ended.display(now: t0.addingTimeInterval(5)).headline == "¡Descanso!")
        #expect(ended.display(now: t0.addingTimeInterval(5)).buttons.map(\.id) == ["skip"])
    }

    @Test func shortTeamNamesAndRelevance() {
        #expect(ToolSession.short("Los Galácticos") == "Los")
        #expect(ToolSession.short("Supercalifragilístico") == "Supercal.")
        let soon = session(.timer, .countdown(CountdownState(total: 60, now: t0)))
        let later = session(.timer, .countdown(CountdownState(total: 3600, now: t0)))
        #expect(soon.relevance(now: t0) > later.relevance(now: t0))
        #expect(session(.postIt, .note("x")).relevance(now: t0) < later.relevance(now: t0))
    }

    @Test func stopwatchLaps() {
        var s = session(.stopwatch, .stopwatch(StopwatchState(start: t0)))
        _ = s.handle("lap", now: t0.addingTimeInterval(65))
        _ = s.handle("lap", now: t0.addingTimeInterval(125))
        guard case .stopwatch(let w) = s.state else { return }
        #expect(w.laps == [65, 60])
        #expect(s.display(now: t0).detail?.contains("Vuelta 3") == true)
    }

    @Test func counterAndExpenseWithUndo() {
        var c = session(.counter, .counter(CounterState(value: 0, step: 1, goal: 8)))
        _ = c.handle("plus"); _ = c.handle("plus"); _ = c.handle("minus")
        #expect(c.display().value == "1")
        var e = session(.expense, .counter(CounterState(value: 0, step: 1, goal: 50, money: true, amounts: [5, 20])))
        _ = e.handle("add:20.0"); _ = e.handle("add:5.0"); _ = e.handle("add:20.0"); _ = e.handle("undo")
        #expect(e.display().value == "25 €")
        #expect(e.display().detail == "Quedan 25 € de 50 €")
        _ = e.handle("add:20.0"); _ = e.handle("add:20.0")
        #expect(e.display().finished)
    }

    @Test func sinceLastResets() {
        var s = session(.sinceLast, .countUp(CountUpState(start: t0)))
        _ = s.handle("reset", now: t0.addingTimeInterval(3600))
        guard case .countUp(let c) = s.state else { return }
        #expect(c.start == t0.addingTimeInterval(3600) && c.history == [t0])
    }

    @Test func fastingPhasesAndGoal() {
        #expect(FastingPhase.label(hours: 2) == "Digestión")
        #expect(FastingPhase.label(hours: 14) == "Quemando grasa")
        let s = session(.fasting, .countUp(CountUpState(start: t0, goalHours: 16)))
        #expect(s.display(now: t0.addingTimeInterval(17 * 3600)).finished)
        #expect(s.alertDate(now: t0)?.date == t0.addingTimeInterval(16 * 3600))
    }
}

@Suite("Listas y tarjetas")
struct StepsTests {
    @Test func shoppingSkipMovesItemToTheEnd() {
        var s = session(.shopping, .steps(StepsState(items: ["Leche", "Pan", "Huevos"].map { StepItem(text: $0) })))
        _ = s.handle("skip")
        #expect(s.display().headline == "Pan")
        #expect(s.display().value == "1/3")
        _ = s.handle("next"); _ = s.handle("next")
        #expect(s.display().headline == "Leche")
        _ = s.handle("next")
        #expect(s.display().finished)
    }

    @Test func flashcardsCountRightAndWrong() {
        var s = session(.flashcards, .steps(StepsState(items: [StepItem(text: "Capital de Italia", detail: "Roma"), StepItem(text: "Apple", detail: "Manzana")])))
        #expect(s.display().buttons.map(\.id) == ["reveal"])
        _ = s.handle("reveal")
        #expect(s.display().detail == "Roma")
        _ = s.handle("right"); _ = s.handle("reveal"); _ = s.handle("wrong")
        #expect(s.display().detail == "1 bien · 1 mal")
    }

    @Test func workoutRestsBetweenSets() {
        var steps = StepsState(items: [StepItem(text: "Sentadillas"), StepItem(text: "Flexiones")])
        steps.sets = 2
        steps.rest = 60
        var s = session(.workout, .steps(steps))
        _ = s.handle("setDone", now: t0)
        #expect(s.display(now: t0.addingTimeInterval(10)).headline.hasPrefix("Descanso"))
        #expect(s.display(now: t0.addingTimeInterval(61)).detail?.hasPrefix("Serie 2 de 2") == true)
        _ = s.handle("setDone", now: t0.addingTimeInterval(100))
        #expect(s.display(now: t0.addingTimeInterval(200)).headline == "Flexiones")
    }

    @Test func recipeStepTimer() {
        var s = session(.recipe, .steps(StepsState(items: [StepItem(text: "Cocer la pasta", minutes: 9)])))
        #expect(s.display(now: t0).buttons.contains { $0.id == "stepTimer" })
        _ = s.handle("stepTimer", now: t0)
        #expect(s.display(now: t0).timer?.end == t0.addingTimeInterval(540))
    }
}

@Suite("Marcador y juegos")
struct ScoreTests {
    @Test func padelGameDeuceAndAdvantage() {
        var m = RacketScore()
        for _ in 0..<3 { m.point(0) }
        for _ in 0..<3 { m.point(1) }
        #expect(m.pointLabel(0) == "40" && m.pointLabel(1) == "40")
        m.point(0)
        #expect(m.pointLabel(0) == "AD")
        m.point(1)
        #expect(m.pointLabel(0) == "40")
        m.point(0); m.point(0)
        #expect(m.games == [1, 0])
    }

    @Test func setsTieBreakAndMatch() {
        var m = RacketScore()
        func game(_ side: Int) { for _ in 0..<4 { m.point(side) } }
        for _ in 0..<6 { game(0) }
        #expect(m.sets == [[6, 0]])
        for _ in 0..<6 { game(0); game(1) }
        #expect(m.tieBreak)
        for _ in 0..<7 { m.point(1) }
        #expect(m.sets.last == [6, 7])
        for _ in 0..<6 { game(0) }
        #expect(m.winner == 0)
    }

    @Test func scoreUndo() {
        var s = session(.score, .score(ScoreState(names: ["A", "B"], racket: false)))
        _ = s.handle("a"); _ = s.handle("a"); _ = s.handle("b"); _ = s.handle("undo")
        #expect(s.display().value == "2 – 0")
    }

    @Test func turnClockPassesTurnAndKeepsTime() {
        var s = session(.turnClock, .turnClock(TurnClockState(players: ["Ana", "Leo"], remaining: [300, 300], turnStart: t0)))
        _ = s.handle("next", now: t0.addingTimeInterval(100))
        guard case .turnClock(let t) = s.state else { return }
        #expect(t.current == 1 && t.remaining[0] == 200)
        #expect(s.display(now: t0.addingTimeInterval(100)).headline == "Turno de Leo")
    }

    @Test func refereeProducesResults() {
        var s = session(.referee, .referee(RefereeState(players: ["Ana", "Leo"])))
        _ = s.handle("dice", now: t0)
        #expect(s.display().value?.hasPrefix("🎲") == true)
        _ = s.handle("who", now: t0)
        #expect(s.display().value?.hasPrefix("Le toca a") == true)
    }
}

@Suite("Ubicación, reloj y respiración")
struct MiscTests {
    @Test func geoDistanceAndBearing() {
        let madridToToledo = Geo.distance(40.4168, -3.7038, 39.8628, -4.0273)
        #expect(abs(madridToToledo - 67_000) < 3_000)
        #expect(abs(Geo.bearing(0, 0, 1, 0) - 0) < 0.01)
        #expect(abs(Geo.bearing(0, 0, 0, 1) - 90) < 0.01)
        #expect(Geo.format(434) == "430 m")
        #expect(Geo.format(2460) == "2,5 km")
    }

    @Test func busStopTurnsGreenInsideTheRadius() {
        var l = LocationState(targetLat: 0, targetLon: 0, targetName: "Atocha", radius: 400, started: t0)
        l.distance = 1200
        #expect(!session(.busStop, .location(l)).display().finished)
        l.distance = 350
        #expect(session(.busStop, .location(l)).display().headline == "¡Tu parada!")
    }

    @Test func worldClockCountsFromThatCitysMidnight() {
        let s = session(.worldClock, .worldClock(WorldClockState(timeZone: "Asia/Tokyo", city: "Tokio")))
        let display = s.display(now: t0)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        #expect(display.timer?.start == calendar.startOfDay(for: t0))
        #expect(display.timer?.countsDown == false)
    }

    @Test func breathingPhases() {
        let pattern = BreathPattern.relax
        #expect(pattern.cycle == 19)
        #expect(pattern.phase(at: 1).label == "Inspira")
        #expect(pattern.phase(at: 5).label == "Aguanta")
        #expect(pattern.phase(at: 12).label == "Espira")
        #expect(pattern.phase(at: 20).label == "Inspira")
    }

    @Test func everyKindHasADisplay() {
        let states: [ToolKind: ToolState] = [
            .postIt: .note("Puerta B12"),
            .nextEvent: .event(EventState(title: "Dentista", start: t0.addingTimeInterval(1500))),
            .speed: .location(LocationState(started: t0)),
            .backToCar: .location(LocationState(started: t0)),
            .breathing: .breathing(BreathingState(start: t0)),
        ]
        for (kind, state) in states {
            #expect(!session(kind, state).display(now: t0).headline.isEmpty, "\(kind)")
        }
    }
}

@MainActor
@Suite("Modelo")
struct ModelTests {
    @Test func sessionsAndFavoritesPersist() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let model = AppModel(directory: dir)
        let session = model.start(.counter, title: "Agua", state: .counter(CounterState(value: 0, step: 1, goal: 8)))
        model.perform("plus", on: session.id)
        model.addFavorite(name: "Agua", kind: .counter, state: .counter(CounterState(value: 0, step: 1, goal: 8)))

        let reloaded = AppModel(directory: dir)
        #expect(reloaded.sessions.first?.display().value == "1")
        #expect(reloaded.favorites.first?.name == "Agua")
        reloaded.end(session.id)
        #expect(AppModel(directory: dir).sessions.isEmpty)
    }

    @Test func favoritesRestartTheirClocks() {
        let old = ToolState.countdown(CountdownState(total: 540, now: t0))
        guard case .countdown(let fresh) = old.restarted(now: t0.addingTimeInterval(10_000)) else { Issue.record("state"); return }
        #expect(fresh.end == t0.addingTimeInterval(10_540))
    }
}
