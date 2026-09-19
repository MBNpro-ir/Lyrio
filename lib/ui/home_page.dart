import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'lyrics_view.dart';

class HomePage extends StatelessWidget {
  final LyrioController controller;
  const HomePage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final data = c.snapshot;
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: ListView(
        key: const PageStorageKey('home'),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.graphic_eq_rounded, color: colors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Lyrio',
                  style: TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.3,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh track and lyrics',
                onPressed: () => c.action('refresh'),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'A soundtrack.\nYour own little space.',
            style: TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.4,
              height: 1.15,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Words that stay with you.',
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [colors.primaryContainer, colors.tertiaryContainer],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -24,
                  top: -28,
                  child: Opacity(
                    opacity: .23,
                    child: CustomPaint(
                      size: const Size(200, 200),
                      painter: OrbitPainter(colors.primary),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(23),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            data.playing
                                ? Icons.graphic_eq_rounded
                                : Icons.music_note_rounded,
                            size: 18,
                            color: colors.onPrimaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            data.title.isEmpty
                                ? 'READY WHEN YOU ARE'
                                : data.playing
                                ? 'NOW PLAYING'
                                : 'LAST ACTIVE TRACK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 38),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: Align(
                          key: ValueKey(data.title),
                          alignment: Alignment.centerLeft,
                          child: Text(
                            data.title.isEmpty
                                ? 'Press play\nanywhere.'
                                : data.title,
                            textDirection: isRtl(data.title)
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.9,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        data.artist.isEmpty
                            ? 'Lyrio follows your music apps'
                            : data.artist,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onPrimaryContainer.withValues(
                            alpha: .8,
                          ),
                        ),
                      ),
                      if (data.album.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            data.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.onPrimaryContainer.withValues(
                                alpha: .65,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (data.timing && data.duration > 0) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (data.position / data.duration).clamp(0, 1),
                            minHeight: 4,
                            color: colors.primary,
                            backgroundColor: colors.primary.withValues(
                              alpha: .12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text(
                              clockLabel(data.position),
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              clockLabel(data.duration),
                              style: TextStyle(
                                fontSize: 10,
                                color: colors.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ] else
                        Text(
                          data.title.isEmpty
                              ? 'No media session detected'
                              : 'This player does not share its playback clock',
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.onPrimaryContainer.withValues(
                              alpha: .7,
                            ),
                          ),
                        ),
                      if (data.source.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            data.source,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: colors.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              secondary: Icon(Icons.layers_outlined, color: colors.primary),
              title: const Text(
                'Floating lyrics',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                data.overlayRunning
                    ? 'Following your music across apps'
                    : 'Take your lyrics with you',
                style: const TextStyle(fontSize: 12),
              ),
              value: data.overlayRunning,
              onChanged: c.loading
                  ? null
                  : (value) async {
                      await c.flushSettings();
                      if (value) {
                        for (final permission in [
                          'listener',
                          'overlay',
                          'notifications',
                        ]) {
                          if (data.permissions[permission] != true) {
                            if (!context.mounted) return;
                            await showPermissionSheet(context, c, permission);
                            return;
                          }
                        }
                      }
                      await c.action('overlay', value);
                    },
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'In the lyrics',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              StatusChip(
                data.synced
                    ? 'SYNCED'
                    : data.status == 'ready'
                    ? 'FULL TEXT'
                    : 'LIVE',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 260,
            clipBehavior: Clip.antiAlias,
            decoration: windowDecoration(colors, {
              ...c.settings,
              'opacity': 1.0,
            }),
            child: LyricsView(data: data, settings: c.settings),
          ),
          if (data.status == 'ready')
            Padding(
              padding: const EdgeInsets.only(top: 9, left: 4),
              child: Text(
                'Via ${data.lyrics['source']} · ${data.synced ? 'Synced to the player clock' : 'Scroll to read every line'}',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
          if ((data.lyrics['attribution'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                data.lyrics['attribution'] as String,
                style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 22),
          AccessPanel(controller: c),
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String text;
  const StatusChip(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: c.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: c.onSecondaryContainer,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

const permissionInfo = {
  'listener': (
    'Connect your music',
    'Notification access',
    'Lyrio uses active media sessions and media notifications to read song title, artist and playback timing. Android labels this permission broadly; Lyrio ignores messages and other non-media notifications.',
    Icons.headphones_rounded,
  ),
  'overlay': (
    'Let the words float',
    'Display over other apps',
    'Allow Lyrio to show a movable lyrics window over the app you are using. You can close it at any time from the window or its notification.',
    Icons.layers_outlined,
  ),
  'notifications': (
    'Keep a visible control',
    'Service notifications',
    'Lyrio shows a persistent notification while the floating window is on. It gives you a Stop button and a quick way back to the app.',
    Icons.notifications_outlined,
  ),
  'battery': (
    'Stay ready in the background',
    'Battery optimization',
    'Optional: allow unrestricted battery use for better background continuity. Some phones also need vendor Autostart enabled or the app locked in Recents. Android Force stop always stops Lyrio.',
    Icons.battery_charging_full_rounded,
  ),
};

Future<void> showPermissionSheet(
  BuildContext context,
  LyrioController controller,
  String permission,
) async {
  final (title, _, body, icon) = permissionInfo[permission]!;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 10, 26, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(body, style: const TextStyle(height: 1.6)),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                controller.action('permission', permission);
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open Android settings'),
            ),
          ],
        ),
      ),
    ),
  );
}

class AccessPanel extends StatelessWidget {
  final LyrioController controller;
  const AccessPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      children: [
        for (final entry in permissionInfo.entries)
          ListTile(
            leading: Icon(
              entry.value.$4,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(
              entry.value.$2,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            subtitle: entry.key == 'battery'
                ? const Text(
                    'Optional for better continuity',
                    style: TextStyle(fontSize: 11),
                  )
                : null,
            trailing: Icon(
              controller.snapshot.permissions[entry.key] == true
                  ? Icons.check_circle_rounded
                  : Icons.arrow_outward_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            onTap: () => showPermissionSheet(context, controller, entry.key),
          ),
      ],
    ),
  );
}

class OrbitPainter extends CustomPainter {
  final Color color;
  OrbitPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.translate(size.width / 2, size.height / 2);
    for (var i = 0; i < 14; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 14);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: size.width * .9,
          height: size.height * .38,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(OrbitPainter oldDelegate) => oldDelegate.color != color;
}
