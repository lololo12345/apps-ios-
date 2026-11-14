package app.ronda.party.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.EmojiEvents
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ronda.party.core.SipLedger
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.Footnote
import app.ronda.party.ui.components.GlassIconButton
import app.ronda.party.ui.components.Headline
import app.ronda.party.ui.components.NumberTransition
import app.ronda.party.ui.components.Subheadline
import app.ronda.party.ui.components.Title3
import app.ronda.party.ui.components.rounded
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.LocalReduceMotion
import app.ronda.party.ui.theme.Neon

/** Content of the scoreboard sheet. */
@Composable
fun ScoreboardContent(session: PartySession, onClose: () -> Unit, onReset: () -> Unit) {
    val standings = session.ledger.standings(session.players)
    val total = session.ledger.total(session.players)
    val reduceMotion = LocalReduceMotion.current
    val grow = remember { Animatable(if (reduceMotion) 1f else 0f) }
    LaunchedEffect(Unit) {
        kotlinx.coroutines.delay(150)
        grow.animateTo(1f, spring(dampingRatio = 0.7f, stiffness = 120f))
    }
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("Cerrar", style = Headline.copy(color = Neon.violet), modifier = Modifier.clickable(onClick = onClose).padding(12.dp))
            Text("Marcador", style = Headline, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
            Text(
                "Reiniciar",
                style = Headline.copy(color = if (total == 0) Neon.tertiaryText else Neon.crimson),
                modifier = Modifier.clickable(enabled = total > 0, onClick = onReset).padding(12.dp),
            )
        }
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(Neon.gutter),
            verticalArrangement = Arrangement.spacedBy(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (total == 0) {
                Column(Modifier.padding(top = 40.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Icon(Icons.Rounded.EmojiEvents, null, tint = Neon.secondaryText, modifier = Modifier.size(48.dp))
                    Text("Aún no hay marcador", style = Title3)
                    Text(
                        "Jugad un poco: cada vez que alguien ${if (session.lexicon.soberMode) "sume puntos" else "beba"}, aparecerá aquí.",
                        style = Subheadline.copy(color = Neon.secondaryText, fontWeight = FontWeight.Normal),
                        textAlign = TextAlign.Center,
                    )
                }
            } else {
                Podium(standings.take(3), grow.value)
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    val max = standings.firstOrNull()?.sips ?: 1
                    standings.forEach { standing -> ScoreRow(session, standing, max, grow.value) }
                }
                Text(summary(session, standings), style = Footnote.copy(color = Neon.secondaryText), textAlign = TextAlign.Center)
            }
        }
    }
}

@Composable
private fun Podium(top: List<SipLedger.Standing>, grown: Float) {
    // Classic podium order: 2nd, 1st, 3rd.
    val order = listOf(1, 0, 2).filter { it in top.indices }
    Row(Modifier.fillMaxWidth().padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Bottom) {
        order.forEach { index ->
            val standing = top[index]
            // Ties share a step: medal and height follow the ranking position, not the slot.
            val rank = (standing.position - 1).coerceIn(0, 2)
            val height = 28f + (listOf(150f, 110f, 80f)[rank] - 28f) * grown
            Column(
                Modifier.weight(1f).semantics(mergeDescendants = true) { },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(listOf("🥇", "🥈", "🥉")[rank], style = rounded(34.sp))
                Text(standing.player.name, style = Headline, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Box(
                    Modifier.fillMaxWidth().height(height.dp)
                        .background(
                            Brush.verticalGradient(listOf(Neon.amber, Neon.magenta).map { it.copy(alpha = 1f - rank * 0.25f) }),
                            RoundedCornerShape(14.dp),
                        ),
                    contentAlignment = Alignment.TopCenter,
                ) {
                    Text("${standing.sips}", style = rounded(28.sp, FontWeight.Black).copy(color = Neon.ink), modifier = Modifier.padding(top = 10.dp).alpha(grown.coerceIn(0f, 1f)))
                }
            }
        }
    }
}

@Composable
private fun ScoreRow(session: PartySession, standing: SipLedger.Standing, max: Int, grown: Float) {
    Row(
        Modifier.fillMaxWidth().background(Neon.surfaceRaised.copy(alpha = 0.9f), RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("${standing.position}", style = Subheadline.copy(color = Neon.secondaryText, fontWeight = FontWeight.Black), modifier = Modifier.width(22.dp))
        Text(standing.player.name, style = Headline, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
        val fraction by animateFloatAsState(if (max > 0) standing.sips.toFloat() / max else 0f, label = "bar")
        BoxWithConstraints(Modifier.width(90.dp).height(8.dp), contentAlignment = Alignment.CenterEnd) {
            Box(Modifier.width(maxWidth * fraction * grown).height(8.dp).background(Neon.amber, RoundedCornerShape(50)))
        }
        AnimatedContent(standing.sips, transitionSpec = { NumberTransition.spec(initialState, targetState) }, label = "sips") {
            Text("$it", style = Headline, modifier = Modifier.widthIn(min = 30.dp), textAlign = TextAlign.End)
        }
        Box(Modifier.alpha(if (standing.sips == 0) 0.35f else 1f)) {
            GlassIconButton(Icons.Rounded.Remove, "Quitar 1 a ${standing.player.name}", tag = "undo.${standing.player.name}", size = 34.dp) {
                if (standing.sips > 0) {
                    session.undoSip(standing.player)
                    Haptics.select()
                }
            }
        }
    }
}

private fun summary(session: PartySession, standings: List<SipLedger.Standing>): String {
    val unit = session.lexicon.unitTitle.lowercase()
    val free = standings.filter { it.sips == 0 }.map { it.player.name }
    var text = "Total de la noche: ${session.ledger.total(session.players)} $unit."
    if (free.isNotEmpty()) text += " Se han librado: ${free.joinToString(", ")}."
    if (!session.soberMode) text += "\nBebed agua y volved a casa con alguien de confianza. 💧"
    return text
}
