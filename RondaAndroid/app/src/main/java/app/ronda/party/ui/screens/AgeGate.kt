package app.ronda.party.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.ronda.party.session.AgeStatus
import app.ronda.party.session.PartySession
import app.ronda.party.ui.components.BigButton
import app.ronda.party.ui.components.Callout
import app.ronda.party.ui.components.Footnote
import app.ronda.party.ui.components.GradientText
import app.ronda.party.ui.components.Title2
import app.ronda.party.ui.components.Title3
import app.ronda.party.ui.components.rounded
import app.ronda.party.ui.theme.Haptics
import app.ronda.party.ui.theme.Neon
import app.ronda.party.ui.theme.NightBackground
import app.ronda.party.ui.theme.neonCard

@Composable
fun AgeGateScreen(session: PartySession) {
    Box(Modifier.fillMaxSize()) {
        NightBackground(listOf(Neon.magenta, Neon.cyan))
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = 24.dp).padding(bottom = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                GradientText(
                    "Ronda", listOf(Neon.magenta, Neon.violet, Neon.cyan),
                    rounded(64.sp, FontWeight.Black).copy(shadow = Shadow(Neon.magenta.copy(alpha = 0.6f), blurRadius = 48f)),
                )
                Text("Juegos para la previa", style = Title3.copy(color = Neon.secondaryText, fontWeight = FontWeight.SemiBold))
            }
            Column(
                Modifier.fillMaxWidth().neonCard(listOf(Neon.magenta, Neon.cyan)).padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text("¿Tienes 18 años o más?", style = Title2)
                Text(
                    "Ronda incluye juegos con alcohol. Si eres menor, puedes jugar en modo sin alcohol: los sorbos se convierten en puntos.",
                    style = Callout.copy(color = Neon.secondaryText),
                    textAlign = TextAlign.Center,
                )
            }
            Spacer(Modifier.weight(1f))
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                BigButton("Sí, tengo 18 o más", icon = Icons.Rounded.Check, tint = Neon.magenta, tag = "age.adult") {
                    Haptics.success()
                    session.updateAgeStatus(AgeStatus.ADULT)
                }
                BigButton("No, soy menor", tint = Neon.cyan, prominent = false, tag = "age.minor") {
                    session.updateAgeStatus(AgeStatus.MINOR)
                }
            }
            Text("Bebe con responsabilidad. Si vas a conducir, no bebas.", style = Footnote.copy(color = Neon.tertiaryText), textAlign = TextAlign.Center)
        }
    }
}
