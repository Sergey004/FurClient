import 'package:flutter/widgets.dart';
import '../models/models.dart';
import '../utils/platform_utils.dart';
import 'fluent_shell.dart';
import 'material_shell.dart';

class AdaptiveShell extends StatelessWidget {
  final OnlineFASession session;
  final VoidCallback onLogout;

  const AdaptiveShell({
    super.key,
    required this.session,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      return FluentShell(
        session: session,
        onLogout: onLogout,
      );
    }
    return MaterialShell(
      session: session,
      onLogout: onLogout,
    );
  }
}
