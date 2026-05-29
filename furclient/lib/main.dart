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
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'navigation/adaptive_shell.dart';
import 'utils/platform_utils.dart';
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
  bool _isLoggedIn = false;
  bool _isRestoringSession = true;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      await _authService.loadSavedSession();
      final session = _authService.session;

      if (session != null) {
        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _isRestoringSession = false;
          });
        }
        return;
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
    if (mounted) {
      setState(() => _isLoggedIn = true);
    }
  }

  void _onLogout() async {
    await _authService.logout();
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
      final session = _authService.session;
      if (session != null) {
        return AdaptiveShell(
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
