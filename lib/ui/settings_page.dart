import 'package:flutter/material.dart';
import '../core/controller.dart';
import '../core/models.dart';
import 'home_page.dart';
import 'lyrics_view.dart';
import 'provider_editor.dart';

class SettingsPage extends StatelessWidget {
  final LyrioController controller;
  const SettingsPage({super.key, required this.controller});
  @override
  Widget build(BuildContext context) {
    final c = controller;
    final colors = Theme.of(context).colorScheme;
    final previewTheme = lyrioTheme(
      colors.primary,
      c.choice('preset') == 'midnight'
          ? Brightness.dark
          : c.choice('preset') == 'paper'
          ? Brightness.light
          : Theme.of(context).brightness,
    );
    final preview = AppSnapshot({
      'track': {
        'title': 'Appearance preview',
        'timingAvailable': true,
        'position': 4000,
      },
      'lyrics': {
        'status': 'ready',
        'synced':
            '[00:00.00]A quiet space for every word\n[00:04.00]هر واژه، همراه موسیقی\n[00:08.00]Let the next line find you',
        'source': 'Original preview',
      },
    });
    return SafeArea(
      bottom: false,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Make it yours.',
                    style: TextStyle(
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A small window. A world of possibilities.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedPreviewDelegate(
              extent: 306,
              child: _PinnedPreview(
                controller: c,
                previewTheme: previewTheme,
                preview: preview,
              ),
            ),
          ),
        ],
        body: ListView(
          key: const PageStorageKey('settings'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 30),
          children: [
            Section(
              title: 'App appearance',
              children: [
                _choices(c, 'Theme', 'theme', {
                  'system': 'System',
                  'light': 'Light',
                  'dark': 'Dark',
                }),
                _toggle(
                  c,
                  'dynamicColor',
                  'Device colors',
                  'Use your Android wallpaper palette',
                  Icons.palette_outlined,
                ),
                if (!c.flag('dynamicColor'))
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 14,
                      children: [
                        for (final color in [
                          0xff8065ff,
                          0xff006b5b,
                          0xff9b4059,
                          0xff8b5900,
                          0xff0064a4,
                        ])
                          Semantics(
                            button: true,
                            label: 'Accent ${color.toRadixString(16)}',
                            child: InkWell(
                              onTap: () => c.set('accent', color),
                              borderRadius: BorderRadius.circular(30),
                              child: CircleAvatar(
                                backgroundColor: Color(color),
                                radius: 22,
                                child: c.settings['accent'] == color
                                    ? const Icon(
                                        Icons.check_rounded,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            Section(
              title: 'Floating window',
              children: [
                _slider(c, 'width', 'Width', 200, 800, 'dp', divisions: 60),
                _slider(c, 'height', 'Height', 140, 900, 'dp', divisions: 76),
                _slider(
                  c,
                  'radius',
                  'Corner radius',
                  0,
                  100,
                  'dp',
                  divisions: 100,
                ),
                _slider(
                  c,
                  'opacity',
                  'Background opacity',
                  0,
                  1,
                  '%',
                  multiplier: 100,
                  divisions: 100,
                ),
                _toggle(
                  c,
                  'blurBehind',
                  'Blur behind window',
                  'Frosted glass only behind this window · Android 12+',
                  Icons.blur_on_rounded,
                ),
                if (c.flag('blurBehind'))
                  _slider(
                    c,
                    'blurRadius',
                    'Blur strength',
                    0,
                    100,
                    'px',
                    divisions: 50,
                  ),
                _toggle(
                  c,
                  'showHeader',
                  'Track title',
                  'Show the title in the window handle',
                  Icons.title_rounded,
                ),
                _toggle(
                  c,
                  'locked',
                  'Position lock',
                  'Prevent moving the floating window',
                  Icons.lock_outline_rounded,
                ),
                _toggle(
                  c,
                  'hidePaused',
                  'Hide words while paused',
                  'Keep the handle available',
                  Icons.pause_circle_outline_rounded,
                ),
                _toggle(
                  c,
                  'keepScreenOn',
                  'Keep screen awake',
                  'While the floating window is enabled',
                  Icons.light_mode_outlined,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Text(
                    'Drag the handle to move. Collapse to keep a small bar. Your position is remembered and kept on screen.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
            Section(
              title: 'Reading & motion',
              children: [
                _choices(c, 'Synced reading', 'mode', {
                  'focus': 'Focus',
                  'full': 'All lines',
                }),
                _slider(
                  c,
                  'visibleLines',
                  'Focus lines',
                  1,
                  9,
                  '',
                  divisions: 8,
                ),
                _slider(
                  c,
                  'fontSize',
                  'Text size',
                  10,
                  100,
                  'sp',
                  divisions: 90,
                ),
                _slider(
                  c,
                  'lineHeight',
                  'Line spacing',
                  1,
                  3,
                  '×',
                  decimals: 2,
                  divisions: 40,
                ),
                _choices(c, 'Alignment', 'alignment', {
                  'auto': 'Auto',
                  'left': 'Left',
                  'center': 'Center',
                  'right': 'Right',
                }),
                _choices(c, 'Line transition', 'animation', {
                  'slide': 'Slide',
                  'fade': 'Fade',
                  'none': 'None',
                }),
                _slider(
                  c,
                  'duration',
                  'Transition duration',
                  0,
                  2000,
                  'ms',
                  divisions: 100,
                ),
                _slider(
                  c,
                  'offsetMs',
                  'Sync adjustment',
                  -10000,
                  10000,
                  'ms',
                  divisions: 200,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'Positive values show the next line earlier. System reduced motion is respected. Unsynced lyrics always show the complete scrollable text.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
                _toggle(
                  c,
                  'glow',
                  'Active line glow',
                  'A gentle accent around the words',
                  Icons.auto_awesome_outlined,
                ),
                _toggle(
                  c,
                  'karaoke',
                  'Word-by-word highlight',
                  'Light up each word as it is sung',
                  Icons.mic_external_on_outlined,
                ),
                const ListTile(
                  leading: Icon(Icons.translate_rounded),
                  title: Text('Persian, beautifully readable'),
                  subtitle: Text(
                    'Bundled Vazirmatn • automatic right-to-left lines',
                  ),
                ),
              ],
            ),
            Section(
              title: 'Lyrics sources',
              children: [
                _provider(
                  c,
                  'auto',
                  'Automatic',
                  'Prefer synced lyrics, then a full-text fallback',
                ),
                _provider(
                  c,
                  'lrclib',
                  'LRCLIB',
                  'Free · synced + plain · no key',
                ),
                _link(c, 'LRCLIB documentation', 'https://lrclib.net/docs'),
                _provider(
                  c,
                  'ovh',
                  'Lyrics.ovh',
                  'Free · plain lyrics · no key',
                ),
                _link(
                  c,
                  'Lyrics.ovh API documentation',
                  'https://lyricsovh.docs.apiary.io/',
                ),
                _provider(
                  c,
                  'musixmatch',
                  'Musixmatch',
                  c.snapshot.keys.contains('musixmatch')
                      ? 'Key saved · coverage depends on your plan'
                      : 'Personal API key required · plan limits apply',
                ),
                ListTile(
                  leading: const Icon(Icons.key_rounded),
                  title: Text(
                    c.snapshot.keys.contains('musixmatch')
                        ? 'Replace or remove Musixmatch key'
                        : 'Add Musixmatch key',
                  ),
                  onTap: () => showKeyEditor(context, c, 'musixmatch'),
                ),
                _link(
                  c,
                  'Get a Musixmatch developer key',
                  'https://developer.musixmatch.com/',
                ),
                for (final provider in c.providers) ...[
                  _provider(
                    c,
                    provider['id'] as String,
                    provider['name'] as String,
                    Uri.tryParse(provider['url'] as String)?.host ??
                        'Custom HTTPS API',
                  ),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.edit_outlined, size: 19),
                    title: Text('Edit ${provider['name']}'),
                    onTap: () =>
                        showProviderEditor(context, c, existing: provider),
                  ),
                ],
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: const Text('Add your own API'),
                  subtitle: const Text(
                    'HTTPS endpoint, JSON fields and optional key',
                  ),
                  onTap: () => showProviderEditor(context, c),
                ),
                _toggle(
                  c,
                  'fallback',
                  'Try other sources',
                  'If your chosen source has no result',
                  Icons.alt_route_rounded,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Text(
                    'Only song title, artist, album and duration go to the selected sources. API keys are encrypted on this device. Catalog coverage and free plans vary; synced lyrics are not guaranteed.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
            Section(
              title: 'Android access',
              children: [
                AccessPanel(controller: c),
                ListTile(
                  leading: const Icon(Icons.settings_applications_outlined),
                  title: const Text('App & vendor settings'),
                  subtitle: const Text(
                    'Autostart / unrestricted battery on some phones',
                  ),
                  onTap: () => c.action('permission', 'app'),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Text(
                    'Removing Lyrio from Recents leaves the foreground window running. Android Force stop and vendor process killers can stop it. Reopen Lyrio and enable the window again after a force stop or reboot.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
            Section(
              title: 'Storage & about',
              children: [
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: const Text('Clear lyrics cache'),
                  subtitle: const Text(
                    'Up to 50 public-source results, for 7 days',
                  ),
                  onTap: () async {
                    await c.action('clearCache');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Lyrics cache cleared')),
                      );
                    }
                  },
                ),
                _link(
                  c,
                  'Source code & feedback',
                  'https://github.com/MBNpro-ir/Lyrio',
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy'),
                  subtitle: const Text(
                    'No ads, analytics or microphone access',
                  ),
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (context) => const AlertDialog(
                      title: Text('Your listening stays yours'),
                      content: SingleChildScrollView(
                        child: Text(
                          'Lyrio reads Android media-session metadata and media notifications. It ignores ordinary notifications.\n\nTrack title, artist, album and duration are sent only to enabled lyrics providers. Providers receive your network address and apply their own policies.\n\nKeys use Android Keystore encryption. Settings and a bounded cache stay on this device; backups are disabled. No listening history or analytics are collected.\n\nVazirmatn is bundled under the SIL Open Font License.',
                        ),
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Lyrio 0.1.0'),
                  subtitle: const Text('com.mbn.lyrio · Android ARM64'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Lyrio',
                    applicationVersion: '0.1.0',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _toggle(
    LyrioController c,
    String key,
    String title,
    String subtitle,
    IconData icon,
  ) => SwitchListTile(
    secondary: Icon(icon),
    title: Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    value: c.flag(key),
    onChanged: (v) => c.set(key, v),
  );
  Widget _slider(
    LyrioController c,
    String key,
    String title,
    double min,
    double max,
    String unit, {
    int multiplier = 1,
    int decimals = 0,
    int? divisions,
  }) {
    final value = c.number(key).clamp(min, max);
    final label = '${(value * multiplier).toStringAsFixed(decimals)}$unit';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(label, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            label: label,
            divisions: divisions ?? 40,
            onChanged: (v) => c.set(key, v),
          ),
        ],
      ),
    );
  }

  Widget _choices(
    LyrioController c,
    String title,
    String key,
    Map<String, String> options,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.entries
              .map(
                (e) => ChoiceChip(
                  label: Text(e.value, style: const TextStyle(fontSize: 12)),
                  selected: c.choice(key) == e.key,
                  onSelected: (_) => c.set(key, e.key),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
  Widget _provider(LyrioController c, String id, String name, String detail) =>
      ListTile(
        leading: Icon(
          c.choice('provider') == id
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_off_rounded,
        ),
        title: Text(
          name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(detail, style: const TextStyle(fontSize: 12)),
        onTap: () => c.set('provider', id),
      );
  Widget _link(LyrioController c, String label, String url) => ListTile(
    dense: true,
    leading: const Icon(Icons.open_in_new_rounded, size: 18),
    title: Text(label, style: const TextStyle(fontSize: 12)),
    onTap: () => c.action('openUrl', url),
  );
}

class _PinnedPreviewDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;
  _PinnedPreviewDelegate({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _PinnedPreviewDelegate oldDelegate) => true;
}

class _PinnedPreview extends StatelessWidget {
  final LyrioController controller;
  final ThemeData previewTheme;
  final AppSnapshot preview;
  const _PinnedPreview({
    required this.controller,
    required this.previewTheme,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 3,
      shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: .18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
        child: Column(
          children: [
            Theme(
              data: previewTheme,
              child: Container(
                height: 220,
                clipBehavior: Clip.antiAlias,
                decoration: windowDecoration(
                  previewTheme.colorScheme,
                  c.settings,
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 13),
                      child: Text(
                        'APPEARANCE PREVIEW',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LyricsView(
                        data: preview,
                        settings: c.settings,
                        preview: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final preset in [
                      'aurora',
                      'sunset',
                      'ocean',
                      'paper',
                      'midnight',
                      'minimal',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_presetTitle(preset)),
                          selected: c.choice('preset') == preset,
                          onSelected: (_) => applyPreset(c, preset),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _presetTitle(String value) =>
      value[0].toUpperCase() + value.substring(1);
}

/// Applies a curated look: each preset owns its gradient, corner radius,
/// opacity, glow and reading mode. Midnight is always dark, paper always
/// light; the rest follow the app theme.
void applyPreset(LyrioController c, String preset) {
  c.set('preset', preset);
  c.set(
    'radius',
    switch (preset) {
      'minimal' => 16.0,
      'ocean' => 32.0,
      'sunset' => 24.0,
      _ => 28.0,
    },
  );
  c.set(
    'opacity',
    switch (preset) {
      'paper' => 1.0,
      'ocean' => .92,
      'sunset' => .96,
      _ => .94,
    },
  );
  c.set('glow', preset == 'aurora' || preset == 'sunset' || preset == 'ocean');
  c.set('mode', preset == 'paper' ? 'full' : 'focus');
}

class Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const Section({super.key, required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    ),
  );
}
