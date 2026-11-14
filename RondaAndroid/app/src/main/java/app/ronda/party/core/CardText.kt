package app.ronda.party.core

import kotlin.random.Random

/** Fills `{1}` and `{2}` in card texts with distinct random players. */
object CardText {
    fun requiredPlayers(template: String): Int =
        if (template.contains("{2}")) 2 else if (template.contains("{1}")) 1 else 0

    data class Filled(val text: String, val involved: List<Player>)

    /** [first] is preferred for `{1}` (usually the player whose turn it is). */
    fun fill(template: String, players: List<Player>, first: Player? = null, random: Random = Random.Default): Filled {
        val needed = requiredPlayers(template)
        if (needed == 0 || players.isEmpty()) return Filled(template, emptyList())
        val pool = players.shuffled(random).toMutableList()
        val chosen = mutableListOf<Player>()
        if (first != null) {
            val index = pool.indexOf(first)
            if (index >= 0) chosen += pool.removeAt(index)
        }
        while (chosen.size < needed && pool.isNotEmpty()) chosen += pool.removeAt(0)
        var text = template
        chosen.forEachIndexed { offset, player -> text = text.replace("{${offset + 1}}", player.name) }
        return Filled(text, chosen)
    }
}

/** Words that change in alcohol-free mode, so every screen stays consistent. */
data class Lexicon(val soberMode: Boolean) {
    fun sips(count: Int): String =
        if (soberMode) (if (count == 1) "1 punto" else "$count puntos")
        else (if (count == 1) "1 sorbo" else "$count sorbos")

    /** "bebe 2 sorbos" / "suma 2 puntos" */
    fun drink(count: Int): String = if (soberMode) "suma ${sips(count)}" else "bebe ${sips(count)}"

    /** Rewrites built-in card text for alcohol-free mode ("bebe 2" → "suma 2 puntos"). */
    fun adapt(text: String): String {
        if (!soberMode) return text
        var result = text
        for ((from, to) in SOBER_REPLACEMENTS) result = result.replace(from, to)
        return result
    }

    val unitTitle: String get() = if (soberMode) "Puntos" else "Sorbos"
    val drinkVerb: String get() = if (soberMode) "Suma" else "Bebe"

    private companion object {
        val SOBER_REPLACEMENTS = listOf(
            "sorbos" to "puntos", "sorbo" to "punto", "Bebe toda la mesa" to "Suma 1 punto toda la mesa",
            "beberá contigo" to "sumará contigo", "bebe también" to "suma también", "cada vez que bebas" to "cada vez que sumes",
            "o bebe " to "o suma ", "Bebe " to "Suma ", "bebe " to "suma ", "bebe." to "suma un punto.",
            "Te tocan 2. Salud." to "Te tocan 2 puntos.", "te toca 5 de golpe" to "te tocan 5 puntos de golpe",
            "Bebes " to "Sumas ", "Reparte " to "Reparte puntos: ", "un buen trago de agua" to "un vaso de agua",
        )
    }
}

fun String.capitalizedFirst(): String = replaceFirstChar { it.uppercase() }
