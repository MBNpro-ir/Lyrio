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

  void _follow(int index, int millis) {
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
          alignment: .35,
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
    Widget line(String text, {bool current = false, bool faded = false}) {
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
      return AnimatedDefaultTextStyle(
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOutCubic,
        textAlign: align,
        style: TextStyle(
          fontFamily: rtl ? 'Vazirmatn' : 'Manrope',
          fontFamilyFallback: const ['Vazirmatn'],
          fontSize: size,
          height: (settings['lineHeight'] as num).toDouble(),
          fontWeight: current ? FontWeight.w700 : FontWeight.w400,
          color: current
              ? color.onSurface
              : color.onSurface.withValues(alpha: faded ? .42 : .7),
          shadows: current && settings['glow'] == true
              ? [
                  Shadow(
                    color: color.primary.withValues(alpha: .25),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        child: Text(
          text.isEmpty ? (data.synced ? '♪' : ' ') : text,
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          textAlign: align,
          softWrap: true,
        ),
      );
    }

    if (data.synced && settings['mode'] == 'focus') {
      final visible = ((settings['visibleLines'] as num?)?.toInt() ?? 3)
          .clamp(1, 9);
      final total = data.lines.length;
      final int start;
      if (total <= visible) {
        start = 0;
      } else if (active < 0) {
        start = 0;
      } else {
        start = (active - visible ~/ 2).clamp(0, total - visible);
      }
      final end = (start + visible).clamp(0, total);
      final focusKey = ValueKey('${data.title}-$active-$visible-$total');
      List<Widget> rows() {
        final out = <Widget>[];
        if (active < 0) {
          var shown = 0;
          out.add(line('♪', current: true));
          shown++;
          for (var i = start; i < end && shown < visible; i++) {
            out.add(const SizedBox(height: 10));
            out.add(line(data.lines[i].text, faded: true));
            shown++;
          }
          return out;
        }
        for (var i = start; i < end; i++) {
          if (out.isNotEmpty) out.add(const SizedBox(height: 10));
          final distance = (i - active).abs();
          out.add(
            line(
              data.lines[i].text,
              current: i == active,
              faded: distance > 1,
            ),
          );
        }
        return out;
      }

      final useSlide = settings['animation'] == 'slide' && !reduced;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Center(
          child: SingleChildScrollView(
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: Duration(milliseconds: ms),
                reverseDuration: Duration(milliseconds: ms),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder:
                    (currentChild, previousChildren) => Stack(
                      alignment: Alignment.center,
                      children:
                          [...previousChildren, currentChild]
                              .whereType<Widget>()
                              .toList(),
                    ),
              transitionBuilder: (child, animation) {
                if (!useSlide) {
                  return FadeTransition(opacity: animation, child: child);
                }
                // Incoming slides up from below, outgoing slides up and out.
                // Outgoing animation runs 1 -> 0, so a begin of (0, -0.45)
                // moves it upward while fading.
                final isIncoming = child.key == focusKey;
                final begin = isIncoming
                    ? const Offset(0, .45)
                    : const Offset(0, -.45);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: begin,
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: SizedBox(
                key: focusKey,
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: rows(),
                ),
              ),
              ),
            ),
          ),
        ),
      );
    }
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
      _follow(active, ms);
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _manualUntil = DateTime.now().add(const Duration(seconds: 5));
          _resume?.cancel();
          _resume = Timer(const Duration(seconds: 5), () {
            if (mounted) _follow(_lastLine, ms);
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
            for (var i = 0; i < rows.length; i++)
              Padding(
                key: _keys[i],
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: line(
                  rows[i],
                  current: !data.synced || i == active,
                  faded: data.synced && i < active,
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
  return BoxDecoration(
    color: preset == 'aurora'
        ? null
        : colors.surfaceContainerHigh.withValues(alpha: opacity),
    gradient: preset == 'aurora'
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primaryContainer.withValues(alpha: opacity),
              colors.surfaceContainerHigh.withValues(alpha: opacity),
            ],
          )
        : null,
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
