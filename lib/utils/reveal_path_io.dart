import 'dart:io';

/// Reveals [path] in the platform file manager.
///
/// Returns `false` when the directory is missing or the shell cannot be
/// launched, so callers can fall back to a hint message.
Future<bool> revealPathInFileManager(String path) async {
  final target = path.trim();
  if (target.isEmpty) {
    return false;
  }
  try {
    if (!await Directory(target).exists()) {
      return false;
    }
    if (Platform.isWindows) {
      await Process.run('explorer', <String>[target]);
      return true;
    }
    if (Platform.isMacOS) {
      await Process.run('open', <String>[target]);
      return true;
    }
    if (Platform.isLinux) {
      await Process.run('xdg-open', <String>[target]);
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}
