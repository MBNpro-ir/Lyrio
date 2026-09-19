import 'package:flutter/material.dart';

typedef Json = Map<String, dynamic>;

class LyricWord {
  final int timeMs;
  final String text;
  const LyricWord(this.timeMs, this.text);
}

class LyricLine {
  final int timeMs;
  final String text;

  /// Per-word timings for karaoke lines (`[00:03.00]<00:03.00>Hello
  /// <00:03.50>world`). Empty for plain line-timed lyrics.
  final List<LyricWord> words;
  const LyricLine(this.timeMs, this.text, [this.words = const []]);
}

int _stampToMs(RegExpMatch stamp) {
  final fraction = (stamp.group(3) ?? '').padRight(3, '0');
  return int.parse(stamp.group(1)!) * 60000 +
      int.parse(stamp.group(2)!) * 1000 +
      int.parse(fraction);
}

List<LyricLine> parseLrc(String source) {
  final timestamp = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
  final inline = RegExp(r'<(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?>');
  final offsetMatch = RegExp(
    r'\[offset:\s*([+-]?\d+)\]',
    caseSensitive: false,
  ).firstMatch(source);
  final offset = int.tryParse(offsetMatch?.group(1) ?? '') ?? 0;
  final lines = <LyricLine>[];
  for (final row in source.split('\n')) {
    final stamps = timestamp.allMatches(row).toList();
    if (stamps.isEmpty) continue;
    final raw = row.substring(stamps.last.end);
    // Karaoke: each inline tag starts a timed word running to the next tag.
    final tags = inline.allMatches(raw).toList();
    var text = '';
    var words = const <LyricWord>[];
    if (tags.isNotEmpty) {
      final built = <LyricWord>[];
      final buffer = StringBuffer();
      for (var i = 0; i < tags.length; i++) {
        final start = tags[i].end;
        final end = i + 1 < tags.length ? tags[i + 1].start : raw.length;
        built.add(LyricWord(_stampToMs(tags[i]) + offset, raw.substring(start, end)));
        buffer.write(raw.substring(start, end));
      }
      text = buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
      words = built;
    } else {
      text = raw.trim();
    }
    for (final stamp in stamps) {
      final time = _stampToMs(stamp);
      lines.add(LyricLine(time + offset, text, words));
    }
  }
  lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return lines;
}

int activeLine(List<LyricLine> lines, int positionMs) {
  var low = 0;
  var high = lines.length - 1;
  var found = -1;
  while (low <= high) {
    final mid = (low + high) ~/ 2;
    if (lines[mid].timeMs <= positionMs) {
      found = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return found;
}

bool isRtl(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x600 && rune <= 0x6ff) ||
        (rune >= 0x750 && rune <= 0x8ff) ||
        (rune >= 0xfb50 && rune <= 0xfefc)) {
      return true;
    }
    if ((rune >= 65 && rune <= 90) || (rune >= 97 && rune <= 122)) return false;
  }
  return false;
}

String clockLabel(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

const defaultSettings = <String, dynamic>{
  'theme': 'system',
  'dynamicColor': true,
  'accent': 0xff8065ff,
  'preset': 'aurora',
  'fontSize': 22.0,
  'opacity': .94,
  'width': 340.0,
  'height': 310.0,
  'radius': 28.0,
  'lineHeight': 1.55,
  'alignment': 'auto',
  'mode': 'focus',
  'animation': 'slide',
  'duration': 420.0,
  'glow': true,
  'karaoke': true,
  'showHeader': true,
  'hidePaused': false,
  'keepScreenOn': false,
  'locked': false,
  'visibleLines': 3.0,
  'blurBehind': false,
  'blurRadius': 40.0,
  'offsetMs': 0.0,
  'provider': 'auto',
  'fallback': true,
  'providers': <dynamic>[],
};

class AppSnapshot {
  final Json track, lyrics, settings, permissions;
  final bool overlayRunning;
  final int accent;
  final Set<String> keys;
  final String serviceError;
  final List<LyricLine> lines;
  AppSnapshot(Json json)
    : track = Json.from(json['track'] as Map? ?? {}),
      lyrics = Json.from(json['lyrics'] as Map? ?? {}),
      settings = {
        ...defaultSettings,
        ...Json.from(json['settings'] as Map? ?? {}),
      },
      permissions = Json.from(json['permissions'] as Map? ?? {}),
      overlayRunning = json['overlayRunning'] == true,
      accent = (json['accent'] as num?)?.toInt() ?? 0xff8065ff,
      keys = Set<String>.from(json['keys'] as List? ?? []),
      serviceError = json['serviceError'] as String? ?? '',
      lines = parseLrc((json['lyrics'] as Map?)?['synced'] as String? ?? '');
  String get title => track['title'] as String? ?? '';
  String get artist => track['artist'] as String? ?? '';
  String get album => track['album'] as String? ?? '';
  String get source => track['source'] as String? ?? '';
  bool get playing => track['playing'] == true;
  bool get timing => track['timingAvailable'] == true;
  int get position => (track['position'] as num?)?.toInt() ?? 0;
  int get duration => (track['duration'] as num?)?.toInt() ?? 0;
  String get status => lyrics['status'] as String? ?? 'idle';
  String get plain => lyrics['plain'] as String? ?? '';
  bool get synced => lines.isNotEmpty && timing;
}

extension PermissionSnapshot on AppSnapshot {
  bool get requiredPermissionsGranted =>
      permissions['listener'] == true &&
      permissions['overlay'] == true &&
      permissions['notifications'] == true;
}

ThemeData lyrioTheme(Color seed, Brightness brightness) {
  final colors = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    fontFamily: 'Manrope',
    fontFamilyFallback: const ['Vazirmatn'],
    scaffoldBackgroundColor: colors.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    sliderTheme: const SliderThemeData(
      showValueIndicator: ShowValueIndicator.onDrag,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
