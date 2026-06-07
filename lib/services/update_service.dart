import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Update service for **Windows** (Velopack).
///
/// Android updates are handled by the `upgrader` package directly
/// in [main.dart] via [UpgradeAlert].
///
/// Windows flow:
/// 1. Check GitHub Releases API for the latest `v*` tag
/// 2. Compare with the installed version from [PackageInfo]
/// 3. If newer → download the Velopack `.nupkg` + `RELEASES` manifest
/// 4. Invoke the bundled `Update.exe --install --silent`
///
/// Portable installs (no Update.exe) fall back to a `.bat` script that
/// replaces files and restarts the app.
class UpdateService extends ChangeNotifier {
  UpdateStatus _status = UpdateStatus.idle;
  String? _errorMessage;
  double _downloadProgress = 0;
  String? _latestVersion;
  String? _currentVersion;

  UpdateStatus get status => _status;
  String? get errorMessage => _errorMessage;
  double get downloadProgress => _downloadProgress;
  String? get latestVersion => _latestVersion;
  String? get currentVersion => _currentVersion;

  /// GitHub repo in `owner/repo` format. Change to match your repo.
  static const String _repo = 'Sergey004/furclient';

  /// Initialise — loads current version, runs a silent background check.
  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _currentVersion = info.version;
    notifyListeners();
    silentCheck();
  }

  /// Silent background check — does not show UI errors.
  Future<void> silentCheck() async {
    try {
      await _checkGitHub();
    } catch (e) {
      debugPrint('=== UpdateService: silent check failed: $e');
    }
  }

  /// Public check — user tapped "Check for updates".
  Future<void> checkForUpdate() async {
    _status = UpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();
    try {
      await _checkGitHub();
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Download and install the update.
  Future<void> downloadAndInstall() async {
    _status = UpdateStatus.downloading;
    _downloadProgress = 0;
    _errorMessage = null;
    notifyListeners();

    try {
      // Try Velopack Update.exe first
      final exePath = _findUpdateExe();
      if (exePath != null) {
        _status = UpdateStatus.installing;
        notifyListeners();

        await Process.start(
          exePath,
          ['--install', '--silent'],
          mode: ProcessStartMode.detached,
        );
        _status = UpdateStatus.installing;
        notifyListeners();
        exit(0);
      } else {
        // No Update.exe — portable install, manual download
        await _downloadAndInstallManual();
      }
    } catch (e) {
      _status = UpdateStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ── Internal ──────────────────────────────────────────────────────────

  Future<void> _checkGitHub() async {
    final uri =
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest');

    final response =
        await http.get(uri, headers: {'Accept': 'application/vnd.github+json'});

    if (response.statusCode != 200) {
      throw Exception('GitHub API returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = data['tag_name'] as String? ?? '';
    _latestVersion = tagName.replaceFirst('v', '');

    if (_currentVersion == null) return;

    if (_isNewer(_latestVersion!, _currentVersion!)) {
      _status = UpdateStatus.available;
    } else {
      _status = UpdateStatus.upToDate;
    }
    notifyListeners();
  }

  /// Manual download + `.bat` installer for portable installs.
  Future<void> _downloadAndInstallManual() async {
    // Find the zip asset from the latest release
    final uri =
        Uri.parse('https://api.github.com/repos/$_repo/releases/latest');

    final response =
        await http.get(uri, headers: {'Accept': 'application/vnd.github+json'});

    if (response.statusCode != 200) {
      throw Exception('GitHub API returned ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final assets = (data['assets'] as List?) ?? [];

    String? downloadUrl;
    String? fileName;

    for (final asset in assets) {
      final name = (asset['name'] as String?) ?? '';
      if (name.endsWith('.zip') && name.contains('windows')) {
        downloadUrl = asset['browser_download_url'] as String?;
        fileName = name;
        break;
      }
    }

    // Fallback to any zip
    downloadUrl ??= assets.isNotEmpty
        ? assets.first['browser_download_url'] as String?
        : null;
    fileName ??= 'furclient.zip';

    if (downloadUrl == null) {
      throw Exception('No downloadable assets found in the latest release');
    }

    // Download with progress
    final dir = Directory.systemTemp.createTempSync('furclient_update_');
    final zipPath = '${dir.path}$fileName';

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(downloadUrl));
    final resp = await request.close();
    final file = File(zipPath);
    final sink = file.openWrite();

    int downloaded = 0;
    final total = resp.contentLength;

    await for (final chunk in resp) {
      downloaded += chunk.length;
      if (total > 0) {
        _downloadProgress = downloaded / total;
        notifyListeners();
      }
      sink.add(chunk);
    }
    await sink.close();
    client.close();

    _status = UpdateStatus.installing;
    notifyListeners();

    // Write and execute a .bat that extracts the zip and restarts
    final exePath = Platform.resolvedExecutable;
    final batPath = '${dir.path}update.bat';
    final bat = File(batPath);
    await bat.writeAsString('''
@echo off
timeout /t 2 /nobreak >nul
powershell -Command "Expand-Archive -Path '$zipPath' -DestinationPath '${exePath.replaceAll(RegExp(r'[^/\\\\]+\$'), '')}' -Force"
del /f /q "$zipPath"
start "" "$exePath"
del /f /q "%~f0"
''');

    await Process.start(
      batPath,
      [],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }

  /// Look for Velopack's `Update.exe` next to the running executable.
  String? _findUpdateExe() {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final candidates = [
      '$exeDir\\Update.exe',
      '$exeDir\\Update.com',
      '${exeDir}Update.exe',
    ];
    for (final p in candidates) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }

  /// Simple semver comparison. Returns [true] if [latest] is newer than
  /// [current].
  bool _isNewer(String latest, String current) {
    try {
      final lParts = latest.split('.').map(int.parse).toList();
      final cParts = current.split('.').map(int.parse).toList();

      for (var i = 0; i < 3; i++) {
        final l = i < lParts.length ? lParts[i] : 0;
        final c = i < cParts.length ? cParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

/// States the update service can be in.
enum UpdateStatus {
  idle,
  checking,
  available,
  downloading,
  installing,
  upToDate,
  error,
}
