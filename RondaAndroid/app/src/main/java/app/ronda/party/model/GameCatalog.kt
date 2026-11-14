package app.ronda.party.model

import app.ronda.party.content.CardBank
import kotlinx.serialization.Serializable

/** The two sections of the home screen. */
enum class PartyMode(val title: String) { NORMAL("Normal"), HOT("Hot") }

/** Content intensity inside the Normal section. */
enum class Intensity(val title: String) { SOFT("Suave"), PARTY("Fiesta") }

enum class GameKind(val title: String, val tagline: String, val howToPlay: String) {
    NEVER_HAVE(
        "Yo nunca", "Bebe quien sí lo haya hecho",
        "Sale una frase «Yo nunca…». Quien SÍ lo haya hecho bebe. Marca en la app quién ha bebido para llevar la cuenta y pasa a la siguiente.",
    ),
    MOST_LIKELY(
        "¿Quién es más probable?", "A la de 3, todos señaláis",
        "Lee la pregunta en voz alta. A la de 3, todos señaláis a la vez a alguien. Quien reciba más dedos bebe 2. Si hay empate, beben todos los empatados.",
    ),
    TRUTH_OR_DRINK(
        "Verdad o trago", "Contesta o bebe",
        "Le toca a quien sale en pantalla: o contesta la pregunta con sinceridad, o bebe y pasa.",
    ),
    DARES(
        "Retos", "Retos atrevidos entre dos",
        "La app elige a dos jugadores y un reto. Se puede rechazar siempre: quien no quiera hacerlo bebe 3 y no pasa nada.",
    ),
    BOMB(
        "La Bomba", "Pásala antes de que explote",
        "Sale una categoría. Pulsad «Encender» y pasad el móvil diciendo cada uno una palabra. La bomba explota en un momento al azar: quien la tenga, bebe.",
    ),
    HIGHER_LOWER(
        "Mayor o menor", "Adivina con la baraja española",
        "Adivina si la siguiente carta será mayor o menor. Cada acierto suma 1 al bote; si fallas o hay empate, te bebes el bote entero. Con 3 aciertos puedes plantarte y pasarle el bote al siguiente.",
    ),
    CIRCLE(
        "El Círculo", "Cada carta, una norma",
        "Por turnos, sacad una carta de la baraja española. Cada número tiene una norma. Quien saque el cuarto Rey se lleva el castigo final.",
    ),
    DUELS(
        "Duelos", "Cara a cara en la pantalla",
        "Elegid dos jugadores. Cada uno en su mitad de la pantalla, cara a cara. Quien pierda el minijuego, bebe 2.",
    ),
    ROULETTE("La Ruleta", "Gira y que decida la suerte", "Gira la ruleta en tu turno y haz lo que salga.");

    val minimumPlayers: Int get() = if (this == MOST_LIKELY) 3 else 2

    val supportsCustomCards: Boolean get() = this in listOf(NEVER_HAVE, MOST_LIKELY, TRUTH_OR_DRINK, DARES)

    /** Stable identifier used in test tags (matches the iOS identifiers). */
    val tag: String
        get() = when (this) {
            NEVER_HAVE -> "neverHave"; MOST_LIKELY -> "mostLikely"; TRUTH_OR_DRINK -> "truthOrDrink"; DARES -> "dares"
            BOMB -> "bomb"; HIGHER_LOWER -> "higherLower"; CIRCLE -> "circle"; DUELS -> "duels"; ROULETTE -> "roulette"
        }

    companion object {
        /** Which games belong to each section. */
        fun games(mode: PartyMode): List<GameKind> = when (mode) {
            PartyMode.NORMAL -> listOf(NEVER_HAVE, MOST_LIKELY, TRUTH_OR_DRINK, BOMB, HIGHER_LOWER, CIRCLE, DUELS, ROULETTE)
            PartyMode.HOT -> listOf(NEVER_HAVE, MOST_LIKELY, TRUTH_OR_DRINK, DARES, BOMB, ROULETTE, CIRCLE)
        }
    }
}

/** Built-in prompt decks per game, mode and intensity. */
object PromptDecks {
    fun prompts(game: GameKind, mode: PartyMode, intensity: Intensity): List<String> = when (game) {
        GameKind.NEVER_HAVE -> if (mode == PartyMode.HOT) CardBank.neverHot
            else if (intensity == Intensity.SOFT) CardBank.neverSoft else CardBank.neverSoft + CardBank.neverParty
        GameKind.MOST_LIKELY -> if (mode == PartyMode.HOT) CardBank.mostLikelyHot
            else if (intensity == Intensity.SOFT) CardBank.mostLikelySoft else CardBank.mostLikelySoft + CardBank.mostLikelyParty
        GameKind.TRUTH_OR_DRINK -> if (mode == PartyMode.HOT) CardBank.truthHot
            else if (intensity == Intensity.SOFT) CardBank.truthSoft else CardBank.truthSoft + CardBank.truthParty
        GameKind.DARES -> CardBank.daresHot
        GameKind.BOMB -> if (mode == PartyMode.HOT) CardBank.bombHot else CardBank.bombNormal
        else -> emptyList()
    }

    /** Sips for refusing or losing on each card type. */
    fun penalty(game: GameKind, mode: PartyMode): Int = when (game) {
        GameKind.NEVER_HAVE -> 1
        GameKind.MOST_LIKELY -> 2
        GameKind.TRUTH_OR_DRINK -> if (mode == PartyMode.HOT) 3 else 2
        GameKind.DARES -> 3
        GameKind.BOMB -> 2
        GameKind.DUELS -> 2
        else -> 1
    }
}

/** A prompt written by the group (inside jokes, local references…), mixed into the built-in deck. */
@Serializable
data class CustomCard(
    val id: String = java.util.UUID.randomUUID().toString(),
    val game: GameKind,
    val mode: PartyMode,
    val text: String,
    val createdAt: Long = System.currentTimeMillis(),
)

object CustomCardRules {
    const val MAX_LENGTH = 160

    /** Normalises a custom card: trims, collapses whitespace, adds the game's prefix where it helps. */
    fun normalize(raw: String, game: GameKind): String? {
        val text = raw.trim().split(Regex("\\s+")).filter { it.isNotEmpty() }.joinToString(" ")
        if (text.length < 3) return null
        val limited = text.take(MAX_LENGTH)
        val folded = app.ronda.party.core.PlayerRules.fold(limited)
        return when (game) {
            GameKind.NEVER_HAVE -> if (folded.startsWith("yo nunca")) limited else "Yo nunca " + lowercasedFirst(limited)
            GameKind.MOST_LIKELY -> if (folded.startsWith("¿quien") || folded.startsWith("quien")) {
                if (limited.startsWith("¿")) limited else "¿" + limited + (if (limited.endsWith("?")) "" else "?")
            } else {
                "¿Quién es más probable que " + lowercasedFirst(limited.trim('¿', '?')) + "?"
            }
            else -> limited
        }
    }

    private fun lowercasedFirst(text: String) = text.replaceFirstChar { it.lowercase() }
}
