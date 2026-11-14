package app.ronda.party.session

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import app.ronda.party.content.CardBank
import app.ronda.party.core.Lexicon
import app.ronda.party.core.Player
import app.ronda.party.core.PlayerRules
import app.ronda.party.core.ShuffledDeck
import app.ronda.party.core.SipLedger
import app.ronda.party.core.TurnOrder
import app.ronda.party.core.WaterBreakSchedule
import app.ronda.party.model.CustomCard
import app.ronda.party.model.CustomCardRules
import app.ronda.party.model.GameKind
import app.ronda.party.model.Intensity
import app.ronda.party.model.PartyMode
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json

enum class AgeStatus { ADULT, MINOR }

/**
 * State of the night: players, the sip tally, settings and the water-break schedule.
 * Players, tally and settings persist so a game survives the app being closed between rounds.
 * Backed by Compose snapshot state, so every screen recomposes when it changes.
 *
 * [demo] starts with four players and persists nothing (used by screenshot tests), like `-uiTesting` on iOS.
 * [fresh] (only with [demo]) starts from a first install.
 */
class PartySession(private val store: KeyValueStore, private val demo: Boolean = false, fresh: Boolean = false) {
    private object Key {
        const val PLAYERS = "players"
        const val LEDGER = "ledger"
        const val AGE = "ageStatus"
        const val SOBER = "soberMode"
        const val WATER = "waterEvery"
        const val INTENSITY = "intensity"
        const val SETUP = "setupDone"
        const val TURN = "turn"
        const val CUSTOM = "customCards"
        const val HAPTICS = "haptics"
    }

    private val json = Json { ignoreUnknownKeys = true }

    var players: List<Player> by mutableStateOf(
        if (demo) (if (fresh) emptyList() else listOf("Ana", "Leo", "Sara", "Dani").map { Player(name = it) })
        else decode(Key.PLAYERS, ListSerializer(Player.serializer())) ?: emptyList()
    )
        private set

    var ledger: SipLedger by mutableStateOf(if (demo) SipLedger() else decode(Key.LEDGER, SipLedger.serializer()) ?: SipLedger())
        private set

    var ageStatus: AgeStatus? by mutableStateOf(
        if (demo) (if (fresh) null else AgeStatus.ADULT) else store.getString(Key.AGE)?.let { runCatching { AgeStatus.valueOf(it) }.getOrNull() }
    )
        private set

    var soberPreference: Boolean by mutableStateOf(if (demo) false else store.getBoolean(Key.SOBER))
        private set

    var waterEvery: Int by mutableStateOf(if (demo) 0 else store.getInt(Key.WATER) ?: 10)
        private set

    var intensity: Intensity by mutableStateOf(
        if (demo) Intensity.PARTY else store.getString(Key.INTENSITY)?.let { runCatching { Intensity.valueOf(it) }.getOrNull() } ?: Intensity.PARTY
    )
        private set

    /** Set when the group finishes the first-run player list. */
    var setupDone: Boolean by mutableStateOf(if (demo) !fresh else store.getBoolean(Key.SETUP))
        private set

    var hapticsEnabled: Boolean by mutableStateOf(if (demo) true else store.getInt(Key.HAPTICS) != 0)
        private set

    var customCards: List<CustomCard> by mutableStateOf(
        if (demo) emptyList() else decode(Key.CUSTOM, ListSerializer(CustomCard.serializer())) ?: emptyList()
    )
        private set

    var mode: PartyMode by mutableStateOf(PartyMode.NORMAL)
    /** Group consent for the Hot section; asked again every time the app is launched. */
    var hotUnlocked: Boolean by mutableStateOf(false)
    var pendingWaterBreak: String? by mutableStateOf(null)

    var turn: TurnOrder by mutableStateOf(TurnOrder(players.size, if (demo) 0 else store.getInt(Key.TURN) ?: 0))
        private set

    private var water = WaterBreakSchedule(waterEvery)
    private val waterMessages = ShuffledDeck(CardBank.waterBreaks)

    // Derived

    /** Minors can use the app only in alcohol-free mode and never see the Hot section. */
    val soberMode: Boolean get() = soberPreference || ageStatus == AgeStatus.MINOR
    val canUseHot: Boolean get() = ageStatus == AgeStatus.ADULT
    val lexicon: Lexicon get() = Lexicon(soberMode)
    val currentPlayer: Player? get() = players.getOrNull(turn.current)

    fun playerLeftOf(player: Player): Player? = players.indexOf(player).takeIf { it >= 0 }?.let { players[turn.left(it)] }
    fun playerRightOf(player: Player): Player? = players.indexOf(player).takeIf { it >= 0 }?.let { players[turn.right(it)] }

    // Settings

    fun updateAgeStatus(value: AgeStatus?) {
        ageStatus = value
        persist { store.putString(Key.AGE, value?.name) }
    }

    fun updateSoberPreference(value: Boolean) {
        soberPreference = value
        persist { store.putBoolean(Key.SOBER, value) }
    }

    fun updateWaterEvery(value: Int) {
        waterEvery = value
        water = WaterBreakSchedule(value)
        persist { store.putInt(Key.WATER, value) }
    }

    fun updateIntensity(value: Intensity) {
        intensity = value
        persist { store.putString(Key.INTENSITY, value.name) }
    }

    fun updateHaptics(value: Boolean) {
        hapticsEnabled = value
        persist { store.putInt(Key.HAPTICS, if (value) 1 else 0) }
    }

    fun updateSetupDone(value: Boolean) {
        setupDone = value
        persist { store.putBoolean(Key.SETUP, value) }
    }

    // Players

    fun addPlayer(raw: String): Boolean {
        if (players.size >= PlayerRules.MAX_PLAYERS) return false
        val name = PlayerRules.sanitize(raw, players) ?: return false
        storePlayers(players + Player(name = name))
        return true
    }

    fun removePlayer(player: Player) = storePlayers(players.filter { it.id != player.id })

    fun movePlayer(from: Int, to: Int) {
        if (from !in players.indices || to !in players.indices) return
        storePlayers(players.toMutableList().apply { add(to, removeAt(from)) })
    }

    private fun storePlayers(value: List<Player>) {
        players = value
        turn = TurnOrder(value.size, turn.current)
        persist { store.putString(Key.PLAYERS, json.encodeToString(ListSerializer(Player.serializer()), value)) }
    }

    // Turns & sips

    fun nextTurn() {
        turn = turn.advanced()
        persist { store.putInt(Key.TURN, turn.current) }
    }

    fun give(sips: Int, to: Player?) {
        to ?: return
        storeLedger(ledger.add(sips, to.id))
    }

    fun give(sips: Int, to: Iterable<Player>) = storeLedger(ledger.add(sips, to.map { it.id }))

    fun everyone(sips: Int) = storeLedger(ledger.add(sips, players.map { it.id }))

    /** Undo a mistaken sip from the scoreboard. */
    fun undoSip(player: Player) = storeLedger(ledger.remove(1, player.id))

    fun resetLedger() = storeLedger(SipLedger())

    private fun storeLedger(value: SipLedger) {
        ledger = value
        persist { store.putString(Key.LEDGER, json.encodeToString(SipLedger.serializer(), value)) }
    }

    /** Call once per card/round. Schedules a water break when due (never in alcohol-free mode). */
    fun registerRound() {
        if (soberMode || !water.registerCard()) return
        pendingWaterBreak = waterMessages.draw()
    }

    // Custom cards

    fun customCards(game: GameKind, mode: PartyMode): List<CustomCard> = customCards.filter { it.game == game && it.mode == mode }

    fun addCustomCard(raw: String, game: GameKind, mode: PartyMode): Boolean {
        val text = CustomCardRules.normalize(raw, game) ?: return false
        storeCustomCards(listOf(CustomCard(game = game, mode = mode, text = text)) + customCards)
        return true
    }

    fun deleteCustomCard(card: CustomCard) = storeCustomCards(customCards.filter { it.id != card.id })

    private fun storeCustomCards(value: List<CustomCard>) {
        customCards = value
        persist { store.putString(Key.CUSTOM, json.encodeToString(ListSerializer(CustomCard.serializer()), value)) }
    }

    // Persistence

    private inline fun persist(block: () -> Unit) {
        if (!demo) block()
    }

    private fun <T> decode(key: String, serializer: kotlinx.serialization.KSerializer<T>): T? =
        store.getString(key)?.let { runCatching { json.decodeFromString(serializer, it) }.getOrNull() }
}
