package app.ronda.party.ui.games

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Undo
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Palette
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.TouchApp
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ronda.party.core.Duel
import app.ronda.party.core.Player
import app.ronda.party.model.GameKind
import app.ronda.party.model.PartyMode
import app.ronda.party.model.PromptDecks
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.BigButton
import app.ronda.party.ui.components.Caption
import app.ronda.party.ui.components.GameScaffold
import app.ronda.party.ui.components.Headline
import app.ronda.party.ui.components.PlayerPicker
import app.ronda.party.ui.components.Subheadline
import app.ronda.party.ui.components.Title3
import app.ronda.party.ui.components.rounded
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.Neon
import app.ronda.party.ui.theme.gradient
import app.ronda.party.ui.theme.neonCard
import app.ronda.party.ui.theme.pressScale
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.random.Random

private val Duel.Kind.icon: ImageVector
    get() = when (this) {
        Duel.Kind.REFLEX -> Icons.Rounded.Bolt
        Duel.Kind.TAPS -> Icons.Rounded.TouchApp
        Duel.Kind.COLORS -> Icons.Rounded.Palette
    }

@Composable
fun DuelsScreen(session: PartySession, onClose: () -> Unit) {
    val colors = GameKind.DUELS.gradient(PartyMode.NORMAL)
    val penalty = PromptDecks.penalty(GameKind.DUELS, PartyMode.NORMAL)
    /** Chosen fighters in tap order; picking a third replaces the oldest pick. */
    var picked by remember { mutableStateOf(listOf<String>()) }
    var kind by remember { mutableStateOf(Duel.Kind.REFLEX) }
    var fighters by remember { mutableStateOf<Pair<Player, Player>?>(null) }
    var lastResult by remember { mutableStateOf<String?>(null) }

    fun finish(result: Duel.Result, top: Player, bottom: Player) {
        when (result) {
            is Duel.Result.Winner -> {
                val loser = if (result.side == Duel.Side.TOP) bottom else top
                val winner = if (result.side == Duel.Side.TOP) top else bottom
                session.give(penalty, loser)
                lastResult = "Ganó ${winner.name}. ${loser.name} ${session.lexicon.drink(penalty)}."
            }
            Duel.Result.Tie -> {
                session.give(1, listOf(top, bottom))
                lastResult = "Empate: ${top.name} y ${bottom.name} ${if (session.lexicon.soberMode) "suman 1" else "beben 1"}."
            }
        }
        session.registerRound()
    }

    Box(Modifier.fillMaxSize()) {
        GameScaffold(
            GameKind.DUELS, PartyMode.NORMAL, session, onClose,
            controls = {
                BigButton("¡A luchar!", icon = Icons.Rounded.Bolt, tint = colors.first(), enabled = picked.size == 2, tag = "duel.start") {
                    val chosen = picked.mapNotNull { id -> session.players.firstOrNull { it.id == id } }
                    if (chosen.size == 2) {
                        Haptics.tap(Haptics.Strength.HEAVY)
                        fighters = chosen[0] to chosen[1]
                    }
                }
            },
        ) {
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(vertical = 12.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Text("Elige dos jugadores", style = Headline)
                PlayerPicker(session.players, picked.toSet(), { next ->
                    var list = picked.filter { it in next }
                    next.filter { it !in list }.forEach { list = list + it }
                    picked = list.takeLast(2)
                }, accent = colors.first())
                Text("Elige el duelo", style = Headline)
                Duel.Kind.entries.forEach { item ->
                    val selected = kind == item
                    val interaction = remember { MutableInteractionSource() }
                    Row(
                        Modifier.fillMaxWidth().pressScale(interaction)
                            .neonCard(if (selected) colors else listOf(Neon.hairline, Neon.hairline), radius = 18.dp)
                            .clip(androidx.compose.foundation.shape.RoundedCornerShape(18.dp))
                            .clickable(interaction, indication = null, role = Role.RadioButton) { kind = item; Haptics.select() }
                            .testTag("duel.kind.${item.name.lowercase()}")
                            .padding(14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp),
                    ) {
                        Icon(item.icon, null, tint = colors.first(), modifier = Modifier.size(28.dp))
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                            Text(item.title, style = Headline)
                            Text(item.instructions, style = Caption.copy(color = Neon.secondaryText))
                        }
                        Icon(
                            if (selected) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked, null,
                            tint = if (selected) colors.first() else Neon.secondaryText,
                        )
                    }
                }
                AnimatedContent(lastResult, transitionSpec = { (slideInVertically { it } + fadeIn()) togetherWith2 fadeOut() }, label = "duelResult") { text ->
                    if (text != null) Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.EmojiEvents, null, tint = Neon.amber, modifier = Modifier.size(18.dp))
                        Text(text, style = Subheadline.copy(color = Neon.amber))
                    }
                }
            }
        }

        AnimatedVisibility(fighters != null, enter = fadeIn(tween(250)) + scaleIn(initialScale = 0.96f), exit = fadeOut(tween(200))) {
            val pair = fighters
            if (pair != null) {
                DuelArena(kind, pair.first, pair.second, onResult = { finish(it, pair.first, pair.second) }, onBack = { fighters = null })
            }
        }
    }
}

private infix fun androidx.compose.animation.EnterTransition.togetherWith2(exit: androidx.compose.animation.ExitTransition) =
    androidx.compose.animation.ContentTransform(this, exit)

private sealed interface ArenaPhase {
    data class Countdown(val value: Int) : ArenaPhase
    data object Waiting : ArenaPhase
    data object Live : ArenaPhase
    data class Finished(val result: Duel.Result) : ArenaPhase
}

/** Face-to-face arena: the top half is rotated so each player reads their side. */
@Composable
private fun DuelArena(kind: Duel.Kind, top: Player, bottom: Player, onResult: (Duel.Result) -> Unit, onBack: () -> Unit) {
    val scope = rememberCoroutineScope()
    var phase by remember { mutableStateOf<ArenaPhase>(ArenaPhase.Countdown(3)) }
    var tapsTop by remember { mutableIntStateOf(0) }
    var tapsBottom by remember { mutableIntStateOf(0) }
    var rounds by remember { mutableStateOf(Duel.colorRounds()) }
    var roundIndex by remember { mutableIntStateOf(0) }
    var remaining by remember { mutableFloatStateOf(Duel.TAP_DURATION.toFloat()) }
    var job by remember { mutableStateOf<Job?>(null) }
    var round by remember { mutableIntStateOf(0) }
    val result by rememberUpdatedState(onResult)
    BackHandler(onBack = onBack)
    DisposableEffect(Unit) { onDispose { job?.cancel() } }

    fun finish(outcome: Duel.Result) {
        if (phase is ArenaPhase.Finished) return
        job?.cancel()
        Haptics.boom()
        phase = ArenaPhase.Finished(outcome)
        result(outcome)
    }

    LaunchedEffect(round) {
        tapsTop = 0; tapsBottom = 0; roundIndex = 0; remaining = Duel.TAP_DURATION.toFloat()
        rounds = Duel.colorRounds()
        job = scope.launch {
            for (value in 3 downTo 1) {
                phase = ArenaPhase.Countdown(value)
                Haptics.tap(Haptics.Strength.MEDIUM)
                delay(700)
            }
            when (kind) {
                Duel.Kind.REFLEX -> {
                    phase = ArenaPhase.Waiting
                    delay(Random.nextLong(1500, 4500))
                    if (phase != ArenaPhase.Waiting) return@launch
                    phase = ArenaPhase.Live
                    Haptics.tap(Haptics.Strength.HEAVY)
                }
                Duel.Kind.TAPS -> {
                    phase = ArenaPhase.Live
                    var left = Duel.TAP_DURATION
                    while (isActive && left > 0) {
                        remaining = left.toFloat()
                        delay(100)
                        left -= 0.1
                    }
                    remaining = 0f
                    finish(Duel.resolveTaps(tapsTop, tapsBottom))
                }
                Duel.Kind.COLORS -> {
                    phase = ArenaPhase.Live
                    for (index in rounds.indices) {
                        roundIndex = index
                        delay(1100)
                        if (phase != ArenaPhase.Live) return@launch
                    }
                    // Nobody tapped on a match: both drink.
                    finish(Duel.Result.Tie)
                }
            }
        }
    }

    fun tapped(side: Duel.Side) {
        val current = phase
        when {
            current == ArenaPhase.Waiting && kind == Duel.Kind.REFLEX -> finish(Duel.resolveReflex(side, beforeGo = true))
            current == ArenaPhase.Live -> when (kind) {
                Duel.Kind.REFLEX -> finish(Duel.resolveReflex(side, beforeGo = false))
                Duel.Kind.TAPS -> {
                    if (side == Duel.Side.TOP) tapsTop++ else tapsBottom++
                    Haptics.tap()
                }
                Duel.Kind.COLORS -> rounds.getOrNull(roundIndex)?.let { finish(Duel.resolveColorTap(side, it)) }
            }
        }
    }

    Box(Modifier.fillMaxSize().background(Neon.ink)) {
        Column(Modifier.fillMaxSize()) {
            Half(Duel.Side.TOP, top, kind, phase, tapsTop, remaining, rounds.getOrNull(roundIndex), roundIndex, Modifier.weight(1f).graphicsLayer { rotationZ = 180f }) { tapped(it) }
            Box(Modifier.fillMaxWidth().height(3.dp).background(Brush.horizontalGradient(listOf(Neon.magenta, Neon.orange))))
            Half(Duel.Side.BOTTOM, bottom, kind, phase, tapsBottom, remaining, rounds.getOrNull(roundIndex), roundIndex, Modifier.weight(1f)) { tapped(it) }
        }
        AnimatedVisibility(phase is ArenaPhase.Finished, modifier = Modifier.align(Alignment.Center), enter = fadeIn() + scaleIn(initialScale = 0.8f), exit = fadeOut()) {
            Row(
                Modifier.padding(horizontal = 24.dp)
                    .background(Neon.ink.copy(alpha = 0.88f), androidx.compose.foundation.shape.RoundedCornerShape(50))
                    .padding(8.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                BigButton("Volver", Modifier.weight(1f), icon = Icons.AutoMirrored.Rounded.Undo, tint = androidx.compose.ui.graphics.Color.White, prominent = false, tag = "duel.back") { onBack() }
                BigButton("Revancha", Modifier.weight(1f), icon = Icons.Rounded.Refresh, tint = Neon.magenta, tag = "duel.rematch") {
                    job?.cancel()
                    phase = ArenaPhase.Countdown(3)
                    round++
                }
            }
        }
    }
}

@Composable
private fun Half(
    side: Duel.Side,
    player: Player,
    kind: Duel.Kind,
    phase: ArenaPhase,
    taps: Int,
    remaining: Float,
    colorRound: Duel.ColorRound?,
    roundIndex: Int,
    modifier: Modifier,
    onTap: (Duel.Side) -> Unit,
) {
    val target = when {
        phase == ArenaPhase.Live && kind == Duel.Kind.REFLEX -> Neon.lime.copy(alpha = 0.85f)
        phase is ArenaPhase.Finished -> when (val r = phase.result) {
            is Duel.Result.Winner -> if (r.side == side) Neon.lime.copy(alpha = 0.35f) else Neon.crimson.copy(alpha = 0.35f)
            Duel.Result.Tie -> Neon.amber.copy(alpha = 0.3f)
        }
        else -> Neon.surface
    }
    val background by animateColorAsState(target, tween(120), label = "half")
    val onTapState by rememberUpdatedState(onTap)
    Box(
        modifier.fillMaxWidth().background(background)
            // Raw pointer down (not a full click) so the fastest finger wins.
            .pointerInput(side) { detectTapGestures(onPress = { onTapState(side) }) }
            .semantics(mergeDescendants = true) { onClick { onTapState(side); true } }
            .testTag("duel.half.${side.name.lowercase()}"),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(16.dp)) {
            Text(player.name, style = rounded(22.sp, FontWeight.Black))
            when (phase) {
                is ArenaPhase.Countdown -> AnimatedContent(phase.value, transitionSpec = { (scaleIn(initialScale = 1.4f) + fadeIn()) togetherWith2 fadeOut() }, label = "count") {
                    Text("$it", style = rounded(80.sp, FontWeight.Black))
                }
                ArenaPhase.Waiting -> Text(if (kind == Duel.Kind.REFLEX) "Espera al verde…" else "¡Atento!", style = Title3.copy(fontWeight = FontWeight.SemiBold))
                ArenaPhase.Live -> when (kind) {
                    Duel.Kind.REFLEX -> Text("¡TOCA!", style = rounded(56.sp, FontWeight.Black).copy(color = Neon.ink))
                    Duel.Kind.TAPS -> Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text("$taps", style = rounded(72.sp, FontWeight.Black))
                        Text(String.format(java.util.Locale.ROOT, "%.1f s", remaining), style = Headline.copy(color = Neon.secondaryText))
                    }
                    Duel.Kind.COLORS -> colorRound?.let {
                        AnimatedContent(roundIndex, transitionSpec = { fadeIn(tween(120)) togetherWith2 fadeOut(tween(80)) }, label = "word") { _ ->
                            Text(Duel.ColorRound.PALETTE[it.word], style = rounded(52.sp, FontWeight.Black).copy(color = listOf(Color.Red, Color(0xFF2F6BFF), Color(0xFF22C55E), Color.Yellow)[it.ink]))
                        }
                    }
                }
                is ArenaPhase.Finished -> Text(
                    when (val r = phase.result) {
                        Duel.Result.Tie -> "Empate"
                        is Duel.Result.Winner -> if (r.side == side) "¡Ganas! 🏆" else "Pierdes 🍻"
                    },
                    style = rounded(34.sp, FontWeight.Black),
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}
