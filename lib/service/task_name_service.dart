import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:oasx/api/api_client.dart';
import 'package:oasx/modules/common/models/storage_key.dart';
import 'package:oasx/translation/i18n.dart';

/// Task names come from OAS, not from OASX's own translation tables.
///
/// Task names change where the tasks live (OAS `assets/i18n/zh-CN.json`), and
/// copying them into OASX lags behind by at least one release — that is why
/// `WeeklyPurchase` stayed untranslated on the error page until 2026-11-03.
///
/// Data path: `GET /home/additional_translate` → `I18n.load_additions()` →
/// `assets/i18n/zh-CN.json`. The response is one flat dictionary mixing task
/// names with option labels, so only class-name-shaped keys are kept.
class TaskNameService extends GetxService {
  TaskNameService({ApiClient? apiClient, GetStorage? storage})
    : _api = apiClient ?? ApiClient(),
      _storage = storage ?? GetStorage();

  final ApiClient _api;
  final GetStorage _storage;

  /// Class name → Chinese name, restricted to class-name-shaped keys.
  final Map<String, String> _names = <String, String>{};

  /// Folded form → class name, so `weekly_purchase` also resolves.
  final Map<String, String> _index = <String, String>{};

  /// Reason of the last failed refresh; null after a successful one.
  String? lastError;

  /// Whether any task name has been received from OAS.
  bool get hasRemoteNames => _names.isNotEmpty;

  /// Reads the registered service, falling back to a detached instance so
  /// widget rendering never throws when the service was not registered yet.
  static TaskNameService get to {
    if (Get.isRegistered<TaskNameService>()) {
      return Get.find<TaskNameService>();
    }
    return _detached ??= TaskNameService();
  }

  static TaskNameService? _detached;

  static final RegExp _classNameShape = RegExp(r'^[A-Z][A-Za-z0-9]*$');
  static final RegExp _codeShape = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

  static String _fold(String value) =>
      value.replaceAll(RegExp(r'[\s_]'), '').toUpperCase();

  /// OASX's offline fallback (`_cn_menu`), folded for lookup.
  ///
  /// Offline use only: new task names must not be added here.
  static final Map<String, String> _fallbackByFold = {
    for (final key in Messages().all_cn_translate.keys) _fold(key): key,
  };

  @override
  void onInit() {
    super.onInit();
    _restore();
    _debug('restored ${_names.length} task names from cache');
  }

  /// Fetches task names from OAS. Never throws; failures land in [lastError].
  Future<void> refresh() async {
    try {
      final translations = await _api.getAdditionalTranslate();
      final zh = translations['zh_CN'] ?? const <String, String>{};
      if (zh.isEmpty) {
        lastError = 'OAS returned no zh-CN dictionary';
        _debug('refresh failed: $lastError');
        return;
      }
      final parsed = <String, String>{};
      for (final entry in zh.entries) {
        if (!_classNameShape.hasMatch(entry.key)) continue;
        final text = entry.value.trim();
        if (text.isEmpty) continue;
        parsed[entry.key] = text;
      }
      if (parsed.isEmpty) {
        lastError = 'no class-name-shaped key among ${zh.length} entries';
        _debug('refresh failed: $lastError');
        return;
      }
      _names
        ..clear()
        ..addAll(parsed);
      _rebuildIndex();
      lastError = null;
      _storage.write(StorageKey.taskNames.name, parsed);
      _debug('refresh ok: ${zh.length} entries → ${parsed.length} task names');
    } catch (error) {
      lastError = '$error';
      _debug('refresh threw: $error');
    }
  }

  /// Chinese name to display: OAS payload → OASX fallback → raw value.
  String display(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return value;
    final canonical = _resolve(value);
    if (canonical != null) {
      final text = _names[canonical];
      if (text != null && text.isNotEmpty) return text;
    }
    final fallbackKey = _fallbackByFold[_fold(value)];
    if (fallbackKey != null) {
      final text = Messages().all_cn_translate[fallbackKey];
      if (text != null && text.isNotEmpty) return text;
    }
    return value;
  }

  /// Class name to show next to the Chinese name, or null when there is
  /// nothing to add: non class-name values (the `未知任务` sentinel), empty
  /// values, and names identical to their class name (English locale or a
  /// missing key) all return null so the UI never renders `X / X`.
  String? code(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty || !_codeShape.hasMatch(value)) return null;
    final canonical = _resolve(value) ?? value;
    return display(value) == canonical ? null : canonical;
  }

  /// Markdown label: `ClassName（中文名）`, or the raw value when unpaired.
  String markdownLabel(String? raw) {
    final value = (raw ?? '').trim();
    final canonical = code(value);
    if (canonical == null) return value;
    return '$canonical（${display(value)}）';
  }

  String? _resolve(String value) {
    if (_names.containsKey(value)) return value;
    return _index[_fold(value)];
  }

  void _rebuildIndex() {
    _index
      ..clear()
      ..addEntries(_names.keys.map((key) => MapEntry(_fold(key), key)));
  }

  void _restore() {
    final cached = _storage.read<Map>(StorageKey.taskNames.name);
    if (cached == null || cached.isEmpty) return;
    _names
      ..clear()
      ..addAll(cached.map((key, value) => MapEntry('$key', '$value')));
    _rebuildIndex();
  }

  void _debug(String message) {
    if (!kDebugMode) return;
    debugPrint('[TaskNameService] $message');
  }
}
