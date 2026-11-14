package app.ronda.party

import app.ronda.party.model.GameKind
import app.ronda.party.model.PartyMode
import app.ronda.party.session.AgeStatus
import app.ronda.party.session.InMemoryStore
import app.ronda.party.session.PartySession
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SessionTest {
    @Test fun freshInstallAsksForAgeAndPlayers() {
        val session = PartySession(InMemoryStore())
        assertNull(session.ageStatus)
        assertTrue(session.players.isEmpty())
        assertFalse(session.setupDone)
        assertEquals(10, session.waterEvery)
    }

    @Test fun minorsAreAlwaysSoberAndCannotUseHot() {
        val session = PartySession(InMemoryStore())
        session.updateAgeStatus(AgeStatus.MINOR)
        session.updateSoberPreference(false)
        assertTrue(session.soberMode)
        assertFalse(session.canUseHot)
        session.updateAgeStatus(AgeStatus.ADULT)
        assertFalse(session.soberMode)
        assertTrue(session.canUseHot)
    }

    @Test fun playersAndTurnsAndNeighbours() {
        val session = PartySession(InMemoryStore())
        assertTrue(session.addPlayer("Ana"))
        assertTrue(session.addPlayer("Leo"))
        assertTrue(session.addPlayer("Sara"))
        assertFalse(session.addPlayer("ana"))
        assertEquals("Ana", session.currentPlayer?.name)
        session.nextTurn()
        assertEquals("Leo", session.currentPlayer?.name)
        val leo = session.players[1]
        assertEquals("Sara", session.playerLeftOf(leo)?.name)
        assertEquals("Ana", session.playerRightOf(leo)?.name)
        session.movePlayer(2, 0)
        assertEquals(listOf("Sara", "Ana", "Leo"), session.players.map { it.name })
    }

    @Test fun persistsAcrossLaunches() {
        val store = InMemoryStore()
        val first = PartySession(store)
        first.updateAgeStatus(AgeStatus.ADULT)
        first.addPlayer("Ana")
        first.addPlayer("Leo")
        first.updateSetupDone(true)
        first.give(3, first.players[0])
        first.updateWaterEvery(5)
        first.nextTurn()
        first.undoSip(first.players[0])
        first.addCustomCard("he ido a Ibiza", GameKind.NEVER_HAVE, PartyMode.NORMAL)

        val second = PartySession(store)
        assertEquals(AgeStatus.ADULT, second.ageStatus)
        assertEquals(listOf("Ana", "Leo"), second.players.map { it.name })
        assertTrue(second.setupDone)
        assertEquals(2, second.ledger.count(second.players[0].id))
        assertEquals("Leo", second.currentPlayer?.name)
        assertEquals(5, second.waterEvery)
        assertEquals(listOf("Yo nunca he ido a Ibiza"), second.customCards(GameKind.NEVER_HAVE, PartyMode.NORMAL).map { it.text })
    }

    @Test fun demoSessionNeverPersists() {
        val store = InMemoryStore()
        val demo = PartySession(store, demo = true)
        assertEquals(4, demo.players.size)
        demo.give(2, demo.players[0])
        assertTrue(PartySession(store).players.isEmpty())
    }

    @Test fun waterBreaksOnlyWhenDrinking() {
        val session = PartySession(InMemoryStore())
        session.updateAgeStatus(AgeStatus.ADULT)
        session.updateWaterEvery(5)
        repeat(5) { session.registerRound() }
        assertNotNull(session.pendingWaterBreak)

        val sober = PartySession(InMemoryStore())
        sober.updateAgeStatus(AgeStatus.MINOR)
        sober.updateWaterEvery(5)
        repeat(10) { sober.registerRound() }
        assertNull(sober.pendingWaterBreak)
    }
}
