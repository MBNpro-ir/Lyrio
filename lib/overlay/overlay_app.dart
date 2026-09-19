import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/models.dart';
import '../ui/lyrics_view.dart';

class OverlayApp extends StatefulWidget {
  final LyrioController controller;
  const OverlayApp({super.key, required this.controller});
  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> {
  bool _compact = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final data = c.snapshot;
      final dark =
          c.choice('preset') == 'midnight' ||
          (c.choice('preset') != 'paper' && c.choice('theme') == 'dark') ||
          (c.choice('preset') != 'paper' &&
              c.choice('theme') == 'system' &&
              WidgetsBinding.instance.platformDispatcher.platformBrightness ==
                  Brightness.dark);
      final seed = Color(
        c.flag('dynamicColor')
            ? data.accent
            : (c.settings['accent'] as num).toInt(),
      );
      final theme = lyrioTheme(seed, dark ? Brightness.dark : Brightness.light);
      final hidden = c.flag('hidePaused') && !data.playing && data.timing;
      final cover = c.flag('coverColor') && data.coverColor != 0
          ? Color(data.coverColor)
          : null;
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Material(
          type: MaterialType.transparency,
          // AnimatedContainer cross-fades the background when the track
          // (and its cover color) changes.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            decoration: windowDecoration(
              theme.colorScheme,
              c.settings,
              shadow: false,
              cover: cover,
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: c.flag('locked')
                      ? null
                      : (_) => c.setDragging(true),
                  onPanUpdate: c.flag('locked')
                      ? null
                      : (event) => c.move(event.delta.dx, event.delta.dy),
                  onPanEnd: c.flag('locked')
                      ? null
                      : (_) {
                          c.setDragging(false);
                          c.endMove();
                        },
                  onPanCancel: () => c.setDragging(false),
                  child: SizedBox(
                    height: _compact ? 68 : 48,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14, right: 4),
                      child: Row(
                        children: [
                          Icon(
                            c.flag('locked')
                                ? Icons.lock_outline_rounded
                                : Icons.drag_indicator_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: c.flag('showHeader') || _compact
                                ? Text(
                                    data.title.isEmpty ? 'Lyrio' : data.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          IconButton(
                            tooltip: _compact ? 'Expand' : 'Collapse',
                            icon: Icon(
                              _compact
                                  ? Icons.unfold_more_rounded
                                  : Icons.unfold_less_rounded,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() => _compact = !_compact);
                              c.action('compact', _compact);
                            },
                          ),
                          IconButton(
                            tooltip: 'Close floating lyrics',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => c.action('overlay', false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!_compact) ...[
                  Expanded(
                    child: hidden
                        ? const Center(child: Text('Paused • lyrics hidden'))
                        : LyricsView(data: data, settings: c.settings),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.lyrics['source'] as String? ?? 'Lyrio',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Text(
                          data.synced ? clockLabel(data.position) : 'FULL TEXT',
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
