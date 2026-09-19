import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'core/controller.dart';
import 'core/models.dart';
import 'ui/home_page.dart';
import 'ui/settings_page.dart';
import 'ui/welcome_page.dart';
import 'overlay/overlay_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Vazirmatn',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield LicenseEntryWithLineBreaks([
      'Manrope',
    ], await rootBundle.loadString('assets/fonts/Manrope-OFL.txt'));
  });
  runApp(LyrioApp(controller: LyrioController()));
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(OverlayApp(controller: LyrioController()));
}

class LyrioApp extends StatelessWidget {
  final LyrioController controller;
  const LyrioApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final seed = Color(
        controller.flag('dynamicColor')
            ? controller.snapshot.accent
            : (controller.settings['accent'] as num).toInt(),
      );
      return MaterialApp(
        title: 'Lyrio',
        debugShowCheckedModeBanner: false,
        theme: lyrioTheme(seed, Brightness.light),
        darkTheme: lyrioTheme(seed, Brightness.dark),
        themeMode: switch (controller.choice('theme')) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        home:
            controller.started &&
                (!controller.stateLoaded ||
                    !controller.snapshot.requiredPermissionsGranted)
            ? WelcomePage(controller: controller)
            : LyrioShell(controller: controller),
      );
    },
  );
}

class LyrioShell extends StatefulWidget {
  final LyrioController controller;
  const LyrioShell({super.key, required this.controller});
  @override
  State<LyrioShell> createState() => _LyrioShellState();
}

class _LyrioShellState extends State<LyrioShell> {
  final _pages = PageController();
  var _index = 0;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          if (widget.controller.error != null)
            SafeArea(
              bottom: false,
              child: MaterialBanner(
                content: Text(widget.controller.error!),
                actions: [
                  TextButton(
                    onPressed: widget.controller.dismissError,
                    child: const Text('Dismiss'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (value) => setState(() => _index = value),
              children: [
                HomePage(controller: widget.controller),
                SettingsPage(controller: widget.controller),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final (i, label, icon) in [
                (0, 'Home', Icons.home_rounded),
                (1, 'Settings', Icons.tune_rounded),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Semantics(
                    selected: i == _index,
                    button: true,
                    label: label,
                    child: InkResponse(
                      radius: 40,
                      onTap: () => _pages.animateToPage(
                        i,
                        duration: Duration(
                          milliseconds: MediaQuery.disableAnimationsOf(context)
                              ? 0
                              : 400,
                        ),
                        curve: Curves.easeOutCubic,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _index
                                  ? colors.primaryContainer
                                  : colors.surfaceContainer,
                            ),
                            child: Icon(
                              icon,
                              color: i == _index
                                  ? colors.onPrimaryContainer
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == _index
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
