package com.mbn.lyrio

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object KeyVault {
    private const val alias = "lyrio.provider.keys"
    private val cached = mutableMapOf<String, String>()
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    @Synchronized fun write(context: Context, id: String, value: String) {
        val prefs = context.getSharedPreferences("credentials", Context.MODE_PRIVATE)
        if (value.isEmpty()) { prefs.edit().remove(id).apply(); cached[id] = ""; return }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val blob = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        prefs.edit().putString(id, Base64.encodeToString(blob, Base64.NO_WRAP)).apply()
        cached[id] = value
    }
    @Synchronized fun read(context: Context, id: String): String {
        cached[id]?.let { return it }
        val value = runCatching {
        val blob = Base64.decode(context.getSharedPreferences("credentials", Context.MODE_PRIVATE).getString(id, ""), Base64.NO_WRAP)
        if (blob.size < 29) "" else Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, blob.copyOfRange(0, 12)))
            String(doFinal(blob.copyOfRange(12, blob.size)), Charsets.UTF_8)
        }
        }.getOrDefault("")
        cached[id] = value
        return value
    }
}
