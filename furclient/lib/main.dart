import 'dart:async';
import 'dart:io' show Platform;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:system_theme/system_theme.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/fa_client.dart';
import 'screens/login_screen.dart';
import 'navigation/adaptive_shell.dart';
import 'utils/platform_utils.dart';
import 'package:path_provider/path_provider.dart';

WebViewEnvironment? webViewEnvironment;

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    if (Platform.isAndroid) {
      await InAppWebViewController.setWebContentsDebuggingEnabled(true);
    }

    // ← добавить сюда:
    if (Platform.isWindows) {
      final availableVersion = await WebViewEnvironment.getAvailableVersion();
      assert(availableVersion != null, 'WebView2 Runtime not found.');
      final dir = await getApplicationSupportDirectory();
      webViewEnvironment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: '${dir.path}\\webview2_data',
          additionalBrowserArguments: '--disable-gpu --use-gl=swiftshader',
        ),
      );
    }

    if (isDesktop) {
      try {
        SystemTheme.fallbackColor = AppColors.fluentCyanDark;
        await SystemTheme.accentColor.load();
      } catch (_) {}
    }

    AppTheme.setSystemOverlay();
    runApp(const FurClientApp());
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
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await _client.init();
      await _authService.loadSavedSession();
      final session = _authService.currentSession;

      if (session != null && session.isLoggedIn) {
        _client.setSession(session);
        final valid = await _client.verifySession();
        if (valid) {
          if (mounted) {
            setState(() {
              _isLoggedIn = true;
              _isRestoringSession = false;
            });
          }
          return;
        } else {
          await _authService.logout();
        }
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

  void _onLogin() {
    debugPrint('=== _onLogin() called');
    final session = _authService.currentSession;
    if (session != null) {
      // Запускаем операцию асинхронно чтобы не заблокировать UI
      _client.setSession(session);
      // Не ждем завершения восстановления cookies
    }
    if (mounted) {
      setState(() => _isLoggedIn = true);
    }
    debugPrint('=== _onLogin() setState completed');
  }

  void _onLogout() async {
    try {
      await _client.clearCookies();
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
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final ThemeData theme;
        if (!isMobile && darkDynamic == null) {
          theme = AppTheme.darkTheme;
        } else if (darkDynamic != null) {
          theme = AppTheme.buildFromDynamicColor(darkDynamic);
        } else {
          theme = AppTheme.darkTheme;
        }

        if (!isMobile) {
          return SystemThemeBuilder(
            builder: (context, systemAccent) {
              final ThemeData desktopTheme;
              if (darkDynamic != null) {
                desktopTheme = AppTheme.buildFromDynamicColor(darkDynamic);
              } else {
                desktopTheme =
                    AppTheme.buildFromSystemAccent(systemAccent.accent);
              }
              return MaterialApp(
                title: 'FurClient',
                debugShowCheckedModeBanner: false,
                theme: desktopTheme,
                home: _buildHome(),
              );
            },
          );
        }

        return MaterialApp(
          title: 'FurClient',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: _buildHome(),
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
