import 'dart:async';
import 'package:flutter/material.dart';
import '../core/models.dart';

/// Shared by Home, the appearance preview and the service-owned Flutter window.
class LyricsView extends StatefulWidget {
  final AppSnapshot data;
  final Json settings;
  final bool preview;
  const LyricsView({
    super.key,
    required this.data,
    required this.settings,
    this.preview = false,
  });
  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final _scroll = ScrollController();
  List<GlobalKey> _keys = [];
  int _lastLine = -2;
  double _lastAlignment = .35;
  String _lastText = '';
  DateTime _manualUntil = DateTime(2000);
  Timer? _resume;
  bool _scheduled = false;

  @override
  void dispose() {
    _scroll.dispose();
    _resume?.cancel();
    super.dispose();
  }

  void _follow(int index, int millis, [double alignment = .35]) {
    if (_scheduled || index < 0) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted ||
          index >= _keys.length ||
          DateTime.now().isBefore(_manualUntil)) {
        return;
      }
      final context = _keys[index].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: alignment,
          duration: Duration(milliseconds: millis),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final settings = widget.settings;
    final color = Theme.of(context).colorScheme;
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        settings['animation'] == 'none';
    final ms = reduced ? 0 : (settings['duration'] as num).toInt();
    final size = (settings['fontSize'] as num).toDouble();
    final position = data.position + (settings['offsetMs'] as num).toInt();
    final active = activeLine(data.lines, position);
    if (data.status != 'ready') {
      final (icon, title, subtitle) = switch (data.status) {
        'loading' => (
          Icons.travel_explore_rounded,
          'Finding your words',
          'Looking up lyrics for this recording…',
        ),
        'instrumental' => (
          Icons.piano_rounded,
          'Let the music speak',
          'This recording is marked instrumental.',
        ),
        'missing' => (
          Icons.lyrics_outlined,
          'No lyrics yet',
          'Try another source in Settings.',
        ),
        'error' => (
          Icons.cloud_off_rounded,
          'Could not load lyrics',
          data.lyrics['message'] as String? ??
              'Check your connection and try again.',
        ),
        _ => (
          Icons.headphones_rounded,
          'A little space for your music',
          'Play a song in your favorite app.',
        ),
      };
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: color.primary),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: color.onSurfaceVariant, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }
    Widget line(
      String text, {
      bool current = false,
      bool faded = false,
      List<LyricWord> words = const [],
      int sungUntilMs = 0,
    }) {
      final rtl = isRtl(text);
      final align = switch (settings['alignment']) {
        'left' => TextAlign.left,
        'center' => TextAlign.center,
        'right' => TextAlign.right,
        _ => rtl ? TextAlign.right : TextAlign.left,
      };
      // Keep typography identical for active and idle lines so wrapping
      // never shifts when a line becomes active. Emphasis comes only from
      // color, weight and glow, which do not affect layout.
      final base = TextStyle(
        fontFamily: rtl ? 'Vazirmatn' : 'Manrope',
        fontFamilyFallback: const ['Vazirmatn'],
        fontSize: size,
        height: (settings['lineHeight'] as num).toDouble(),
        fontWeight: current ? FontWeight.w700 : FontWeight.w400,
        shadows: current && settings['glow'] == true
            ? [
                Shadow(
                  color: color.primary.withValues(alpha: .25),
                  blurRadius: 18,
                ),
              ]
            : null,
      );
      // Karaoke: timed words light up one by one as they are sung.
      // Weight stays constant so lighting a word never re-wraps the line.
      if (current && words.isNotEmpty && settings['karaoke'] != false) {
        return Text.rich(
          TextSpan(
            children: [
              for (final word in words)
                TextSpan(
                  text: word.text,
                  style: base.copyWith(
                    color: word.timeMs <= sungUntilMs
                        ? color.onSurface
                        : color.onSurface.withValues(alpha: .45),
                  ),
                ),
            ],
          ),
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: align,
          softWrap: true,
        );
      }
      return AnimatedDefaultTextStyle(
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
        textAlign: align,
        style: base.copyWith(
          color: current
              ? color.onSurface
              : color.onSurface.withValues(alpha: faded ? .42 : .7),
        ),
        child: Text(
          text.isEmpty ? (data.synced ? '♪' : ' ') : text,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: align,
          softWrap: true,
        ),
      );
    }

    // Focus scrolls line-by-line exactly like "All lines": the list glides
    // upward and the active line is highlighted. No text is ever swapped,
    // so nothing flashes or restarts. `visibleLines` sets how many lines
    // around the active one stay prominent in focus mode.
    final isFocus = data.synced && settings['mode'] == 'focus';
    final focusRadius = isFocus
        ? (((settings['visibleLines'] as num?)?.toInt() ?? 3).clamp(1, 9) ~/
                2)
        : 1;
    final text = data.plain.isNotEmpty
        ? data.plain
        : data.lines.map((e) => e.text).join('\n');
    final rows = data.synced
        ? data.lines.map((e) => e.text).toList()
        : text.split('\n');
    final identity = '${data.title}|${data.lyrics['synced']}|$text';
    if (_lastText != identity) {
      _lastText = identity;
      _keys = List.generate(rows.length, (_) => GlobalKey());
      _lastLine = -2;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
    if (data.synced && active != _lastLine) {
      _lastLine = active;
      _lastAlignment = isFocus ? .45 : .35;
      _follow(active, ms, _lastAlignment);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _manualUntil = DateTime.now().add(const Duration(seconds: 5));
          _resume?.cancel();
          _resume = Timer(const Duration(seconds: 5), () {
            if (mounted) _follow(_lastLine, ms, _lastAlignment);
          });
        }
        return false;
      },
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (settings['mode'] == 'focus' &&
                data.status == 'ready' &&
                !data.synced)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Focus needs synced lyrics — showing the full text.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.onSurfaceVariant,
                  ),
                ),
              ),
            for (var i = 0; i < rows.length; i++)
              Padding(
                key: _keys[i],
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: line(
                  rows[i],
                  current: !data.synced || i == active,
                  faded: isFocus
                      ? (active < 0 || (i - active).abs() > focusRadius)
                      : (data.synced && i < active),
                  words: data.synced ? data.lines[i].words : const [],
                  sungUntilMs: position,
                ),
              ),
            if ((data.lyrics['attribution'] as String? ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  data.lyrics['attribution'] as String,
                  style: TextStyle(fontSize: 11, color: color.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration windowDecoration(
  ColorScheme colors,
  Json settings, {
  bool shadow = true,
}) {
  final preset = settings['preset'];
  final opacity = (settings['opacity'] as num).toDouble();
  final gradient = switch (preset) {
    'aurora' => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.primaryContainer.withValues(alpha: opacity),
        colors.surfaceContainerHigh.withValues(alpha: opacity),
      ],
    ),
    'sunset' => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.tertiaryContainer.withValues(alpha: opacity),
        colors.primaryContainer.withValues(alpha: opacity),
      ],
    ),
    'ocean' => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colors.secondaryContainer.withValues(alpha: opacity),
        colors.surfaceContainerHigh.withValues(alpha: opacity),
      ],
    ),
    _ => null,
  };
  return BoxDecoration(
    color: gradient == null
        ? colors.surfaceContainerHigh.withValues(alpha: opacity)
        : null,
    gradient: gradient,
    borderRadius: BorderRadius.circular((settings['radius'] as num).toDouble()),
    border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
    // No shadow for the system overlay window: the WindowManager surface is
    // exactly the window size, so a blurred shadow gets clipped into a
    // square faint halo behind the rounded container.
    boxShadow: shadow
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: .15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ]
        : null,
  );
}
