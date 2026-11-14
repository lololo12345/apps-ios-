package app.ronda.party.ui.games

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowDownward
import androidx.compose.material.icons.rounded.ArrowUpward
import androidx.compose.material.icons.rounded.Layers
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Style
import androidx.compose.material.icons.rounded.PanTool
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material.icons.rounded.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.runtime.LaunchedEffect
import app.ronda.party.core.CircleGame
import app.ronda.party.core.HigherLowerGame
import app.ronda.party.core.Player
import app.ronda.party.core.SpanishCard
import app.ronda.party.model.GameKind
import app.ronda.party.model.PartyMode
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.BigButton
import app.ronda.party.ui.components.Body
import app.ronda.party.ui.components.Callout
import app.ronda.party.ui.components.Caption
import app.ronda.party.ui.components.Footnote
import app.ronda.party.ui.components.GameScaffold
import app.ronda.party.ui.components.GradientText
import app.ronda.party.ui.components.Headline
import app.ronda.party.ui.components.SipBadge
import app.ronda.party.ui.components.SpanishCardView
import app.ronda.party.ui.components.Subheadline
import app.ronda.party.ui.components.Title3
import app.ronda.party.ui.components.rounded
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.LocalReduceMotion
import app.ronda.party.ui.theme.Neon
import app.ronda.party.ui.theme.gradient
import app.ronda.party.ui.theme.neonCard

/** A card turned over around the vertical axis (new card flips in as the old one flips out). */
@Composable
fun FlippingCard(card: SpanishCard, size: androidx.compose.ui.unit.Dp) {
    val reduceMotion = LocalReduceMotion.current
    Box(Modifier.height(size * 1.45f), contentAlignment = Alignment.Center) {
        AnimatedContent(card, transitionSpec = { flip(reduceMotion) }, contentKey = { it.id }, label = "flip") { shown ->
            val angle = remember { Animatable(if (reduceMotion) 0f else -90f) }
            LaunchedEffect(Unit) { angle.animateTo(0f, tween(380, easing = FastOutSlowInEasing)) }
            SpanishCardView(shown, size, Modifier.graphicsLayer { rotationY = angle.value; cameraDistance = 14f * density })
        }
    }
}

private fun flip(reduceMotion: Boolean): ContentTransform =
    if (reduceMotion) fadeIn(tween(200)) togetherWith fadeOut(tween(200))
    else fadeIn(tween(200, delayMillis = 120)) togetherWith fadeOut(tween(160))

@Composable
fun HigherLowerScreen(session: PartySession, onClose: () -> Unit) {
    val colors = GameKind.HIGHER_LOWER.gradient(PartyMode.NORMAL)
    // Built up front so the first frame (during the zoom-in) already shows a card.
    var game by remember { mutableStateOf(HigherLowerGame.new()) }
    var message by remember { mutableStateOf<Pair<String, Boolean>?>(null) }

    fun guess(choice: HigherLowerGame.Guess) {
        val player = session.currentPlayer
        val move = game.guess(choice)
        game = move.game
        val name = player?.name ?: "Alguien"
        when (val outcome = move.outcome) {
            is HigherLowerGame.Outcome.Hit -> {
                Haptics.success()
                message = "¡Acierto! ${move.card.fullName}. El bote sube a ${outcome.pot}." to true
            }
            is HigherLowerGame.Outcome.Miss -> {
                Haptics.warning()
                session.give(outcome.drinks, player)
                message = "Fallo: ${move.card.fullName}. $name ${session.lexicon.drink(outcome.drinks)}." to false
                session.nextTurn(); session.registerRound()
            }
            is HigherLowerGame.Outcome.Tie -> {
                Haptics.warning()
                session.give(outcome.drinks, player)
                message = "¡Empate! ${move.card.fullName}. $name ${session.lexicon.drink(outcome.drinks)}." to false
                session.nextTurn(); session.registerRound()
            }
        }
    }

    fun stand() {
        val name = session.currentPlayer?.name ?: "Alguien"
        game = game.stand()
        session.nextTurn()
        Haptics.tap(Haptics.Strength.MEDIUM)
        message = "$name se planta. El bote de ${game.pot} pasa a ${session.currentPlayer?.name ?: "el siguiente"}." to true
    }

    GameScaffold(
        GameKind.HIGHER_LOWER, PartyMode.NORMAL, session, onClose,
        controls = {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                BigButton("Menor", Modifier.weight(1f), icon = Icons.Rounded.ArrowDownward, tint = Neon.cyan, tag = "hl.lower") { guess(HigherLowerGame.Guess.LOWER) }
                BigButton("Mayor", Modifier.weight(1f), icon = Icons.Rounded.ArrowUpward, tint = Neon.amber, tag = "hl.higher") { guess(HigherLowerGame.Guess.HIGHER) }
            }
            AnimatedVisibility(game.canStand) {
                BigButton("Plantarse y pasar el bote", icon = Icons.Rounded.PanTool, tint = Neon.lime, prominent = false, tag = "hl.stand") { stand() }
            }
            Text("Orden: As · 2–7 · Sota · Caballo · Rey. Si sale igual, cuenta como fallo.", style = Caption.copy(color = Neon.tertiaryText), textAlign = TextAlign.Center)
        },
    ) {
        Spacer(Modifier.weight(1f))
        GradientText("Le toca a ${session.currentPlayer?.name ?: "—"}", colors, Title3, Modifier.testTag("hl.player"))
        Spacer(Modifier.height(18.dp))
        FlippingCard(game.current, 160.dp)
        Spacer(Modifier.height(18.dp))
        Row(Modifier.testTag("hl.pot"), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            SipBadge(maxOf(1, game.pot), session.lexicon, if (session.lexicon.soberMode) "Si fallas, sumas" else "Si fallas, bebes")
            if (game.streak > 0) {
                Icon(Icons.Rounded.Whatshot, null, tint = Neon.amber, modifier = Modifier.size(18.dp))
                Text(if (game.streak == 1) "1 acierto" else "${game.streak} aciertos seguidos", style = Subheadline.copy(color = Neon.amber, fontWeight = FontWeight.Bold))
            }
        }
        Spacer(Modifier.height(18.dp))
        Box(Modifier.heightIn(min = 52.dp), contentAlignment = Alignment.Center) {
            AnimatedContent(
                message,
                transitionSpec = { (slideInVertically { it / 2 } + fadeIn()) togetherWith fadeOut(tween(150)) },
                label = "message",
            ) { shown ->
                if (shown != null) {
                    Text(shown.first, style = Headline.copy(color = if (shown.second) Neon.lime else Neon.orange), textAlign = TextAlign.Center)
                }
            }
        }
        Spacer(Modifier.weight(1f))
    }
}

private data class CircleDraw(val card: SpanishCard, val rule: CircleGame.Rule, val drawer: Player?, val finalKing: Boolean)

@Composable
fun CircleScreen(mode: PartyMode, session: PartySession, onClose: () -> Unit) {
    val colors = GameKind.CIRCLE.gradient(mode)
    var game by remember { mutableStateOf(CircleGame.new(mode == PartyMode.HOT)) }
    var drawn by remember { mutableStateOf<CircleDraw?>(null) }
    var autoNote by remember { mutableStateOf<String?>(null) }

    fun draw() {
        val result = game.draw() ?: return
        game = result.game
        val drawer = session.currentPlayer
        val rule = result.rule
        val notes = mutableListOf<String>()
        if (rule.drawerSips > 0 && drawer != null) {
            session.give(rule.drawerSips, drawer)
            notes += "${drawer.name}: +${rule.drawerSips}"
        }
        if (rule.everyoneSips > 0) {
            session.everyone(rule.everyoneSips)
            notes += "Todos: +${rule.everyoneSips}"
        }
        // In the normal deck, 4 and 5 send a sip to the neighbours automatically.
        if (mode == PartyMode.NORMAL && drawer != null && (result.card.rank == 4 || result.card.rank == 5)) {
            val target = if (result.card.rank == 4) session.playerLeftOf(drawer) else session.playerRightOf(drawer)
            if (target != null) {
                session.give(1, target)
                notes += "${target.name}: +1"
            }
        }
        autoNote = if (notes.isEmpty()) null else "Apuntado en el marcador · " + notes.joinToString(" · ")
        if (result.isFinalKing) Haptics.boom() else Haptics.tap(Haptics.Strength.MEDIUM)
        drawn = CircleDraw(result.card, rule, drawer, result.isFinalKing)
        session.nextTurn()
        session.registerRound()
    }

    GameScaffold(
        GameKind.CIRCLE, mode, session, onClose,
        controls = {
            if (game.isFinished) {
                BigButton("Nueva ronda", icon = Icons.Rounded.Refresh, tint = colors.first(), tag = "circle.restart") {
                    game = CircleGame.new(mode == PartyMode.HOT)
                    drawn = null
                    autoNote = null
                }
            } else {
                BigButton("Sacar carta", icon = Icons.Rounded.Style, tint = colors.first(), tag = "circle.draw") { draw() }
            }
        },
    ) {
        Spacer(Modifier.weight(1f))
        GradientText(
            if (game.isFinished) "¡Ronda terminada!" else "Le toca a ${session.currentPlayer?.name ?: "—"}",
            colors, Title3, Modifier.testTag("circle.player"),
        )
        Spacer(Modifier.height(10.dp))
        Row(Modifier.testTag("circle.status"), horizontalArrangement = Arrangement.spacedBy(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Rounded.Layers, null, tint = Neon.secondaryText, modifier = Modifier.size(16.dp))
            Text("${game.cardsLeft} cartas", style = Subheadline.copy(color = Neon.secondaryText))
            Icon(Icons.Rounded.WorkspacePremium, null, tint = if (game.kingsDrawn >= 3) Neon.crimson else Neon.secondaryText, modifier = Modifier.size(16.dp))
            Text("Reyes: ${game.kingsDrawn}/4", style = Subheadline.copy(color = if (game.kingsDrawn >= 3) Neon.crimson else Neon.secondaryText))
        }
        Spacer(Modifier.height(16.dp))
        val current = drawn
        if (current != null) {
            FlippingCard(current.card, 130.dp)
            Spacer(Modifier.height(16.dp))
            Column(
                Modifier.fillMaxWidth().neonCard(colors).padding(18.dp).testTag("circle.rule"),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                GradientText(current.rule.title, if (current.finalKing) listOf(Neon.crimson, Neon.orange) else colors, rounded(22.sp, FontWeight.Black))
                Text(session.lexicon.adapt(current.rule.detail), style = Body, textAlign = TextAlign.Center)
                autoNote?.let { Text(it, style = Footnote.copy(color = Neon.amber, fontWeight = FontWeight.SemiBold), textAlign = TextAlign.Center) }
            }
        } else {
            Column(Modifier.padding(vertical = 40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(Icons.Rounded.Style, null, tint = colors.first(), modifier = Modifier.size(64.dp))
                Text("Las cartas están en círculo. Por turnos, sacad una y cumplid su norma.", style = Callout.copy(color = Neon.secondaryText), textAlign = TextAlign.Center)
            }
        }
        Spacer(Modifier.weight(1f))
    }
}
