import Foundation
import Testing
@testable import Ronda

private func players(_ names: String...) -> [Player] { names.map { Player(name: $0) } }

@Suite("ShuffledDeck")
struct ShuffledDeckTests {
    @Test func drawsEveryCardOncePerCycle() {
        var deck = ShuffledDeck(Array(1...20))
        var generator = SeededGenerator(seed: 7)
        let firstCycle = (0..<20).compactMap { _ in deck.draw(using: &generator) }
        #expect(Set(firstCycle).count == 20)
        #expect(deck.remainingInCycle == 0)
        // Second cycle reshuffles and keeps going.
        #expect(deck.draw(using: &generator) != nil)
        #expect(deck.drawnCount == 21)
    }

    @Test func emptyDeckReturnsNil() {
        var deck = ShuffledDeck<String>([])
        #expect(deck.draw() == nil)
    }

    @Test func seededGeneratorIsDeterministic() {
        var a = SeededGenerator(seed: 42), b = SeededGenerator(seed: 42)
        #expect((0..<5).map { _ in a.next() } == (0..<5).map { _ in b.next() })
    }
}

@Suite("Players and turns")
struct PlayerTests {
    @Test func sanitizesNames() {
        let existing = players("Ana")
        #expect(PlayerRules.sanitize("  Leo   Messi ", existing: existing) == "Leo Messi")
        #expect(PlayerRules.sanitize("   ", existing: existing) == nil)
        #expect(PlayerRules.sanitize("ÁNA", existing: existing) == nil)
        #expect(PlayerRules.sanitize(String(repeating: "x", count: 40), existing: [])?.count == PlayerRules.maxNameLength)
    }

    @Test func seatOrderWrapsAround() {
        var turn = TurnOrder(count: 4)
        #expect(turn.left(of: 3) == 0)
        #expect(turn.right(of: 0) == 3)
        for _ in 0..<5 { turn.advance() }
        #expect(turn.current == 1)
        #expect(TurnOrder(count: 3, start: 7).current == 1)
        #expect(TurnOrder(count: 0).left(of: 0) == 0)
    }
}

@Suite("SipLedger")
struct LedgerTests {
    @Test func tallyAndStandingsWithTies() {
        let group = players("Ana", "Leo", "Sara", "Dani")
        var ledger = SipLedger()
        ledger.add(3, to: group[1].id)
        ledger.add(3, to: group[2].id)
        ledger.add(1, to: group[0].id)
        ledger.add(0, to: group[3].id)
        ledger.add(-2, to: group[3].id)

        #expect(ledger.total == 7)
        let standings = ledger.standings(for: group)
        #expect(standings.map(\.player.name) == ["Leo", "Sara", "Ana", "Dani"])
        #expect(standings.map(\.position) == [1, 1, 3, 4])
    }

    @Test func multiPlayerAddCountsEachOnce() {
        let group = players("Ana", "Leo")
        var ledger = SipLedger()
        ledger.add(2, to: [group[0].id, group[0].id, group[1].id])
        #expect(ledger.count(for: group[0].id) == 2)
        #expect(ledger.total == 4)
        ledger.reset()
        #expect(ledger.total == 0)
    }

    @Test func ledgerRoundTripsThroughJSON() throws {
        let id = UUID()
        var ledger = SipLedger()
        ledger.add(5, to: id)
        let decoded = try JSONDecoder().decode(SipLedger.self, from: JSONEncoder().encode(ledger))
        #expect(decoded == ledger)
    }

    @Test func waterBreakEveryN() {
        var schedule = WaterBreakSchedule(every: 3)
        #expect([schedule.registerCard(), schedule.registerCard(), schedule.registerCard(), schedule.registerCard()] == [false, false, true, false])
        var off = WaterBreakSchedule(every: 0)
        #expect(!(0..<20).contains { _ in off.registerCard() })
    }
}

@Suite("Card text")
struct CardTextTests {
    @Test func fillsDistinctPlayersPreferringCurrent() {
        let group = players("Ana", "Leo", "Sara")
        var generator = SeededGenerator(seed: 1)
        for _ in 0..<20 {
            let result = CardText.fill("{1}, baila con {2}.", players: group, first: group[2], using: &generator)
            #expect(result.involved.count == 2)
            #expect(result.involved[0] == group[2])
            #expect(result.involved[0] != result.involved[1])
            #expect(result.text.hasPrefix("Sara, baila con "))
            #expect(!result.text.contains("{"))
        }
    }

    @Test func leavesPlainCardsUntouched() {
        var generator = SeededGenerator(seed: 1)
        let result = CardText.fill("Yo nunca he volado.", players: players("Ana"), using: &generator)
        #expect(result.text == "Yo nunca he volado.")
        #expect(result.involved.isEmpty)
    }

    @Test func soberLexiconRewritesDrinking() {
        let sober = Lexicon(soberMode: true)
        #expect(sober.drink(2) == "suma 2 puntos")
        #expect(sober.adapt("Cuenta tu último ligue o bebe 3.") == "Cuenta tu último ligue o suma 3.")
        #expect(!sober.adapt("Brindis general: bebe toda la mesa.").contains("bebe"))
        let normal = Lexicon(soberMode: false)
        #expect(normal.sips(1) == "1 sorbo")
        #expect(normal.adapt("bebe 2") == "bebe 2")
    }
}

@Suite("Mayor o menor")
struct HigherLowerTests {
    @Test func spanishDeckHas40UniqueCards() {
        let deck = SpanishCard.fullDeck
        #expect(deck.count == 40)
        #expect(Set(deck).count == 40)
        #expect(!deck.contains { [8, 9].contains($0.rank) })
    }

    @Test func outcomesFollowTheRules() {
        var generator = SeededGenerator(seed: 99)
        var game = HigherLowerGame(using: &generator)
        var hits = 0, losses = 0
        for _ in 0..<200 {
            let before = game.current
            let potBefore = game.pot
            let result = game.guess(.higher, using: &generator)
            #expect(game.current == result.card)
            switch result.outcome {
            case .hit(let pot):
                #expect(result.card.rank > before.rank)
                #expect(pot == potBefore + 1)
                hits += 1
            case .miss(let drinks):
                #expect(result.card.rank < before.rank)
                #expect(drinks == max(1, potBefore))
                #expect(game.pot == 0)
                losses += 1
            case .tie(let drinks):
                #expect(result.card.rank == before.rank)
                #expect(drinks == max(1, potBefore))
                losses += 1
            }
        }
        #expect(hits > 0 && losses > 0)
    }

    @Test func standRequiresStreakAndKeepsPot() {
        var generator = SeededGenerator(seed: 3)
        var game = HigherLowerGame(using: &generator)
        #expect(!game.canStand)
        var guard_ = 0
        while game.streak < HigherLowerGame.hitsNeededToStand && guard_ < 500 {
            let guess: HigherLowerGame.Guess = game.current.rank <= 6 ? .higher : .lower
            _ = game.guess(guess, using: &generator)
            guard_ += 1
        }
        #expect(game.canStand)
        let pot = game.pot
        game.stand()
        #expect(game.pot == pot)
        #expect(!game.canStand)
    }
}

@Suite("El Círculo")
struct CircleTests {
    @Test func fourthKingEndsTheRound() {
        var generator = SeededGenerator(seed: 5)
        var game = CircleGame(hot: false, using: &generator)
        var kings = 0
        var finalSeen = false
        while let result = game.draw() {
            if result.card.rank == 12 { kings += 1 }
            if result.isFinalKing {
                finalSeen = true
                #expect(result.rule.drawerSips == 5)
            }
        }
        #expect(kings == 4)
        #expect(finalSeen)
        #expect(game.isFinished)
        #expect(game.draw() == nil)
    }

    @Test func everyRankHasARuleInBothModes() {
        for rank in SpanishCard.ranks where rank != 12 {
            #expect(CircleGame.normalRules[rank] != nil)
            #expect(CircleGame.hotRules[rank] != nil)
        }
    }
}

@Suite("Bomba, duelos y ruleta")
struct PartyMechanicsTests {
    @Test func fuseStaysInRangeAndAccelerates() {
        var generator = SeededGenerator(seed: 11)
        for _ in 0..<50 {
            let fuse = BombFuse(using: &generator)
            #expect(BombFuse.durationRange.contains(fuse.duration))
            #expect(fuse.tickInterval(elapsed: 0) > fuse.tickInterval(elapsed: fuse.duration * 0.9))
            #expect(fuse.tickInterval(elapsed: fuse.duration * 2) >= 0.15)
            #expect(fuse.hasExploded(elapsed: fuse.duration))
            #expect(!fuse.hasExploded(elapsed: fuse.duration - 0.01))
        }
    }

    @Test func duelResolution() {
        #expect(Duel.resolveReflex(tap: .top, beforeGo: true) == .winner(.bottom))
        #expect(Duel.resolveReflex(tap: .top, beforeGo: false) == .winner(.top))
        #expect(Duel.resolveTaps(top: 30, bottom: 28) == .winner(.top))
        #expect(Duel.resolveTaps(top: 10, bottom: 10) == .tie)
        let match = Duel.ColorRound(word: 1, ink: 1)
        let mismatch = Duel.ColorRound(word: 1, ink: 2)
        #expect(Duel.resolveColorTap(side: .bottom, round: match) == .winner(.bottom))
        #expect(Duel.resolveColorTap(side: .bottom, round: mismatch) == .winner(.top))
    }

    @Test func colorRoundsAlwaysContainAnEarlyMatch() {
        for seed in UInt64(0)..<200 {
            var generator = SeededGenerator(seed: seed)
            let rounds = Duel.colorRounds(using: &generator)
            #expect(rounds.count == 12)
            #expect(rounds.prefix(7).contains { $0.matches })
            #expect(rounds.allSatisfy { (0..<4).contains($0.word) && (0..<4).contains($0.ink) })
        }
    }

    @Test func rouletteLandsOnPickedSegment() {
        let wheel = Roulette(segments: CardBank.rouletteNormal)
        var generator = SeededGenerator(seed: 2)
        var rotation = 0.0
        var seen = Set<Int>()
        for _ in 0..<300 {
            let index = wheel.pick(using: &generator)
            let jitter = Double.random(in: -1...1, using: &generator)
            rotation = wheel.rotation(landingOn: index, from: rotation, jitter: jitter)
            #expect(wheel.segment(atRotation: rotation) == index)
            seen.insert(index)
        }
        #expect(seen.count == wheel.segments.count)
    }

    @Test func rouletteRespectsWeights() {
        let wheel = Roulette(segments: [
            .init(title: "A", detail: "", spinnerSips: 0, everyoneSips: 0, weight: 9),
            .init(title: "B", detail: "", spinnerSips: 0, everyoneSips: 0, weight: 1),
        ])
        var generator = SeededGenerator(seed: 8)
        let picks = (0..<2000).map { _ in wheel.pick(using: &generator) }
        let share = Double(picks.filter { $0 == 0 }.count) / 2000
        #expect(share > 0.85 && share < 0.95)
    }
}

@Suite("Contenido")
struct ContentTests {
    @Test func everyGameHasEnoughCardsInEveryMode() {
        for mode in PartyMode.allCases {
            for game in GameKind.games(for: mode) where game.supportsCustomCards || game == .bomb {
                for intensity in Intensity.allCases {
                    let prompts = PromptDecks.prompts(for: game, mode: mode, intensity: intensity)
                    #expect(prompts.count >= 20, "\(game) \(mode) \(intensity)")
                    #expect(Set(prompts).count == prompts.count, "Duplicate card in \(game) \(mode)")
                }
            }
        }
    }

    @Test func hotSectionHasItsOwnGamesAndDaresUseTwoPlayers() {
        #expect(GameKind.games(for: .hot).contains(.dares))
        #expect(!GameKind.games(for: .normal).contains(.dares))
        #expect(!GameKind.games(for: .hot).contains(.duels))
        #expect(CardBank.daresHot.allSatisfy { CardText.requiredPlayers($0) >= 1 })
    }

    @Test func neverHaveCardsStartConsistently() {
        for card in CardBank.neverSoft + CardBank.neverParty + CardBank.neverHot {
            #expect(card.hasPrefix("Yo nunca"), "\(card)")
        }
        for card in CardBank.mostLikelySoft + CardBank.mostLikelyParty + CardBank.mostLikelyHot {
            #expect(card.hasPrefix("¿Quién es más probable") && card.hasSuffix("?"), "\(card)")
        }
    }

    @Test func customCardNormalization() {
        #expect(CustomCardRules.normalize("he ido a Ibiza", for: .neverHave) == "Yo nunca he ido a Ibiza")
        #expect(CustomCardRules.normalize("Yo nunca he cantado", for: .neverHave) == "Yo nunca he cantado")
        #expect(CustomCardRules.normalize("se duerma primero", for: .mostLikely) == "¿Quién es más probable que se duerma primero?")
        #expect(CustomCardRules.normalize("  ", for: .truthOrDrink) == nil)
    }
}
