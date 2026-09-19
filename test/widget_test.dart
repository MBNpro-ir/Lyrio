import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyrio/main.dart';
import 'package:lyrio/core/controller.dart';
import 'package:lyrio/core/models.dart';
import 'package:lyrio/ui/lyrics_view.dart';
import 'package:lyrio/overlay/overlay_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final sample = <String, dynamic>{
    'track': {
      'title': 'Your next favorite song',
      'artist': 'An original Lyrio preview',
      'source': 'Music player',
      'duration': 180000,
      'position': 42000,
      'timingAvailable': true,
      'playing': true,
    },
    'lyrics': {
      'status': 'ready',
      'source': 'Preview',
      'synced':
          '[00:00]A quiet space for every word\n[00:40]هر واژه، همراه موسیقی\n[00:48]Let the next line find you',
    },
    'settings': defaultSettings,
    'permissions': {
      'listener': true,
      'overlay': true,
      'notifications': true,
      'battery': false,
    },
  };
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LyrioController.channel, (call) async {
          if (call.method == 'state') return jsonEncode(sample);
          return null;
        });
  });
  testWidgets('Home has real idle state and swipe navigates to Settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = LyrioController(start: false);
    await tester.pumpWidget(LyrioApp(controller: c));
    expect(find.text('Press play\nanywhere.'), findsOneWidget);
    expect(find.text('Midnight City'), findsNothing);
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(find.text('Make it yours.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets('Plain lyrics stay complete and can scroll to the last line', (
    tester,
  ) async {
    final data = AppSnapshot({
      'lyrics': {
        'status': 'ready',
        'plain': List.generate(40, (i) => 'Complete line $i').join('\n'),
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 200,
          child: LyricsView(data: data, settings: defaultSettings),
        ),
      ),
    );
    expect(find.text('Complete line 39'), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -4000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Visual QA: light, dark, narrow and larger text', (tester) async {
    final font = FontLoader('Vazirmatn')
      ..addFont(rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'));
    await font.load();
    await (FontLoader(
      'Manrope',
    )..addFont(rootBundle.load('assets/fonts/Manrope.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = LyrioController(start: false);
    c.snapshot = AppSnapshot(sample);
    c.loading = false;
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: LyrioApp(controller: c),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await render.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('artifacts/screenshots').create(recursive: true);
        await File(
          'artifacts/screenshots/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('home-light');
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await capture('settings-light');
    c.set('theme', 'dark');
    await tester.pumpAndSettle();
    await capture('settings-dark');
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'Floating renderer fits a small window and collapses without navigation',
    (tester) async {
      tester.view.physicalSize = const Size(340, 310);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = LyrioController(start: false);
      c.snapshot = AppSnapshot(sample);
      await tester.pumpWidget(OverlayApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsNothing);
      expect(find.byTooltip('Close floating lyrics'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Collapse'));
      tester.view.physicalSize = const Size(340, 76);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Expand'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
