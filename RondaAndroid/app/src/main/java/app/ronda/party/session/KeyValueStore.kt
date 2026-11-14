package app.ronda.party.session

import android.content.SharedPreferences

/** Tiny persistence abstraction so the session can be unit-tested without Android. */
interface KeyValueStore {
    fun getString(key: String): String?
    fun putString(key: String, value: String?)
    fun getInt(key: String): Int?
    fun putInt(key: String, value: Int)
    fun getBoolean(key: String): Boolean
    fun putBoolean(key: String, value: Boolean)
}

class InMemoryStore : KeyValueStore {
    private val values = mutableMapOf<String, Any>()
    override fun getString(key: String) = values[key] as? String
    override fun putString(key: String, value: String?) { if (value == null) values.remove(key) else values[key] = value }
    override fun getInt(key: String) = values[key] as? Int
    override fun putInt(key: String, value: Int) { values[key] = value }
    override fun getBoolean(key: String) = values[key] as? Boolean ?: false
    override fun putBoolean(key: String, value: Boolean) { values[key] = value }
}

class SharedPreferencesStore(private val prefs: SharedPreferences) : KeyValueStore {
    override fun getString(key: String): String? = prefs.getString(key, null)
    override fun putString(key: String, value: String?) { prefs.edit().apply { if (value == null) remove(key) else putString(key, value) }.apply() }
    override fun getInt(key: String): Int? = if (prefs.contains(key)) prefs.getInt(key, 0) else null
    override fun putInt(key: String, value: Int) { prefs.edit().putInt(key, value).apply() }
    override fun getBoolean(key: String): Boolean = prefs.getBoolean(key, false)
    override fun putBoolean(key: String, value: Boolean) { prefs.edit().putBoolean(key, value).apply() }
}
