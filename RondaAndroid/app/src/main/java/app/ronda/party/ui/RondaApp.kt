package app.ronda.party.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import app.ronda.party.model.GameKind
import app.ronda.party.model.PartyMode
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.ConfirmDialog
import app.ronda.party.ui.components.RondaSheet
import app.ronda.party.ui.games.BombGameScreen
import app.ronda.party.ui.games.CircleScreen
import app.ronda.party.ui.games.DuelsScreen
import app.ronda.party.ui.games.HigherLowerScreen
import app.ronda.party.ui.games.PromptGameScreen
import app.ronda.party.ui.games.RouletteScreen
import app.ronda.party.ui.screens.AgeGateScreen
import app.ronda.party.ui.screens.HomeScreen
import app.ronda.party.ui.screens.PlayersScreen
import app.ronda.party.ui.screens.ScoreboardContent
import app.ronda.party.ui.screens.SettingsContent
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.LocalReduceMotion
import app.ronda.party.ui.theme.Neon

private enum class Root { AGE, PLAYERS, HOME }

data class ActiveGame(val kind: GameKind, val mode: PartyMode)

@Composable
fun RondaApp(session: PartySession, reduceMotion: Boolean = false, startGame: ActiveGame? = null) {
    MaterialTheme(colorScheme = darkColorScheme(primary = Neon.violet, background = Neon.ink, surface = Neon.surface)) {
        CompositionLocalProvider(LocalReduceMotion provides reduceMotion) {
            val root = when {
                session.ageStatus == null -> Root.AGE
                !session.setupDone || session.players.size < 2 -> Root.PLAYERS
                else -> Root.HOME
            }
            Box(Modifier.fillMaxSize().background(Neon.ink)) {
                AnimatedContent(root, transitionSpec = { fadeIn(tween(400)) togetherWith fadeOut(tween(400)) }, label = "root") { shown ->
                    when (shown) {
                        Root.AGE -> AgeGateScreen(session)
                        Root.PLAYERS -> PlayersScreen(session, isFirstRun = true)
                        Root.HOME -> HomeHost(session, startGame)
                    }
                }
            }
        }
    }
}

@Composable
private fun HomeHost(session: PartySession, startGame: ActiveGame?) {
    var active by remember { mutableStateOf(startGame) }
    var sheet by rememberSaveable { mutableStateOf<String?>(null) }
    var confirmReset by remember { mutableStateOf(false) }
    var confirmAge by remember { mutableStateOf(false) }
    val reduceMotion = LocalReduceMotion.current

    Box(Modifier.fillMaxSize()) {
        // Zoom: the game grows in from the grid and shrinks back when closing.
        AnimatedContent(
            active,
            transitionSpec = {
                if (reduceMotion) fadeIn(tween(200)) togetherWith fadeOut(tween(200))
                else if (targetState != null) {
                    (scaleIn(spring(dampingRatio = 0.86f, stiffness = 420f), initialScale = 0.82f) + fadeIn(tween(220))) togetherWith
                        (scaleOut(tween(300, easing = FastOutSlowInEasing), targetScale = 1.04f) + fadeOut(tween(250)))
                } else {
                    (scaleIn(tween(300), initialScale = 1.04f) + fadeIn(tween(250))) togetherWith
                        (scaleOut(tween(280, easing = FastOutSlowInEasing), targetScale = 0.82f) + fadeOut(tween(220)))
                }
            },
            label = "game",
        ) { game ->
            if (game == null) {
                HomeScreen(
                    session,
                    onOpenGame = { kind, mode -> active = ActiveGame(kind, mode) },
                    onPlayers = { sheet = "players" },
                    onScoreboard = { sheet = "scoreboard" },
                    onSettings = { sheet = "settings" },
                )
            } else {
                BackHandler { active = null }
                val close = { active = null }
                when (game.kind) {
                    GameKind.NEVER_HAVE, GameKind.MOST_LIKELY, GameKind.TRUTH_OR_DRINK, GameKind.DARES ->
                        PromptGameScreen(game.kind, game.mode, session, close)
                    GameKind.BOMB -> BombGameScreen(game.mode, session, close)
                    GameKind.HIGHER_LOWER -> HigherLowerScreen(session, close)
                    GameKind.CIRCLE -> CircleScreen(game.mode, session, close)
                    GameKind.DUELS -> DuelsScreen(session, close)
                    GameKind.ROULETTE -> RouletteScreen(game.mode, session, close)
                }
            }
        }

        RondaSheet(sheet == "players", onDismiss = { sheet = null }, tag = "sheet.players") {
            PlayersScreen(session, isFirstRun = false, onDone = { sheet = null })
        }
        RondaSheet(sheet == "scoreboard", onDismiss = { sheet = null }, background = Neon.ink, tag = "sheet.scoreboard") {
            ScoreboardContent(session, onClose = { sheet = null }, onReset = { confirmReset = true })
        }
        RondaSheet(sheet == "settings", onDismiss = { sheet = null }, background = Neon.ink, tag = "sheet.settings") {
            SettingsContent(session, onClose = { sheet = null }, onAskAgeAgain = { confirmAge = true })
        }
        ConfirmDialog(confirmReset, "¿Reiniciar el marcador?", "Reiniciar", onConfirm = {
            session.resetLedger()
            Haptics.warning()
            confirmReset = false
        }, onDismiss = { confirmReset = false })
        ConfirmDialog(confirmAge, "¿Volver a preguntar la edad?", "Volver a preguntar", destructive = false, onConfirm = {
            confirmAge = false
            sheet = null
            session.hotUnlocked = false
            session.updateAgeStatus(null)
        }, onDismiss = { confirmAge = false })
    }
}
