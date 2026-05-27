import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/fa_urls.dart';
import '../utils/platform_utils.dart';
import '../widgets/adaptive/adaptive.dart';

class LoginScreen extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onLogin;

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
    await cookieManager.deleteAllCookies();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _showWebView = true;
      _loginCompleter = Completer<UserSession?>();
    });

    _loginCompleter!.future.then((session) {
      if (!mounted) return;
      setState(() {
        _showWebView = false;
        _isLoading = false;
      });
      if (session != null && session.isLoggedIn) {
        widget.onLogin();
      } else {
        setState(() {
          _errorMessage = 'Login was not completed. Please try again.';
        });
      }
    }).catchError((e) {
      if (!mounted) return;
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
    if (url == null) return;
    if (!_isFAHost(url.host)) return;

    final path = url.path;
    final isRoot = path == '/' || path == '';
    final isUserPage = path.startsWith('/user/');

    if (isRoot || isUserPage) {
      final cookieManager = CookieManager();
      final cookies = await cookieManager.getCookies(
        url: WebUri(FAUrls.baseUrl),
      );

      String? cookieA;
      final List<List<String>> cookiePairs = [];
      for (final cookie in cookies) {
        cookiePairs.add([cookie.name, cookie.value]);
        if (cookie.name == 'a') {
          cookieA = cookie.value;
        }
      }

      if (cookieA != null && cookieA.isNotEmpty) {
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
            final result = await controller.evaluateJavascript(
              source:
                  "document.querySelector('a[href*=\"/user/\"]')?.textContent || ''",
            );
            if (result != null && result is String && result.isNotEmpty) {
              username = result.trim();
            }
          } catch (_) {}
        }

        if (username.isEmpty) {
          username = 'user';
        }

        final session = UserSession(
          username: username,
          avatarUrl: FAUrls.avatar(username),
          isLoggedIn: true,
          cookies: jsonEncode(cookiePairs),
        );

        if (_loginCompleter != null && !_loginCompleter!.isCompleted) {
          await widget.authService.saveSession(session);
          _loginCompleter!.complete(session);
        }
      }
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
    final webView = Column(
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
        onLoadStart: (controller, url) {},
        onLoadStop: (controller, url) async {
          await _handleNavigation(controller, url);
          if (url == null) return;
          if (!_isFAHost(url.host)) {
            final uri = Uri.parse(url.toString());
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            await controller.goBack();
          } else if (_isExternalPath(url.path)) {
            final uri = Uri.parse(url.toString());
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            await controller.goBack();
          }
        },
            onReceivedError: (controller, request, error) {
              if (error.type == WebResourceErrorType.HOST_LOOKUP ||
                  error.type ==
                      WebResourceErrorType.CANNOT_CONNECT_TO_HOST) {
                if (_loginCompleter != null &&
                    !_loginCompleter!.isCompleted) {
                  _loginCompleter!.completeError(
                    'Cannot connect to FurAffinity. Check your internet connection.',
                  );
                }
              }
            },
            onWebViewCreated: (controller) {},
          ),
        ),
      ],
    );

    if (isWindows) {
      return fluent.ContentDialog(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        content: SizedBox(
          height: 600,
          child: webView,
        ),
        actions: [],
      );
    }

    return webView;
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
                              color: Colors.white, strokeWidth: 2),
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
                      Icon(
                        Icons.monitor,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
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
