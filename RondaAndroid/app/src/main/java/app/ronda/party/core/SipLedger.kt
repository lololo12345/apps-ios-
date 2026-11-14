package app.ronda.party.core

import kotlinx.serialization.Serializable

/** Running tally of sips (or points in alcohol-free mode) per player for the whole night. Immutable. */
@Serializable
data class SipLedger(val sips: Map<String, Int> = emptyMap(), val total: Int = 0) {

    fun add(amount: Int, to: String): SipLedger {
        if (amount <= 0) return this
        return copy(sips = sips + (to to count(to) + amount), total = total + amount)
    }

    fun add(amount: Int, to: Iterable<String>): SipLedger =
        to.toSet().fold(this) { ledger, id -> ledger.add(amount, id) }

    fun count(playerId: String): Int = sips[playerId] ?: 0

    /** Corrects a mistaken entry; never goes below zero. */
    fun remove(amount: Int, from: String): SipLedger {
        val current = count(from)
        val removed = minOf(maxOf(0, amount), current)
        if (removed == 0) return this
        return copy(sips = sips + (from to current - removed), total = total - removed)
    }

    /** Total for the players still at the table (removed players no longer count). */
    fun total(players: List<Player>): Int = players.sumOf { count(it.id) }

    data class Standing(val player: Player, val sips: Int, /** Competition ranking: ties share a position (1, 2, 2, 4). */ val position: Int)

    fun standings(players: List<Player>): List<Standing> {
        val sorted = players.withIndex().sortedWith(
            compareByDescending<IndexedValue<Player>> { count(it.value.id) }.thenBy { it.index }
        )
        val result = mutableListOf<Standing>()
        sorted.forEachIndexed { index, entry ->
            val value = count(entry.value.id)
            val position = if (index > 0 && result[index - 1].sips == value) result[index - 1].position else index + 1
            result += Standing(entry.value, value, position)
        }
        return result
    }
}

/** Every N cards the game inserts a water break. 0 disables it. */
class WaterBreakSchedule(val every: Int) {
    var cardsSinceBreak = 0
        private set

    /** Call once per card shown. Returns true when a water break should be shown now. */
    fun registerCard(): Boolean {
        if (every <= 0) return false
        cardsSinceBreak += 1
        if (cardsSinceBreak >= every) {
            cardsSinceBreak = 0
            return true
        }
        return false
    }
}
