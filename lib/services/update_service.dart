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
  String? _selectedVersion;
  List<String> _availableVersions = [];

  UpdateStatus get status => _status;
  String? get errorMessage => _errorMessage;
  double get downloadProgress => _downloadProgress;
  String? get latestVersion => _latestVersion;
  String? get currentVersion => _currentVersion;
  String? get selectedVersion => _selectedVersion;
  List<String> get availableVersions => List.unmodifiable(_availableVersions);

  void selectVersion(String version) {
    _selectedVersion = version;
    notifyListeners();
  }

  /// GitHub repo in `owner/repo` format.
  static const String _repo = 'Sergey004/FurClient';

  /// GitHub API headers — User-Agent is required by GitHub or you get 403.
  static const Map<String, String> _githubHeaders = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'FurClient',
  };

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
    // Fetch all releases to support version selection.
    final uri = Uri.parse('https://api.github.com/repos/$_repo/releases');
    final response = await http.get(uri, headers: _githubHeaders);

    if (response.statusCode == 404) {
      throw Exception('No releases found');
    }
    if (response.statusCode == 403) {
      throw Exception('GitHub API rate-limited (403). Try again later.');
    }
    if (response.statusCode != 200) {
      throw Exception('GitHub API returned ${response.statusCode}');
    }

    final releases = jsonDecode(response.body) as List<dynamic>;
    final versions = <String>[];
    for (final item in releases) {
      final tag = (item['tag_name'] as String?) ?? '';
      if (tag.isNotEmpty) {
        versions.add(tag.replaceFirst('v', ''));
      }
    }

    // Sort by semver (ascending) — latest is the highest.
    versions.sort((a, b) => _compareVersions(a, b));
    _availableVersions = versions.reversed.toList(); // highest first
    _latestVersion = versions.isNotEmpty ? versions.last : null;
    _selectedVersion ??= _latestVersion;

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
    // Use selected version, or fall back to latest.
    final versionTag =
        _selectedVersion != null ? 'v$_selectedVersion' : 'v$_latestVersion';
    final useLatest = _selectedVersion == null;
    final endpoint = useLatest
        ? 'https://api.github.com/repos/$_repo/releases/latest'
        : 'https://api.github.com/repos/$_repo/releases/tags/$versionTag';
    final uri = Uri.parse(endpoint);

    final response = await http.get(uri, headers: _githubHeaders);

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

  /// Returns negative if [a] < [b], positive if [a] > [b], 0 if equal.
  int _compareVersions(String a, String b) {
    try {
      final aParts = a.split('.').map(int.parse).toList();
      final bParts = b.split('.').map(int.parse).toList();
      final len = aParts.length > bParts.length ? aParts.length : bParts.length;
      for (var i = 0; i < len; i++) {
        final av = i < aParts.length ? aParts[i] : 0;
        final bv = i < bParts.length ? bParts[i] : 0;
        if (av != bv) return av.compareTo(bv);
      }
      return 0;
    } catch (_) {
      return a.compareTo(b);
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
