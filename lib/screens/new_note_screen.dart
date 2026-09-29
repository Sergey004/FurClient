import 'package:flutter/material.dart';
import '../services/fa_client.dart';
import '../utils/haptics.dart';
import '../widgets/adaptive/adaptive.dart';

/// Композ нового нотеса: to + subject + message → sendNote
/// (ключ формы клиент добирает сам со страницы /newpm/<to>).
class NewNoteScreen extends StatefulWidget {
  final FAClient client;
  final String? initialTo;

  const NewNoteScreen({super.key, required this.client, this.initialTo});

  @override
  State<NewNoteScreen> createState() => _NewNoteScreenState();
}

class _NewNoteScreenState extends State<NewNoteScreen> {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Note sent to $to'),
            duration: const Duration(seconds: 2)));
        Navigator.of(context).pop();
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
    return AdaptiveScaffold(
      appBar: AppBar(title: const Text('New note')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
