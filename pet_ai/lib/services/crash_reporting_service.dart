import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pet_satellite/services/pb_service.dart';

/// Отправляет необработанные ошибки и стектрейсы в коллекцию PocketBase.
///
/// Механизм:
///  - перехватывает ошибки фреймворка ([FlutterError.onError]) и
///    необработанные асинхронные ошибки ([PlatformDispatcher.onError]);
///  - при включённой настройке отправляет каждую ошибку fire-and-forget в
///    коллекцию `error_reports`;
///  - никогда не бросает исключения изнутри (защита от рекурсии).
///
/// Требуемая схема коллекции `error_reports` (type: base) на сервере:
///   - `message`      (text)
///   - `stack`        (text, длинный)
///   - `type`         (text)   — 'flutter' | 'async' | 'manual'
///   - `platform`     (text)
///   - `app_version`  (text)
///   - `user_id`      (text)   — id пользователя, если авторизован
///   - `fatal`        (bool)
/// Правило создания (createRule) должно быть пустым `""`, чтобы отчёты можно
/// было отправлять и без авторизации.
class CrashReportingService extends ChangeNotifier {
  static const _enabledKey = 'crash_reporting_enabled';
  static const _collection = 'error_reports';

  /// Максимальная длина стектрейса в символах (защита от гигантских записей).
  static const _maxStackLength = 12000;

  final PocketBaseService _pbService;

  CrashReportingService({required PocketBaseService pbService})
    : _pbService = pbService;

  static CrashReportingService get instance =>
      GetIt.instance<CrashReportingService>();

  PocketBase get _pb => _pbService.pb;

  bool _enabled = true;
  bool get enabled => _enabled;

  bool _installed = false;

  /// Re-entrancy guard: предотвращает отправку ошибок, возникших во время
  /// самой отправки (иначе — бесконечная рекурсия).
  bool _reporting = false;

  String _appVersion = 'unknown';

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  /// Загружает настройку, кэширует версию приложения и устанавливает
  /// глобальные обработчики ошибок. Вызывать один раз из `main()`.
  Future<void> init() async {
    _enabled =
        (await SharedPreferencesAsync().getBool(_enabledKey)) ?? true;

    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      // package_info может быть недоступен — оставляем 'unknown'.
    }

    _install();
  }

  void _install() {
    if (_installed) return;
    _installed = true;

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      // Сохраняем стандартное поведение (красный экран в debug, лог).
      previousFlutterOnError?.call(details);
      reportError(
        details.exception,
        details.stack,
        type: 'flutter',
        fatal: false,
      );
    };

    final previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      reportError(error, stack, type: 'async', fatal: true);
      // Делегируем предыдущему обработчику (если был), иначе считаем
      // ошибку обработанной.
      return previousPlatformOnError?.call(error, stack) ?? true;
    };
  }

  // ── Settings ────────────────────────────────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await SharedPreferencesAsync().setBool(_enabledKey, value);
    notifyListeners();
  }

  // ── Reporting ─────────────────────────────────────────────────────────────────

  /// Отправляет ошибку в PocketBase, если механизм включён.
  /// Fire-and-forget: не бросает исключения и ничего не ждёт от вызывающего.
  void reportError(
    Object error,
    StackTrace? stack, {
    String type = 'manual',
    bool fatal = false,
  }) {
    if (!_enabled || _reporting) return;
    _reporting = true;
    // Fire-and-forget: ошибки внутри _send проглатываются.
    unawaited(_send(error, stack, type, fatal));
  }

  Future<void> _send(
    Object error,
    StackTrace? stack,
    String type,
    bool fatal,
  ) async {
    try {
      final body = <String, dynamic>{
        'message': error.toString(),
        'stack': _truncate(stack?.toString() ?? ''),
        'type': type,
        'platform': _platformLabel(),
        'app_version': _appVersion,
        'user': _pb.authStore.record?.id ?? '',
        'fatal': fatal,
      };
      await _pb.collection(_collection).create(body: body);
    } catch (_) {
      // Намеренно проглатываем — отчёт об ошибке не должен падать сам.
    } finally {
      _reporting = false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  String _truncate(String s) =>
      s.length <= _maxStackLength ? s : s.substring(0, _maxStackLength);

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    try {
      return Platform.operatingSystem; // ios, android, macos, ...
    } catch (_) {
      return 'unknown';
    }
  }
}
