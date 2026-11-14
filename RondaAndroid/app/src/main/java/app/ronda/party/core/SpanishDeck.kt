package app.ronda.party.core

import kotlin.random.Random

/** The 40-card Spanish deck: 1–7, Sota (10), Caballo (11) and Rey (12) in four suits. */
data class SpanishCard(val rank: Int, val suit: Suit) {
    enum class Suit(val displayName: String) { OROS("Oros"), COPAS("Copas"), ESPADAS("Espadas"), BASTOS("Bastos") }

    val id: String get() = "$rank-${suit.name}"

    val rankName: String
        get() = when (rank) {
            1 -> "As"; 10 -> "Sota"; 11 -> "Caballo"; 12 -> "Rey"; else -> "$rank"
        }

    val shortRank: String
        get() = when (rank) {
            1 -> "A"; 10 -> "S"; 11 -> "C"; 12 -> "R"; else -> "$rank"
        }

    val fullName: String get() = "$rankName de ${suit.displayName}"

    companion object {
        val RANKS = listOf(1, 2, 3, 4, 5, 6, 7, 10, 11, 12)
        val fullDeck: List<SpanishCard> get() = Suit.entries.flatMap { suit -> RANKS.map { SpanishCard(it, suit) } }
    }
}

/**
 * "Mayor o menor": guess whether the next card is higher or lower. Each hit adds a sip to the pot;
 * a miss (or a tie) means drinking the whole pot. After 3 hits in a row you may stand and pass the
 * pot to the next player. Immutable: every move returns the next state.
 */
data class HigherLowerGame(
    val deck: List<SpanishCard>,
    val current: SpanishCard,
    val pot: Int = 0,
    val streak: Int = 0,
) {
    enum class Guess { HIGHER, LOWER }

    sealed interface Outcome {
        data class Hit(val pot: Int) : Outcome
        data class Miss(val drinks: Int) : Outcome
        data class Tie(val drinks: Int) : Outcome
    }

    data class Move(val game: HigherLowerGame, val card: SpanishCard, val outcome: Outcome)

    val canStand: Boolean get() = streak >= HITS_NEEDED_TO_STAND
    val cardsLeft: Int get() = deck.size

    fun guess(guess: Guess, random: Random = Random.Default): Move {
        val source = deck.ifEmpty { SpanishCard.fullDeck.filter { it != current }.shuffled(random) }
        val next = source.last()
        val rest = source.dropLast(1)
        if (next.rank == current.rank) {
            val drinks = maxOf(1, pot)
            return Move(copy(deck = rest, current = next, pot = 0, streak = 0), next, Outcome.Tie(drinks))
        }
        val isHigher = next.rank > current.rank
        if ((guess == Guess.HIGHER) == isHigher) {
            return Move(copy(deck = rest, current = next, pot = pot + 1, streak = streak + 1), next, Outcome.Hit(pot + 1))
        }
        val drinks = maxOf(1, pot)
        return Move(copy(deck = rest, current = next, pot = 0, streak = 0), next, Outcome.Miss(drinks))
    }

    /** Ends the current player's run; the pot stays for the next player. */
    fun stand(): HigherLowerGame = copy(streak = 0)

    companion object {
        const val HITS_NEEDED_TO_STAND = 3

        fun new(random: Random = Random.Default): HigherLowerGame {
            val cards = SpanishCard.fullDeck.shuffled(random)
            return HigherLowerGame(deck = cards.dropLast(1), current = cards.last())
        }
    }
}

/**
 * "El Círculo": each rank of the Spanish deck carries a rule. Whoever draws the fourth king
 * drinks the final penalty and the round ends. Immutable.
 */
data class CircleGame(
    val hot: Boolean,
    val deck: List<SpanishCard>,
    val kingsDrawn: Int = 0,
    val lastCard: SpanishCard? = null,
) {
    data class Rule(
        val title: String,
        val detail: String,
        /** Sips for the player who drew the card, if the rule applies automatically. */
        val drawerSips: Int,
        /** Sips for everyone at the table. */
        val everyoneSips: Int,
    )

    data class Draw(val game: CircleGame, val card: SpanishCard, val rule: Rule, val isFinalKing: Boolean)

    val cardsLeft: Int get() = deck.size
    val isFinished: Boolean get() = kingsDrawn >= 4 || deck.isEmpty()

    fun draw(): Draw? {
        if (isFinished) return null
        val card = deck.last()
        val kings = if (card.rank == 12) kingsDrawn + 1 else kingsDrawn
        val next = copy(deck = deck.dropLast(1), kingsDrawn = kings, lastCard = card)
        return Draw(next, card, rule(card.rank, hot, kings), card.rank == 12 && kings == 4)
    }

    companion object {
        fun new(hot: Boolean, random: Random = Random.Default) = CircleGame(hot, SpanishCard.fullDeck.shuffled(random))

        /** [kingsDrawn] counts the king just drawn when [rank] is 12. */
        fun rule(rank: Int, hot: Boolean, kingsDrawn: Int = 0): Rule {
            if (rank == 12) {
                if (kingsDrawn >= 4) {
                    return Rule("¡El cuarto Rey!", "Has sacado el último Rey: te toca 5 de golpe y se acaba la ronda.", 5, 0)
                }
                val left = 4 - kingsDrawn
                return Rule(
                    "Rey nº $kingsDrawn",
                    "Bebes 1. ${if (left == 1) "Solo queda 1 Rey" else "Quedan $left reyes"}: quien saque el cuarto se lleva el castigo final.",
                    1, 0,
                )
            }
            val table = if (hot) HOT_RULES else NORMAL_RULES
            return table[rank] ?: Rule("Libre", "Te libras esta vez.", 0, 0)
        }

        val NORMAL_RULES = mapOf(
            1 to Rule("Todos", "Brindis general: bebe toda la mesa.", 0, 1),
            2 to Rule("Reparte", "Reparte 2 entre quien quieras.", 0, 0),
            3 to Rule("Para ti", "Te tocan 2. Salud.", 2, 0),
            4 to Rule("Izquierda", "Le toca a quien tienes a tu izquierda.", 0, 0),
            5 to Rule("Derecha", "Le toca a quien tienes a tu derecha.", 0, 0),
            6 to Rule("Yo nunca", "Di un «yo nunca». Bebe quien sí lo haya hecho.", 0, 0),
            7 to Rule("Categoría", "Elige una categoría y decid cosas por turnos. Quien se quede en blanco, 2.", 0, 0),
            10 to Rule("Norma", "Inventa una norma que dure toda la ronda. Quien la rompa, bebe.", 0, 0),
            11 to Rule("Preguntón", "Hasta tu próximo turno, quien conteste a tus preguntas bebe.", 0, 0),
        )

        val HOT_RULES = mapOf(
            1 to Rule("Brindis hot", "Brindad mirándoos a los ojos. Quien aparte la mirada primero, bebe 2.", 0, 1),
            2 to Rule("Reparte", "Reparte 2 entre quien más te guste de la mesa.", 0, 0),
            3 to Rule("Confiesa", "Cuenta tu último ligue o bebe 3.", 0, 0),
            4 to Rule("Izquierda", "Piropo a quien tienes a tu izquierda. Si se ríe, bebe.", 0, 0),
            5 to Rule("Derecha", "Quien está a tu derecha te pregunta lo que quiera. Contesta o bebe 2.", 0, 0),
            6 to Rule("Yo nunca hot", "Di un «yo nunca» picante. Bebe quien sí lo haya hecho.", 0, 0),
            7 to Rule("Categoría hot", "Categoría picante (lugares para una cita, apps de ligar…). Quien se quede en blanco, 2.", 0, 0),
            10 to Rule("Norma hot", "Inventa una norma picante para la ronda. Quien la rompa, bebe.", 0, 0),
            11 to Rule("Pareja de tragos", "Elige a alguien: cada vez que bebas tú, bebe también, hasta tu próximo turno.", 0, 0),
        )
    }
}
