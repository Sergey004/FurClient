import 'package:flutter/widgets.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../utils/platform_utils.dart';
import 'fluent_shell.dart';
import 'material_shell.dart';

class AdaptiveShell extends StatelessWidget {
  final FAClient client;
  final UserSession session;
  final VoidCallback onLogout;

  const AdaptiveShell({
    super.key,
    required this.client,
    required this.session,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      return FluentShell(
        client: client,
        session: session,
        onLogout: onLogout,
      );
    }
    return MaterialShell(
      client: client,
      session: session,
      onLogout: onLogout,
    );
  }
}
