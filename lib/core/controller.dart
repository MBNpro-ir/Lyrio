import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'models.dart';

class LyrioController extends ChangeNotifier with WidgetsBindingObserver {
  static const channel = MethodChannel('com.mbn.lyrio/native');
  AppSnapshot snapshot = AppSnapshot({});
  Json settings = {...defaultSettings};
  String? error;
  bool loading = true, _reading = false, _disposed = false;
  final bool started;
  bool stateLoaded = false;
  bool _pending = false;
  Timer? _timer, _saveTimer;
  Future<void> _writes = Future.value();

  LyrioController({bool start = true}) : started = start {
    if (start) {
      WidgetsBinding.instance.addObserver(this);
      refresh();
      _startTimer();
    }
  }
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(milliseconds: 180),
      (_) => refresh(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
      _startTimer();
    } else {
      _timer?.cancel();
    }
  }

  Future<void> refresh() async {
    if (_reading || _disposed) return;
    _reading = true;
    try {
      final raw = await channel.invokeMethod<String>('state');
      if (raw != null && !_disposed) {
        snapshot = AppSnapshot(jsonDecode(raw) as Json);
        stateLoaded = true;
        if (!_pending) settings = snapshot.settings;
        if (snapshot.serviceError.isNotEmpty) error = snapshot.serviceError;
      }
    } on PlatformException catch (e) {
      error = e.message;
    } on MissingPluginException {
      error = 'Lyrio needs its Android companion. Run the Android build.';
    } finally {
      _reading = false;
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<bool> action(String name, [dynamic args]) async {
    try {
      await channel.invokeMethod<dynamic>(name, args);
      error = null;
      await refresh();
      return true;
    } on PlatformException catch (e) {
      error = e.message ?? 'Android could not complete the action.';
    } on MissingPluginException {
      error = 'This action is available on Android.';
    }
    if (!_disposed) notifyListeners();
    return false;
  }

  void set(String name, dynamic value) {
    settings = {...settings, name: value};
    _pending = true;
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 180), flushSettings);
  }

  Future<void> flushSettings() async {
    _saveTimer?.cancel();
    final payload = jsonEncode(settings);
    _writes = _writes.then((_) async {
      await action('saveSettings', payload);
      if (jsonEncode(settings) == payload) _pending = false;
    });
    await _writes;
  }

  double number(String key) => (settings[key] as num).toDouble();
  bool flag(String key) => settings[key] == true;
  String choice(String key) => settings[key] as String;
  List<Json> get providers =>
      (settings['providers'] as List).map((e) => Json.from(e as Map)).toList();
  void dismissError() {
    error = null;
    unawaited(action('clearError'));
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _saveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
