package app.ronda.party.ui.screens

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Celebration
import androidx.compose.material.icons.rounded.Delete
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.BigButton
import app.ronda.party.ui.components.Body
import app.ronda.party.ui.components.Callout
import app.ronda.party.ui.components.Footnote
import app.ronda.party.ui.components.GlassIconButton
import app.ronda.party.ui.components.Headline
import app.ronda.party.ui.components.Subheadline
import app.ronda.party.ui.components.rounded
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.Neon
import app.ronda.party.ui.theme.NightBackground
import app.ronda.party.ui.theme.glass

/** Player list in seat order. [isFirstRun] shows the big title and the "¡A jugar!" button. */
@Composable
fun PlayersScreen(session: PartySession, isFirstRun: Boolean, onDone: (() -> Unit)? = null) {
    var draft by remember { mutableStateOf("") }
    var rejected by remember { mutableStateOf(false) }
    val focus = remember { FocusRequester() }

    fun add() {
        if (session.addPlayer(draft)) {
            draft = ""
            rejected = false
            Haptics.tap()
        } else if (draft.isNotBlank()) {
            rejected = true
            Haptics.warning()
        }
    }

    Box(Modifier.fillMaxSize()) {
        if (isFirstRun) NightBackground(listOf(Neon.violet, Neon.cyan))
        Column(Modifier.fillMaxSize().then(if (isFirstRun) Modifier.statusBarsPadding() else Modifier).imePadding()) {
            if (!isFirstRun) {
                Row(Modifier.fillMaxWidth().padding(horizontal = Neon.gutter, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("Jugadores", style = Headline, modifier = Modifier.weight(1f))
                    Text(
                        "Listo",
                        style = Headline.copy(color = Neon.violet),
                        modifier = Modifier.clickable { onDone?.invoke() }.padding(8.dp).testTag("players.done"),
                    )
                }
            }
            LazyColumn(
                Modifier.weight(1f).fillMaxWidth(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(Neon.gutter),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                item {
                    Column(Modifier.padding(bottom = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (isFirstRun) Text("¿Quién juega?", style = rounded(34.sp, FontWeight.Black))
                        Text(
                            "Escribid los nombres en el orden en el que estáis sentados: así la app sabe quién está a la izquierda y a la derecha de cada uno.",
                            style = Callout.copy(color = Neon.secondaryText),
                        )
                    }
                }
                item {
                    val shape = RoundedCornerShape(50)
                    Row(
                        Modifier.fillMaxWidth().glass(shape).padding(start = 18.dp, end = 6.dp, top = 6.dp, bottom = 6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Box(Modifier.weight(1f)) {
                            if (draft.isEmpty()) Text("Nombre", style = Body.copy(color = Neon.tertiaryText))
                            BasicTextField(
                                draft,
                                onValueChange = { draft = it; rejected = false },
                                singleLine = true,
                                textStyle = Body,
                                cursorBrush = SolidColor(Neon.violet),
                                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, autoCorrectEnabled = false, imeAction = ImeAction.Next),
                                keyboardActions = KeyboardActions(onNext = { add() }),
                                modifier = Modifier.fillMaxWidth().focusRequester(focus).testTag("players.field"),
                            )
                        }
                        GlassIconButton(Icons.Rounded.Add, "Añadir jugador", tag = "players.add", tint = Neon.violet, size = 40.dp) { add() }
                    }
                    if (rejected) {
                        Text("Ese nombre ya está o no es válido.", style = Footnote.copy(color = Neon.orange, fontWeight = FontWeight.SemiBold), modifier = Modifier.padding(top = 8.dp, start = 8.dp))
                    }
                }
                if (session.players.isNotEmpty()) {
                    item {
                        Text(
                            "${session.players.size} jugadores · usa las flechas para cambiar el orden",
                            style = Footnote.copy(color = Neon.secondaryText),
                            modifier = Modifier.padding(top = 12.dp, start = 4.dp),
                        )
                    }
                }
                itemsIndexed(session.players, key = { _, player -> player.id }) { index, player ->
                    Row(
                        Modifier.animateItem().fillMaxWidth().background(Neon.surfaceRaised.copy(alpha = 0.9f), RoundedCornerShape(16.dp))
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                    ) {
                        Box(Modifier.size(28.dp).background(Neon.lime, CircleShape), contentAlignment = Alignment.Center) {
                            Text("${index + 1}", style = Subheadline.copy(color = Color.Black, fontWeight = FontWeight.Black))
                        }
                        Text(player.name, style = Headline, modifier = Modifier.weight(1f))
                        // Fixed slots so the arrows line up on every row.
                        if (index > 0) GlassIconButton(Icons.Rounded.KeyboardArrowUp, "Subir a ${player.name}", size = 34.dp) { session.movePlayer(index, index - 1); Haptics.select() }
                        else Spacer(Modifier.size(34.dp))
                        if (index < session.players.lastIndex) GlassIconButton(Icons.Rounded.KeyboardArrowDown, "Bajar a ${player.name}", size = 34.dp) { session.movePlayer(index, index + 1); Haptics.select() }
                        else Spacer(Modifier.size(34.dp))
                        GlassIconButton(Icons.Rounded.Delete, "Quitar a ${player.name}", tag = "players.remove.${player.name}", tint = Neon.crimson, size = 34.dp) {
                            session.removePlayer(player); Haptics.tap()
                        }
                    }
                }
            }
            if (isFirstRun) {
                BigButton(
                    if (session.players.size < 2) "Añade al menos 2 jugadores" else "¡A jugar!",
                    modifier = Modifier.padding(horizontal = Neon.gutter).padding(bottom = 8.dp).navigationBarsPadding(),
                    icon = Icons.Rounded.Celebration,
                    tint = Neon.magenta,
                    enabled = session.players.size >= 2,
                    tag = "players.start",
                ) {
                    Haptics.success()
                    session.updateSetupDone(true)
                }
            }
        }
    }
    LaunchedEffect(Unit) { if (isFirstRun && session.players.isEmpty()) runCatching { focus.requestFocus() } }
}
