package app.ronda.party

import androidx.activity.ComponentActivity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import app.ronda.party.session.InMemoryStore
import app.ronda.party.session.PartySession
import app.ronda.party.ui.RondaApp
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * End-to-end flows through the real UI (same scenarios as the iOS UI tests), saving a screenshot
 * of every screen to app/build/screenshots for visual review.
 */
@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [35], qualifiers = "w393dp-h852dp-xxhdpi")
class UiFlowTest {
    @get:Rule val rule = createAndroidComposeRule<ComponentActivity>()

    private fun shot(name: String) {
        rule.waitForIdle()
        rule.onRoot().captureRoboImage("build/screenshots/$name.png")
    }

    private fun tap(tag: String) {
        rule.onNodeWithTag(tag, useUnmergedTree = true).performClick()
        rule.waitForIdle()
    }

    private fun advance(ms: Long) {
        rule.mainClock.advanceTimeBy(ms)
        rule.waitForIdle()
    }

    private fun start(session: PartySession) {
        rule.setContent { RondaApp(session) }
        advance(1200)
    }

    private fun openGame(tag: String) {
        tap(tag)
        advance(800)
    }

    private fun close() {
        tap("game.close")
        advance(800)
    }

    @Test fun firstRunFlow() {
        val session = PartySession(InMemoryStore(), demo = true, fresh = true)
        start(session)
        shot("00-age-gate")
        tap("age.adult")
        advance(800)
        rule.onNodeWithText("¿Quién juega?").assertIsDisplayed()
        for (name in listOf("Ana", "Leo", "Sara")) {
            rule.onNodeWithTag("players.field").performTextInput(name)
            tap("players.add")
        }
        rule.onNodeWithTag("players.field").performTextInput("ana")
        tap("players.add")
        rule.onNodeWithText("Ese nombre ya está o no es válido.").assertIsDisplayed()
        shot("01-players")
        assertEquals(3, session.players.size)
        tap("players.start")
        advance(1200)
        rule.onNodeWithTag("game.normal.neverHave").assertIsDisplayed()
    }

    @Test fun normalGames() {
        val session = PartySession(InMemoryStore(), demo = true)
        start(session)
        shot("02-home-normal")

        openGame("game.normal.neverHave")
        shot("03-never")
        tap("pick.Ana"); tap("pick.Leo")
        tap("prompt.next")
        advance(600)
        assertEquals(1, session.ledger.count(session.players[0].id))
        close()

        openGame("game.normal.mostLikely")
        tap("prompt.point")
        advance(900)
        shot("04-most-likely-countdown")
        advance(2000)
        tap("pick.Sara")
        tap("prompt.next")
        assertEquals(2, session.ledger.count(session.players[2].id))
        close()

        openGame("game.normal.truthOrDrink")
        shot("05-truth")
        tap("prompt.pass")
        advance(600)
        close()

        openGame("game.normal.higherLower")
        tap("hl.higher")
        advance(800)
        shot("06-higher-lower")
        close()

        openGame("game.normal.circle")
        tap("circle.draw")
        advance(800)
        rule.onNodeWithTag("circle.rule").assertIsDisplayed()
        shot("07-circle")
        close()

        openGame("game.normal.roulette")
        tap("roulette.spin")
        advance(1500)
        shot("08-roulette-spinning")
        advance(3000)
        rule.onNodeWithTag("roulette.result").assertIsDisplayed()
        shot("09-roulette")
        close()

        openGame("game.normal.bomb")
        shot("10-bomb")
        tap("bomb.start")
        advance(41_000)
        rule.onNodeWithText("¡BOOM! Quien tenga el móvil en la mano, pierde.").assertIsDisplayed()
        tap("pick.Dani")
        shot("11-bomb-exploded")
        tap("bomb.next")
        advance(600)
        close()

        openGame("game.normal.duels")
        tap("pick.Ana"); tap("pick.Leo"); tap("pick.Dani")
        tap("duel.kind.taps")
        shot("12-duels-setup")
        tap("duel.start")
        advance(2600)
        repeat(5) { tap("duel.half.bottom") }
        tap("duel.half.top")
        advance(600)
        shot("13-duel-arena")
        advance(5000)
        rule.onNodeWithTag("duel.back").assertIsDisplayed()
        shot("14-duel-result")
        tap("duel.back")
        advance(600)
        close()

        tap("home.scoreboard")
        advance(1500)
        shot("15-scoreboard")
        val before = session.ledger.total
        tap("undo.Ana")
        assertEquals(before - 1, session.ledger.total)
        assertTrue(session.ledger.total > 0)
    }

    @Test fun hotSection() {
        val session = PartySession(InMemoryStore(), demo = true)
        start(session)
        tap("mode.hot")
        advance(800)
        shot("20-hot-consent")
        tap("hot.accept")
        advance(800)
        shot("21-home-hot")
        openGame("game.hot.dares")
        shot("22-dares")
        tap("prompt.done")
        advance(600)
        close()
        openGame("game.hot.neverHave")
        shot("23-never-hot")
        close()
        openGame("game.hot.roulette")
        tap("roulette.spin")
        advance(4500)
        shot("24-roulette-hot")
    }

    @Test fun settingsSoberModeAndPlayers() {
        val session = PartySession(InMemoryStore(), demo = true)
        start(session)
        tap("home.settings")
        advance(600)
        shot("30-settings")
        tap("settings.sober")
        assertTrue(session.soberMode)
        tap("settings.customCards")
        advance(600)
        rule.onNodeWithTag("custom.field").performTextInput("he bailado en una mesa")
        tap("custom.add")
        shot("31-custom-cards")
        assertEquals("Yo nunca he bailado en una mesa", session.customCards.first().text)
        rule.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        advance(600)
        rule.activityRule.scenario.onActivity { it.onBackPressedDispatcher.onBackPressed() }
        advance(600)
        openGame("game.normal.truthOrDrink")
        shot("32-truth-sober")
        rule.onNodeWithText("Pasa: +2").assertIsDisplayed()
        close()
        tap("home.players")
        advance(600)
        shot("33-players-sheet")
    }
}
