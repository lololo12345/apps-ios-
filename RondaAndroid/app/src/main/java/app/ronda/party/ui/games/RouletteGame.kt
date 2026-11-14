package app.ronda.party.ui.games

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowDropDown
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ronda.party.content.CardBank
import app.ronda.party.core.Player
import app.ronda.party.core.Roulette
import app.ronda.party.model.GameKind
import app.ronda.party.model.PartyMode
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.BigButton
import app.ronda.party.ui.components.Callout
import app.ronda.party.ui.components.GameScaffold
import app.ronda.party.ui.components.GradientText
import app.ronda.party.ui.components.Title3
import app.ronda.party.ui.components.rounded
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.LocalReduceMotion
import app.ronda.party.ui.theme.Neon
import app.ronda.party.ui.theme.gradient
import app.ronda.party.ui.theme.neonCard
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.pow
import kotlin.random.Random

private const val SPIN_MS = 3200

@Composable
fun RouletteScreen(mode: PartyMode, session: PartySession, onClose: () -> Unit) {
    val colors = GameKind.ROULETTE.gradient(mode)
    val wheel = remember(mode) { Roulette(if (mode == PartyMode.HOT) CardBank.rouletteHot else CardBank.rouletteNormal) }
    val palette = if (mode == PartyMode.HOT) listOf(Neon.crimson, Neon.magenta, Neon.rose, Neon.orange, Neon.violet)
        else listOf(Neon.violet, Neon.cyan, Neon.magenta, Neon.lime, Neon.orange)
    val reduceMotion = LocalReduceMotion.current
    val scope = rememberCoroutineScope()
    val rotation = remember { Animatable(0f) }
    var spinning by remember { mutableStateOf(false) }
    var result by remember { mutableStateOf<Pair<Roulette.Segment, Player?>?>(null) }
    var tickJob by remember { mutableStateOf<Job?>(null) }
    DisposableEffect(Unit) { onDispose { tickJob?.cancel() } }

    fun apply(segment: Roulette.Segment, spinner: Player?) {
        if (segment.spinnerSips > 0) session.give(segment.spinnerSips, spinner)
        if (segment.everyoneSips > 0) session.everyone(segment.everyoneSips)
        if (mode != PartyMode.NORMAL || spinner == null) return
        if (segment.title == "Izquierda") session.give(1, session.playerLeftOf(spinner))
        if (segment.title == "Derecha") session.give(1, session.playerRightOf(spinner))
    }

    fun spin() {
        val index = wheel.pick()
        val target = wheel.rotation(index, rotation.value.toDouble(), extraTurns = if (reduceMotion) 1 else 5, jitter = Random.nextDouble(-1.0, 1.0)).toFloat()
        val spinner = session.currentPlayer
        val start = rotation.value
        spinning = true
        result = null
        Haptics.tap(Haptics.Strength.HEAVY)
        // A tick each time a slice passes the pointer. The wheel decelerates with an ease-out curve
        // (angle ≈ 1 − (1 − t)³), so the k-th of N crossings happens at t = 1 − (1 − k/N)^(1/3).
        tickJob?.cancel()
        if (!reduceMotion) {
            val slice = 360f / wheel.segments.size
            val crossings = maxOf(1, ((target - start) / slice).toInt())
            tickJob = scope.launch {
                var previous = 0.0
                for (k in 1..crossings) {
                    val time = SPIN_MS * (1 - (1 - k.toDouble() / crossings).pow(1.0 / 3.0))
                    delay((time - previous).toLong())
                    previous = time
                    Haptics.tick()
                }
            }
        }
        scope.launch {
            rotation.animateTo(target, tween(SPIN_MS, easing = CubicBezierEasing(0.12f, 0.8f, 0.2f, 1f)))
            val segment = wheel.segments[index]
            apply(segment, spinner)
            Haptics.success()
            result = segment to spinner
            spinning = false
            session.nextTurn()
            session.registerRound()
        }
    }

    GameScaffold(
        GameKind.ROULETTE, mode, session, onClose,
        controls = {
            BigButton(if (spinning) "Girando…" else "¡Girar!", icon = Icons.Rounded.Refresh, tint = colors.first(), enabled = !spinning, tag = "roulette.spin") { spin() }
        },
    ) {
        Spacer(Modifier.weight(1f))
        GradientText("Gira ${session.currentPlayer?.name ?: ""}", colors, Title3)
        Spacer(Modifier.height(18.dp))
        Box(Modifier.size(300.dp).semantics { contentDescription = "Ruleta" }, contentAlignment = Alignment.TopCenter) {
            // Static glow behind the wheel: never redrawn while it spins.
            Box(
                Modifier.size(300.dp).drawBehind {
                    drawCircle(
                        Brush.radialGradient(listOf(colors.first().copy(alpha = 0.45f), Color.Transparent), center = center, radius = size.minDimension * 0.63f),
                        radius = size.minDimension * 0.63f,
                    )
                }
            )
            val titles = wheel.segments.map { session.lexicon.adapt(it.title) }
            // The wheel is drawn once (cached) and only rotated on the GPU: every frame of the spin is cheap.
            Wheel(titles, palette, Modifier.size(300.dp).graphicsLayer { rotationZ = rotation.value })
            Icon(
                Icons.Rounded.ArrowDropDown, null, tint = Color.White,
                modifier = Modifier.size(56.dp).offset(y = (-24).dp),
            )
        }
        Spacer(Modifier.height(18.dp))
        Box(Modifier.heightIn(min = 120.dp)) {
            androidx.compose.animation.AnimatedVisibility(result != null && !spinning, enter = fadeIn() + scaleIn(initialScale = 0.9f), exit = fadeOut()) {
                result?.let { (segment, _) ->
                    Column(
                        Modifier.fillMaxWidth().neonCard(colors).padding(16.dp).testTag("roulette.result"),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        GradientText(session.lexicon.adapt(segment.title), colors, rounded(22.sp, FontWeight.Black))
                        Text(session.lexicon.adapt(segment.detail), style = Callout, textAlign = TextAlign.Center)
                    }
                }
            }
        }
        Spacer(Modifier.weight(1f))
    }
}

/** Static wheel drawing. Segment i spans [i, i+1) × slice, clockwise from the top. */
@Composable
private fun Wheel(titles: List<String>, palette: List<Color>, modifier: Modifier) {
    val measurer = rememberTextMeasurer()
    Box(
        modifier.drawWithCache {
            val radius = size.minDimension / 2
            val slice = 360f / titles.size
            val style = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Black, color = Neon.ink, textAlign = TextAlign.End)
            val labels = titles.map {
                measurer.measure(it, style, maxLines = 1, overflow = TextOverflow.Ellipsis, constraints = Constraints.fixedWidth((radius * 0.56f).toInt()))
            }
            onDrawBehind {
                titles.indices.forEach { index ->
                    val start = index * slice - 90f
                    val color = palette[index % palette.size]
                    drawArc(
                        Brush.verticalGradient(listOf(color, color.copy(alpha = 0.78f))),
                        startAngle = start, sweepAngle = slice, useCenter = true,
                    )
                    drawArc(Neon.ink, startAngle = start, sweepAngle = slice, useCenter = true, style = Stroke(2.dp.toPx()))
                }
                titles.indices.forEach { index ->
                    // Radial label confined to the outer part of its slice so neighbours never overlap.
                    rotate((index + 0.5f) * slice - 90f, pivot = center) {
                        val label = labels[index]
                        translate(center.x + radius * 0.32f, center.y - label.size.height / 2f) {
                            drawText(label)
                        }
                    }
                }
                drawCircle(Neon.ink, radius = size.minDimension * 0.09f)
                drawCircle(Color.White.copy(alpha = 0.8f), radius = size.minDimension * 0.09f, style = Stroke(3.dp.toPx()))
            }
        }
    )
}
