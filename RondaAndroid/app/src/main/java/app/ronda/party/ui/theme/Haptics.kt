package app.ronda.party.ui.theme

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Short, crisp vibrations. Uses the device's predefined effects (tuned per phone) when available.
 */
object Haptics {
    private var vibrator: Vibrator? = null
    var enabled: () -> Boolean = { true }

    fun install(context: Context) {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }?.takeIf { it.hasVibrator() }
    }

    enum class Strength { LIGHT, MEDIUM, HEAVY }

    fun tap(strength: Strength = Strength.LIGHT) = when (strength) {
        Strength.LIGHT -> play(predefined(VibrationEffect.EFFECT_TICK) ?: oneShot(12, 90))
        Strength.MEDIUM -> play(predefined(VibrationEffect.EFFECT_CLICK) ?: oneShot(18, 160))
        Strength.HEAVY -> play(predefined(VibrationEffect.EFFECT_HEAVY_CLICK) ?: oneShot(28, 255))
    }

    /** Short crisp tick (roulette segments, bomb fuse). */
    fun tick() = play(predefined(VibrationEffect.EFFECT_TICK) ?: oneShot(8, 120))

    fun select() = play(predefined(VibrationEffect.EFFECT_TICK) ?: oneShot(10, 100))

    fun success() = play(predefined(VibrationEffect.EFFECT_DOUBLE_CLICK) ?: oneShot(20, 180))

    fun warning() = play(waveform(longArrayOf(0, 30, 60, 30), intArrayOf(0, 200, 0, 200)))

    fun boom() = play(waveform(longArrayOf(0, 60, 40, 180), intArrayOf(0, 255, 0, 255)))

    private fun play(effect: VibrationEffect) {
        if (!enabled()) return
        runCatching { vibrator?.vibrate(effect) }
    }

    private fun predefined(id: Int): VibrationEffect? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) VibrationEffect.createPredefined(id) else null

    private fun oneShot(ms: Long, amplitude: Int) = VibrationEffect.createOneShot(ms, amplitude)

    private fun waveform(timings: LongArray, amplitudes: IntArray) = VibrationEffect.createWaveform(timings, amplitudes, -1)
}
