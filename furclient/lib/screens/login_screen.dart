import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/fa_urls.dart';
import '../widgets/adaptive/adaptive.dart';
import '../utils/cookie_manager.dart';
import '../main.dart' show webViewEnvironment;

// Типы для работы с куки из разных источников
typedef WebCookie = Map<String, dynamic>;

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
    try {
      await FAICookieManager.deleteAll();
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

    _loginCompleter!.future.then((session) async {
      if (!mounted) return;
      debugPrint('=== Login future completed with session: $session');

      if (session == null) {
        setState(() {
          _showWebView = false;
          _isLoading = false;
          _errorMessage = 'Login was not completed. Please try again.';
        });
        return;
      }

      // Показываем оверлей поверх WebView пока идёт onLogin
      setState(() {
        _showLoginOverlay = true;
        _isLoading = false;
      });

      try {
        debugPrint('=== Starting onLogin() call');
        await widget.onLogin();
        debugPrint('=== onLogin() returned successfully');
      } catch (e) {
        debugPrint('=== Error in onLogin(): $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'Error completing login: $e';
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _showWebView = false;
            _showLoginOverlay = false;
            _isLoading = false;
          });
        }
      }
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

  Future<void> _extractCookies(
    InAppWebViewController controller,
    Map<String, Map<String, dynamic>> cookieDataMap,
  ) async {
    debugPrint('=== Starting enhanced cookie extraction with multiple strategies');
    
    // Strategy 1: CookieManager (can get HttpOnly cookies)
    try {
      final cm = FAICookieManager.instance;
      final urls = [
        'https://www.furaffinity.net',
        'https://furaffinity.net',
        'https://www.furaffinity.net/',
      ];

      for (var attempt = 0; attempt < 3; attempt++) {
        if (attempt > 0) {
          debugPrint('=== CookieManager retry attempt ${attempt + 1}...');
          await Future.delayed(const Duration(seconds: 1));
        }

        for (final url in urls) {
          try {
            final cookies = await cm
                .getCookies(url: WebUri(url))
                .timeout(const Duration(seconds: 3));
            if (cookies.isNotEmpty) {
              debugPrint('=== $url cookies: ${cookies.length} (${cookies.map((c) => c.name).join(", ")})');
              _addCookiesToMap(cookies, cookieDataMap);
            }
          } catch (e) {
            debugPrint('=== CookieManager error for $url: $e');
          }
        }

        if (cookieDataMap.containsKey('cf_clearance')) {
          debugPrint('=== cf_clearance found on attempt ${attempt + 1}');
          break;
        }
      }

      debugPrint(
        '=== CookieManager total: ${cookieDataMap.length} cookies (${cookieDataMap.keys.join(", ")})',
      );
    } catch (e) {
      debugPrint('=== Error in CookieManager extraction: $e');
    }

    // Strategy 2: document.cookie with exponential backoff
    final backoffDelays = [const Duration(milliseconds: 500), const Duration(seconds: 1), const Duration(seconds: 2)];
    
    for (int attempt = 0; attempt < backoffDelays.length; attempt++) {
      try {
        final delay = backoffDelays[attempt];
        debugPrint('=== Attempt ${attempt + 1}: Waiting $delay before document.cookie extraction');
        await Future.delayed(delay);
        
        final result = await controller.evaluateJavascript(
          source: "document.cookie",
        ).timeout(const Duration(seconds: 5));
        
        if (result != null && result is String && result.isNotEmpty) {
          debugPrint('=== document.cookie found: ${result.substring(0, min(result.length, 100))}...');
          final documentCookies = _parseDocumentCookieString(result);
          _addCookiesToMap(documentCookies, cookieDataMap);
        }
        
        // Check if we have the essential cookies we need
        final hasEssentialCookies = cookieDataMap.containsKey('a') || 
                                 cookieDataMap.containsKey('b') || 
                                 cookieDataMap.containsKey('cf_clearance');
        
        if (hasEssentialCookies) {
          debugPrint('=== Found essential cookies, stopping extraction');
          break;
        }
        
      } catch (e) {
        debugPrint('=== Error in document.cookie attempt ${attempt + 1}: $e');
      }
    }
    
    debugPrint('=== Cookie extraction completed. Total cookies: ${cookieDataMap.length}');
  }

  void _addCookiesToMap(
    List<dynamic> cookies,
    Map<String, Map<String, dynamic>> cookieDataMap,
  ) {
    int addedCount = 0;
    for (final c in cookies) {
      String name;
      String value;
      String domain;
      String path;
      bool isHttpOnly;
      bool isSecure;
      int expiresDate;
      
      if (c is Cookie) {
        // Handle flutter_inappwebview.Cookie type
        name = c.name;
        value = c.value as String? ?? '';
        domain = c.domain ?? '.furaffinity.net';
        path = c.path ?? '/';
        isHttpOnly = c.isHttpOnly ?? false;
        isSecure = c.isSecure ?? true;
        expiresDate = c.expiresDate is int ? c.expiresDate as int : 0;
      } else if (c is Map<String, dynamic>) {
        // Handle WebCookie type
        name = c['name'] as String? ?? '';
        value = c['value'] as String? ?? '';
        domain = c['domain'] as String? ?? '.furaffinity.net';
        path = c['path'] as String? ?? '/';
        isHttpOnly = c['isHttpOnly'] as bool? ?? false;
        isSecure = c['isSecure'] as bool? ?? true;
        expiresDate = c['expiresDate'] as int? ?? 0;
      } else {
        continue;
      }
      
      if (name.isNotEmpty && value.isNotEmpty && !cookieDataMap.containsKey(name)) {
        final displayValue = value.substring(0, min(value.length, 10));
        debugPrint(
          '=== Cookie: $name | domain=$domain | httpOnly=$isHttpOnly | value=$displayValue...',
        );
        cookieDataMap[name] = {
          'name': name,
          'value': value,
          'domain': domain,
          'path': path,
          'isHttpOnly': isHttpOnly,
          'isSecure': isSecure,
          'expiresDate': expiresDate,
        };
        addedCount++;
      }
    }
    if (addedCount > 0) {
      debugPrint('=== Added $addedCount new cookies to map, total: ${cookieDataMap.length}');
    }
  }

  ({bool isValid, String reason}) _validateCookies(
    Map<String, Map<String, dynamic>> cookieDataMap,
  ) {
    debugPrint('=== Starting cookie validation');
    
    // Check for essential cookies
    final hasSessionCookie = cookieDataMap.containsKey('a');
    final hasBackupCookie = cookieDataMap.containsKey('b');
    final hasCloudflareClearance = cookieDataMap.containsKey('cf_clearance');
    
    if (!hasSessionCookie && !hasBackupCookie) {
      debugPrint('=== Missing both session cookies (a and b)');
      return (isValid: false, reason: 'Missing session cookies');
    }
    
    // Validate Cloudflare clearance if present
    if (hasCloudflareClearance) {
      final cfCookie = cookieDataMap['cf_clearance'];
      if (cfCookie == null || cfCookie['value'] == null || cfCookie['value'].toString().isEmpty) {
        debugPrint('=== Invalid cf_clearance cookie');
        return (isValid: false, reason: 'Invalid Cloudflare clearance cookie');
      }
      debugPrint('=== Cloudflare clearance cookie is valid');
    }
    
    // Validate session cookie if present
    if (hasSessionCookie) {
      final sessionCookie = cookieDataMap['a'];
      if (sessionCookie == null || sessionCookie['value'] == null || sessionCookie['value'].toString().isEmpty) {
        debugPrint('=== Invalid session cookie (a)');
        return (isValid: false, reason: 'Invalid session cookie');
      }
      debugPrint('=== Session cookie (a) is valid');
    }
    
    // Validate backup cookie if present
    if (hasBackupCookie) {
      final backupCookie = cookieDataMap['b'];
      if (backupCookie == null || backupCookie['value'] == null || backupCookie['value'].toString().isEmpty) {
        debugPrint('=== Invalid backup cookie (b)');
        return (isValid: false, reason: 'Invalid backup cookie');
      }
      debugPrint('=== Backup cookie (b) is valid');
    }
    
    // Check cookie age (not expired)
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final cookie in cookieDataMap.values) {
      final expiresDate = cookie['expiresDate'] as int? ?? 0;
      if (expiresDate > 0 && expiresDate < now) {
        debugPrint('=== Cookie ${cookie['name']} is expired');
        return (isValid: false, reason: 'Expired cookie found');
      }
    }
    
    debugPrint('=== Cookie validation passed');
    return (isValid: true, reason: 'Valid');
  }

  List<WebCookie> _parseDocumentCookieString(String cookieString) {
    final cookies = <WebCookie>[];
    if (cookieString.isEmpty) return cookies;
    
    try {
      final cookiePairs = cookieString.split(';');
      debugPrint('=== Parsing ${cookiePairs.length} cookie pairs');
      
      for (final pair in cookiePairs) {
        final trimmed = pair.trim();
        if (trimmed.isEmpty) continue;
        
        final parts = trimmed.split('=');
        if (parts.length >= 2) {
          final name = parts[0].trim();
          final value = parts.sublist(1).join('=').trim();
          
          // Include FA-specific cookies and other potentially useful cookies
          if (name.startsWith('a') || 
              name.startsWith('b') || 
              name.startsWith('cf_') || 
              name.startsWith('sz') ||
              name.startsWith('b_') ||
              name.startsWith('c_') ||
              name.startsWith('session') ||
              name.startsWith('user') ||
              name.startsWith('auth')) {
            
            // Parse additional attributes if present
            final cookie = <String, dynamic>{
              'name': name,
              'value': value,
              'domain': '.furaffinity.net',
              'path': '/',
              'isHttpOnly': false,
              'isSecure': true,
              'expiresDate': 0,
            };
            
            // Try to extract additional attributes from the cookie string
            if (parts.length > 2) {
              final attributes = parts.sublist(2).join('=');
              if (attributes.contains('HttpOnly')) {
                cookie['isHttpOnly'] = true;
              }
              if (attributes.contains('Secure')) {
                cookie['isSecure'] = true;
              }
              if (attributes.contains('Expires=')) {
                try {
                  final expiresMatch = RegExp(r'Expires=([^;]+)').firstMatch(attributes);
                  if (expiresMatch != null) {
                    final expiresStr = expiresMatch.group(1)!.trim();
                    final expiresDate = DateTime.parse(expiresStr);
                    cookie['expiresDate'] = expiresDate.millisecondsSinceEpoch;
                  }
                } catch (e) {
                  debugPrint('=== Error parsing expires date: $e');
                }
              }
            }
            
            cookies.add(cookie);
            debugPrint('=== Parsed cookie: $name=${value.substring(0, min(value.length, 10))}...');
          }
        }
      }
      
      debugPrint('=== Successfully parsed ${cookies.length} cookies');
    } catch (e) {
      debugPrint('=== Error parsing cookie string: $e');
    }
    
    return cookies;
  }

  Future<void> _solveCloudflareChallenge(InAppWebViewController controller) async {
    debugPrint('=== Attempting to solve Cloudflare challenge');
    
    try {
      // Try to click the Cloudflare challenge button if it exists
      final result = await controller.evaluateJavascript(
        source: '''
          // Look for Cloudflare challenge elements and attempt to solve them
          const challengeSelectors = [
            '.cf-browser-verification',
            '.cf-challenge',
            '#challenge-form',
            'input[type="submit"]',
            'button[type="submit"]'
          ];
          
          let elementClicked = false;
          
          for (const selector of challengeSelectors) {
            const element = document.querySelector(selector);
            if (element) {
              console.log('Found Cloudflare challenge element:', selector);
              element.click();
              elementClicked = true;
              
              // Wait a bit for the click to take effect
              await new Promise(resolve => setTimeout(resolve, 1000));
              break;
            }
          }
          
          // If no specific challenge element found, try general click on page
          if (!elementClicked) {
            console.log('No specific Cloudflare challenge element found, trying general click');
            // Try to click on the page body to simulate user interaction
            document.body.click();
            await new Promise(resolve => setTimeout(resolve, 1000));
          }
          
          // Return success status
          return { success: true, clicked: elementClicked };
        ''',
      ).timeout(const Duration(seconds: 5));
      
      if (result != null && result is Map) {
        final success = result['success'] as bool? ?? false;
        final clicked = result['clicked'] as bool? ?? false;
        debugPrint('=== Cloudflare challenge result: success=$success, clicked=$clicked');
      } else {
        debugPrint('=== Cloudflare challenge result: $result');
      }
      
    } catch (e) {
      debugPrint('=== Error solving Cloudflare challenge: $e');
    }
  }

  Future<void> _saveCookiesToCookieStore(
    Map<String, Map<String, dynamic>> cookieDataMap,
  ) async {
    debugPrint('=== Starting enhanced cookie saving with validation');

    final validCookies = <Cookie>[];
    final invalidCookies = <String>[];
    
    // First validate the cookies
    final validation = _validateCookies(cookieDataMap);
    if (!validation.isValid) {
      debugPrint('=== Cookie validation failed: ${validation.reason}');
      return;
    }

    for (final cookieData in cookieDataMap.values) {
      final name = cookieData['name'] as String?;
      final value = cookieData['value'] as String?;
      final domain = cookieData['domain'] as String?;
      final path = cookieData['path'] as String?;
      final isHttpOnly = cookieData['isHttpOnly'] as bool?;
      final isSecure = cookieData['isSecure'] as bool?;
      final expiresDate = cookieData['expiresDate'] as int?;

      if (name == null || value == null || value.isEmpty || domain == null || path == null) {
        invalidCookies.add(name ?? 'null');
        debugPrint('=== Invalid cookie: $name=$value');
        continue;
      }

      // Prioritize essential cookies
      final isEssential = name == 'a' || name == 'b' || name == 'cf_clearance';
      final cookie = Cookie(
        name: name,
        value: value,
        domain: domain,
        path: path,
        isHttpOnly: isHttpOnly ?? false,
        isSecure: isSecure ?? true,
        expiresDate: expiresDate,
      );
      
      validCookies.add(cookie);
      debugPrint('=== Valid cookie: $name=$value${isEssential ? ' (ESSENTIAL)' : ''}');
    }

    if (validCookies.isEmpty) {
      debugPrint('=== No valid cookies to save');
      return;
    }

    try {
      // Save cookies to CookieManager using the static method
      for (final cookie in validCookies) {
        await FAICookieManager.setCookie(
          url: 'https://www.furaffinity.net',
          name: cookie.name,
          value: cookie.value,
          domain: cookie.domain ?? '.furaffinity.net',
          path: cookie.path ?? '/',
          isHttpOnly: cookie.isHttpOnly ?? false,
          isSecure: cookie.isSecure ?? true,
          expiresDate: cookie.expiresDate,
        );
      }
      debugPrint('=== Successfully saved ${validCookies.length} cookies to CookieManager');

      debugPrint('=== Enhanced cookie saving completed: ${validCookies.length} cookies saved');
      
    } catch (e) {
      debugPrint('=== Error in enhanced cookie saving: $e');
    }
  }

  Future<void> _handleNavigation(
    InAppWebViewController controller,
    Uri? url,
  ) async {
    if (_loginCompleter?.isCompleted ?? false) {
      debugPrint('=== Login already completed, ignoring navigation');
      return;
    }

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

      final Map<String, Map<String, dynamic>> cookieDataMap = {};

      // Извлекаем cookies тремя способами для надежности
      // 1. CookieManager — может получить HttpOnly cookies (cf_clearance)
      // 2. document.cookie — для не-HttpOnly cookies как дополнение

      await _extractCookies(controller, cookieDataMap);

      debugPrint(
        '=== Collected ${cookieDataMap.length} cookies: ${cookieDataMap.keys.join(", ")}',
      );

      // Use enhanced cookie validation
      final validation = _validateCookies(cookieDataMap);
      if (!validation.isValid) {
        debugPrint('=== Cookie validation failed: ${validation.reason}');
        debugPrint('=== Waiting for more cookies...');
        return;
      }

      debugPrint('=== Cookie validation passed: ${validation.reason}');

      // Логируем найденные FA cookies
      debugPrint('=== === Found FA Cookies === ===');
      for (final name in ['a', 'b', 'cf_clearance', 'sz']) {
        if (cookieDataMap.containsKey(name)) {
          final cookie = cookieDataMap[name];
          final value = cookie?['value'] as String? ?? '';
          final displayLength = value.isNotEmpty ? min(value.length, 20) : 0;
          final displayValue =
              displayLength > 0 ? value.substring(0, displayLength) : 'N/A';
          debugPrint('$name: $displayValue...');
        }
      }
      debugPrint('=== === === === === === === ===');

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

      // Use enhanced cookie saving
      debugPrint('=== Saving cookies with enhanced method');
      await _saveCookiesToCookieStore(cookieDataMap);

      final cookieDataList = cookieDataMap.values.map((e) => e).toList();

      final session = UserSession(
        username: username,
        avatarUrl: FAUrls.avatar(username),
        isLoggedIn: true,
        cookies: jsonEncode(cookieDataList),
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

                  if (_loginCompleter?.isCompleted ?? false) return;
                  if (url == null) return;

                  if (!_isFAHost(url.host) || _isExternalPath(url.path)) {
                    final uri = Uri.parse(url.toString());
                    try {
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        ).timeout(const Duration(seconds: 5));
                      }
                      if (mounted) {
                        await controller
                            .goBack()
                            .timeout(const Duration(seconds: 5));
                      }
                    } catch (e) {
                      debugPrint('=== Error launching external URL: $e');
                    }
                  }
                },
                onReceivedError: (controller, request, error) {
                  if (!(request.isForMainFrame ?? false)) return;
                  
                  // Handle Cloudflare challenge by checking for CF-related content
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
        ),
        if (_showLoginOverlay)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Completing login...',
                      style: TextStyle(color: Colors.white),
                    ),
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
                'FurClient',
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
