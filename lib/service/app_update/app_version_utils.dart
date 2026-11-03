import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Contains shared app-version helpers for update checks.
class AppVersionUtils {
  /// Returns true when [latest] is newer than [current].
  static bool compareVersion(String current, String latest) {
    final currentParts = _normalizeVersion(current);
    final latestParts = _normalizeVersion(latest);
    final maxLength = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;
    for (var index = 0; index < maxLength; index++) {
      final currentValue = index < currentParts.length
          ? currentParts[index]
          : 0;
      final latestValue = index < latestParts.length ? latestParts[index] : 0;
      if (latestValue > currentValue) {
        return true;
      }
      if (latestValue < currentValue) {
        return false;
      }
    }
    return false;
  }

  /// Returns the normalized application version string.
  static Future<String> getCurrentVersion() async {
    if (!kReleaseMode) {
      return 'v0.0.1';
    }
    final packageInfo = await PackageInfo.fromPlatform();
    return 'v${packageInfo.version}'.split('-')[0];
  }

  /// Normalizes a semantic version string into integer parts.
  ///
  /// Windows VERSIONINFO reports the pubspec version verbatim (`1.0.1+3`), so
  /// the build suffix has to be dropped before splitting; otherwise `1+3`
  /// fails to parse and the patch segment collapses to 0. Release tags may
  /// additionally carry a fourth revision segment (`v1.0.1.1`) while pubspec
  /// versions stop at `major.minor.patch`, so only the first three segments
  /// take part in the comparison. Without that, a local `v1.0.1` build would
  /// keep "finding" its own `v1.0.1.1` tag forever.
  static List<int> _normalizeVersion(String version) {
    final normalized = version.trim().replaceFirst(RegExp('^v'), '');
    final core = normalized.split('+').first;
    final parts = core
        .split(RegExp(r'[.\-]'))
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
    return parts.length > 3 ? parts.sublist(0, 3) : parts;
  }
}
