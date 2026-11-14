package app.ronda.party.core

import kotlin.random.Random

/**
 * "La Bomba": the phone ticks while being passed around and explodes at a random moment.
 * The tick interval shrinks as the fuse burns, so tension builds.
 */
class BombFuse(val duration: Double) {
    /** Seconds until the next tick: from ~1 s at the start down to 0.15 s at the end. */
    fun tickInterval(elapsed: Double): Double {
        val progress = (elapsed / duration).coerceIn(0.0, 1.0)
        return maxOf(0.15, 1.0 - 0.85 * progress * progress)
    }

    fun hasExploded(elapsed: Double): Boolean = elapsed >= duration

    companion object {
        val DURATION_RANGE = 15.0..40.0
        fun random(random: Random = Random.Default) =
            BombFuse(random.nextDouble(DURATION_RANGE.start, DURATION_RANGE.endInclusive))
    }
}

/** Head-to-head mini games played on one screen, one player per half. */
object Duel {
    enum class Kind(val title: String, val instructions: String) {
        REFLEX("Reflejos", "Espera a que tu mitad se ponga verde y toca. Si tocas antes, pierdes."),
        TAPS("Toques", "Toca tu mitad todas las veces que puedas en 5 segundos."),
        COLORS("Colores", "Toca solo cuando el color de la palabra coincida con lo que dice. Si fallas, pierdes."),
    }

    enum class Side {
        TOP, BOTTOM;
        val other: Side get() = if (this == TOP) BOTTOM else TOP
    }

    sealed interface Result {
        data class Winner(val side: Side) : Result
        data object Tie : Result
    }

    /** Reflex duel: a tap before "go" loses immediately; otherwise the first tap after "go" wins. */
    fun resolveReflex(tap: Side, beforeGo: Boolean): Result = if (beforeGo) Result.Winner(tap.other) else Result.Winner(tap)

    const val TAP_DURATION = 5.0

    fun resolveTaps(top: Int, bottom: Int): Result =
        if (top == bottom) Result.Tie else Result.Winner(if (top > bottom) Side.TOP else Side.BOTTOM)

    /** Colour-word duel (Stroop effect). A round matches when the ink colour equals the written word. */
    data class ColorRound(val word: Int, val ink: Int) {
        val matches: Boolean get() = word == ink

        companion object {
            val PALETTE = listOf("ROJO", "AZUL", "VERDE", "AMARILLO")
        }
    }

    /** Sequence of rounds that guarantees a match appears early. */
    fun colorRounds(count: Int = 12, random: Random = Random.Default): List<ColorRound> {
        val palette = ColorRound.PALETTE.size
        val guaranteedMatch = random.nextInt(2, maxOf(3, minOf(count, 7)))
        return List(count) { index ->
            val word = random.nextInt(palette)
            if (index == guaranteedMatch) {
                ColorRound(word, word)
            } else {
                var ink = random.nextInt(palette)
                // Keep matches rare (~1 in 4) so the duel tests attention, not luck.
                if (ink == word && random.nextInt(3) != 0) ink = (ink + 1 + random.nextInt(palette - 1)) % palette
                ColorRound(word, ink)
            }
        }
    }

    fun resolveColorTap(side: Side, round: ColorRound): Result =
        if (round.matches) Result.Winner(side) else Result.Winner(side.other)
}

/** "La Ruleta": weighted wheel of outcomes. */
class Roulette(val segments: List<Segment>) {
    data class Segment(
        val title: String,
        val detail: String,
        /** Sips for the spinner, applied automatically. */
        val spinnerSips: Int,
        /** Sips for everyone, applied automatically. */
        val everyoneSips: Int,
        val weight: Int,
    )

    val totalWeight: Int get() = segments.sumOf { it.weight }

    fun pick(random: Random = Random.Default): Int {
        var roll = random.nextInt(maxOf(1, totalWeight))
        segments.forEachIndexed { index, segment ->
            if (roll < segment.weight) return index
            roll -= segment.weight
        }
        return segments.size - 1
    }

    /**
     * Final wheel rotation (degrees, clockwise) so that [index] stops under the pointer at the top,
     * after a few full turns from [currentRotation].
     */
    fun rotation(landingOn: Int, currentRotation: Double, extraTurns: Int = 5, jitter: Double = 0.0): Double {
        val slice = 360.0 / segments.size
        // Segment i is drawn starting at angle i*slice (clockwise from the top), centred at (i + 0.5)*slice.
        val target = 360 - (landingOn + 0.5) * slice + jitter * slice * 0.35
        val base = currentRotation - currentRotation.rem(360.0)
        return base + extraTurns * 360.0 + target
    }

    /** Which segment is under the top pointer for a given rotation. */
    fun segmentAt(rotation: Double): Int {
        val slice = 360.0 / segments.size
        var angle = (360 - rotation.rem(360.0)).rem(360.0)
        if (angle < 0) angle += 360
        return minOf(segments.size - 1, (angle / slice).toInt())
    }
}
