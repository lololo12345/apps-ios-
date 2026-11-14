package app.ronda.party.ui.components

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Close
import androidx.compose.material.icons.rounded.LocalBar
import androidx.compose.material.icons.rounded.PanTool
import androidx.compose.material.icons.rounded.QuestionMark
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ronda.party.core.Lexicon
import app.ronda.party.core.Player
import app.ronda.party.core.SpanishCard
import app.ronda.party.model.GameKind
import app.ronda.party.model.PartyMode
import app.ronda.party.session.PartySession
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.Neon
import app.ronda.party.ui.theme.NightBackground
import app.ronda.party.ui.theme.glass
import app.ronda.party.ui.theme.gradient
import app.ronda.party.ui.theme.gradientStyle
import app.ronda.party.ui.theme.icon
import app.ronda.party.ui.theme.neonCard
import app.ronda.party.ui.theme.pressScale

/** Numeric roll like SwiftUI's numericText: up when the value grows, down when it shrinks. */
object NumberTransition {
    fun spec(from: Int, to: Int): androidx.compose.animation.ContentTransform {
        val up = to >= from
        return (slideInVertically(tween(220)) { if (up) it else -it } + fadeIn(tween(220))) togetherWith
            (slideOutVertically(tween(220)) { if (up) -it else it } + fadeOut(tween(160)))
    }
}

// Typography helpers

fun rounded(size: TextUnit, weight: FontWeight = FontWeight.Bold) = TextStyle(fontSize = size, fontWeight = weight, color = Color.White)
val TitleStyle = rounded(28.sp, FontWeight.Black)
val Title2 = rounded(22.sp, FontWeight.Bold)
val Title3 = rounded(20.sp, FontWeight.Bold)
val Headline = rounded(17.sp, FontWeight.SemiBold)
val Body = rounded(17.sp, FontWeight.Normal)
val Callout = rounded(16.sp, FontWeight.Normal)
val Subheadline = rounded(15.sp, FontWeight.SemiBold)
val Footnote = rounded(13.sp, FontWeight.Normal)
val Caption = rounded(12.sp, FontWeight.Normal)

@Composable
fun GradientText(text: String, colors: List<Color>, style: TextStyle, modifier: Modifier = Modifier, textAlign: TextAlign? = null) {
    Text(text, modifier, style = gradientStyle(style, colors), textAlign = textAlign)
}

/** Circular glass icon button (close, help, header actions). */
@Composable
fun GlassIconButton(icon: ImageVector, label: String, tag: String? = null, tint: Color? = null, size: Dp = 44.dp, onClick: () -> Unit) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        Modifier
            .pressScale(interaction)
            .size(size)
            .clip(CircleShape)
            .glass(CircleShape, tint)
            .clickable(interaction, indication = null, role = Role.Button) { onClick() }
            .semantics { contentDescription = label }
            .then(if (tag != null) Modifier.testTag(tag) else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
    }
}

/**
 * Main call-to-action button. Taps closer together than [cooldownMs] are ignored, so a double tap
 * never skips a card or a turn.
 */
@Composable
fun BigButton(
    title: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    tint: Color = Neon.violet,
    prominent: Boolean = true,
    enabled: Boolean = true,
    tag: String? = null,
    cooldownMs: Long = 350,
    onClick: () -> Unit,
) {
    val interaction = remember { MutableInteractionSource() }
    var lastTap by remember { mutableStateOf(0L) }
    val shape = RoundedCornerShape(50)
    Row(
        modifier
            .pressScale(interaction)
            .fillMaxWidth()
            .heightIn(min = 54.dp)
            .clip(shape)
            .then(
                if (prominent) Modifier
                    .background(Brush.verticalGradient(listOf(tint, tint.copy(alpha = 0.82f))), shape)
                    .border(1.dp, Color.White.copy(alpha = 0.22f), shape)
                else Modifier.glass(shape)
            )
            .clickable(interaction, indication = null, enabled = enabled, role = Role.Button) {
                val now = System.currentTimeMillis()
                if (now - lastTap >= cooldownMs) {
                    lastTap = now
                    onClick()
                }
            }
            .alpha(if (enabled) 1f else 0.4f)
            .padding(horizontal = 18.dp, vertical = 14.dp)
            .then(if (tag != null) Modifier.testTag(tag) else Modifier),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        val content = if (prominent) Color.White else tint
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = content, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(8.dp))
        }
        FitText(title, Headline.copy(color = content), minSize = 12.sp)
    }
}

/** One line that shrinks (like SwiftUI's minimumScaleFactor) instead of being cut. */
@Composable
fun FitText(text: String, style: TextStyle, minSize: TextUnit, modifier: Modifier = Modifier) {
    var size by remember(text, style.fontSize) { mutableStateOf(style.fontSize) }
    Text(
        text, modifier, style = style.copy(fontSize = size), maxLines = 1, softWrap = false, overflow = TextOverflow.Clip,
        onTextLayout = { if (it.didOverflowWidth && size.value > minSize.value) size = (size.value * 0.92f).sp },
    )
}

/** Glass capsule with a label (game title in the top bar). */
@Composable
fun GlassPill(modifier: Modifier = Modifier, tint: Color? = null, content: @Composable () -> Unit) {
    val shape = RoundedCornerShape(50)
    Row(
        modifier.clip(shape).glass(shape, tint).padding(horizontal = 14.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) { content() }
}

/**
 * Frame shared by every game: glowing background, glass top bar (close, title, how to play)
 * and a bottom area for the controls.
 */
@Composable
fun GameScaffold(
    game: GameKind,
    mode: PartyMode,
    session: PartySession,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
    controls: @Composable ColumnScope.() -> Unit,
    content: @Composable ColumnScope.() -> Unit,
) {
    val colors = game.gradient(mode)
    var showRules by remember { mutableStateOf(false) }
    Box(modifier.fillMaxSize()) {
        NightBackground(colors)
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = Neon.gutter).padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                GlassIconButton(Icons.Rounded.Close, "Salir del juego", tag = "game.close", onClick = onClose)
                Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                    GlassPill {
                        Icon(game.icon, null, tint = Color.White, modifier = Modifier.size(18.dp))
                        Text(game.title, style = Headline, maxLines = 1, overflow = TextOverflow.Ellipsis)
                        if (mode == PartyMode.HOT) Icon(Icons.Rounded.Whatshot, null, tint = Neon.crimson, modifier = Modifier.size(18.dp))
                    }
                }
                GlassIconButton(Icons.Rounded.QuestionMark, "Cómo se juega", tag = "game.rules") { showRules = true }
            }
            Column(
                Modifier.weight(1f).fillMaxWidth().padding(horizontal = Neon.gutter),
                horizontalAlignment = Alignment.CenterHorizontally,
                content = content,
            )
            Column(
                Modifier.fillMaxWidth().padding(horizontal = Neon.gutter).padding(bottom = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
                content = controls,
            )
        }

        RondaSheet(visible = showRules, onDismiss = { showRules = false }, fullHeight = false) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(game.icon, null, tint = colors.first(), modifier = Modifier.size(26.dp))
                GradientText(game.title, colors, Title2)
            }
            Spacer(Modifier.height(16.dp))
            Text(game.howToPlay, style = Body.copy(color = Neon.secondaryText))
            Spacer(Modifier.height(16.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Rounded.PanTool, null, tint = Neon.secondaryText, modifier = Modifier.size(16.dp))
                Text("Siempre puedes pasar: nadie está obligado a nada.", style = Footnote.copy(color = Neon.secondaryText, fontWeight = FontWeight.SemiBold))
            }
        }

        WaterBreakOverlay(session.pendingWaterBreak) { session.pendingWaterBreak = null }
    }
}

/** Bottom sheet drawn inside the same window (smooth, and visible in screenshot tests). */
@Composable
fun BoxScope.RondaSheet(
    visible: Boolean,
    onDismiss: () -> Unit,
    fullHeight: Boolean = true,
    background: Color = Neon.surface,
    tag: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    BackHandler(enabled = visible, onBack = onDismiss)
    AnimatedVisibility(visible, enter = fadeIn(tween(220)), exit = fadeOut(tween(220))) {
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f))
                .clickable(remember { MutableInteractionSource() }, indication = null) { onDismiss() }
        )
    }
    AnimatedVisibility(
        visible,
        modifier = Modifier.align(Alignment.BottomCenter),
        enter = slideInVertically(tween(320)) { it },
        exit = slideOutVertically(tween(260)) { it },
    ) {
        val shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
        Column(
            Modifier
                .fillMaxWidth()
                .then(if (fullHeight) Modifier.fillMaxHeight(0.94f) else Modifier)
                .clip(shape)
                .background(background, shape)
                .border(1.dp, Neon.hairline, shape)
                .clickable(remember { MutableInteractionSource() }, indication = null) { }
                .navigationBarsPadding()
                .then(if (tag != null) Modifier.testTag(tag) else Modifier)
                .padding(if (fullHeight) 0.dp else 24.dp),
        ) {
            Box(Modifier.fillMaxWidth().padding(top = if (fullHeight) 8.dp else 0.dp), contentAlignment = Alignment.Center) {
                Box(Modifier.padding(bottom = 8.dp).size(width = 40.dp, height = 5.dp).background(Color.White.copy(alpha = 0.25f), CircleShape))
            }
            content()
        }
    }
}

/** Centered confirmation dialog drawn in-window. */
@Composable
fun BoxScope.ConfirmDialog(visible: Boolean, title: String, confirm: String, destructive: Boolean = true, onConfirm: () -> Unit, onDismiss: () -> Unit) {
    BackHandler(enabled = visible, onBack = onDismiss)
    AnimatedVisibility(visible, enter = fadeIn(), exit = fadeOut()) {
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.6f))
                .clickable(remember { MutableInteractionSource() }, indication = null) { onDismiss() },
            contentAlignment = Alignment.Center,
        ) {
            Column(
                Modifier.padding(32.dp).neonCard(listOf(Neon.violet, Neon.magenta)).padding(22.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(title, style = Headline, textAlign = TextAlign.Center)
                BigButton(confirm, tint = if (destructive) Neon.crimson else Neon.violet, tag = "confirm.ok") { onConfirm() }
                BigButton("Cancelar", tint = Color.White, prominent = false, tag = "confirm.cancel") { onDismiss() }
            }
        }
    }
}

/** Big prompt card in the middle of the screen. */
@Composable
fun PromptCard(text: String, colors: List<Color>, eyebrow: String? = null, modifier: Modifier = Modifier) {
    Column(
        modifier
            .fillMaxWidth()
            // Fixed band of heights: short and long cards keep the same footprint, so nothing jumps.
            .heightIn(min = 220.dp, max = 340.dp)
            .neonCard(colors)
            .padding(26.dp)
            .testTag("prompt.card"),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
    ) {
        if (eyebrow != null) {
            GradientText(eyebrow.uppercase(), colors, Footnote.copy(fontWeight = FontWeight.Black, letterSpacing = 1.2.sp))
        }
        AutoSizeText(text, rounded(28.sp, FontWeight.Bold), minSize = 16.sp)
    }
}

/** Text that shrinks (like SwiftUI's minimumScaleFactor) until it fits. */
@Composable
fun AutoSizeText(text: String, style: TextStyle, minSize: TextUnit, modifier: Modifier = Modifier, maxLines: Int = Int.MAX_VALUE) {
    var size by remember(text) { mutableStateOf(style.fontSize) }
    var ready by remember(text) { mutableStateOf(false) }
    Text(
        text,
        modifier.alpha(if (ready) 1f else 0f),
        style = style.copy(fontSize = size),
        textAlign = TextAlign.Center,
        maxLines = maxLines,
        onTextLayout = { result ->
            if ((result.hasVisualOverflow || result.didOverflowHeight) && size.value > minSize.value) {
                size = (size.value * 0.92f).sp
            } else {
                ready = true
            }
        },
    )
}

/** "Bebe 2 sorbos" pill. */
@Composable
fun SipBadge(count: Int, lexicon: Lexicon, prefix: String? = null, modifier: Modifier = Modifier) {
    GlassPill(modifier.padding(0.dp), tint = Neon.amber) {
        Icon(if (lexicon.soberMode) Icons.Rounded.Star else Icons.Rounded.LocalBar, null, tint = Color.White, modifier = Modifier.size(16.dp))
        Text((prefix?.let { "$it " } ?: "") + lexicon.sips(count), style = Subheadline.copy(fontWeight = FontWeight.Bold))
    }
}

/** Multi-select player chips ("¿Quién ha bebido?"). Big groups scroll inside a fixed area. */
@Composable
fun PlayerPicker(
    players: List<Player>,
    selection: Set<String>,
    onChange: (Set<String>) -> Unit,
    single: Boolean = false,
    accent: Color = Neon.violet,
) {
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val columns = maxOf(1, ((maxWidth + 8.dp) / (92.dp + 8.dp)).toInt())
        val scroll = rememberScrollState()
        Column(
            Modifier.fillMaxWidth()
                .then(if (players.size > 8) Modifier.heightIn(max = 150.dp).verticalScroll(scroll) else Modifier),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            players.chunked(columns).forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { player ->
                        val isOn = player.id in selection
                        val interaction = remember { MutableInteractionSource() }
                        val shape = RoundedCornerShape(50)
                        Box(
                            Modifier.weight(1f)
                                .pressScale(interaction)
                                .clip(shape)
                                .background(if (isOn) accent else Neon.surfaceRaised, shape)
                                .border(1.dp, if (isOn) Color.Transparent else Neon.hairline, shape)
                                .clickable(interaction, indication = null, role = Role.Checkbox) {
                                    onChange(
                                        when {
                                            single -> if (isOn) emptySet() else setOf(player.id)
                                            isOn -> selection - player.id
                                            else -> selection + player.id
                                        }
                                    )
                                    Haptics.select()
                                }
                                .semantics { selected = isOn }
                                .testTag("pick.${player.name}")
                                .padding(vertical = 10.dp, horizontal = 6.dp),
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                player.name,
                                style = Subheadline.copy(color = if (isOn) Color.Black else Color.White),
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                        }
                    }
                    repeat(columns - row.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
    }
}

@Composable
fun BoxScope.WaterBreakOverlay(message: String?, onDone: () -> Unit) {
    AnimatedVisibility(
        message != null,
        enter = fadeIn(tween(300)) + scaleIn(initialScale = 0.95f),
        exit = fadeOut(tween(250)) + scaleOut(targetScale = 0.95f),
    ) {
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.6f))
                .clickable(remember { MutableInteractionSource() }, indication = null) { }
                .testTag("water.break"),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                Modifier.padding(32.dp).neonCard(listOf(Neon.cyan, Neon.violet)).padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(18.dp),
            ) {
                Icon(Icons.Rounded.WaterDrop, null, tint = Neon.cyan, modifier = Modifier.size(54.dp))
                Text(message ?: "", style = Title3, textAlign = TextAlign.Center)
                BigButton("¡Hecho!", tint = Neon.cyan, tag = "water.done") { onDone() }
            }
        }
    }
}

/** Spanish playing card face. */
@Composable
fun SpanishCardView(card: SpanishCard, size: Dp = 170.dp, modifier: Modifier = Modifier) {
    val tint = when (card.suit) {
        SpanishCard.Suit.OROS -> Neon.amber
        SpanishCard.Suit.COPAS -> Neon.crimson
        SpanishCard.Suit.ESPADAS -> Neon.cyan
        SpanishCard.Suit.BASTOS -> Neon.lime
    }
    // 🪙 and 🪵 arrived with Android 11's emoji font; older phones get close equivalents.
    val modernEmoji = android.os.Build.VERSION.SDK_INT >= 30
    val glyph = when (card.suit) {
        SpanishCard.Suit.OROS -> if (modernEmoji) "🪙" else "💰"
        SpanishCard.Suit.COPAS -> "🏆"
        SpanishCard.Suit.ESPADAS -> "⚔️"
        SpanishCard.Suit.BASTOS -> if (modernEmoji) "🪵" else "🏑"
    }
    val shape = RoundedCornerShape(size * 0.1f)
    val dark = Color(0xFF1A1726)
    Box(
        modifier
            .size(width = size, height = size * 1.45f)
            .drawBehind {
                drawCircle(
                    Brush.radialGradient(listOf(tint.copy(alpha = 0.45f), Color.Transparent), radius = this.size.maxDimension * 0.75f),
                    radius = this.size.maxDimension * 0.75f,
                    center = Offset(this.size.width / 2, this.size.height * 0.55f),
                )
            }
            .background(Color(0xFFFBF7EE), shape)
            .semantics { contentDescription = card.fullName },
        contentAlignment = Alignment.Center,
    ) {
        Box(Modifier.fillMaxSize().padding(6.dp).border(4.dp, tint, RoundedCornerShape(size * 0.08f)))
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            val fontScale = size.value
            Text(card.shortRank, style = TextStyle(fontSize = (fontScale * 0.42f).sp, fontWeight = FontWeight.Black, color = dark))
            Text(glyph, style = TextStyle(fontSize = (fontScale * 0.22f).sp))
            Text(
                card.rankName.uppercase(),
                style = TextStyle(fontSize = (fontScale * 0.08f).sp, fontWeight = FontWeight.Black, color = dark.copy(alpha = 0.6f), letterSpacing = 1.sp),
            )
        }
    }
}
