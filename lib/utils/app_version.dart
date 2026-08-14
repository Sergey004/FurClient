import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Resolves the version label shown in the UI.
///
/// Release builds show the stable semantic version from pubspec. Debug
/// builds show the git commit (count + short hash) so developers can tell
/// exactly which commit they are running. Users who want stability run the
/// versioned (release) builds.
class AppVersion {
  static Future<String> resolve() async {
    final info = await PackageInfo.fromPlatform();
    if (!kDebugMode) return info.version;

    final count = await _git(['rev-list', '--count', 'HEAD']);
    final hash = await _git(['rev-parse', '--short', 'HEAD']);
    if (count != null && hash != null) {
      return 'debug #$count ($hash)';
    }
    return '${info.version} (debug)';
  }

  static Future<String?> _git(List<String> args) async {
    try {
      final result = await Process.run(
        'git',
        args,
        runInShell: true,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(const Duration(seconds: 5));
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {
      // git unavailable (e.g. release build without a .git checkout).
    }
    return null;
  }
}
