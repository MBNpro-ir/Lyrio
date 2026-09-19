package com.mbn.lyrio
import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class LyrioNotificationListener : NotificationListenerService() {
    override fun onCreate() { super.onCreate(); LyrioCore.init(this) }
    override fun onListenerConnected() { LyrioCore.init(this) }
    override fun onListenerDisconnected() { LyrioCore.disconnect() }
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val n = sbn.notification
        if (sbn.packageName == packageName || n.category != Notification.CATEGORY_TRANSPORT) return
        LyrioCore.init(this)
        val title = n.extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val artist = n.extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        if (title.isNotBlank()) LyrioCore.notificationFallback(sbn.key, title, artist, sbn.packageName)
    }
    override fun onNotificationRemoved(sbn: StatusBarNotification) { LyrioCore.removeNotification(sbn.key) }
}
