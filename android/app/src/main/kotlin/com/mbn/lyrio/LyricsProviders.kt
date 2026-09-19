package com.mbn.lyrio

import android.content.Context
import android.net.Uri
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.security.MessageDigest
import java.io.File
import java.text.SimpleDateFormat
import java.util.Locale
import kotlin.math.abs

/** All calls are sequential on the Core executor; no provider receives arbitrary notifications. */
object LyricsProviders {
    private val cooldown = mutableMapOf<String, Long>()
    private var lastRequest = 0L
    private fun encode(value: String) = URLEncoder.encode(value, "UTF-8").replace("+", "%20")
    private class ProviderFailure(val safeMessage: String) : Exception()
    private fun request(url: String, headers: Map<String, String> = emptyMap()): String? {
        val parsed = URL(url)
        require(parsed.protocol == "https" && parsed.userInfo == null) { "Use an HTTPS endpoint without credentials in the URL." }
        val now = System.currentTimeMillis()
        val waitUntil = cooldown[parsed.host] ?: 0L
        if (now < waitUntil) throw ProviderFailure("Rate limited; try again in ${(waitUntil - now) / 1000 + 1}s.")
        val delay = 350 - (now - lastRequest)
        if (delay > 0) Thread.sleep(delay)
        lastRequest = System.currentTimeMillis()
        val connection = parsed.openConnection() as HttpURLConnection
        try {
            connection.connectTimeout = 8000
            connection.readTimeout = 10000
            connection.instanceFollowRedirects = false // Do not forward API credentials to another host.
            connection.setRequestProperty("User-Agent", "Lyrio/0.1.0 (https://github.com/MBNpro-ir/Lyrio)")
            connection.setRequestProperty("Accept", "application/json")
            headers.forEach { (key, value) -> connection.setRequestProperty(key, value) }
            val code = connection.responseCode
            if (code == 404) return null
            if (code == 429) {
                val retry = connection.getHeaderField("Retry-After").orEmpty()
                val until = retry.toLongOrNull()?.let { System.currentTimeMillis() + it.coerceAtLeast(1) * 1000 }
                    ?: runCatching { SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss z", Locale.US).parse(retry)?.time }.getOrNull()
                    ?: (System.currentTimeMillis() + 60000)
                cooldown[parsed.host] = until.coerceAtLeast(System.currentTimeMillis() + 1000)
                throw ProviderFailure("Rate limited by provider. Retry after its cooldown.")
            }
            if (code == 401 || code == 403) throw ProviderFailure("API key or subscription does not allow this request.")
            if (code !in 200..299) throw ProviderFailure("Provider returned HTTP $code.")
            val bytes = connection.inputStream.use { stream ->
                val output = java.io.ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                while (output.size() <= 1_000_000) {
                    val count = stream.read(buffer)
                    if (count < 0) break
                    output.write(buffer, 0, count)
                }
                output.toByteArray()
            }
            if (bytes.size > 1_000_000) throw ProviderFailure("Provider response is too large.")
            return String(bytes, Charsets.UTF_8)
        } finally { connection.disconnect() }
    }
    private fun result(plain: String, synced: String, source: String, attribution: String = "", instrumental: Boolean = false) =
        JSONObject().put("status", if (instrumental) "instrumental" else "ready").put("plain", plain)
            .put("synced", synced).put("source", source).put("attribution", attribution)
    private fun nonNull(json: JSONObject, key: String) = if (json.isNull(key)) "" else json.optString(key)
    private fun lrcResult(json: JSONObject) = result(nonNull(json, "plainLyrics"), nonNull(json, "syncedLyrics"), "LRCLIB", "", json.optBoolean("instrumental"))

    /** Weird player titles ("Song (Remastered 2024) [Live]", "Artist feat. X")
     * rarely match provider catalogs verbatim. Generate cleaned fallbacks. */
    private fun stripExtras(s: String): String {
        var v = s.replace(Regex("\\s*[\\(\\[].*?[\\)\\]]"), "").trim()
        v = v.replace(Regex("\\s+-\\s+.*(remaster|remix|live|acoustic|version|edit|deluxe).*$", RegexOption.IGNORE_CASE), "").trim()
        return v
    }
    private fun mainArtist(s: String): String =
        s.split(Regex("\\s+(feat\\.?|ft\\.?|featuring|with|&|×|x|,)\\s+", RegexOption.IGNORE_CASE))
            .firstOrNull()?.trim().orEmpty().ifEmpty { s }

    /** Ordered (title, artist) attempts: exact first, cleaned variants after. */
    private fun candidates(track: JSONObject): List<Pair<String, String>> {
        val out = mutableListOf<Pair<String, String>>()
        fun add(t: String, a: String) {
            if (t.isNotBlank() && a.isNotBlank() && !out.contains(t to a)) out.add(t to a)
        }
        val title = track.optString("title")
        val artist = track.optString("artist").ifBlank { track.optString("displaySubtitle") }
        add(title, artist)
        add(stripExtras(title), artist)
        add(title, mainArtist(artist))
        add(stripExtras(title), mainArtist(artist))
        return out.take(4)
    }

    fun find(context: Context, track: JSONObject, config: JSONObject, force: Boolean): JSONObject {
        val selected = config.optString("provider", "auto")
        val customSpecs = config.optJSONArray("providers") ?: JSONArray()
        val order = mutableListOf<String>()
        if (selected != "auto") order.add(selected)
        if (selected == "auto" || config.optBoolean("fallback", true)) {
            order.addAll(listOf("lrclib", "ovh"))
            if (KeyVault.read(context, "musixmatch").isNotEmpty()) order.add("musixmatch")
            for (i in 0 until customSpecs.length()) order.add(customSpecs.getJSONObject(i).optString("id"))
        }
        val failures = mutableListOf<String>()
        var plainCandidate: JSONObject? = null
        for (id in order.distinct()) {
            try {
                val cacheable = id == "lrclib" || id == "ovh"
                val cacheKey = MessageDigest.getInstance("SHA-256").digest("$id|${track}".toByteArray()).joinToString("") { "%02x".format(it) }
                val folder = File(context.cacheDir, "lyrics").apply { mkdirs() }
                val file = File(folder, "$cacheKey.json")
                val cached = if (cacheable && !force && file.exists() && System.currentTimeMillis() - file.lastModified() < 7 * 86400000L)
                    runCatching { JSONObject(file.readText()) }.getOrNull() else null
                val found = cached ?: when (id) {
                    "lrclib" -> lrclib(track)
                    "ovh" -> candidates(track).firstNotNullOfOrNull { (t, a) ->
                        request("https://api.lyrics.ovh/v1/${encode(a)}/${encode(t)}")?.let {
                            result(nonNull(JSONObject(it), "lyrics"), "", "Lyrics.ovh")
                        }
                    }
                    "musixmatch" -> musixmatch(context, track)
                    else -> {
                        val spec = (0 until customSpecs.length()).map { customSpecs.getJSONObject(it) }.firstOrNull { it.optString("id") == id }
                            ?: throw ProviderFailure("Provider is no longer configured.")
                        custom(context, track, spec)
                    }
                }
                if (found == null || (found.optString("plain").isBlank() && found.optString("synced").isBlank() && found.optString("status") != "instrumental")) continue
                if (cacheable && cached == null) {
                    runCatching { file.writeText(found.toString()); folder.listFiles()?.sortedByDescending { it.lastModified() }?.drop(50)?.forEach { it.delete() } }
                }
                if (selected != "auto" || found.optString("synced").isNotBlank() || found.optString("status") == "instrumental") return found
                if (plainCandidate == null) plainCandidate = found
            } catch (e: ProviderFailure) { failures.add("$id: ${e.safeMessage}") }
              catch (_: java.net.SocketTimeoutException) { failures.add("$id: Connection timed out.") }
              catch (_: Exception) { failures.add("$id: Network or response error.") }
        }
        return plainCandidate ?: JSONObject().put("status", if (failures.isEmpty()) "missing" else "error")
            .put("message", if (failures.isEmpty()) "No lyrics found for this recording." else failures.joinToString("\n"))
    }
    private fun lrclib(track: JSONObject): JSONObject? {
        val tries = candidates(track)
        val first = tries.firstOrNull() ?: return null
        val query = Uri.parse("https://lrclib.net/api/get").buildUpon().appendQueryParameter("track_name", first.first)
            .appendQueryParameter("artist_name", first.second)
        if (track.optString("album").isNotBlank()) query.appendQueryParameter("album_name", track.optString("album"))
        if (track.optLong("duration") > 0) query.appendQueryParameter("duration", (track.optLong("duration") / 1000.0).toString())
        request(query.build().toString())?.let { return lrcResult(JSONObject(it)) }
        val normalized: (String) -> String = { it.lowercase().replace(Regex("[^\\p{L}\\p{N}]"), "") }
        for ((t, a) in tries) {
            val search = Uri.parse("https://lrclib.net/api/search").buildUpon().appendQueryParameter("track_name", t)
                .appendQueryParameter("artist_name", a).build()
            val matches = JSONArray(request(search.toString()) ?: "[]")
            val valid = (0 until matches.length()).map { matches.getJSONObject(it) }.filter {
                normalized(it.optString("trackName")) == normalized(t) &&
                normalized(it.optString("artistName")) == normalized(a) &&
                (track.optLong("duration") <= 0 || abs(it.optDouble("duration") - track.optLong("duration") / 1000.0) <= 5)
            }
            valid.sortedByDescending { !it.isNull("syncedLyrics") }.firstOrNull()?.let { return lrcResult(it) }
        }
        return null
    }
    private fun musixmatch(context: Context, track: JSONObject): JSONObject? {
        val key = KeyVault.read(context, "musixmatch")
        if (key.isBlank()) throw ProviderFailure("Add your developer API key in Settings.")
        for ((t, a) in candidates(track).take(2)) {
            val uri = Uri.parse("https://api.musixmatch.com/ws/1.1/matcher.lyrics.get").buildUpon()
                .appendQueryParameter("q_track", t).appendQueryParameter("q_artist", a)
                .appendQueryParameter("apikey", key).build()
            val message = JSONObject(request(uri.toString()) ?: continue).getJSONObject("message")
            val code = message.getJSONObject("header").optInt("status_code")
            if (code == 404) continue
            if (code != 200) throw ProviderFailure("API returned status $code; check your plan and key.")
            val lyric = message.getJSONObject("body").getJSONObject("lyrics")
            if (lyric.optInt("restricted") == 1) throw ProviderFailure("Lyrics are restricted in your region.")
            // Keep the returned preview/truncation notice and copyright exactly as supplied.
            return result(lyric.optString("lyrics_body"), "", "Musixmatch", lyric.optString("lyrics_copyright"))
        }
        return null
    }
    private fun custom(context: Context, track: JSONObject, spec: JSONObject): JSONObject? {
        var url = spec.getString("url")
        val values = mapOf("title" to track.optString("title"), "artist" to track.optString("artist"), "album" to track.optString("album"), "duration" to (track.optLong("duration") / 1000).toString(),
            "displayTitle" to track.optString("displayTitle"), "composer" to track.optString("composer"), "genre" to track.optString("genre"),
            "year" to track.optLong("year").takeIf { it > 0 }?.toString().orEmpty(), "trackNumber" to track.optLong("trackNumber").takeIf { it > 0 }?.toString().orEmpty())
        values.forEach { (k, v) -> url = url.replace("{$k}", encode(v)) }
        val headers = mutableMapOf<String, String>()
        val key = KeyVault.read(context, spec.getString("id"))
        when (spec.optString("auth")) {
            "bearer" -> if (key.isNotEmpty()) headers["Authorization"] = "Bearer $key"
            "header" -> if (key.isNotEmpty()) headers[spec.optString("keyName", "X-API-Key")] = key
            "query" -> if (key.isNotEmpty()) url = Uri.parse(url).buildUpon().appendQueryParameter(spec.optString("keyName", "apikey"), key).build().toString()
        }
        val json = JSONObject(request(url, headers) ?: return null)
        fun path(name: String): String {
            if (name.isBlank()) return ""
            var value: Any? = json
            name.split('.').forEach { field ->
                value = when (val current = value) {
                    is JSONObject -> current.opt(field)
                    is JSONArray -> field.toIntOrNull()?.let { current.opt(it) }
                    else -> null
                }
            }
            return value as? String ?: ""
        }
        return result(path(spec.optString("plainPath", "plainLyrics")), path(spec.optString("syncedPath", "syncedLyrics")), spec.optString("name", "Custom"), path(spec.optString("attributionPath")))
    }
    fun clearCache(context: Context) { File(context.cacheDir, "lyrics").listFiles()?.forEach { it.delete() } }
}
