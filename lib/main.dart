import 'dart:async';
import 'dart:io' show Platform, HttpClient;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:system_theme/system_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart' hide URLRequest;
import 'package:window_manager/window_manager.dart';
import 'package:workmanager/workmanager.dart';

import 'services/auth_service.dart';
import 'utils/haptics.dart';
import 'services/fa_client.dart';
import 'services/notification_poller.dart';
import 'services/update_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'utils/cookie_manager.dart';
import 'screens/login_screen.dart';
import 'screens/journal_detail_screen.dart';
import 'screens/note_detail_screen.dart';
import 'screens/submission_detail_screen.dart';
import 'screens/user_content_screen.dart';
import 'screens/gallery_screen.dart';
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
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:flutter/foundation.dart';

WebViewEnvironment? webViewEnvironment;

/// Фоновый вход workmanager (Android, без Google Play Services —
/// androidx.work сам падает на AlarmManager-реализацию).
/// Свежий изолят: свои FAClient/AuthService/уведомления.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('=== Workmanager: background task $task started');
      await initNotifications();
      final client = FAClient();
      await client.init();
      final auth = AuthService();
      await auth.loadSavedSession();
      final session = auth.currentSession;
      if (session == null || !session.isLoggedIn) {
        debugPrint('=== Workmanager: no session, skipping');
        return true;
      }
      await client.setSession(session);
      await NotificationPoller(client).pollAndNotify();
      debugPrint('=== Workmanager: background task $task done');
      return true;
    } catch (e) {
      debugPrint('=== Workmanager: background task error: $e');
      return true;
    }
  });
}

void main() {
  runZonedGuarded(() async {
    await http.runWithClient(() async {
      if (kDebugMode) {
        MarionetteBinding.ensureInitialized();
      } else {
        WidgetsFlutterBinding.ensureInitialized();
      }

      // Настройка хаптик (haptics_enabled) — до любых UI-взаимодействий.
      await FHaptics.load();

      if (Platform.isAndroid) {
        await InAppWebViewController.setWebContentsDebuggingEnabled(true);
        // Пин максимальной частоты панели: на LTPO-экранах (1–120 Гц) без
        // этого Flutter прыгает между 60 и 120 Гц при смене поверхностей.
        try {
          await FlutterDisplayMode.setHighRefreshRate();
        } catch (e) {
          debugPrint('DisplayMode init error: $e');
        }
        try {
          await initNotifications();
          await requestNotificationPermissions();
        } catch (e) {
          debugPrint('Notification init error: $e');
        }
        // Фоновый опрос уведомлений каждые 30 минут (минимум workmanager'а
        // — 15 минут; без GMS androidx.work использует AlarmManager).
        try {
          await Workmanager().initialize(callbackDispatcher);
          await Workmanager().registerPeriodicTask(
            'furclient-notification-poll',
            'notificationPoll',
            frequency: const Duration(minutes: 30),
            constraints: Constraints(networkType: NetworkType.connected),
            existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
          );
        } catch (e) {
          debugPrint('Workmanager init error: $e');
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
            // Без --disable-gpu: в headless-режиме со swiftshader Cloudflare
            // Turnstile палит окружение, и managed-челлендж не проходит.
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
  StreamSubscription<SystemAccentColor>? _systemThemeSubscription;
  bool _isLoggedIn = false;
  bool _isRestoringSession = true;

  static final GlobalKey<NavigatorState> _navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _themeProvider.addListener(_onThemeChanged);
    _setupSystemThemeListener();
    // Windows: CF-челленджи, которые headless WebView2 пройти не может,
    // показываем пользователю в видимом диалоге (см. _CfChallengeDialog).
    _client.cfChallengeResolver = _resolveCloudflareChallenge;
    // Тап по уведомлению → deep-link роутер (FATarget).
    onNotificationTap = (url) {
      final target = FATarget.parseString(url);
      if (target != null) _navigateToTarget(target);
    };
    // Foreground-опрос уведомлений: раз после старта + таймер на Windows
    // (на Android в фоне работает workmanager; dedup по watermark'ам
    // исключает дубли между foreground- и background-прогонами).
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted) NotificationPoller(_client).pollAndNotify();
    });
    if (isWindows) {
      Timer.periodic(const Duration(minutes: 30), (_) {
        NotificationPoller(_client).pollAndNotify();
      });
    }
    _initApp();
    _setupDeepLinks();
  }

  bool _cfDialogOpen = false;

  /// Показывает Turnstile/CF-челлендж в видимом InAppWebView на общем
  /// [webViewEnvironment]; cf_clearance после прохождения остаётся в том же
  /// профиле и подхватывается headless-запросами. Возвращает true, если
  /// челлендж пройден (запрос стоит повторить).
  Future<bool> _resolveCloudflareChallenge(String url) async {
    if (!isWindows || webViewEnvironment == null) return false;
    if (_cfDialogOpen) return false;
    _cfDialogOpen = true;
    try {
      final ctx = _navigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return false;
      final solved = await fluent.showDialog<bool>(
        context: ctx,
        builder: (context) => _CfChallengeDialog(url: url),
      );
      return solved ?? false;
    } finally {
      _cfDialogOpen = false;
    }
  }

  void _setupSystemThemeListener() {
    if (isDesktop) {
      _systemThemeSubscription = SystemTheme.onChange.listen((_) {
        if (mounted) {
          // Reload accent color and rebuild theme
          SystemTheme.accentColor.load().then((_) {
            if (mounted) setState(() {});
          });
        }
      });
    }
  }

  static bool _initialDeepLinkHandled = false;
  String? _lastDeepLink;
  DateTime? _lastDeepLinkAt;

  void _setupDeepLinks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLinks().getInitialLink().then((initialLink) {
        if (initialLink != null && !_initialDeepLinkHandled && mounted) {
          _initialDeepLinkHandled = true;
          _handleDeepLink(initialLink);
        }
      });
    });

    _linkSubscription = AppLinks().uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');
    final now = DateTime.now();
    if (_lastDeepLink == uri.toString() &&
        _lastDeepLinkAt != null &&
        now.difference(_lastDeepLinkAt!) < const Duration(seconds: 1)) {
      return;
    }
    _lastDeepLink = uri.toString();
    _lastDeepLinkAt = now;
    final target = FATarget.parse(uri);
    if (target == null) {
      debugPrint('Could not parse deep link');
      return;
    }

    debugPrint('Parsed target: $target');
    _navigateToTarget(target);
  }

  void _navigateToTarget(FATarget target) {
    final targetType = target.type;

    if (!mounted) return;

    switch (targetType) {
      case FATargetType.submission:
        final submissionId = target.submissionId;
        if (submissionId != null) {
          final session = _authService.currentSession;
          if (session != null && session.isLoggedIn) {
            _client.setSession(session);
            _client.verifySession().then((valid) {
              if (valid && mounted) {
                setState(() {
                  _isLoggedIn = true;
                });
                // Try to get current context from navigator key if needed
                final navState = _navigatorKey.currentState;
                if (navState != null) {
                  navState.push(
                    MaterialPageRoute(
                      builder: (_) => SubmissionDetailScreen(
                        client: _client,
                        submissionId: submissionId.toString(),
                        sfwMode: false,
                      ),
                    ),
                  );
                } else {
                  // Navigator not ready yet, will need fallback handling
                  debugPrint(
                      'Navigator not ready for submission deep link: $submissionId');
                }
              }
            });
          }
        }
        break;
      case FATargetType.journal:
        final journalId = target.journalId;
        if (journalId != null && mounted) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => JournalDetailScreen(
                client: _client,
                journalId: journalId.toString(),
              ),
            ),
          );
        }
        break;
      case FATargetType.user:
        final username = target.username;
        if (username != null && mounted) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => UserContentScreen(
                client: _client,
                username: username,
                contentType: UserContentType.journals,
              ),
            ),
          );
        }
        break;
      case FATargetType.gallery:
        final username = target.username;
        if (username != null && mounted) {
          _navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => GalleryScreen(
                client: _client,
                sfwMode: false,
              ),
            ),
          );
        }
        break;
      case FATargetType.favorites:
        // Navigate to gallery tab by default
        // Note: This requires app-level coordination with AdaptiveShell
        debugPrint('Favorites deep link - needs shell-level navigation');
        break;
      case FATargetType.note:
        final navState = _navigatorKey.currentState;
        if (navState != null) {
          navState.push(
            MaterialPageRoute(
              builder: (_) => NoteDetailScreen(
                client: _client,
                url: target.url.toString(),
              ),
            ),
          );
        }
        break;
      case FATargetType.journals:
        _navToTabByUrl(target);
        break;
      case FATargetType.watchlist:
        _navToTabByUrl(target);
        break;
      default:
        debugPrint('Unhandled target type: $targetType');
    }
  }

  Future<void> _navToTabByUrl(FATarget target) async {
    if (!mounted) return;
    setState(() {
      // Will be handled via shell notification or similar
    });
  }

  void _onThemeChanged() {
    final isDark = _themeProvider.mode == AppThemeMode.dark;
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
        // Оптимистичный рестарт: шелл показываем сразу — сплэш не должен
        // ждать сетевую проверку (WebView-фетч 2–5 с, при CF до 60 с).
        if (mounted) {
          setState(() {
            _isLoggedIn = true;
            _isRestoringSession = false;
          });
        }
        // Верификация в фоне: false = сессия реально мертва (CF-заслон
        // возвращает true) — тихо разлогиниваем.
        unawaited(_client.verifySession().then((valid) async {
          debugPrint('=== _initApp: background verification: $valid');
          if (!valid) {
            await _authService.logout();
            if (mounted) setState(() => _isLoggedIn = false);
          }
        }));
        return;
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
    _systemThemeSubscription?.cancel();
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
        fluent.ThemeMode fluentThemeMode;

        switch (mode) {
          case AppThemeMode.system:
            theme = AppTheme.fluentLightTheme(accent: accent);
            darkTheme = AppTheme.fluentFromSystemAccent(accent);
            fluentThemeMode = fluent.ThemeMode.system;
            break;
          case AppThemeMode.light:
            theme = AppTheme.fluentLightTheme(accent: accent);
            darkTheme = null;
            fluentThemeMode = fluent.ThemeMode.light;
            break;
          case AppThemeMode.dark:
            theme = AppTheme.fluentDarkTheme;
            darkTheme = AppTheme.fluentFromSystemAccent(accent);
            fluentThemeMode = fluent.ThemeMode.dark;
            break;
        }

        return fluent.FluentApp(
          title: 'FurClient',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          themeMode: fluentThemeMode,
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
            }

            return MaterialApp(
              title: 'FurClient',
              debugShowCheckedModeBanner: false,
              themeMode: _themeProvider.themeMode,
              theme: theme,
              darkTheme: darkTheme,
              navigatorKey: _FurClientAppState._navigatorKey,
              onGenerateRoute: _onGenerateRoute,
              home: UpgradeAlert(child: _buildHome()),
            );
          },
        );
      },
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final name = settings.name;
    if (name == null || name.isEmpty) return null;
    final target = FATarget.parse(Uri.parse(name));
    if (target == null) return null;

    switch (target.type) {
      case FATargetType.user:
        final username = target.username;
        if (username == null) return null;
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => UserContentScreen(
            client: _client,
            username: username,
            contentType: UserContentType.journals,
          ),
        );
      case FATargetType.gallery:
      case FATargetType.favorites:
      case FATargetType.journals:
        final username = target.username;
        if (username == null) return null;
        final contentType = switch (target.type) {
          FATargetType.gallery => UserContentType.gallery,
          FATargetType.favorites => UserContentType.favorites,
          _ => UserContentType.journals,
        };
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => UserContentScreen(
            client: _client,
            username: username,
            contentType: contentType,
          ),
        );
      default:
        return null;
    }
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

/// Видимый резолвер Cloudflare-челленджа (Windows).
///
/// Headless WebView2 не проходит Turnstile сам (бот-детекция по сигналам
/// окружения), поэтому челлендж показывается пользователю в этом диалоге.
/// Как только целевая страница реально загрузилась (не челлендж-экран),
/// диалог сам закрывается с результатом true.
class _CfChallengeDialog extends StatefulWidget {
  final String url;
  const _CfChallengeDialog({required this.url});

  @override
  State<_CfChallengeDialog> createState() => _CfChallengeDialogState();
}

class _CfChallengeDialogState extends State<_CfChallengeDialog> {
  bool _completed = false;

  Future<void> _onLoadStop(InAppWebViewController controller, Uri? url) async {
    if (_completed) return;
    final html = await controller.getHtml() ?? '';
    // Челлендж-страница крошечная и размечена _cf_chl_opt/cf-chl-widget;
    // настоящая страница FA всегда крупнее и размечена по-другому.
    if (!FAClient.isCloudflarePageHtml(html) && html.length > 5000) {
      _completed = true;
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return fluent.ContentDialog(
      title: const fluent.Text('Проверка Cloudflare'),
      content: SizedBox(
        width: 720,
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const fluent.Text(
              'FurAffinity просит подтвердить, что вы не бот. '
              'Пройдите проверку — страница закроется сама.',
            ),
            const SizedBox(height: 8),
            Expanded(
              child: InAppWebView(
                webViewEnvironment: webViewEnvironment,
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  domStorageEnabled: true,
                ),
                initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                onLoadStop: _onLoadStop,
              ),
            ),
          ],
        ),
      ),
      actions: [
        fluent.Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: const fluent.Text('Отмена'),
        ),
      ],
    );
  }
}
