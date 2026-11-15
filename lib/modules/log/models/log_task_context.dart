import 'package:oasx/translation/i18n.dart';

String _fold(String value) =>
    value.replaceAll(RegExp(r'[\s_]'), '').toUpperCase();

/// Canonical names keep upper-case logger headings translatable in the UI.
final _taskNames = <String, String>{
  for (final key in Messages().all_cn_translate.keys) _fold(key): key,
};

/// Newer backends render level-0 headings as `中文名(foldedclass)`, e.g.
/// `探索(exploration)` or `每周购买(weeklypurchase)`. The part inside the
/// parentheses is the class name folded to lower case without separators, so
/// it must be mapped back to `Exploration` / `WeeklyPurchase` before the UI can
/// pair a Chinese name with a class name.
final _headingShape = RegExp(r'^(.+?)\(([A-Za-z][A-Za-z0-9_.]*)\)$');

String _canonicalTask(String value) {
  final raw = value.trim();
  final probe = _headingShape.firstMatch(raw)?.group(2) ?? raw;
  // Unknown tasks keep the folded identifier: `TaskNameService` indexes the
  // names OAS ships by the same folded form, so the pair still resolves.
  return _taskNames[_fold(probe)] ?? probe;
}

/// Tracks only level-0 task headings, not battle/page subheadings.
/// save_error_log keeps the final separator plus the preceding two lines,
/// so these headings survive even when scheduler/[Task] messages are omitted.
class LogTaskContext {
  String? task;
  String? fallbackTask;
  bool _separator = false;
  String? _heading;

  void consume(String line) {
    final explicit = RegExp(
      r'\[Task\]\s+(\w+)\s+\(|Scheduler: Start task `([^`]+)`',
    ).firstMatch(line);
    if (explicit != null) {
      task = _canonicalTask(explicit.group(1) ?? explicit.group(2)!);
    }
    final trimmed = line.trim();
    if (RegExp(r'^═{15,}$').hasMatch(trimmed)) {
      if (_heading != null) {
        task = _heading!.toUpperCase() == 'START'
            ? null
            : _canonicalTask(_heading!);
      }
      _heading = null;
      _separator = true;
      return;
    }
    final title = RegExp(r'^─{10,}\s*(.*?)\s*─{10,}$').firstMatch(trimmed);
    _heading = _separator ? title?.group(1)?.trim() : null;
    _separator = false;
    // Tracebacks and module_path survive in some older saved error formats.
    if (line.contains('module_path:') || line.trimLeft().startsWith('File ')) {
      final path = RegExp(
        r'tasks[/\\]([^/\\]+)[/\\]script_task\.py',
      ).firstMatch(line);
      if (path != null) fallbackTask = _canonicalTask(path.group(1)!);
    }
  }
}
