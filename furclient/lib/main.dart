import 'dart:io' show Platform;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:system_theme/system_theme.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/fa_client.dart';
import 'screens/login_screen.dart';
import 'navigation/app_navigator.dart';

bool get _isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_isDesktop) {
    SystemTheme.fallbackColor = AppColors.fluentCyanDark;
    await SystemTheme.accentColor.load();
  }
  AppTheme.setSystemOverlay();
  runApp(const FurClientApp());
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
    await _client.init();
    await _authService.loadSavedSession();
    final session = _authService.currentSession;

    if (session != null && session.isLoggedIn) {
      _client.setSession(session);
      await _authService.restoreSessionCookies();
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

    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _isRestoringSession = false;
      });
    }
  }

  void _onLogin() {
    final session = _authService.currentSession;
    if (session != null) {
      _client.setSession(session);
    }
    setState(() => _isLoggedIn = true);
  }

  void _onLogout() async {
    await _client.clearCookies();
    await _authService.logout();
    if (mounted) {
      setState(() => _isLoggedIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) {
      return DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          final theme = darkDynamic != null
              ? AppTheme.buildFromDynamicColor(darkDynamic)
              : AppTheme.darkTheme;
          return MaterialApp(
            title: 'FurClient',
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: _buildHome(),
          );
        },
      );
    }

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return SystemThemeBuilder(
          builder: (context, systemAccent) {
            final ThemeData theme;
            if (darkDynamic != null) {
              theme = AppTheme.buildFromDynamicColor(darkDynamic);
            } else {
              theme = AppTheme.buildFromSystemAccent(systemAccent.accent);
            }
            return MaterialApp(
              title: 'FurClient',
              debugShowCheckedModeBanner: false,
              theme: theme,
              home: _buildHome(),
            );
          },
        );
      },
    );
  }

  Widget _buildHome() {
    if (_isRestoringSession) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.fluentCyan),
              SizedBox(height: 16),
              Text('Restoring session...', style: TextStyle(color: AppColors.textDim, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      final session = _authService.currentSession;
      if (session != null) {
        return AppNavigator(
          client: _client,
          session: session,
          onLogout: _onLogout,
        );
      }
    }

    return LoginScreen(authService: _authService, onLogin: _onLogin);
  }
}
