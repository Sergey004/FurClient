import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/fa_urls.dart';
import '../widgets/adaptive/adaptive.dart';
import '../main.dart' show webViewEnvironment;

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final Future<void> Function() onLogin;

  const LoginScreen({
    super.key,
    required this.authService,
    required this.onLogin,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  bool _showWebView = false;
  String? _errorMessage;
  Completer<UserSession?>? _loginCompleter;
  late AnimationController _glowController;
  bool _isProcessingNavigation = false;
  bool _showLoginOverlay = false;

  static final _allowedHosts = ['www.furaffinity.net', 'furaffinity.net'];

  static final _externalPaths = [
    RegExp(r'^/register/?$'),
    RegExp(r'^/lostpw/?$'),
  ];

  bool _isExternalPath(String path) {
    for (final pattern in _externalPaths) {
      if (pattern.hasMatch(path)) return true;
    }
    return false;
  }

  bool _isFAHost(String? host) {
    if (host == null) return false;
    return _allowedHosts.contains(host) || host.endsWith('.furaffinity.net');
  }

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _startLogin() async {
    final cookieManager = CookieManager();
    try {
      await cookieManager.deleteAllCookies().timeout(
        const Duration(seconds: 5),
        onTimeout: () async {
          debugPrint('=== Timeout clearing cookies');
          return false;
        },
      );
    } catch (e) {
      debugPrint('=== Error clearing cookies: $e');
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showWebView = true;
      _loginCompleter = Completer<UserSession?>();
      _isProcessingNavigation = false;
    });

    _loginCompleter!.future.then((session) {
      if (!mounted) return;
      debugPrint('=== Login future completed with session: $session');

      // Показываем оверлей поверх WebView вместо полного скрытия браузера
      if (mounted) {
        setState(() {
          _showLoginOverlay = true;
          _isLoading = false;
        });
      }

      // Затем асинхронно вызываем onLogin чтобы не блокировать UI
    Future.microtask(() async {
      try {
        debugPrint('=== Starting onLogin() call');
        await widget.onLogin();
        debugPrint('=== onLogin() returned successfully');

        if (mounted) {
          debugPrint('=== Setting _showWebView=false and _isLoading=false');
          setState(() {
            _showWebView = false;
            _isLoading = false;
          });
          debugPrint('=== setState completed');
        } else {
          debugPrint('=== Widget not mounted, skipping setState');
        }
      } catch (e) {
        debugPrint('=== Error in onLogin(): $e');
        if (mounted) {
          setState(() {
            _showWebView = false;
            _isLoading = false;
            _errorMessage = 'Error completing login: $e';
          });
        }
      }
      debugPrint('=== Future.microtask completed');
    });
          }
        } finally {
          // Скрываем WebView и оверлей после завершения onLogin
          if (mounted) {
            setState(() {
              _showWebView = false;
              _showLoginOverlay = false;
            });
          }
        }
        debugPrint('=== Future.microtask completed');
      });
    }).catchError((e) {
      if (!mounted) return;
      debugPrint('=== Login future error: $e');
      setState(() {
        _showWebView = false;
        _isLoading = false;
        _errorMessage = 'Login failed: $e';
      });
    });
  }

  void _cancelLogin() {
    _loginCompleter?.complete(null);
    setState(() {
      _showWebView = false;
      _isLoading = false;
    });
  }

  Future<void> _handleNavigation(
    InAppWebViewController controller,
    Uri? url,
  ) async {
    // Если логин уже завершен - не обрабатываем дальше
    if (_loginCompleter?.isCompleted ?? false) {
      debugPrint('=== Login already completed, ignoring navigation');
      return;
    }

    // Избегаем параллельной обработки
    if (_isProcessingNavigation) {
      debugPrint('=== Already processing navigation, skipping');
      return;
    }

    _isProcessingNavigation = true;
    try {
      if (url == null) return;
      if (!_isFAHost(url.host)) return;

      final path = url.path;
      final isRoot = path == '/' || path == '';
      final isUserPage = path.startsWith('/user/');

      if (!isRoot && !isUserPage) return;

      final Map<String, String> cookieMap = {};

      // Способ 1: Читаем cookies через CookieManager (Android/iOS/Windows)
      try {
        final cm = CookieManager();
        final faCookies = await cm
            .getCookies(
              url: WebUri(FAUrls.baseUrl),
            )
            .timeout(const Duration(seconds: 5));
        debugPrint('=== CookieManager found ${faCookies.length} cookies');
        for (final c in faCookies) {
          cookieMap[c.name] = c.value;
        }
      } catch (e) {
        debugPrint('=== CookieManager error: $e');
      }

      // Способ 2: Читаем cookies через document.cookie (ВСЕГДА, чтобы не потерять cookies)
      try {
        final rawCookies = await controller
            .evaluateJavascript(
              source: 'document.cookie',
            )
            .timeout(const Duration(seconds: 5)) as String?;

        debugPrint('=== document.cookie from JS: $rawCookies');

        if (rawCookies != null && rawCookies.isNotEmpty) {
          for (final part in rawCookies.split(';')) {
            final idx = part.indexOf('=');
            if (idx < 0) continue;
            final name = part.substring(0, idx).trim();
            final value = part.substring(idx + 1).trim();
            if (name.isNotEmpty && value.isNotEmpty) {
              cookieMap[name] = value;
            }
          }
        }
      } catch (e) {
        debugPrint('=== JS cookie error: $e');
      }

      // Преобразуем Map в список пар для JSON сохранения
      final List<List<String>> cookiePairs =
          cookieMap.entries.map((e) => [e.key, e.value]).toList();

      debugPrint(
          '=== Collected ${cookieMap.length} cookies: ${cookieMap.keys.join(", ")}');

      // Проверяем что собрали хотя бы какие-то cookies
      if (cookieMap.isEmpty) return;

      // Извлекаем username из URL или DOM
      String username = '';
      if (isUserPage) {
        final parts = path.split('/');
        for (final part in parts) {
          if (part.isNotEmpty && part != 'user') {
            username = part;
            break;
          }
        }
      }

      if (username.isEmpty) {
        try {
          final result = await controller
              .evaluateJavascript(
                source:
                    "document.querySelector('a[href*=\"/user/\"]')?.textContent?.trim() || ''",
              )
              .timeout(const Duration(seconds: 5));
          if (result != null && result is String && result.isNotEmpty) {
            username = result.trim();
          }
        } catch (_) {}
      }

      if (username.isEmpty) username = 'user';

      final session = UserSession(
        username: username,
        avatarUrl: FAUrls.avatar(username),
        isLoggedIn: true,
        cookies: jsonEncode(cookiePairs),
      );

      if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
        debugPrint('=== Saving session for user: $username');
        await widget.authService.saveSession(session).timeout(
          const Duration(seconds: 10),
          onTimeout: () async {
            debugPrint('=== Timeout saving session');
          },
        );
        debugPrint('=== Session saved, completing login');
        _loginCompleter!.complete(session);
        debugPrint('=== Login completed successfully');
      }
    } finally {
      _isProcessingNavigation = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktopWidth = width >= AppBreakpoints.desktop;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _showWebView
            ? _buildWebView(isDesktopWidth)
            : _buildLoginForm(isDesktopWidth),
      ),
    );
  }

  Widget _buildWebView(bool isDesktopWidth) {
    return Stack(
      children: [
        Column(
          children: [
        Container(
          color: AppColors.bgCard,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Sign in to FurAffinity',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _cancelLogin,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
        const LinearProgressIndicator(
          color: AppColors.fluentCyan,
          backgroundColor: AppColors.bgInput,
        ),
        Expanded(
          child: InAppWebView(
            webViewEnvironment: webViewEnvironment,
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              databaseEnabled: true,
              supportZoom: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              disableDefaultErrorPage: false,
              transparentBackground: false,
              thirdPartyCookiesEnabled: true,
              allowFileAccessFromFileURLs: false,
              allowUniversalAccessFromFileURLs: false,
            ),
            initialUrlRequest: URLRequest(
              url: WebUri(FAUrls.login),
            ),
            onLoadStart: (controller, url) {
              debugPrint('onLoadStart: $url');
            },
            onLoadStop: (controller, url) async {
              debugPrint('onLoadStop: $url');
              try {
                await _handleNavigation(controller, url).timeout(
                  const Duration(seconds: 15),
                  onTimeout: () async {
                    debugPrint('=== Timeout in _handleNavigation');
                  },
                );
              } catch (e) {
                debugPrint('=== Error in onLoadStop: $e');
              }

              // Если уже обработана успешная навигация - не продолжаем
              if (_loginCompleter?.isCompleted ?? false) {
                debugPrint('=== Login completed, skipping post-navigation');
                return;
              }

              if (url == null) return;
              if (!_isFAHost(url.host)) {
                final uri = Uri.parse(url.toString());
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication)
                        .timeout(const Duration(seconds: 5));
                  }
                  if (mounted) {
                    try {
                      await controller
                          .goBack()
                          .timeout(const Duration(seconds: 5));
                    } catch (e) {
                      debugPrint('=== Error on controller.goBack(): $e');
                    }
                  }
                } catch (e) {
                  debugPrint('=== Error launching external URL: $e');
                }
              } else if (_isExternalPath(url.path)) {
                final uri = Uri.parse(url.toString());
                try {
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication)
                        .timeout(const Duration(seconds: 5));
                  }
                  if (mounted) {
                    try {
                      await controller
                          .goBack()
                          .timeout(const Duration(seconds: 5));
                    } catch (e) {
                      debugPrint('=== Error on controller.goBack(): $e');
                    }
                  }
                } catch (e) {
                  debugPrint('=== Error launching external URL: $e');
                }
              }
            },
            onReceivedError: (controller, request, error) {
              if (!(request.isForMainFrame ?? false)) return;
              if (error.type == WebResourceErrorType.HOST_LOOKUP ||
                  error.type == WebResourceErrorType.CANNOT_CONNECT_TO_HOST) {
                if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
                  _loginCompleter!.completeError(
                    'Cannot connect to FurAffinity. Check your internet connection.',
                  );
                }
              }
            },
            onWebViewCreated: (controller) {},
            ),
        ),

        if (_showLoginOverlay)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Completing login...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoginForm(bool isDesktopWidth) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktopWidth ? 480 : double.infinity,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  final glow = _glowController.value;
                  return Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.fluentCyanBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.fluentCyan.withValues(
                          alpha: 0.3 + glow * 0.4,
                        ),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.fluentCyan.withValues(
                            alpha: 0.08 * glow,
                          ),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.pets,
                      color: AppColors.fluentCyan,
                      size: 40,
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'FA Nexus',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'FurAffinity Client',
                style: TextStyle(
                  color: AppColors.fluentCyan.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48),
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.danger,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              SizedBox(
                width: double.infinity,
                child: AdaptiveButton(
                  label: 'Sign in with FurAffinity',
                  onPressed: _isLoading ? null : _startLogin,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: AdaptiveProgress(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login, size: 20),
                            SizedBox(width: 10),
                            Text('Sign in with FurAffinity'),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'You will be redirected to FurAffinity to sign in.\nYour credentials are handled securely.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (isDesktopWidth) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.monitor, size: 14, color: AppColors.textMuted),
                      SizedBox(width: 6),
                      Text(
                        'Windows • Linux • macOS • Android • iOS',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
