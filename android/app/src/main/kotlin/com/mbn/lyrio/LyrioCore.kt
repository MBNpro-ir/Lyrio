package com.mbn.lyrio

import android.app.NotificationManager
import android.app.Application
import android.content.ComponentName
import android.content.Context
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.Executors

/** Process-owned: survives Activity destruction. Observes only Android media metadata. */
object LyrioCore {
    lateinit var context: Application
        private set
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private val controllers = linkedMapOf<MediaController, MediaController.Callback>()
    private var manager: MediaSessionManager? = null
    private var registered = false
    private var selected: MediaController? = null
    @Volatile private var revision = 0
    private var signature = ""
    private var fallback = JSONObject()
    private var fallbackKey = ""
    private var track = JSONObject()
    var lyrics = JSONObject().put("status", "idle")
        private set
    var overlayRunning = false
    var activityVisible = false
    var serviceError = ""
    private val sessionsChanged = MediaSessionManager.OnActiveSessionsChangedListener { attach(it.orEmpty()) }

    fun init(ctx: Context) {
        if (!::context.isInitialized) context = ctx.applicationContext as Application
        if (manager == null) manager = context.getSystemService(MediaSessionManager::class.java)
        connect()
    }
    fun preferences() = context.getSharedPreferences("lyrio", Context.MODE_PRIVATE)
    fun settings(): JSONObject {
        val defaults = JSONObject("""{"theme":"system","dynamicColor":true,"accent":4286605311,"preset":"aurora","fontSize":22,"opacity":0.94,"width":340,"height":310,"radius":28,"lineHeight":1.55,"alignment":"auto","mode":"focus","animation":"slide","duration":420,"glow":true,"showHeader":true,"hidePaused":false,"keepScreenOn":false,"locked":false,"visibleLines":3,"offsetMs":0,"provider":"auto","fallback":true,"providers":[]}""")
        val saved = runCatching { JSONObject(preferences().getString("settings", "{}")!!) }.getOrDefault(JSONObject())
        saved.keys().forEach { defaults.put(it, saved.get(it)) }
        return defaults
    }
    fun saveSettings(value: JSONObject) {
        val old = settings()
        preferences().edit().putString("settings", value.toString()).apply()
        LyrioOverlayService.instance?.applySettings()
        if (old.optString("provider") != value.optString("provider") || old.optBoolean("fallback") != value.optBoolean("fallback") || old.optJSONArray("providers").toString() != value.optJSONArray("providers").toString()) fetch(true)
    }
    fun listenerEnabled(): Boolean {
        val component = ComponentName(context, LyrioNotificationListener::class.java)
        return Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
            ?.split(':')?.any { ComponentName.unflattenFromString(it) == component } == true
    }
    fun connect() {
        if (!listenerEnabled()) { disconnect(); return }
        val component = ComponentName(context, LyrioNotificationListener::class.java)
        try {
            if (!registered) {
                manager?.addOnActiveSessionsChangedListener(sessionsChanged, component, main)
                registered = true
            }
            attach(manager?.getActiveSessions(component).orEmpty())
        } catch (_: SecurityException) { disconnect() }
    }
    fun disconnect() {
        if (registered) manager?.removeOnActiveSessionsChangedListener(sessionsChanged)
        registered = false
        controllers.forEach { (c, callback) -> c.unregisterCallback(callback) }
        controllers.clear()
        selected = null
        fallback = JSONObject()
        fallbackKey = ""
        updateTrack()
    }
    private fun attach(list: List<MediaController>) {
        val tokens = list.map { it.sessionToken }.toSet()
        controllers.keys.filter { it.sessionToken !in tokens }.forEach { controller ->
            controllers.remove(controller)?.let { controller.unregisterCallback(it) }
        }
        list.filter { c -> controllers.keys.none { it.sessionToken == c.sessionToken } }.forEach { controller ->
            val callback = object : MediaController.Callback() {
                override fun onMetadataChanged(metadata: MediaMetadata?) = updateTrack()
                override fun onPlaybackStateChanged(state: PlaybackState?) = updateTrack()
                override fun onSessionDestroyed() {
                    controllers.remove(controller)?.let { controller.unregisterCallback(it) }
                    updateTrack()
                }
            }
            controllers[controller] = callback
            controller.registerCallback(callback, main)
        }
        updateTrack()
    }
    fun notificationFallback(key: String, title: String, artist: String, packageName: String) {
        fallbackKey = key
        fallback = JSONObject().put("title", title).put("artist", artist).put("album", "")
            .put("package", packageName).put("source", label(packageName)).put("timingAvailable", false)
        updateTrack()
    }
    fun removeNotification(key: String) {
        if (key == fallbackKey) { fallback = JSONObject(); fallbackKey = ""; updateTrack() }
    }
    private fun label(pkg: String): String = runCatching {
        context.packageManager.getApplicationLabel(context.packageManager.getApplicationInfo(pkg, 0)).toString()
    }.getOrDefault(pkg)
    private fun updateTrack() {
        selected = controllers.keys.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
            ?: selected?.takeIf { it in controllers.keys }
            ?: controllers.keys.firstOrNull { it.metadata != null }
        val controller = selected
        val metadata = controller?.metadata
        track = if (metadata == null) JSONObject(fallback.toString()) else JSONObject()
            .put("title", metadata.getString(MediaMetadata.METADATA_KEY_TITLE) ?: metadata.getString(MediaMetadata.METADATA_KEY_DISPLAY_TITLE) ?: "")
            .put("artist", metadata.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: metadata.getString(MediaMetadata.METADATA_KEY_ALBUM_ARTIST) ?: "")
            .put("album", metadata.getString(MediaMetadata.METADATA_KEY_ALBUM) ?: "")
            .put("duration", metadata.getLong(MediaMetadata.METADATA_KEY_DURATION))
            .put("source", label(controller!!.packageName)).put("package", controller.packageName)
            .put("timingAvailable", controller.playbackState?.position?.let { it >= 0 } == true)
        val next = listOf(track.optString("title"), track.optString("artist"), track.optString("album"), track.optLong("duration")).joinToString("|")
        if (next != signature) { signature = next; fetch() }
    }
    fun fetch(force: Boolean = false) {
        val generation = ++revision
        val snapshot = JSONObject(track.toString())
        if (!activityVisible && !overlayRunning) { lyrics = JSONObject().put("status", "idle"); return }
        if (snapshot.optString("title").isBlank()) { lyrics = JSONObject().put("status", "idle"); return }
        lyrics = JSONObject().put("status", "loading")
        val config = settings()
        io.execute {
            if (generation != revision) return@execute
            val result = LyricsProviders.find(context, snapshot, config, force)
            main.post { if (generation == revision) lyrics = result }
        }
    }
    fun state(): JSONObject {
        val current = JSONObject(track.toString())
        val playback = selected?.playbackState
        val playing = playback?.state == PlaybackState.STATE_PLAYING
        var position = playback?.position?.coerceAtLeast(0) ?: 0L
        if (playing && playback != null && playback.lastPositionUpdateTime > 0) {
            position += ((SystemClock.elapsedRealtime() - playback.lastPositionUpdateTime).coerceAtLeast(0) * playback.playbackSpeed).toLong()
        }
        val duration = current.optLong("duration")
        if (duration > 0) position = position.coerceAtMost(duration)
        current.put("position", position.coerceAtLeast(0)).put("playing", playing)
        val config = settings()
        val keys = JSONArray()
        listOf("musixmatch").plus((0 until config.getJSONArray("providers").length()).map { config.getJSONArray("providers").getJSONObject(it).optString("id") }).forEach {
            if (KeyVault.read(context, it).isNotBlank()) keys.put(it)
        }
        val permissions = JSONObject().put("listener", listenerEnabled()).put("overlay", Settings.canDrawOverlays(context))
            .put("notifications", context.getSystemService(NotificationManager::class.java).areNotificationsEnabled())
            .put("battery", context.getSystemService(PowerManager::class.java).isIgnoringBatteryOptimizations(context.packageName))
        val accent = if (Build.VERSION.SDK_INT >= 31) context.getColor(android.R.color.system_accent1_500).toLong() and 0xffffffffL else 0xff8065ffL
        return JSONObject().put("track", current).put("lyrics", lyrics).put("settings", config).put("permissions", permissions)
            .put("overlayRunning", overlayRunning).put("accent", accent).put("keys", keys).put("serviceError", serviceError)
    }
}
