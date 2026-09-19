# Android lifecycle and permissions

Lyrio targets SDK 36 and runs on Android 8+ ARM64. A NotificationListenerService enables access to MediaSessionManager. Callbacks observe metadata/playback changes and session destruction. Among active sessions, a playing session is preferred. Only transport/media notifications are accepted for the metadata fallback.

Playback position is calculated from the player's reported position, monotonic last-update timestamp and playback speed. Pause stops interpolation; seeking replaces the timestamp. A player without timing information is shown as full text even if LRC exists.

The floating window is TYPE_APPLICATION_OVERLAY and has its own Flutter engine. The foreground service declares specialUse with a concrete lyrics-overlay description, starts from the visible activity, shows a persistent notification with Stop and uses START_STICKY for ordinary process reclamation. The task's removal does not explicitly stop it. Ordinary sticky-service recreation rechecks permission and enabled state.

No alarm loop, accessibility service, microphone or perpetual wake lock is used. Screen-off events pause the overlay Flutter lifecycle and its UI polling; media callbacks remain owned by Android. Keep screen awake is opt-in and applies to the visible overlay.

The window is touchable only in its own bounds. It does not capture typing/focus and cannot bypass other apps' secure-overlay protections.

## What cannot be guaranteed

- Android Force stop, Android's active-app Stop action and OEM process killers may stop all execution.
- A foreground service and battery exemption do not make a process immortal.
- Reboot does not silently enable the overlay; reopen Lyrio and turn it on.
- Some players omit artist/title, report inaccurate timing or expose only a notification. No audio fingerprinting is performed.
- Sideloaded applications may need **Allow restricted settings** before notification access can be enabled.
- Xiaomi/HyperOS and other manufacturers may require Autostart, unrestricted battery or a Recents lock.

These are device-validation items, not claims proven by a desktop unit test.

References: [MediaSessionManager](https://developer.android.com/reference/android/media/session/MediaSessionManager), [foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types#special-use), [user-stopped services](https://developer.android.com/develop/background-work/services/fgs/handle-user-stopping).
