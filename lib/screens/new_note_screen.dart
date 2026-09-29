import 'package:flutter/material.dart';
import '../services/fa_client.dart';
import '../utils/haptics.dart';

/// Композ нового нотеса — модальный bottom sheet в стиле панели
/// параметров поиска: to + subject + message → sendNote (ключ формы
/// клиент добирает сам со страницы /newpm/<to>).
class NewNoteSheet extends StatefulWidget {
  final FAClient client;
  final String? initialTo;

  const NewNoteSheet({super.key, required this.client, this.initialTo});

  /// Открыть композ шитом (клавиатура учитывается через viewInsets).
  static Future<void> show(BuildContext context, FAClient client,
      {String? initialTo}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => NewNoteSheet(client: client, initialTo: initialTo),
    );
  }

  @override
  State<NewNoteSheet> createState() => _NewNoteSheetState();
}

class _NewNoteSheetState extends State<NewNoteSheet> {
  late final TextEditingController _toCtrl =
      TextEditingController(text: widget.initialTo ?? '');
  final TextEditingController _subjectCtrl = TextEditingController();
  final TextEditingController _messageCtrl = TextEditingController();
  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_isSending) return;
    final to = _toCtrl.text.trim();
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (to.isEmpty || subject.isEmpty || message.isEmpty) {
      setState(() => _error = 'Fill in all fields');
      return;
    }
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await widget.client.sendNote(
          to: to, subject: subject, message: message);
      FHaptics.success();
      if (mounted) {
        FHaptics.success();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('=== NewNote send error: $e');
      if (mounted) setState(() => _error = 'Send failed: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('New note',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _toCtrl,
              style: TextStyle(color: colors.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'To (username)',
                labelStyle: TextStyle(color: colors.onSurfaceVariant),
                hintText: 'sergey004',
                hintStyle: TextStyle(color: colors.onSurfaceVariant),
                filled: true,
                fillColor: colors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _subjectCtrl,
              style: TextStyle(color: colors.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Subject',
                labelStyle: TextStyle(color: colors.onSurfaceVariant),
                filled: true,
                fillColor: colors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageCtrl,
              minLines: 6,
              maxLines: 12,
              style: TextStyle(color: colors.onSurface, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Message',
                labelStyle: TextStyle(color: colors.onSurfaceVariant),
                alignLabelWithHint: true,
                filled: true,
                fillColor: colors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: colors.error, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : FilledButton.icon(
                      onPressed: _send,
                      icon: const Icon(Icons.send),
                      label: const Text('Send note'),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
