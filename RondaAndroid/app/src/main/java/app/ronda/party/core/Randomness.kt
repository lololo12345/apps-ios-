package app.ronda.party.core

import kotlin.random.Random

/**
 * Draws items in random order without repeating any until all have been used, then reshuffles.
 * Avoids the classic party-game annoyance of seeing the same card twice in a night.
 */
class ShuffledDeck<T>(val items: List<T>) {
    private val order = ArrayDeque<Int>()
    var drawnCount = 0
        private set

    val isEmpty: Boolean get() = items.isEmpty()
    val remainingInCycle: Int get() = order.size

    fun draw(random: Random = Random.Default): T? {
        if (items.isEmpty()) return null
        if (order.isEmpty()) order.addAll(items.indices.shuffled(random))
        drawnCount += 1
        return items[order.removeLast()]
    }
}
