package app.ronda.party

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Display
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import app.ronda.party.session.PartySession
import app.ronda.party.session.SharedPreferencesStore
import app.ronda.party.ui.RondaApp
import app.ronda.party.ui.theme.Haptics

class MainActivity : ComponentActivity() {
    private val session by lazy {
        PartySession(SharedPreferencesStore(getSharedPreferences("ronda", MODE_PRIVATE)))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
        )
        requestHighestRefreshRate()
        Haptics.install(this)
        Haptics.enabled = { session.hapticsEnabled }
        val reduceMotion = runCatching {
            Settings.Global.getFloat(contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f
        }.getOrDefault(false)
        setContent { RondaApp(session, reduceMotion) }
    }

    /**
     * Asks for the fastest refresh rate the screen offers at its current resolution (90/120 Hz on
     * phones that have it), so animations run as smoothly as the hardware allows.
     */
    private fun requestHighestRefreshRate() {
        val display: Display = (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) display else null)
            ?: @Suppress("DEPRECATION") windowManager.defaultDisplay
            ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: return
        window.attributes = window.attributes.also {
            it.preferredDisplayModeId = best.modeId
            it.preferredRefreshRate = best.refreshRate
        }
    }
}
