import Foundation
import Testing
@testable import PlanB

@Suite("Catálogo")
struct CatalogTests {
    @Test func hasAboutThreeHundredUniquePlans() {
        #expect(PlanCatalog.all.count >= 290)
        #expect(Set(PlanCatalog.all.map(\.id)).count == PlanCatalog.all.count)
        #expect(Set(PlanCatalog.all.map(\.summary)).count == PlanCatalog.all.count)
        #expect(PlanCatalog.byID.count == PlanCatalog.all.count)
    }

    @Test func everyPlanIsComplete() {
        for plan in PlanCatalog.all {
            #expect(!plan.emoji.isEmpty, "\(plan.id)")
            #expect(plan.title.count >= 4, "\(plan.id)")
            #expect(plan.summary.hasSuffix(".") || plan.summary.hasSuffix("!") || plan.summary.hasSuffix("?"), "\(plan.id)")
            #expect(!plan.tip.isEmpty, "\(plan.id)")
            #expect(!plan.times.isEmpty, "\(plan.id)")
            #expect(!plan.id.isEmpty && !plan.id.contains(" "), "\(plan.id)")
        }
    }

    @Test func tagGrammarParsesEveryToken() {
        let parsed = PlanTags.parse("low out evening pm night romantic hot")
        #expect(parsed.isComplete)
        #expect(parsed.budget == .low && parsed.place == .out && parsed.duration == .evening)
        #expect(parsed.times == [.afternoon, .night])
        #expect(parsed.mood == .romantic && parsed.intimate)
        #expect(!PlanTags.parse("free home calm").isComplete)
        #expect(PlanTags.parse("free home hour any calm oops").unknown == ["oops"])
        #expect(PlanTags.parse("free home hour any calm").times.count == 3)
    }

    @Test func slugsAreStable() {
        #expect(PlanTags.slug("Picnic en el parque") == "picnic-en-el-parque")
        #expect(PlanTags.slug("¿Qué tal? Día de ÑANDÚES") == "que-tal-dia-de-nandues")
    }

    @Test func everyFilterValueHasPlans() {
        let together = PlanCatalog.all.filter { !$0.intimate }
        for mood in Mood.allCases { #expect(together.filter { $0.mood == mood }.count >= 40, "\(mood)") }
        for place in Place.allCases { #expect(together.filter { $0.place == place }.count >= 60, "\(place)") }
        for budget in Budget.allCases { #expect(together.contains { $0.budget == budget }, "\(budget)") }
        for duration in Duration.allCases { #expect(together.contains { $0.duration == duration }, "\(duration)") }
        for time in TimeOfDay.allCases { #expect(together.filter { $0.times.contains(time) }.count >= 50, "\(time)") }
        #expect(together.filter { $0.budget == .free && $0.place == .home }.count >= 30)
    }

    @Test func intimateSectionIsSeparateAndSizeable() {
        let intimate = PlanCatalog.all.filter(\.intimate)
        #expect(intimate.count >= 35)
        #expect(intimate.allSatisfy { $0.colors.count == 2 })
    }
}

@Suite("Filtros y baraja")
struct FilterTests {
    private let picnic = PlanCatalog.plan(id: "picnic-en-el-parque")!

    @Test func emptyFilterMatchesEverything() {
        #expect(PlanFilter().isEmpty)
        #expect(PlanCatalog.all.allSatisfy { PlanFilter().matches($0) })
    }

    @Test func filtersCombine() {
        #expect(picnic.budget == .low && picnic.place == .out && picnic.duration == .evening)
        #expect(PlanFilter(maxBudget: .low).matches(picnic))
        #expect(!PlanFilter(maxBudget: .free).matches(picnic))
        #expect(PlanFilter(maxDuration: .day).matches(picnic))
        #expect(!PlanFilter(maxDuration: .hour).matches(picnic))
        #expect(!PlanFilter(place: .home).matches(picnic))
        #expect(!PlanFilter(time: .night).matches(picnic))
        #expect(PlanFilter(moods: [.calm, .active]).matches(picnic))
        #expect(!PlanFilter(moods: [.romantic]).matches(picnic))
        #expect(PlanFilter(maxBudget: .mid, place: .out, moods: [.calm]).activeCount == 3)
    }

    @Test func deckShowsEveryPlanOnceBeforeRepeating() {
        let plans = Array(PlanCatalog.all.prefix(25))
        var generator = SeededGenerator(seed: 3)
        var deck = PlanDeck(plans: plans, using: &generator)
        var seen: [String] = []
        for _ in 0..<25 {
            seen.append(deck.current!.id)
            deck.advance(using: &generator)
        }
        #expect(Set(seen).count == 25)
        #expect(deck.current != nil)
        #expect(deck.current?.id != seen.last)
        #expect(deck.upcoming(3).count == 3)
        #expect(deck.upcoming(3).first == deck.current)
    }

    @Test func emptyDeckIsSafe() {
        var generator = SeededGenerator(seed: 1)
        var deck = PlanDeck(plans: [], using: &generator)
        deck.advance(using: &generator)
        #expect(deck.isEmpty && deck.current == nil && deck.upcoming(3).isEmpty)
    }
}

@Suite("Plan del día, pistas y estadísticas")
struct LogicTests {
    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func dailyPlanIsStableDuringTheDayAndChanges() {
        let morning = DailyPlan.pick(for: date(2026, 11, 14, 8), from: PlanCatalog.all)
        let evening = DailyPlan.pick(for: date(2026, 11, 14, 22), from: PlanCatalog.all)
        #expect(morning == evening)
        #expect(morning?.intimate == false)
        let week = (1...7).compactMap { DailyPlan.pick(for: date(2026, 11, $0), from: PlanCatalog.all)?.id }
        #expect(Set(week).count >= 5)
        #expect(DailyPlan.pick(for: .now, from: []) == nil)
    }

    @Test func surpriseHintsNeverGiveAwayTheTitle() {
        for plan in PlanCatalog.all {
            let hints = SurpriseHints.hints(for: plan)
            #expect(hints.count >= 4)
            #expect(!hints.contains { $0.localizedCaseInsensitiveContains(plan.title) })
        }
    }

    @Test func weeklyStreakCountsConsecutiveWeeks() {
        let now = date(2026, 11, 18)  // Wednesday
        let calendar = MemoryStats.weekCalendar
        #expect(MemoryStats.weeklyStreak([], now: now, calendar: calendar) == 0)
        // This week, last week and the one before.
        let three = [date(2026, 11, 17), date(2026, 11, 12), date(2026, 11, 3)]
        #expect(MemoryStats.weeklyStreak(three, now: now, calendar: calendar) == 3)
        // Nothing yet this week: the streak from last week is still alive.
        #expect(MemoryStats.weeklyStreak([date(2026, 11, 12), date(2026, 11, 3)], now: now, calendar: calendar) == 2)
        // A gap breaks it.
        #expect(MemoryStats.weeklyStreak([date(2026, 11, 17), date(2026, 10, 27)], now: now, calendar: calendar) == 1)
    }

    @Test func onThisDayFindsMemoriesFromAYearAgo() {
        let now = date(2026, 11, 14)
        let dates = [date(2026, 11, 1), date(2025, 11, 16), date(2024, 3, 1)]
        #expect(MemoryStats.onThisDay(dates, now: now) == 1)
        #expect(MemoryStats.onThisDay([date(2025, 10, 1)], now: now) == nil)
        #expect(MemoryStats.onThisDay([date(2026, 11, 14)], now: now) == nil)
    }

    @Test func averageIgnoresUnrated() {
        #expect(MemoryStats.averageRating([5, 4, 0]) == 4.5)
        #expect(MemoryStats.averageRating([0, 0]) == nil)
    }

    @Test func wheelLandsOnTheChosenSlice() {
        var rotation = 0.0
        for count in 2...8 {
            for index in 0..<count {
                for jitter in [-1.0, 0, 1.0] {
                    rotation = PlanWheel.rotation(landingOn: index, count: count, from: rotation, jitter: jitter)
                    #expect(PlanWheel.segment(atRotation: rotation, count: count) == index)
                }
            }
        }
    }
}

@MainActor
@Suite("Estado")
struct StateTests {
    private func makeState() -> AppState {
        let name = "planb.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AppState(defaults: defaults, uiTesting: false)
    }

    @Test func namesAreCleaned() {
        let state = makeState()
        #expect(!state.hasNames)
        state.setNames("  Ana   María ", "Leo")
        #expect(state.coupleName == "Ana María y Leo")
        #expect(AppState.cleanName(String(repeating: "x", count: 40)).count == 20)
    }

    @Test func intimatePlansOnlyAfterConsent() {
        let state = makeState()
        state.section = .intimate
        #expect(state.matchingPlans.allSatisfy { !$0.intimate })
        state.intimateUnlocked = true
        state.section = .intimate
        #expect(!state.matchingPlans.isEmpty && state.matchingPlans.allSatisfy(\.intimate))
        state.intimateUnlocked = false
        #expect(state.section == .together)
    }

    @Test func filtersRebuildTheDeck() {
        let state = makeState()
        state.filter = PlanFilter(maxBudget: .free, place: .home)
        #expect(!state.deck.isEmpty)
        #expect(state.deck.plans.allSatisfy { $0.budget == .free && $0.place == .home })
    }

    @Test func savedAndActivePlansPersist() {
        let name = "planb.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        let first = AppState(defaults: defaults, uiTesting: false)
        let picnic = PlanCatalog.plan(id: "picnic-en-el-parque")!
        first.toggleSaved(picnic)
        first.choose(picnic)
        first.filter = PlanFilter(place: .out)
        first.surprise = Surprise(planID: picnic.id)

        let second = AppState(defaults: defaults, uiTesting: false)
        #expect(second.savedPlans == [picnic])
        #expect(second.activePlan == picnic)
        #expect(second.filter.place == .out)
        #expect(second.surprise?.planID == picnic.id)
        second.toggleSaved(picnic)
        #expect(second.savedPlans.isEmpty)
    }

    @Test func customPlansJoinTheDeck() {
        let state = makeState()
        let record = CustomPlanRecord(emoji: "🎳", title: "Bolos con los amigos", summary: "Partida y cena.", tip: "", budget: .low, place: .out, duration: .evening, mood: .active, intimate: false)
        state.customPlans = [record.plan]
        #expect(state.plan(id: record.plan.id)?.title == "Bolos con los amigos")
        #expect(state.matchingPlans.contains { $0.isCustom })
    }

    @Test func customPlanRules() {
        #expect(CustomPlanRules.clean("  Ir   al cine ", max: 60) == "Ir al cine")
        #expect(CustomPlanRules.clean("no", max: 60) == nil)
        #expect(CustomPlanRules.emoji("🎳 bolos") == "🎳")
        #expect(CustomPlanRules.emoji("abc") == "💡")
    }
}
