package app.ronda.party.ui.games

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ronda.party.core.CardText
import app.ronda.party.core.ShuffledDeck
import app.ronda.party.model.GameKind
import app.ronda.party.model.PartyMode
import app.ronda.party.model.PromptDecks
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.BigButton
import app.ronda.party.ui.components.GameScaffold
import app.ronda.party.ui.components.GradientText
import app.ronda.party.ui.components.PlayerPicker
import app.ronda.party.ui.components.PromptCard
import app.ronda.party.ui.components.SipBadge
import app.ronda.party.ui.components.Subheadline
import app.ronda.party.ui.components.rounded
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.LocalReduceMotion
import app.ronda.party.ui.theme.Neon
import app.ronda.party.ui.theme.gradient
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private sealed interface Pointing {
    data object Question : Pointing
    data class Countdown(val value: Int) : Pointing
    data object Pick : Pointing
}

private data class DealtCard(val serial: Int, val text: String, val involved: List<app.ronda.party.core.Player>)

/** Card-based games: Yo nunca, ¿Quién es más probable?, Verdad o trago and Retos. */
@Composable
fun PromptGameScreen(kind: GameKind, mode: PartyMode, session: PartySession, onClose: () -> Unit) {
    val colors = kind.gradient(mode)
    val penalty = PromptDecks.penalty(kind, mode)
    val lexicon = session.lexicon
    val reduceMotion = LocalReduceMotion.current
    val scope = rememberCoroutineScope()

    // The deck is built up front so the very first frame (during the zoom-in) already shows a card.
    val deck = remember {
        val custom = session.customCards(kind, mode).map { it.text }
        ShuffledDeck(PromptDecks.prompts(kind, mode, session.intensity) + custom)
    }
    var serial by remember { mutableIntStateOf(0) }
    fun drawCard(): DealtCard? {
        val template = deck.draw() ?: return null
        val filled = CardText.fill(template, session.players, session.currentPlayer)
        serial += 1
        return DealtCard(serial, filled.text, filled.involved)
    }
    var card by remember { mutableStateOf(drawCard()) }
    var selection by remember { mutableStateOf(emptySet<String>()) }
    var pointing by remember { mutableStateOf<Pointing>(Pointing.Question) }
    var countdown by remember { mutableStateOf<Job?>(null) }

    fun next(advanceTurn: Boolean) {
        selection = emptySet()
        pointing = Pointing.Question
        if (advanceTurn) session.nextTurn()
        session.registerRound()
        card = drawCard()
    }

    fun startCountdown() {
        countdown?.cancel()
        countdown = scope.launch {
            for (value in 3 downTo 1) {
                pointing = Pointing.Countdown(value)
                Haptics.tap(Haptics.Strength.MEDIUM)
                delay(800)
            }
            Haptics.success()
            pointing = Pointing.Pick
        }
    }

    fun eyebrow(c: DealtCard) = when (kind) {
        GameKind.NEVER_HAVE -> if (mode == PartyMode.HOT) "Yo nunca · Hot" else "Yo nunca"
        GameKind.MOST_LIKELY -> "¿Quién es más probable…?"
        GameKind.TRUTH_OR_DRINK -> "Le toca a ${session.currentPlayer?.name ?: "alguien"}"
        GameKind.DARES -> if (c.involved.isEmpty()) "Reto para ${session.currentPlayer?.name ?: "alguien"}" else "Reto"
        else -> kind.title
    }
    val badgePrefix = when (kind) {
        GameKind.NEVER_HAVE -> if (lexicon.soberMode) "Quien sí, suma" else "Quien sí, bebe"
        GameKind.MOST_LIKELY -> if (lexicon.soberMode) "El más señalado suma" else "El más señalado bebe"
        else -> if (lexicon.soberMode) "Si pasas, sumas" else "Si pasas, bebes"
    }
    val accent = colors.first()

    GameScaffold(
        kind, mode, session, onClose,
        controls = {
            when (kind) {
                GameKind.NEVER_HAVE -> {
                    Text(if (lexicon.soberMode) "¿Quién suma punto?" else "¿Quién ha bebido?", style = Subheadline.copy(color = Neon.secondaryText))
                    PlayerPicker(session.players, selection, { selection = it }, accent = accent)
                    BigButton("Siguiente", icon = Icons.AutoMirrored.Rounded.ArrowForward, tint = accent, tag = "prompt.next") {
                        session.give(penalty, session.players.filter { it.id in selection })
                        next(advanceTurn = false)
                    }
                }
                GameKind.MOST_LIKELY -> AnimatedContent(pointing == Pointing.Pick, transitionSpec = { crossFade() }, label = "mostLikely") { picking ->
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        if (picking) {
                            Text("¿A quién habéis señalado más? (si hay empate, marca a todos)", style = Subheadline.copy(color = Neon.secondaryText), textAlign = TextAlign.Center)
                            PlayerPicker(session.players, selection, { selection = it }, accent = accent)
                            BigButton("Siguiente", icon = Icons.AutoMirrored.Rounded.ArrowForward, tint = accent, enabled = selection.isNotEmpty(), tag = "prompt.next") {
                                session.give(penalty, session.players.filter { it.id in selection })
                                next(advanceTurn = false)
                            }
                        } else {
                            BigButton("3, 2, 1… ¡Señalad!", icon = Icons.Rounded.TouchApp, tint = accent, enabled = pointing == Pointing.Question, tag = "prompt.point") {
                                startCountdown()
                            }
                        }
                    }
                }
                else -> Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    val target = card?.involved?.firstOrNull() ?: session.currentPlayer
                    BigButton(
                        if (lexicon.soberMode) "Pasa: +$penalty" else "Pasa: bebe $penalty",
                        Modifier.weight(1f), tint = Neon.amber, prominent = false, tag = "prompt.pass",
                    ) {
                        session.give(penalty, target)
                        Haptics.tap(Haptics.Strength.MEDIUM)
                        next(advanceTurn = true)
                    }
                    BigButton(
                        if (kind == GameKind.DARES) "¡Reto cumplido!" else "Ha contestado",
                        Modifier.weight(1f), icon = Icons.Rounded.Check, tint = accent, tag = "prompt.done",
                    ) {
                        Haptics.success()
                        next(advanceTurn = true)
                    }
                }
            }
        },
    ) {
        Spacer(Modifier.weight(1f))
        AnimatedContent(card, transitionSpec = { deal(reduceMotion).using(SizeTransform(clip = false)) }, contentKey = { it?.serial }, label = "card") { shown ->
            if (shown != null) {
                PromptCard(lexicon.adapt(shown.text), colors, eyebrow(shown))
            } else {
                PromptCard("No hay cartas para este juego.", colors, "Sin cartas")
            }
        }
        Spacer(Modifier.height(18.dp))
        Box(Modifier.heightIn(min = 110.dp), contentAlignment = Alignment.Center) {
            AnimatedContent(
                pointing,
                transitionSpec = { (fadeIn(tween(200)) + scaleIn(initialScale = 0.6f)) togetherWith fadeOut(tween(150)) },
                label = "badge",
            ) { state ->
                if (state is Pointing.Countdown) {
                    GradientText(
                        "${state.value}", colors, rounded(96.sp, FontWeight.Black),
                        Modifier.semantics { contentDescription = "Cuenta atrás ${state.value}" },
                    )
                } else {
                    SipBadge(penalty, lexicon, badgePrefix)
                }
            }
        }
        Spacer(Modifier.weight(1f))
    }
}
