import 'dart:async';
import 'dart:io' show Platform, HttpClient;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:system_theme/system_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'services/auth_service.dart';
import 'services/fa_client.dart';
import 'services/update_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'utils/cookie_manager.dart';
import 'screens/login_screen.dart';
import 'navigation/adaptive_shell.dart';
import 'utils/platform_utils.dart';
import 'package:upgrader/upgrader.dart';
import 'utils/fa_image_proxy.dart';
import 'package:path_provider/path_provider.dart';

WebViewEnvironment? webViewEnvironment;

void main() {
  runZonedGuarded(() async {
    await http.runWithClient(() async {
      WidgetsFlutterBinding.ensureInitialized();

      if (Platform.isAndroid) {
        await InAppWebViewController.setWebContentsDebuggingEnabled(true);
      }

      if (Platform.isWindows) {
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
        // Запускаем прокси для FA CDN — читает cookies из webview2_data профиля
        await FAImageProxy().start();
      }

      if (isDesktop) {
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
  final UpdateService _updateService = UpdateService();
  final ThemeProvider _themeProvider = ThemeProvider();
  bool _isLoggedIn = false;
  bool _isRestoringSession = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      debugPrint('=== _initApp: Starting application initialization');
      await _client.init();

      // Windows: start update checker in background
      if (isWindows) {
        _updateService.init();
      }
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
      // freshLogin=true: skip CF pass and verifySession — user just logged in
      // through WebView, cookies are known-valid. verifySession with Dio HTTP
      // client often gets 403 due to PersistCookieJar issues or CF TLS fingerprint.
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
  void dispose() {
    _updateService.dispose();
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      return _buildFluentApp();
    }
    return _buildMaterialApp();
  }

  Widget _buildFluentApp() {
    final accent = SystemTheme.accentColor.accent;
    final fluentTheme = accent != Colors.transparent
        ? AppTheme.fluentFromSystemAccent(accent)
        : AppTheme.fluentDarkTheme;

    return fluent.FluentApp(
      title: 'FurClient',
      debugShowCheckedModeBanner: false,
      theme: fluentTheme,
      home: _buildHome(),
    );
  }

  Widget _buildMaterialApp() {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        final themeMode = _themeProvider.themeMode;
        final useSystemAccent = _themeProvider.useSystemAccent;

        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            ThemeData theme;
            ThemeData? lightTheme;

            if (!useSystemAccent) {
              // Original mode — hardcoded dark cyan
              theme = AppTheme.darkTheme;
            } else if (!isMobile && darkDynamic != null) {
              theme = AppTheme.buildFromDynamicColor(darkDynamic);
            } else if (darkDynamic != null && lightDynamic != null) {
              theme = AppTheme.buildFromDynamicColor(darkDynamic);
              lightTheme = AppTheme.buildTheme(
                lightDynamic.copyWith(
                  surface: lightDynamic.surface,
                  onSurface: lightDynamic.onSurface,
                ),
              );
            } else {
              theme = AppTheme.darkTheme;
            }

            if (!isMobile) {
              return SystemThemeBuilder(
                builder: (context, systemAccent) {
                  final ThemeData desktopTheme;
                  if (!useSystemAccent) {
                    desktopTheme = AppTheme.darkTheme;
                  } else if (darkDynamic != null) {
                    desktopTheme = AppTheme.buildFromDynamicColor(darkDynamic);
                  } else {
                    desktopTheme =
                        AppTheme.buildFromSystemAccent(systemAccent.accent);
                  }
                  return MaterialApp(
                    title: 'FurClient',
                    debugShowCheckedModeBanner: false,
                    themeMode: themeMode,
                    theme: lightTheme ?? desktopTheme,
                    darkTheme: desktopTheme,
                    home: UpgradeAlert(
                      child: _buildHome(),
                    ),
                  );
                },
              );
            }

            return MaterialApp(
              title: 'FurClient',
              debugShowCheckedModeBanner: false,
              themeMode: themeMode,
              theme: lightTheme ?? theme,
              darkTheme: theme,
              home: UpgradeAlert(
                child: _buildHome(),
              ),
            );
          },
        );
      },
    );
  }

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
          themeProvider: _themeProvider,
        );
      }
    }

    if (isWindows) {
      return fluent.ScaffoldPage(
        content: LoginScreen(authService: _authService, onLogin: _onLogin),
      );
    }
    return LoginScreen(authService: _authService, onLogin: _onLogin);
  }
}
