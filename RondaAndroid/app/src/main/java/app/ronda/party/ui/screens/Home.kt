package app.ronda.party.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Celebration
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Group
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PanTool
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.ThumbUp
import androidx.compose.material.icons.rounded.VerifiedUser
import androidx.compose.material.icons.rounded.Whatshot
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import app.ronda.party.ui.components.NumberTransition
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ronda.party.model.GameKind
import app.ronda.party.model.Intensity
import app.ronda.party.model.PartyMode
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.BigButton
import app.ronda.party.ui.components.Callout
import app.ronda.party.ui.components.Caption
import app.ronda.party.ui.components.GlassIconButton
import app.ronda.party.ui.components.GradientText
import app.ronda.party.ui.components.Headline
import app.ronda.party.ui.components.Subheadline
import app.ronda.party.ui.components.Title3
import app.ronda.party.ui.components.rounded
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.LocalReduceMotion
import app.ronda.party.ui.theme.Neon
import app.ronda.party.ui.theme.NightBackground
import app.ronda.party.ui.theme.glass
import app.ronda.party.ui.theme.gradient
import app.ronda.party.ui.theme.icon
import app.ronda.party.ui.theme.modeColors
import app.ronda.party.ui.theme.neonCard
import app.ronda.party.ui.theme.pressScale
import kotlinx.coroutines.launch

@Composable
fun HomeScreen(
    session: PartySession,
    onOpenGame: (GameKind, PartyMode) -> Unit,
    onPlayers: () -> Unit,
    onScoreboard: () -> Unit,
    onSettings: () -> Unit,
) {
    val mode = session.mode
    Box(Modifier.fillMaxSize()) {
        AnimatedContent(mode, transitionSpec = { fadeIn(tween(500)) togetherWith fadeOut(tween(500)) }, label = "bg") {
            NightBackground(modeColors(it))
        }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().navigationBarsPadding()
                .padding(horizontal = Neon.gutter).padding(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp),
        ) {
            Header(session, onPlayers, onScoreboard, onSettings)
            ModePicker(session)
            AnimatedVisibility(mode == PartyMode.NORMAL, enter = expandVertically() + fadeIn(), exit = shrinkVertically() + fadeOut()) {
                IntensityPicker(session)
            }
            // Normal ⇄ Hot swaps the whole grid with a cross-fade instead of recolouring tiles in place.
            AnimatedContent(
                targetState = Triple(mode, session.canUseHot, session.hotUnlocked),
                transitionSpec = { (fadeIn(tween(300)) + scaleIn(initialScale = 0.98f)) togetherWith fadeOut(tween(200)) },
                label = "grid",
            ) { (shownMode, canUseHot, unlocked) ->
                when {
                    shownMode == PartyMode.HOT && !canUseHot -> LockedHot()
                    shownMode == PartyMode.HOT && !unlocked -> HotConsentCard { session.hotUnlocked = true }
                    else -> GameGrid(session, shownMode, onOpenGame)
                }
            }
        }
    }
}

@Composable
private fun Header(session: PartySession, onPlayers: () -> Unit, onScoreboard: () -> Unit, onSettings: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            GradientText(
                "Ronda",
                if (session.mode == PartyMode.HOT) listOf(Neon.rose, Neon.crimson) else listOf(Neon.magenta, Neon.cyan),
                rounded(40.sp, FontWeight.Black),
            )
            val total = session.ledger.total(session.players)
            Row {
                Text("${session.players.size} jugadores · ${session.lexicon.unitTitle.lowercase()}: ", style = Subheadline.copy(color = Neon.secondaryText, fontWeight = FontWeight.Normal))
                AnimatedContent(total, transitionSpec = { NumberTransition.spec(initialState, targetState) }, label = "total") {
                    Text("$it", style = Subheadline.copy(color = Neon.secondaryText, fontWeight = FontWeight.Normal))
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            GlassIconButton(Icons.Rounded.Group, "Jugadores", tag = "home.players", onClick = onPlayers)
            GlassIconButton(Icons.Rounded.EmojiEvents, "Marcador", tag = "home.scoreboard", onClick = onScoreboard)
            GlassIconButton(Icons.Rounded.Settings, "Ajustes", tag = "home.settings", onClick = onSettings)
        }
    }
}

@Composable
private fun ModePicker(session: PartySession) {
    val shape = RoundedCornerShape(50)
    Row(Modifier.fillMaxWidth().glass(shape).padding(5.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        PartyMode.entries.forEach { item ->
            val selected = session.mode == item
            val textColor by animateColorAsState(if (selected) Color.White else Neon.secondaryText, label = "modeText")
            Row(
                Modifier.weight(1f).clip(shape)
                    .then(if (selected) Modifier.background(Brush.horizontalGradient(modeColors(item).let { if (item == PartyMode.HOT) listOf(Neon.crimson, Neon.magenta) else listOf(Neon.violet, Neon.cyan) }), shape) else Modifier)
                    .clickable(role = Role.Tab) {
                        if (session.mode != item) {
                            session.mode = item
                            Haptics.select()
                        }
                    }
                    .semantics { this.selected = selected }
                    .testTag("mode.${item.name.lowercase()}")
                    .padding(vertical = 12.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Icon(if (item == PartyMode.HOT) Icons.Rounded.Whatshot else Icons.Rounded.Celebration, null, tint = textColor, modifier = Modifier.size(18.dp))
                Spacer(Modifier.size(6.dp))
                Text(item.title, style = Headline.copy(color = textColor))
            }
        }
    }
}

@Composable
private fun IntensityPicker(session: PartySession) {
    val shape = RoundedCornerShape(10.dp)
    Row(Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.08f), shape).padding(3.dp).testTag("home.intensity")) {
        Intensity.entries.forEach { level ->
            val selected = session.intensity == level
            Box(
                Modifier.weight(1f).clip(RoundedCornerShape(8.dp))
                    .background(if (selected) Color.White.copy(alpha = 0.2f) else Color.Transparent)
                    .clickable(role = Role.Tab) { session.updateIntensity(level); Haptics.select() }
                    .semantics { this.selected = selected }
                    .padding(vertical = 7.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(level.title, style = Subheadline.copy(fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal))
            }
        }
    }
}

@Composable
private fun GameGrid(session: PartySession, mode: PartyMode, onOpenGame: (GameKind, PartyMode) -> Unit) {
    val reduceMotion = LocalReduceMotion.current
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        GameKind.games(mode).chunked(2).forEachIndexed { row, pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                pair.forEachIndexed { column, kind ->
                    val index = row * 2 + column
                    // Staggered entrance.
                    val appear = remember(mode) { Animatable(if (reduceMotion) 1f else 0f) }
                    LaunchedEffect(mode) {
                        kotlinx.coroutines.delay(index * 35L)
                        appear.animateTo(1f, spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessLow))
                    }
                    val enabled = session.players.size >= kind.minimumPlayers
                    GameTile(
                        kind, mode, enabled,
                        Modifier.weight(1f).graphicsLayer {
                            alpha = appear.value
                            translationY = (1f - appear.value) * 18.dp.toPx()
                        },
                    ) {
                        Haptics.tap(Haptics.Strength.MEDIUM)
                        onOpenGame(kind, mode)
                    }
                }
                if (pair.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun GameTile(kind: GameKind, mode: PartyMode, enabled: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val colors = kind.gradient(mode)
    val interaction = remember { MutableInteractionSource() }
    Column(
        modifier
            .pressScale(interaction)
            .heightIn(min = 150.dp)
            .neonCard(colors, radius = 22.dp)
            .clip(RoundedCornerShape(22.dp))
            .clickable(interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick)
            .graphicsLayer { alpha = if (enabled) 1f else 0.45f }
            .testTag("game.${mode.name.lowercase()}.${kind.tag}")
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Icon(
            kind.icon, null,
            modifier = Modifier.size(32.dp).drawGradient(colors),
            tint = Color.White,
        )
        Spacer(Modifier.weight(1f, fill = false).heightIn(min = 18.dp))
        Text(kind.title, style = Headline, maxLines = 2, overflow = TextOverflow.Ellipsis)
        Text(
            if (enabled) kind.tagline else "Mínimo ${kind.minimumPlayers} jugadores",
            style = Caption.copy(color = Neon.secondaryText),
            maxLines = 2,
        )
    }
}

/** Paints the icon with the game's gradient. */
private fun Modifier.drawGradient(colors: List<Color>): Modifier = this
    .graphicsLayer { compositingStrategy = androidx.compose.ui.graphics.CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        drawRect(Brush.linearGradient(colors), blendMode = androidx.compose.ui.graphics.BlendMode.SrcAtop)
    }

@Composable
private fun LockedHot() {
    Column(
        Modifier.fillMaxWidth().neonCard(listOf(Neon.crimson, Neon.magenta)).padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Icons.Rounded.Lock, null, tint = Neon.crimson, modifier = Modifier.size(36.dp))
        Text("El apartado Hot es solo para mayores de edad.", style = Headline, textAlign = TextAlign.Center)
    }
}

@Composable
private fun HotConsentCard(onAccept: () -> Unit) {
    Column(
        Modifier.fillMaxWidth().neonCard(listOf(Neon.crimson, Neon.magenta)).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Rounded.Whatshot, null, tint = Neon.rose)
            Text("Antes de entrar", style = Title3.copy(color = Neon.rose))
        }
        ConsentLine(Icons.Rounded.VerifiedUser, "Todos los que jugáis sois mayores de edad.")
        ConsentLine(Icons.Rounded.ThumbUp, "Todo el grupo quiere jugar al modo Hot.")
        ConsentLine(Icons.Rounded.PanTool, "Cualquiera puede pasar de un reto o pregunta: bebe y listo, sin dar explicaciones.")
        BigButton("Todos estamos de acuerdo", icon = Icons.Rounded.Whatshot, tint = Neon.crimson, tag = "hot.accept", onClick = onAccept)
    }
}

@Composable
private fun ConsentLine(icon: ImageVector, text: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Icon(icon, null, tint = Neon.rose, modifier = Modifier.size(20.dp))
        Text(text, style = Callout)
    }
}
