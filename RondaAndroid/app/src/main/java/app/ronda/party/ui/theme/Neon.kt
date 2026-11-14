package app.ronda.party.ui.theme

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Bolt
import androidx.compose.material.icons.rounded.Casino
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.LocalFireDepartment
import androidx.compose.material.icons.rounded.PanTool
import androidx.compose.material.icons.rounded.QuestionAnswer
import androidx.compose.material.icons.rounded.Style
import androidx.compose.material.icons.rounded.SwapVert
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import app.ronda.party.model.GameKind
import app.ronda.party.model.PartyMode
import kotlin.math.max

/**
 * Ronda's identity: neon on near-black, like a club at night. Dark-only on purpose: it is played
 * in dim rooms at night, and a bright screen in the middle of the table would ruin the atmosphere.
 */
object Neon {
    val cyan = Color(0xFF2EE6FF)
    val violet = Color(0xFF8B5CFF)
    val magenta = Color(0xFFFF3FD8)
    val lime = Color(0xFFB6FF3B)
    val orange = Color(0xFFFF7A2F)
    val amber = Color(0xFFFFC234)
    val crimson = Color(0xFFFF2E5E)
    val rose = Color(0xFFFF6FA8)

    val ink = Color(0xFF07060D)
    val surface = Color(0xFF15121F)
    val surfaceRaised = Color(0xFF1E1A2C)
    val hairline = Color.White.copy(alpha = 0.09f)
    val secondaryText = Color.White.copy(alpha = 0.62f)
    val tertiaryText = Color.White.copy(alpha = 0.38f)

    /** Translucent "glass" fill and rim (Android has no Liquid Glass; this mimics its look). */
    val glassFill = Color.White.copy(alpha = 0.09f)
    val glassRim = Color.White.copy(alpha = 0.16f)

    val gutter = 16.dp
    val radius = 26.dp
}

/** Respects the system "remove animations" setting (set from MainActivity). */
val LocalReduceMotion = compositionLocalOf { false }

fun GameKind.gradient(mode: PartyMode): List<Color> {
    if (mode == PartyMode.HOT) {
        return when (this) {
            GameKind.NEVER_HAVE -> listOf(Neon.rose, Neon.crimson)
            GameKind.MOST_LIKELY -> listOf(Neon.magenta, Neon.rose)
            GameKind.TRUTH_OR_DRINK -> listOf(Neon.crimson, Neon.orange)
            GameKind.DARES -> listOf(Neon.rose, Neon.violet)
            GameKind.BOMB -> listOf(Neon.orange, Neon.crimson)
            GameKind.ROULETTE -> listOf(Neon.magenta, Neon.crimson)
            else -> listOf(Neon.crimson, Neon.violet)
        }
    }
    return when (this) {
        GameKind.NEVER_HAVE -> listOf(Neon.cyan, Neon.violet)
        GameKind.MOST_LIKELY -> listOf(Neon.lime, Neon.cyan)
        GameKind.TRUTH_OR_DRINK -> listOf(Neon.violet, Neon.magenta)
        GameKind.DARES -> listOf(Neon.rose, Neon.violet)
        GameKind.BOMB -> listOf(Neon.orange, Neon.crimson)
        GameKind.HIGHER_LOWER -> listOf(Neon.amber, Neon.orange)
        GameKind.CIRCLE -> listOf(Neon.cyan, Neon.lime)
        GameKind.DUELS -> listOf(Neon.magenta, Neon.orange)
        GameKind.ROULETTE -> listOf(Neon.violet, Neon.cyan)
    }
}

val GameKind.icon: ImageVector
    get() = when (this) {
        GameKind.NEVER_HAVE -> Icons.Rounded.PanTool
        GameKind.MOST_LIKELY -> Icons.Rounded.Groups
        GameKind.TRUTH_OR_DRINK -> Icons.Rounded.QuestionAnswer
        GameKind.DARES -> Icons.Rounded.Favorite
        GameKind.BOMB -> Icons.Rounded.LocalFireDepartment
        GameKind.HIGHER_LOWER -> Icons.Rounded.SwapVert
        GameKind.CIRCLE -> Icons.Rounded.Style
        GameKind.DUELS -> Icons.Rounded.Bolt
        GameKind.ROULETTE -> Icons.Rounded.Casino
    }

fun modeColors(mode: PartyMode) = if (mode == PartyMode.HOT) listOf(Neon.crimson, Neon.magenta) else listOf(Neon.violet, Neon.cyan)

/**
 * Static glow backdrop. Radial gradients instead of blurs: same look, no per-frame blur filter,
 * so everything on top keeps the display's full refresh rate.
 */
@Composable
fun NightBackground(colors: List<Color>, modifier: Modifier = Modifier) {
    val first = colors.firstOrNull() ?: Neon.violet
    val last = colors.lastOrNull() ?: Neon.cyan
    Box(
        modifier
            .fillMaxSize()
            .drawBehind {
                drawRect(Neon.ink)
                val longest = max(size.width, size.height)
                drawRect(
                    Brush.radialGradient(
                        listOf(first.copy(alpha = 0.42f), Color.Transparent),
                        center = Offset(size.width * 0.1f, size.height * 0.05f),
                        radius = longest * 0.62f,
                    )
                )
                drawRect(
                    Brush.radialGradient(
                        listOf(last.copy(alpha = 0.32f), Color.Transparent),
                        center = Offset(size.width * 0.95f, size.height * 0.95f),
                        radius = longest * 0.58f,
                    )
                )
            }
    )
}

/** Card surface with a neon gradient rim and a soft coloured glow. */
fun Modifier.neonCard(colors: List<Color>, radius: Dp = Neon.radius): Modifier {
    val shape = RoundedCornerShape(radius)
    val glow = colors.firstOrNull() ?: Color.Transparent
    return this
        .drawBehind {
            // Cheap glow: a radial gradient that fades to nothing (no blurred shadow, no hard edges).
            val radius = max(size.width, size.height) * 0.62f
            drawCircle(
                Brush.radialGradient(listOf(glow.copy(alpha = 0.2f), Color.Transparent), center = Offset(size.width / 2, size.height * 0.6f), radius = radius),
                radius = radius,
                center = Offset(size.width / 2, size.height * 0.6f),
            )
        }
        .background(Neon.surface.copy(alpha = 0.92f), shape)
        .border(1.5.dp, Brush.linearGradient(colors.ifEmpty { listOf(Neon.hairline, Neon.hairline) }), shape)
}

/** Translucent glass surface. */
fun Modifier.glass(shape: Shape, tint: Color? = null): Modifier = this
    .background(tint?.copy(alpha = 0.22f) ?: Neon.glassFill, shape)
    .border(1.dp, Brush.verticalGradient(listOf(Neon.glassRim, Color.White.copy(alpha = 0.05f))), shape)

fun gradientStyle(base: TextStyle, colors: List<Color>): TextStyle =
    base.copy(brush = Brush.linearGradient(if (colors.size >= 2) colors else listOf(colors.first(), colors.first())))

/** Subtle scale-down on press. */
fun Modifier.pressScale(interaction: MutableInteractionSource): Modifier = composed {
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(if (pressed) 0.96f else 1f, spring(stiffness = 900f), label = "press")
    graphicsLayer { scaleX = scale; scaleY = scale }
}
