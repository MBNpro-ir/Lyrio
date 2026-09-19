# Provider setup

| Source | Authentication | Content | Setup |
|---|---|---|---|
| LRCLIB | None | Synced LRC and/or plain lyrics; instrumental flag | [Official documentation](https://lrclib.net/docs) |
| Lyrics.ovh | None | Plain lyrics | [Official documentation](https://lyricsovh.docs.apiary.io/), [source](https://github.com/NTag/lyrics.ovh) |
| Musixmatch | Your developer key | Official matcher.lyrics.get response, possibly a preview | [Developer portal](https://developer.musixmatch.com/), [official API schema](https://github.com/musixmatch/musixmatch-sdk) |
| Custom | None, Bearer, custom header or query parameter | Configured string fields in a JSON object | Settings → Add your own API |

Free availability is not universal. Musixmatch access, quotas and permitted lyric length depend on your account; a free/full/synced entitlement is not assumed. The built-in adapter does not use private mobile APIs or scrape sites. Genius's public API is a metadata/annotation API, so it is not presented as a full-lyrics provider.

## Selection and matching

Automatic mode tries LRCLIB, Lyrics.ovh, a configured Musixmatch key and custom providers, preferring synchronized content. Selecting a provider prioritizes that provider. Disable **Try other sources** to confine requests to it.

LRCLIB receives the title and artist, plus album/duration when available. If exact lookup is missing, search candidates must match normalized title and artist and, when known, duration within three seconds. A wrong recording's synchronized lyrics are worse than an honest no-match.

Requests are sequential, separated by at least 350ms. HTTP 429 establishes a host cooldown from numeric or HTTP-date Retry-After. Network requests have timeouts and a 1 MB response limit. Responses are never logged. Redirects are not followed, preventing credentials being forwarded to an unexpected host.

Only public LRCLIB/Lyrics.ovh results are cached (up to 50, for 7 days). Musixmatch and custom results are held in memory only. Musixmatch restrictions, copyright text and any returned truncation notice are preserved.

## Custom API example

Endpoint:

```text
https://your-server.example/lyrics?artist={artist}&title={title}&duration={duration}
```

Templates: `{title}`, `{artist}`, `{album}`, `{duration}` (seconds). Every substituted value is URL-encoded.

Response:

```json
{
  "data": {
    "text": "An original line\nAnother original line",
    "lrc": "[00:01.00]An original line\n[00:05.00]Another original line",
    "credit": "Provided by your lyrics service"
  }
}
```

Set plain path to `data.text`, synced path to `data.lrc`, attribution path to `data.credit`. Either lyrics path may be empty. Numeric path components can select array entries, e.g. `results.0.lyrics`. The response root must be a JSON object. Only GET and UTF-8 JSON are supported; arbitrary scripts/HTML scraping are not.

Enter keys separately from URLs. Key values use AES-GCM with an Android Keystore key; application backup is disabled. Auth and endpoint fields contain no embedded production keys. Editing a provider leaves its existing key intact when the key field is blank; the key editor can remove it explicitly.

Each configured source receives the requested music metadata and your IP address under its own privacy and licensing policies.
