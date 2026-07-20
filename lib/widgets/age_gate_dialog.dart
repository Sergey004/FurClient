import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/platform_utils.dart';

/// Key under which the 18+ confirmation is persisted in [SharedPreferences].
const String kAgeConfirmedKey = 'age_confirmed';

/// Returns `true` if the user has previously confirmed being 18+.
Future<bool> isAgeConfirmed() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(kAgeConfirmedKey) ?? false;
}

/// Marks the 18+ confirmation as accepted in [SharedPreferences].
Future<void> setAgeConfirmed() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kAgeConfirmedKey, true);
}

/// Shows the 18+ age gate dialog and returns `true` only if the user ticked
/// the checkbox and pressed "Continue". On "Cancel" (or dismissal) returns
/// `false`. Branches on platform: Fluent `ContentDialog` on Windows, Material
/// `AlertDialog` everywhere else.
Future<bool> showAgeGateDialog(BuildContext context) {
  if (isWindows) {
    return _showFluent(context);
  }
  return _showMaterial(context);
}

Future<bool> _showFluent(BuildContext context) async {
  bool confirmed = false;
  final result = await fluent.showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return fluent.ContentDialog(
            title: const Text('Are you 18 or older?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will disable the SFW filter and show adult content. '
                  'Please confirm that you are 18 years of age or older.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                fluent.Checkbox(
                  checked: confirmed,
                  content: const Text('Yes, I am 18 or older'),
                  onChanged: (v) => setState(() => confirmed = v ?? false),
                ),
              ],
            ),
            actions: [
              fluent.Button(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              fluent.FilledButton(
                onPressed: confirmed
                    ? () => Navigator.of(ctx).pop(true)
                    : null,
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    },
  );
  return result ?? false;
}

Future<bool> _showMaterial(BuildContext context) async {
  bool confirmed = false;
  final colorScheme = Theme.of(context).colorScheme;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            backgroundColor: colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.12),
              ),
            ),
            title: Text(
              'Are you 18 or older?',
              style: TextStyle(color: colorScheme.onSurface),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will disable the SFW filter and show adult content. '
                  'Please confirm that you are 18 years of age or older.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: confirmed,
                  onChanged: (v) => setState(() => confirmed = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Yes, I am 18 or older',
                    style: TextStyle(color: colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: confirmed
                    ? () => Navigator.of(ctx).pop(true)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.materialLavenderDark,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Continue'),
              ),
            ],
          );
        },
      );
    },
  );
  return result ?? false;
}
