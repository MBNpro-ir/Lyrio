# Validation record — 2026-09-19

Environment: Windows x64, Flutter stable revision 6a19cca564 (3.47.5), Dart 3.13.4, Android SDK 36, NDK 28.2.13676358, JDK 21. Initial validation used a temporary SDK checkout at this revision. Development now uses the system Flutter installation on PATH, at the same revision.

| Check | Result |
|---|---|
| Flutter analyze | Passed, no issues |
| Flutter unit/widget tests | 9 passed |
| Android debug build | Passed, target android-arm64 |
| Packaged native libraries | arm64-v8a only |
| Kotlin bridge and service in DEX | Verified |
| Manrope and Vazirmatn in APK | Verified |
| Android Lint | Passed: 0 errors, 21 warnings |
| PowerShell scripts | Parser validation passed |
| LRCLIB live lookup | Returned synchronized and plain content |
| Lyrics.ovh live lookup | Returned plain content |
| UI render review | Light/dark captures inspected; small-width/large-text test passed |

Tests cover LRC fractions/multiple timestamps/offsets, exact boundaries and backward seeking, enhanced-tag removal, mixed-script direction, lack of a media clock, idle Home, swipe navigation, complete plain lyrics, small screens and collapsed overlay layout.

Lint warnings include the intentionally ARM64-only target, the optional battery-exemption flow, physical window coordinates, and Kotlin extension/style suggestions. The current Gradle/Kotlin compatibility path also emits migration/deprecation warnings; it compiles successfully. These warnings were not hidden using a blanket lint baseline.

The phone was not installed or controlled during final verification. Real notification-listener delivery, OEM service persistence, overlay permissions and rendering over other apps must be exercised using [PHONE_TEST.md](PHONE_TEST.md). Musixmatch was not queried without a personal API key. A custom endpoint needs testing against the user's actual response schema. Debug signing is not production signing.

The live provider check inspected response structure/length only; no fetched lyrics are committed. Screenshots use original preview text.
