import 'package:flutter/widgets.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../theme/theme_provider.dart';
import '../utils/platform_utils.dart';
import 'fluent_shell.dart';
import 'material_shell.dart';

class AdaptiveShell extends StatelessWidget {
  final FAClient client;
  final UserSession session;
  final VoidCallback onLogout;
  final ThemeProvider themeProvider;

  const AdaptiveShell({
    super.key,
    required this.client,
    required this.session,
    required this.onLogout,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      return FluentShell(
        client: client,
        session: session,
        onLogout: onLogout,
        themeProvider: themeProvider,
      );
    }
    return MaterialShell(
      client: client,
      session: session,
      onLogout: onLogout,
      themeProvider: themeProvider,
    );
  }
}
