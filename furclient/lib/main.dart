import 'dart:async';
import 'dart:io' show Platform, HttpClient;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:system_theme/system_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:window_manager/window_manager.dart';
import 'services/auth_service.dart';
import 'services/fa_client.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'utils/cookie_manager.dart';
import 'screens/login_screen.dart';
import 'navigation/adaptive_shell.dart';
import 'utils/platform_utils.dart';
import 'utils/fa_image_proxy.dart';
import 'package:path_provider/path_provider.dart';

WebViewEnvironment? webViewEnvironment;

/// Global theme provider — created once before runApp.
late final ThemeProvider themeProvider;

void main() {
  runZonedGuarded(() async {
    await http.runWithClient(() async {
      WidgetsFlutterBinding.ensureInitialized();

      themeProvider = ThemeProvider();

      if (Platform.isAndroid) {
        await InAppWebViewController.setWebContentsDebuggingEnabled(true);
      }

      if (Platform.isWindows) {
        // ── Window Manager: hide native title bar, enable custom Win 11 title bar
        await windowManager.ensureInitialized();
        windowManager.waitUntilReadyToShow().then((_) async {
          await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
          await windowManager.setSize(const Size(1280, 720));
          await windowManager.setMinimumSize(const Size(640, 480));
          await windowManager.center();
          await windowManager.show();
        });

        final availableVersion = await WebViewEnvironment.getAvailableVersion();
        assert(availableVersion != null, 'WebView2 Runtime not found.');
        final dir = await getApplicationSupportDirectory();
        debugPrint(
            '=== Creating WebViewEnvironment with webview2_data profile at: ${dir.path}\\webview2_data');
        webViewEnvironment = await WebViewEnvironment.create(
          settings: WebViewEnvironmentSettings(
            userDataFolder: '${dir.path}\\webview2_data',
            additionalBrowserArguments: '--disable-gpu --use-gl=swiftshader',
          ),
        );
        debugPrint(
            '=== WebViewEnvironment created successfully, version: $availableVersion');
        await FAImageProxy().start();
      }

      if (!kIsWeb) {
        try {
          SystemTheme.fallbackColor = AppColors.fluentCyanDark;
          await SystemTheme.accentColor.load();
        } catch (_) {}
      }

      AppTheme.setSystemOverlay();

      runApp(const FurClientApp());
    }, () {
      if (Platform.isAndroid) {
        return CronetClient.defaultCronetEngine();
      } else if (Platform.isIOS || Platform.isMacOS) {
        return CupertinoClient.defaultSessionConfiguration();
      } else {
        return IOClient(HttpClient());
      }
    });
  }, (error, stack) {
    debugPrint('Unhandled error: $error\n$stack');
  });
}

class FurClientApp extends StatefulWidget {
  const FurClientApp({super.key});

  @override
  State<FurClientApp> createState() => _FurClientAppState();
}

class _FurClientAppState extends State<FurClientApp> {
  final AuthService _authService = AuthService();
  final FAClient _client = FAClient();
  bool _isLoggedIn = false;
  bool _isRestoringSession = true;

  @override
  void initState() {
    super.initState();
    themeProvider.addListener(_onThemeChanged);
    _initApp();
  }

  @override
  void dispose() {
    themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    // Update system overlay for status/nav bar colours
    final isDark = themeProvider.mode == AppThemeMode.dark ||
        themeProvider.mode == AppThemeMode.original;
    if (themeProvider.mode == AppThemeMode.system) {
      // Will be resolved by MediaQuery, set dark as default
      AppTheme.setSystemOverlay();
    } else {
      AppTheme.setSystemOverlay(dark: isDark);
    }
    // Rebuild the entire app tree to pick up new theme
    setState(() {});
  }

  Future<void> _initApp() async {
    try {
      debugPrint('=== _initApp: Starting application initialization');
      await _client.init();
      debugPrint('=== _initApp: FAClient initialized');
      await _authService.loadSavedSession();
      debugPrint(
          '=== _initApp: Session loaded: ${_authService.currentSession != null}');
      final session = _authService.currentSession;

      if (session != null && session.isLoggedIn) {
        debugPrint(
            '=== _initApp: Restoring session for user: ${session.username}');
        await _client.setSession(session);
        final valid = await _client.verifySession();
        debugPrint('=== _initApp: Session verification result: $valid');
        if (valid) {
          if (mounted) {
            setState(() {
              _isLoggedIn = true;
              _isRestoringSession = false;
            });
          }
          return;
        } else {
          debugPrint('=== _initApp: Session invalid, logging out');
          await _authService.logout();
        }
      } else {
        debugPrint('=== _initApp: No valid session to restore');
      }
    } catch (e) {
      debugPrint('Init error: $e');
    }

    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _isRestoringSession = false;
      });
    }
  }

  Future<void> _onLogin() async {
    debugPrint('=== _onLogin() called');
    final session = _authService.currentSession;
    if (session != null) {
      await _client.setSession(session, freshLogin: true);
    }
    if (mounted) {
      setState(() => _isLoggedIn = true);
    }
    debugPrint('=== _onLogin() completed successfully');
  }

  void _onLogout() async {
    try {
      await _client.clearCookies();
      await FAICookieManager.deleteAll();
      await _authService.logout();
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoggedIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      return _buildFluentApp();
    }
    return _buildMaterialApp();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FLUENT APP (Windows)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFluentApp() {
    final mode = themeProvider.mode;
    final accent = AppTheme.systemAccent;

    fluent.FluentThemeData theme;
    fluent.FluentThemeData? darkTheme;

    switch (mode) {
      case AppThemeMode.system:
        // Follow system dark/light + system accent
        theme = AppTheme.fluentLightTheme(accent: accent);
        darkTheme = AppTheme.fluentFromSystemAccent(accent);
        break;
      case AppThemeMode.light:
        theme = AppTheme.fluentLightTheme(accent: accent);
        darkTheme = null; // force light
        break;
      case AppThemeMode.dark:
        theme = AppTheme.fluentDarkTheme; // fallback if FluentApp needs one
        darkTheme = AppTheme.fluentFromSystemAccent(accent);
        break;
      case AppThemeMode.original:
        theme = AppTheme.fluentDarkTheme;
        darkTheme = AppTheme.fluentDarkTheme;
        break;
    }

    return fluent.FluentApp(
      title: 'FurClient',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: theme,
      darkTheme: darkTheme,
      home: _buildHome(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MATERIAL APP (Android / other)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMaterialApp() {
    final mode = themeProvider.mode;

    if (mode == AppThemeMode.original) {
      // Original: always dark, no system colour injection
      return MaterialApp(
        title: 'FurClient',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: _buildHome(),
      );
    }

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final accent = AppTheme.systemAccent;

        ThemeData theme;
        ThemeData? darkTheme;

        switch (mode) {
          case AppThemeMode.system:
            // Use dynamic colour on Android S+, system accent fallback
            if (lightDynamic != null && darkDynamic != null) {
              theme = AppTheme.buildLightFromDynamic(lightDynamic);
              darkTheme =
                  AppTheme.buildFromDynamicColor(darkDynamic);
            } else {
              theme = AppTheme.buildLightTheme(accent: accent);
              darkTheme = AppTheme.buildFromSystemAccent(accent);
            }
            break;
          case AppThemeMode.light:
            if (lightDynamic != null) {
              theme = AppTheme.buildLightFromDynamic(lightDynamic);
            } else {
              theme = AppTheme.buildLightTheme(accent: accent);
            }
            darkTheme = null;
            break;
          case AppThemeMode.dark:
            if (darkDynamic != null) {
              darkTheme =
                  AppTheme.buildFromDynamicColor(darkDynamic);
            } else {
              darkTheme = AppTheme.buildFromSystemAccent(accent);
            }
            theme = darkTheme; // fallback for MaterialApp
            break;
          case AppThemeMode.original:
            theme = AppTheme.darkTheme;
            darkTheme = null;
            break;
        }

        return MaterialApp(
          title: 'FurClient',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: theme,
          darkTheme: darkTheme,
          home: _buildHome(),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HOME (shared between Fluent & Material)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHome() {
    if (_isRestoringSession) {
      if (isWindows) {
        return fluent.ScaffoldPage(
          content: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const fluent.ProgressRing(),
                const SizedBox(height: 16),
                Text(
                  'Restoring session...',
                  style: TextStyle(color: AppColors.textDim, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.fluentCyan),
              const SizedBox(height: 16),
              Text(
                'Restoring session...',
                style: TextStyle(color: AppColors.textDim, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      final session = _authService.currentSession;
      if (session != null) {
        return AdaptiveShell(
          client: _client,
          session: session,
          onLogout: _onLogout,
        );
      }
    }

    if (isWindows) {
      return fluent.ScaffoldPage(
        content:
            LoginScreen(authService: _authService, onLogin: _onLogin),
      );
    }
    return LoginScreen(authService: _authService, onLogin: _onLogin);
  }
}
