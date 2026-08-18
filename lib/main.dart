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
import 'package:window_manager/window_manager.dart';
import 'services/auth_service.dart';
import 'services/fa_client.dart';
import 'services/update_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'utils/cookie_manager.dart';
import 'screens/login_screen.dart';
import 'navigation/adaptive_shell.dart';
import 'widgets/fluent_root_chrome.dart';
import 'utils/platform_utils.dart';
import 'package:upgrader/upgrader.dart';
import 'utils/fa_image_proxy.dart';
import 'package:path_provider/path_provider.dart';
import 'utils/notifications.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:app_links/app_links.dart';
import 'package:fa_kit/fa_kit.dart';

WebViewEnvironment? webViewEnvironment;

void main() {
  runZonedGuarded(() async {
    await http.runWithClient(() async {
      WidgetsFlutterBinding.ensureInitialized();

      if (Platform.isAndroid) {
        await InAppWebViewController.setWebContentsDebuggingEnabled(true);
        try {
          await initNotifications();
          await requestNotificationPermissions();
        } catch (e) {
          debugPrint('Notification init error: $e');
        }
      }

      if (Platform.isWindows) {
        await initNotifications();
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

        // Hide the OS title bar so the single FluentRootChrome caption bar is
        // the only one in the window (prevents duplicate min/max/close buttons).
        await windowManager.ensureInitialized();
        const windowOptions = WindowOptions(
          titleBarStyle: TitleBarStyle.hidden,
          size: Size(1280, 800),
          minimumSize: Size(720, 540),
          center: true,
        );
        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
        });
      }

      if (isDesktop) {
        try {
          SystemTheme.fallbackColor = AppColors.fluentCyanDark;
          await SystemTheme.accentColor.load();
        } catch (_) {}
      }

      AppTheme.setSystemOverlay();
      // Pre-init ThemeProvider before runApp so theme is loaded from the
      // very first frame (splash, restoration screen, etc.).
      await ThemeProvider.instance.loadFromPrefs();
      if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
        enableFlutterDriverExtension();
      }
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
  final ThemeProvider _themeProvider = ThemeProvider.instance;
  StreamSubscription<Uri>? _linkSubscription;
  bool _isLoggedIn = false;
  bool _isRestoringSession = true;

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
    _initApp();
    _setupDeepLinks();
  }

  void _setupDeepLinks() {
    _linkSubscription = AppLinks().uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');
    final target = FATarget.parse(uri);
    if (target == null) {
      debugPrint('Could not parse deep link');
      return;
    }

    // For now, just log the target - navigation will be handled elsewhere
    debugPrint('Parsed target: $target');
  }

  void _onThemeChanged() {
    final isDark = _themeProvider.mode == AppThemeMode.dark ||
        _themeProvider.mode == AppThemeMode.original;
    if (_themeProvider.mode == AppThemeMode.system) {
      AppTheme.setSystemOverlay();
    } else {
      AppTheme.setSystemOverlay(dark: isDark);
    }
    setState(() {});
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
    _themeProvider.removeListener(_onThemeChanged);
    _updateService.dispose();
    _themeProvider.dispose();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use FluentApp (Windows-native chrome) on Windows, MaterialApp everywhere else.
    if (isWindows) {
      return _buildFluentApp();
    }
    return _buildMaterialApp();
  }

  /// Windows-only root widget. Mirrors [_buildMaterialApp] but swaps the
  /// MaterialApp for a [fluent.FluentApp] using the Fluent theme builders
  /// defined in [AppTheme]. Android/macOS/Linux are unaffected — they go
  /// through [_buildMaterialApp].
  Widget _buildFluentApp() {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        final mode = _themeProvider.mode;
        final accent = AppTheme.systemAccent;

        fluent.FluentThemeData theme;
        fluent.FluentThemeData? darkTheme;

        switch (mode) {
          case AppThemeMode.system:
            theme = AppTheme.fluentLightTheme(accent: accent);
            darkTheme = AppTheme.fluentFromSystemAccent(accent);
            break;
          case AppThemeMode.light:
            theme = AppTheme.fluentLightTheme(accent: accent);
            darkTheme = null;
            break;
          case AppThemeMode.dark:
            theme = AppTheme.fluentDarkTheme;
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
          themeMode: _themeProvider.themeMode,
          theme: theme,
          darkTheme: darkTheme,
          home: FluentRootChrome(
            child: UpgradeAlert(child: _buildHome()),
          ),
        );
      },
    );
  }

  Widget _buildMaterialApp() {
    return ListenableBuilder(
      listenable: _themeProvider,
      builder: (context, _) {
        final mode = _themeProvider.mode;

        // Original: always dark, no system colour injection
        if (mode == AppThemeMode.original) {
          return MaterialApp(
            title: 'FurClient',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: UpgradeAlert(child: _buildHome()),
          );
        }

        return DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            final accent = AppTheme.systemAccent;
            ThemeData theme;
            ThemeData? darkTheme;

            switch (mode) {
              case AppThemeMode.system:
                if (lightDynamic != null && darkDynamic != null) {
                  theme = AppTheme.buildLightFromDynamic(lightDynamic);
                  darkTheme = AppTheme.buildFromDynamicColor(darkDynamic);
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
                  darkTheme = AppTheme.buildFromDynamicColor(darkDynamic);
                } else {
                  darkTheme = AppTheme.buildFromSystemAccent(accent);
                }
                theme = darkTheme;
                break;
              case AppThemeMode.original:
                theme = AppTheme.darkTheme;
                darkTheme = null;
                break;
            }

            return MaterialApp(
              title: 'FurClient',
              debugShowCheckedModeBanner: false,
              themeMode: _themeProvider.themeMode,
              theme: theme,
              darkTheme: darkTheme,
              home: UpgradeAlert(child: _buildHome()),
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
          content: Builder(
            builder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return ColoredBox(
                color: colorScheme.surface,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const fluent.ProgressRing(),
                      const SizedBox(height: 16),
                      Text(
                        'Restoring session...',
                        style:
                            TextStyle(color: AppColors.textDim, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(),
              ),
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

    // On Windows wrap the login screen in a Fluent ScaffoldPage so it lives
    // inside the FluentApp tree. LoginScreen itself already branches on
    // isWindows for its inner widgets.
    if (isWindows) {
      return fluent.ScaffoldPage(
        content: LoginScreen(authService: _authService, onLogin: _onLogin),
      );
    }
    return LoginScreen(authService: _authService, onLogin: _onLogin);
  }
}
