package app.ronda.party.ui.games

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ronda.party.core.BombFuse
import app.ronda.party.core.ShuffledDeck
import app.ronda.party.core.capitalizedFirst
import app.ronda.party.model.GameKind
import app.ronda.party.model.PartyMode
import app.ronda.party.model.PromptDecks
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.AutoSizeText
import app.ronda.party.ui.components.BigButton
import app.ronda.party.ui.components.Footnote
import app.ronda.party.ui.components.GameScaffold
import app.ronda.party.ui.components.GradientText
import app.ronda.party.ui.components.Headline
import app.ronda.party.ui.components.PlayerPicker
import app.ronda.party.ui.components.Subheadline
import app.ronda.party.ui.components.rounded
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.LocalReduceMotion
import app.ronda.party.ui.theme.Neon
import app.ronda.party.ui.theme.gradient
import app.ronda.party.ui.theme.neonCard
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.sin

private enum class BombPhase { READY, BURNING, EXPLODED }

/** Hot potato with categories: the phone ticks faster and faster and explodes at a random moment. */
@Composable
fun BombGameScreen(mode: PartyMode, session: PartySession, onClose: () -> Unit) {
    val colors = GameKind.BOMB.gradient(mode)
    val penalty = PromptDecks.penalty(GameKind.BOMB, mode)
    val reduceMotion = LocalReduceMotion.current
    val scope = rememberCoroutineScope()

    val categories = remember { ShuffledDeck(PromptDecks.prompts(GameKind.BOMB, mode, session.intensity)) }
    var category by remember { mutableStateOf(categories.draw() ?: "") }
    var phase by remember { mutableStateOf(BombPhase.READY) }
    var ticks by remember { mutableIntStateOf(0) }
    var heat by remember { mutableFloatStateOf(0f) }
    var holder by remember { mutableStateOf(emptySet<String>()) }
    var fuseJob by remember { mutableStateOf<Job?>(null) }
    val shake = remember { Animatable(0f) }
    val flash = remember { Animatable(0f) }
    DisposableEffect(Unit) { onDispose { fuseJob?.cancel() } }

    fun light() {
        val fuse = BombFuse.random()
        phase = BombPhase.BURNING
        ticks = 0
        Haptics.tap(Haptics.Strength.HEAVY)
        fuseJob?.cancel()
        fuseJob = scope.launch {
            // Time is the sum of the waits (follows the coroutine clock, so tests can fast-forward it).
            var elapsed = 0.0
            while (isActive && !fuse.hasExploded(elapsed)) {
                ticks += 1
                heat = (elapsed / fuse.duration).toFloat().coerceAtMost(1f)
                if (heat > 0.7f) Haptics.tap(Haptics.Strength.HEAVY) else Haptics.tick()
                val wait = minOf(fuse.tickInterval(elapsed), fuse.duration - elapsed)
                delay((wait * 1000).toLong().coerceAtLeast(1))
                elapsed += wait
            }
            Haptics.boom()
            phase = BombPhase.EXPLODED
            heat = 1f
            if (!reduceMotion) {
                launch { flash.snapTo(0.55f); flash.animateTo(0f, tween(600)) }
                shake.snapTo(0f)
                shake.animateTo(1f, tween(550, easing = LinearEasing))
            }
        }
    }

    val shakeOffset = if (shake.value in 0.001f..0.999f) (sin(shake.value * PI * 8) * 14 * (1 - shake.value)).toFloat() else 0f

    Box(Modifier.fillMaxSize().graphicsLayer { translationX = shakeOffset.dp.toPx() }) {
        GameScaffold(
            GameKind.BOMB, mode, session, onClose,
            controls = {
                AnimatedContent(phase, transitionSpec = { crossFade() }, label = "bombControls") { shown ->
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        when (shown) {
                            BombPhase.READY -> {
                                BigButton("Encender la mecha", icon = Icons.Rounded.LocalFireDepartment, tint = Neon.orange, tag = "bomb.start") { light() }
                                BigButton("Otra categoría", icon = Icons.Rounded.Shuffle, tint = Neon.orange, prominent = false, tag = "bomb.skip") {
                                    category = categories.draw() ?: category
                                    Haptics.select()
                                }
                            }
                            BombPhase.BURNING -> Text(
                                "No toques nada: solo pásala 🔥",
                                style = Subheadline.copy(color = Neon.secondaryText),
                                modifier = Modifier.padding(vertical = 18.dp),
                            )
                            BombPhase.EXPLODED -> {
                                Text("¿Quién la tenía?", style = Subheadline.copy(color = Neon.secondaryText))
                                PlayerPicker(session.players, holder, { holder = it }, single = true, accent = Neon.orange)
                                BigButton(
                                    if (holder.isEmpty()) "Elige a quien perdió" else session.lexicon.drink(penalty).capitalizedFirst(),
                                    icon = Icons.AutoMirrored.Rounded.ArrowForward, tint = Neon.orange, enabled = holder.isNotEmpty(), tag = "bomb.next",
                                ) {
                                    session.give(penalty, session.players.filter { it.id in holder })
                                    holder = emptySet()
                                    session.registerRound()
                                    phase = BombPhase.READY
                                    heat = 0f
                                    category = categories.draw() ?: category
                                }
                            }
                        }
                    }
                }
            },
        ) {
            Spacer(Modifier.weight(1f))
            Column(
                Modifier.fillMaxWidth().neonCard(colors).padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                GradientText("CATEGORÍA", colors, Footnote.copy(fontWeight = FontWeight.Black, letterSpacing = 1.2.sp))
                AnimatedContent(category, transitionSpec = { crossFade() }, label = "category") {
                    AutoSizeText(it, rounded(30.sp, FontWeight.Bold), minSize = 18.sp, modifier = Modifier.testTag("bomb.category"), maxLines = 3)
                }
            }
            Spacer(Modifier.height(22.dp))
            Bomb(phase, ticks, heat, reduceMotion)
            Spacer(Modifier.height(22.dp))
            Text(
                when (phase) {
                    BombPhase.READY -> "Encended la mecha y pasad el móvil diciendo una palabra cada uno."
                    BombPhase.BURNING -> "¡Rápido! Di una palabra y pásala."
                    BombPhase.EXPLODED -> "¡BOOM! Quien tenga el móvil en la mano, pierde."
                },
                style = Headline.copy(color = Neon.secondaryText),
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.weight(1f))
        }
        // Explosion flash.
        if (flash.value > 0f) Box(Modifier.fillMaxSize().background(Color.White.copy(alpha = flash.value)))
    }
}

@Composable
private fun Bomb(phase: BombPhase, ticks: Int, heat: Float, reduceMotion: Boolean) {
    val glow by animateFloatAsState(heat, tween(400), label = "heat")
    val even = ticks % 2 == 0
    val burning = phase == BombPhase.BURNING && !reduceMotion
    val pulse by animateFloatAsState(if (burning && even) 1.12f else 1f, spring(dampingRatio = 0.5f, stiffness = 1200f), label = "pulse")
    val tilt by animateFloatAsState(if (burning) (if (even) -4f else 4f) else 0f, spring(dampingRatio = 0.5f, stiffness = 1200f), label = "tilt")
    val boom by animateFloatAsState(if (phase == BombPhase.EXPLODED) 1.25f else 1f, spring(dampingRatio = 0.45f, stiffness = 300f), label = "boom")
    Box(
        Modifier.fillMaxWidth().height(230.dp).drawBehind {
            val radius = size.minDimension * 0.6f * (0.9f + glow * 0.3f)
            drawCircle(
                Brush.radialGradient(
                    listOf(Neon.orange.copy(alpha = 0.2f + glow * 0.6f), Neon.crimson.copy(alpha = glow * 0.25f), Color.Transparent),
                    center = center, radius = radius,
                ),
                radius = radius,
            )
        },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            if (phase == BombPhase.EXPLODED) "💥" else "💣",
            style = TextStyle(fontSize = 120.sp),
            modifier = Modifier
                .graphicsLayer { scaleX = pulse * boom; scaleY = pulse * boom; rotationZ = tilt }
                .semantics { contentDescription = if (phase == BombPhase.EXPLODED) "La bomba ha explotado" else "Bomba" },
        )
    }
}
