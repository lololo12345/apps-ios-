package app.ronda.party

import app.ronda.party.content.CardBank
import app.ronda.party.core.BombFuse
import app.ronda.party.core.CardText
import app.ronda.party.core.CircleGame
import app.ronda.party.core.Duel
import app.ronda.party.core.HigherLowerGame
import app.ronda.party.core.Lexicon
import app.ronda.party.core.Player
import app.ronda.party.core.PlayerRules
import app.ronda.party.core.Roulette
import app.ronda.party.core.ShuffledDeck
import app.ronda.party.core.SipLedger
import app.ronda.party.core.SpanishCard
import app.ronda.party.core.TurnOrder
import app.ronda.party.core.WaterBreakSchedule
import app.ronda.party.model.CustomCardRules
import app.ronda.party.model.GameKind
import app.ronda.party.model.Intensity
import app.ronda.party.model.PartyMode
import app.ronda.party.model.PromptDecks
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

private fun players(vararg names: String) = names.map { Player(name = it) }

class ShuffledDeckTest {
    @Test fun drawsEveryCardOncePerCycle() {
        val deck = ShuffledDeck((1..20).toList())
        val random = Random(7)
        val firstCycle = List(20) { deck.draw(random) }
        assertEquals(20, firstCycle.toSet().size)
        assertEquals(0, deck.remainingInCycle)
        assertNotNull(deck.draw(random))
        assertEquals(21, deck.drawnCount)
    }

    @Test fun emptyDeckReturnsNull() {
        assertNull(ShuffledDeck(emptyList<String>()).draw())
    }
}

class PlayerTest {
    @Test fun sanitizesNames() {
        val existing = players("Ana")
        assertEquals("Leo Messi", PlayerRules.sanitize("  Leo   Messi ", existing))
        assertNull(PlayerRules.sanitize("   ", existing))
        assertNull(PlayerRules.sanitize("ÁNA", existing))
        assertEquals(PlayerRules.MAX_NAME_LENGTH, PlayerRules.sanitize("x".repeat(40), emptyList())?.length)
    }

    @Test fun seatOrderWrapsAround() {
        var turn = TurnOrder(4)
        assertEquals(0, turn.left(3))
        assertEquals(3, turn.right(0))
        repeat(5) { turn = turn.advanced() }
        assertEquals(1, turn.current)
        assertEquals(1, TurnOrder(3, 7).current)
        assertEquals(0, TurnOrder(0).left(0))
    }
}

class LedgerTest {
    @Test fun tallyAndStandingsWithTies() {
        val group = players("Ana", "Leo", "Sara", "Dani")
        val ledger = SipLedger()
            .add(3, group[1].id).add(3, group[2].id).add(1, group[0].id)
            .add(0, group[3].id).add(-2, group[3].id)
        assertEquals(7, ledger.total)
        val standings = ledger.standings(group)
        assertEquals(listOf("Leo", "Sara", "Ana", "Dani"), standings.map { it.player.name })
        assertEquals(listOf(1, 1, 3, 4), standings.map { it.position })
    }

    @Test fun multiPlayerAddCountsEachOnce() {
        val group = players("Ana", "Leo")
        val ledger = SipLedger().add(2, listOf(group[0].id, group[0].id, group[1].id))
        assertEquals(2, ledger.count(group[0].id))
        assertEquals(4, ledger.total)
    }

    @Test fun totalIgnoresRemovedPlayers() {
        val group = players("Ana", "Leo", "Sara")
        val ledger = SipLedger().add(2, group[0].id).add(5, group[2].id)
        assertEquals(7, ledger.total(group))
        assertEquals(2, ledger.total(group.take(2)))
    }

    @Test fun removeCorrectsWithoutGoingNegative() {
        var ledger = SipLedger().add(3, "a")
        ledger = ledger.remove(1, "a")
        assertEquals(2, ledger.count("a")); assertEquals(2, ledger.total)
        ledger = ledger.remove(10, "a")
        assertEquals(0, ledger.count("a")); assertEquals(0, ledger.total)
        ledger = ledger.remove(1, "other").remove(-4, "a")
        assertEquals(0, ledger.total)
    }

    @Test fun ledgerRoundTripsThroughJson() {
        val ledger = SipLedger().add(5, "id")
        val decoded = Json.decodeFromString(SipLedger.serializer(), Json.encodeToString(SipLedger.serializer(), ledger))
        assertEquals(ledger, decoded)
    }

    @Test fun waterBreakEveryNCards() {
        val schedule = WaterBreakSchedule(3)
        assertEquals(listOf(false, false, true, false, false, true), List(6) { schedule.registerCard() })
        val off = WaterBreakSchedule(0)
        assertFalse((0 until 20).any { off.registerCard() })
    }
}

class CardTextTest {
    @Test fun fillsDistinctPlayersPreferringCurrent() {
        val group = players("Ana", "Leo", "Sara")
        val random = Random(1)
        repeat(20) {
            val result = CardText.fill("{1}, baila con {2}.", group, group[2], random)
            assertEquals(2, result.involved.size)
            assertEquals(group[2], result.involved[0])
            assertNotEquals(result.involved[0], result.involved[1])
            assertTrue(result.text.startsWith("Sara, baila con "))
            assertFalse(result.text.contains("{"))
        }
    }

    @Test fun leavesPlainCardsUntouched() {
        val result = CardText.fill("Yo nunca he volado.", players("Ana"))
        assertEquals("Yo nunca he volado.", result.text)
        assertTrue(result.involved.isEmpty())
    }

    @Test fun soberLexiconRewritesDrinking() {
        val sober = Lexicon(true)
        assertEquals("suma 2 puntos", sober.drink(2))
        assertEquals("Cuenta tu último ligue o suma 3.", sober.adapt("Cuenta tu último ligue o bebe 3."))
        assertFalse(sober.adapt("Brindis general: bebe toda la mesa.").contains("bebe"))
        val normal = Lexicon(false)
        assertEquals("1 sorbo", normal.sips(1))
        assertEquals("bebe 2", normal.adapt("bebe 2"))
    }
}

class HigherLowerTest {
    @Test fun spanishDeckHas40UniqueCards() {
        val deck = SpanishCard.fullDeck
        assertEquals(40, deck.size)
        assertEquals(40, deck.toSet().size)
        assertFalse(deck.any { it.rank == 8 || it.rank == 9 })
    }

    @Test fun outcomesFollowTheRules() {
        val random = Random(99)
        var game = HigherLowerGame.new(random)
        var hits = 0
        var losses = 0
        repeat(200) {
            val before = game.current
            val potBefore = game.pot
            val move = game.guess(HigherLowerGame.Guess.HIGHER, random)
            game = move.game
            assertEquals(move.card, game.current)
            when (val outcome = move.outcome) {
                is HigherLowerGame.Outcome.Hit -> {
                    assertTrue(move.card.rank > before.rank); assertEquals(potBefore + 1, outcome.pot); hits++
                }
                is HigherLowerGame.Outcome.Miss -> {
                    assertTrue(move.card.rank < before.rank); assertEquals(maxOf(1, potBefore), outcome.drinks)
                    assertEquals(0, game.pot); losses++
                }
                is HigherLowerGame.Outcome.Tie -> {
                    assertEquals(before.rank, move.card.rank); assertEquals(maxOf(1, potBefore), outcome.drinks); losses++
                }
            }
        }
        assertTrue(hits > 0 && losses > 0)
    }

    @Test fun standRequiresStreakAndKeepsPot() {
        val random = Random(3)
        var game = HigherLowerGame.new(random)
        assertFalse(game.canStand)
        var guard = 0
        while (game.streak < HigherLowerGame.HITS_NEEDED_TO_STAND && guard < 500) {
            val guess = if (game.current.rank <= 6) HigherLowerGame.Guess.HIGHER else HigherLowerGame.Guess.LOWER
            game = game.guess(guess, random).game
            guard++
        }
        assertTrue(game.canStand)
        val pot = game.pot
        game = game.stand()
        assertEquals(pot, game.pot)
        assertFalse(game.canStand)
    }
}

class CircleTest {
    @Test fun fourthKingEndsTheRound() {
        var game = CircleGame.new(hot = false, random = Random(5))
        var kings = 0
        var finalSeen = false
        while (true) {
            val draw = game.draw() ?: break
            game = draw.game
            if (draw.card.rank == 12) kings++
            if (draw.isFinalKing) {
                finalSeen = true
                assertEquals(5, draw.rule.drawerSips)
            }
        }
        assertEquals(4, kings)
        assertTrue(finalSeen)
        assertTrue(game.isFinished)
        assertNull(game.draw())
    }

    @Test fun kingTextCountsDown() {
        assertTrue(CircleGame.rule(12, false, 1).detail.contains("Quedan 3 reyes"))
        assertTrue(CircleGame.rule(12, false, 3).detail.contains("Solo queda 1 Rey"))
        assertEquals(5, CircleGame.rule(12, true, 4).drawerSips)
        assertEquals("Rey nº 2", CircleGame.rule(12, false, 2).title)
    }

    @Test fun everyRankHasARuleInBothModes() {
        for (rank in SpanishCard.RANKS.filter { it != 12 }) {
            assertNotNull(CircleGame.NORMAL_RULES[rank])
            assertNotNull(CircleGame.HOT_RULES[rank])
        }
    }
}

class PartyMechanicsTest {
    @Test fun fuseStaysInRangeAndAccelerates() {
        val random = Random(11)
        repeat(50) {
            val fuse = BombFuse.random(random)
            assertTrue(fuse.duration in BombFuse.DURATION_RANGE)
            assertTrue(fuse.tickInterval(0.0) > fuse.tickInterval(fuse.duration * 0.9))
            assertTrue(fuse.tickInterval(fuse.duration * 2) >= 0.15)
            assertTrue(fuse.hasExploded(fuse.duration))
            assertFalse(fuse.hasExploded(fuse.duration - 0.01))
        }
    }

    @Test fun duelResolution() {
        assertEquals(Duel.Result.Winner(Duel.Side.BOTTOM), Duel.resolveReflex(Duel.Side.TOP, beforeGo = true))
        assertEquals(Duel.Result.Winner(Duel.Side.TOP), Duel.resolveReflex(Duel.Side.TOP, beforeGo = false))
        assertEquals(Duel.Result.Winner(Duel.Side.TOP), Duel.resolveTaps(30, 28))
        assertEquals(Duel.Result.Tie, Duel.resolveTaps(10, 10))
        assertEquals(Duel.Result.Winner(Duel.Side.BOTTOM), Duel.resolveColorTap(Duel.Side.BOTTOM, Duel.ColorRound(1, 1)))
        assertEquals(Duel.Result.Winner(Duel.Side.TOP), Duel.resolveColorTap(Duel.Side.BOTTOM, Duel.ColorRound(1, 2)))
    }

    @Test fun colorRoundsAlwaysContainAnEarlyMatch() {
        for (seed in 0 until 200) {
            val rounds = Duel.colorRounds(random = Random(seed))
            assertEquals(12, rounds.size)
            assertTrue(rounds.take(7).any { it.matches })
            assertTrue(rounds.all { it.word in 0..3 && it.ink in 0..3 })
        }
    }

    @Test fun rouletteLandsOnPickedSegment() {
        val wheel = Roulette(CardBank.rouletteNormal)
        val random = Random(2)
        var rotation = 0.0
        val seen = mutableSetOf<Int>()
        repeat(300) {
            val index = wheel.pick(random)
            rotation = wheel.rotation(index, rotation, jitter = random.nextDouble(-1.0, 1.0))
            assertEquals(index, wheel.segmentAt(rotation))
            seen += index
        }
        assertEquals(wheel.segments.size, seen.size)
    }

    @Test fun rouletteRespectsWeights() {
        val wheel = Roulette(listOf(Roulette.Segment("A", "", 0, 0, 9), Roulette.Segment("B", "", 0, 0, 1)))
        val random = Random(8)
        val share = List(2000) { wheel.pick(random) }.count { it == 0 } / 2000.0
        assertTrue(share > 0.85 && share < 0.95)
    }
}

class ContentTest {
    @Test fun everyGameHasEnoughCardsInEveryMode() {
        for (mode in PartyMode.entries) for (game in GameKind.games(mode).filter { it.supportsCustomCards || it == GameKind.BOMB }) {
            for (intensity in Intensity.entries) {
                val prompts = PromptDecks.prompts(game, mode, intensity)
                assertTrue("$game $mode $intensity", prompts.size >= 20)
                assertEquals("Duplicate card in $game $mode", prompts.size, prompts.toSet().size)
            }
        }
    }

    @Test fun hotSectionHasItsOwnGamesAndDaresUseTwoPlayers() {
        assertTrue(GameKind.DARES in GameKind.games(PartyMode.HOT))
        assertFalse(GameKind.DARES in GameKind.games(PartyMode.NORMAL))
        assertFalse(GameKind.DUELS in GameKind.games(PartyMode.HOT))
        assertTrue(CardBank.daresHot.all { CardText.requiredPlayers(it) >= 1 })
    }

    @Test fun cardsStartConsistently() {
        for (card in CardBank.neverSoft + CardBank.neverParty + CardBank.neverHot) assertTrue(card, card.startsWith("Yo nunca"))
        for (card in CardBank.mostLikelySoft + CardBank.mostLikelyParty + CardBank.mostLikelyHot) {
            assertTrue(card, card.startsWith("¿Quién es más probable") && card.endsWith("?"))
        }
    }

    @Test fun customCardsAreNormalized() {
        assertEquals("Yo nunca he ido a Ibiza", CustomCardRules.normalize("he ido a Ibiza", GameKind.NEVER_HAVE))
        assertEquals("Yo nunca he cantado", CustomCardRules.normalize("Yo nunca he cantado", GameKind.NEVER_HAVE))
        assertEquals("¿Quién es más probable que se duerma primero?", CustomCardRules.normalize("se duerma primero", GameKind.MOST_LIKELY))
        assertNull(CustomCardRules.normalize("  ", GameKind.TRUTH_OR_DRINK))
    }
}
