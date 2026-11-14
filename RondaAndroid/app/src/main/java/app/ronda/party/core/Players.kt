package app.ronda.party.core

import kotlinx.serialization.Serializable
import java.text.Normalizer
import java.util.Locale
import java.util.UUID

@Serializable
data class Player(val id: String = UUID.randomUUID().toString(), val name: String)

object PlayerRules {
    const val MAX_NAME_LENGTH = 16
    const val MAX_PLAYERS = 16

    /** Trims, collapses inner whitespace and limits length. Returns null for empty or duplicate names. */
    fun sanitize(raw: String, existing: List<Player>): String? {
        val collapsed = raw.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
        if (collapsed.isEmpty()) return null
        val name = collapsed.take(MAX_NAME_LENGTH)
        val key = fold(name)
        return if (existing.any { fold(it.name) == key }) null else name
    }

    /** Case- and accent-insensitive key ("Ána" == "ana"). */
    fun fold(text: String): String =
        Normalizer.normalize(text, Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}+"), "")
            .lowercase(Locale.ROOT)
}

/** Seat order around the table: who is on your left and right, whose turn is next. Immutable. */
class TurnOrder(val count: Int, start: Int = 0) {
    val current: Int = if (count > 0) ((start % count) + count) % count else 0

    fun advanced(): TurnOrder = TurnOrder(count, current + 1)

    fun left(of: Int): Int = if (count > 0) (of + 1) % count else 0
    fun right(of: Int): Int = if (count > 0) (of - 1 + count) % count else 0
}
