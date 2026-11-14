package app.ronda.party.ui.screens

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.EditNote
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Vibration
import androidx.compose.material.icons.rounded.VerifiedUser
import androidx.compose.material.icons.rounded.WaterDrop
import androidx.compose.material3.Icon
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import app.ronda.party.model.GameKind
import app.ronda.party.model.PartyMode
import app.ronda.party.model.CustomCardRules
import app.ronda.party.session.AgeStatus
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.Body
import app.ronda.party.ui.components.Footnote
import app.ronda.party.ui.components.Headline
import app.ronda.party.ui.components.Subheadline
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.Neon

/** Content of the settings sheet (with the "Mis cartas" page pushed inside it). */
@Composable
fun SettingsContent(session: PartySession, onClose: () -> Unit, onAskAgeAgain: () -> Unit) {
    var page by remember { mutableStateOf(0) }
    AnimatedContent(
        page,
        transitionSpec = {
            if (targetState > initialState) slideInHorizontally { it } togetherWith slideOutHorizontally { -it / 3 }
            else slideInHorizontally { -it / 3 } togetherWith slideOutHorizontally { it }
        },
        label = "settingsPage",
    ) { shown ->
        if (shown == 0) SettingsMain(session, onClose, onAskAgeAgain) { page = 1 }
        else CustomCardsPage(session) { page = 0 }
    }
}

@Composable
private fun SettingsMain(session: PartySession, onClose: () -> Unit, onAskAgeAgain: () -> Unit, onCustomCards: () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        SheetBar("Ajustes", trailing = "Listo", onTrailing = onClose)
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(Neon.gutter), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            SectionHeader("Juego")
            Group {
                ToggleRow(
                    Icons.Rounded.Star, "Modo sin alcohol", session.soberMode,
                    enabled = session.ageStatus != AgeStatus.MINOR, tag = "settings.sober",
                ) { session.updateSoberPreference(it) }
                Divider()
                Column(Modifier.alpha(if (session.soberMode) 0.4f else 1f).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Icon(Icons.Rounded.WaterDrop, null, tint = Neon.cyan, modifier = Modifier.size(22.dp))
                        Text("Rondas de agua", style = Body)
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        listOf(0 to "Nunca", 5 to "Cada 5", 10 to "Cada 10", 15 to "Cada 15").forEach { (value, label) ->
                            val selected = session.waterEvery == value
                            Box(
                                Modifier.weight(1f).clip(RoundedCornerShape(10.dp))
                                    .background(if (selected) Neon.violet else Neon.surfaceRaised)
                                    .clickable(enabled = !session.soberMode, role = Role.RadioButton) { session.updateWaterEvery(value); Haptics.select() }
                                    .padding(vertical = 8.dp),
                                contentAlignment = Alignment.Center,
                            ) { Text(label, style = Footnote.copy(fontWeight = FontWeight.SemiBold)) }
                        }
                    }
                }
            }
            Footer(
                if (session.ageStatus == AgeStatus.MINOR) "Como eres menor, Ronda funciona siempre en modo sin alcohol: los sorbos son puntos."
                else "En modo sin alcohol los sorbos se convierten en puntos y prendas. Las rondas de agua aparecen cada pocas cartas para que la noche dure."
            )

            SectionHeader("Contenido")
            Group {
                NavRow(Icons.Rounded.EditNote, "Mis cartas", "settings.customCards", onCustomCards)
                Divider()
                ToggleRow(Icons.Rounded.Vibration, "Vibraciones", session.hapticsEnabled) { session.updateHaptics(it) }
            }

            SectionHeader("Responsabilidad")
            Group {
                NavRow(Icons.Rounded.VerifiedUser, "Cambiar la confirmación de edad", "settings.age", onAskAgeAgain)
                Divider()
                Row(Modifier.padding(14.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(Icons.Rounded.Favorite, null, tint = Neon.rose, modifier = Modifier.size(18.dp))
                    Text(
                        "Bebe con responsabilidad. Si vas a conducir, no bebas. Nadie está obligado a beber ni a hacer ningún reto.",
                        style = Footnote.copy(color = Neon.secondaryText),
                    )
                }
            }
        }
    }
}

@Composable
private fun CustomCardsPage(session: PartySession, onBack: () -> Unit) {
    var mode by remember { mutableStateOf(PartyMode.NORMAL) }
    var game by remember { mutableStateOf(GameKind.NEVER_HAVE) }
    var draft by remember { mutableStateOf("") }
    val editable = if (mode == PartyMode.HOT) listOf(GameKind.NEVER_HAVE, GameKind.MOST_LIKELY, GameKind.TRUTH_OR_DRINK, GameKind.DARES)
        else listOf(GameKind.NEVER_HAVE, GameKind.MOST_LIKELY, GameKind.TRUTH_OR_DRINK)
    if (game !in editable) game = GameKind.NEVER_HAVE
    val cards = session.customCards(game, mode)
    val canAdd = CustomCardRules.normalize(draft, game) != null

    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Row(Modifier.clickable(onClick = onBack).padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, null, tint = Neon.violet, modifier = Modifier.size(20.dp))
                Text(" Ajustes", style = Headline.copy(color = Neon.violet))
            }
            Text("Mis cartas", style = Headline, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
            Spacer(Modifier.width(100.dp))
        }
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(Neon.gutter), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (session.canUseHot) Segmented(PartyMode.entries.map { it.title }, PartyMode.entries.indexOf(mode)) { mode = PartyMode.entries[it] }
            Segmented(editable.map { if (it == GameKind.MOST_LIKELY) "Más probable" else it.title }, editable.indexOf(game)) { game = editable[it] }
            Group {
                Row(Modifier.padding(start = 14.dp, end = 8.dp, top = 6.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.weight(1f).padding(vertical = 8.dp)) {
                        if (draft.isEmpty()) Text(placeholder(game), style = Body.copy(color = Neon.tertiaryText))
                        BasicTextField(draft, { draft = it }, textStyle = Body, cursorBrush = SolidColor(Neon.violet), maxLines = 4,
                            modifier = Modifier.fillMaxWidth().testTag("custom.field"))
                    }
                    Text(
                        "Añadir",
                        style = Headline.copy(color = if (canAdd) Neon.violet else Neon.tertiaryText),
                        modifier = Modifier.clickable(enabled = canAdd) {
                            if (session.addCustomCard(draft, game, mode)) { draft = ""; Haptics.success() }
                        }.padding(8.dp).testTag("custom.add"),
                    )
                }
            }
            Footer(
                if (game == GameKind.DARES) "Usa {1} y {2} para que la app ponga nombres de jugadores. Ejemplo: «{1}, cántale una canción a {2}»."
                else "Tus cartas se mezclan con las de la app. Ideal para bromas internas del grupo."
            )
            SectionHeader("${cards.size} cartas tuyas")
            if (cards.isNotEmpty()) Group {
                cards.forEachIndexed { index, card ->
                    if (index > 0) Divider()
                    Row(Modifier.padding(start = 14.dp, end = 4.dp, top = 4.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(card.text, style = Body, modifier = Modifier.weight(1f).padding(vertical = 8.dp))
                        Box(Modifier.clickable { session.deleteCustomCard(card); Haptics.tap() }.padding(10.dp)) {
                            Icon(Icons.Rounded.Delete, "Borrar carta", tint = Neon.crimson, modifier = Modifier.size(20.dp))
                        }
                    }
                }
            }
        }
    }
}

private fun placeholder(game: GameKind) = when (game) {
    GameKind.NEVER_HAVE -> "Yo nunca he…"
    GameKind.MOST_LIKELY -> "¿Quién es más probable que…?"
    GameKind.TRUTH_OR_DRINK -> "Escribe una pregunta"
    else -> "Escribe un reto"
}

@Composable
fun SheetBar(title: String, trailing: String, onTrailing: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Spacer(Modifier.width(80.dp))
        Text(title, style = Headline, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
        Text(trailing, style = Headline.copy(color = Neon.violet), modifier = Modifier.width(80.dp).clickable(onClick = onTrailing).padding(12.dp).testTag("sheet.done"), textAlign = TextAlign.End)
    }
}

@Composable
private fun SectionHeader(text: String) =
    Text(text.uppercase(), style = Footnote.copy(color = Neon.secondaryText), modifier = Modifier.padding(start = 14.dp, top = 12.dp))

@Composable
private fun Footer(text: String) = Text(text, style = Footnote.copy(color = Neon.secondaryText), modifier = Modifier.padding(horizontal = 14.dp))

@Composable
private fun Group(content: @Composable ColumnScope.() -> Unit) =
    Column(Modifier.fillMaxWidth().background(Neon.surfaceRaised, RoundedCornerShape(16.dp)), content = content)

@Composable
private fun Divider() = Box(Modifier.fillMaxWidth().padding(start = 48.dp).height(1.dp).background(Neon.hairline))

@Composable
private fun ToggleRow(icon: ImageVector, title: String, checked: Boolean, enabled: Boolean = true, tag: String? = null, onChange: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().alpha(if (enabled) 1f else 0.4f).padding(horizontal = 14.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, null, tint = Neon.amber, modifier = Modifier.size(22.dp))
        Text(title, style = Body, modifier = Modifier.weight(1f))
        Switch(
            checked, onCheckedChange = { onChange(it); Haptics.select() }, enabled = enabled,
            colors = SwitchDefaults.colors(checkedTrackColor = Neon.lime, checkedThumbColor = Color.White),
            modifier = if (tag != null) Modifier.testTag(tag) else Modifier,
        )
    }
}

@Composable
private fun NavRow(icon: ImageVector, title: String, tag: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).testTag(tag).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(icon, null, tint = Neon.violet, modifier = Modifier.size(22.dp))
        Text(title, style = Body, modifier = Modifier.weight(1f))
        Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, null, tint = Neon.tertiaryText)
    }
}

@Composable
private fun Segmented(options: List<String>, selected: Int, onSelect: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().background(Color.White.copy(alpha = 0.08f), RoundedCornerShape(10.dp)).padding(3.dp)) {
        options.forEachIndexed { index, label ->
            Box(
                Modifier.weight(1f).clip(RoundedCornerShape(8.dp))
                    .background(if (index == selected) Color.White.copy(alpha = 0.2f) else Color.Transparent)
                    .clickable(role = Role.Tab) { onSelect(index) }
                    .padding(vertical = 7.dp, horizontal = 4.dp),
                contentAlignment = Alignment.Center,
            ) { Text(label, style = Footnote.copy(fontWeight = if (index == selected) FontWeight.SemiBold else FontWeight.Normal), maxLines = 1) }
        }
    }
}
