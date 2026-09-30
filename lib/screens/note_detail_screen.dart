import 'package:material_ui/material_ui.dart';
import 'package:fa_kit/fa_kit.dart' as fa;
import '../services/fa_client.dart';
import '../utils/fa_image_loader.dart';
import '../utils/haptics.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/fur_html_widget.dart';
import '../widgets/adaptive/adaptive.dart';
import 'profile_screen.dart';

/// Страница нотеса: контент + ответ (replyKey из формы на странице).
class NoteDetailScreen extends StatefulWidget {
  final FAClient client;
  final String url;

  const NoteDetailScreen({super.key, required this.client, required this.url});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  fa.FANotePage? _note;
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  final TextEditingController _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final note = await widget.client.getNote(widget.url);
      if (mounted) {
        setState(() {
          _note = note;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendReply() async {
    final note = _note;
    if (note == null || _isSending) return;
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    if (note.answerKey == null || note.answerKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reply form unavailable for this note')));
      return;
    }
    setState(() => _isSending = true);
    try {
      await widget.client.sendNote(
        to: note.author,
        subject: note.title.startsWith('Re:') ? note.title : 'Re: ${note.title}',
        message: text,
        replyKey: note.answerKey,
      );
      FHaptics.success();
      if (mounted) {
        _replyCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reply sent'), duration: Duration(seconds: 2)));
      }
    } catch (e) {
      debugPrint('=== sendReply error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Send failed: $e'), duration: const Duration(seconds: 3)));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _openAuthor(String username) {
    Navigator.of(context).push(
      adaptiveRoute(
        builder: (_) => ProfileScreen(
          client: widget.client,
          session: widget.client.session!,
          targetUsername: username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final note = _note;

    return AdaptiveScaffold(
      appBar: AppBar(title: const Text('Note')),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading note...')
          : _error != null
              ? ErrorView(message: _error!, onRetry: _load)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note!.title,
                          style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: note.author.isNotEmpty
                            ? () => _openAuthor(note.author)
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (note.author.isNotEmpty) ...[
                                FAAvatar(username: note.author, size: 30),
                                const SizedBox(width: 8),
                                Text(note.displayAuthor,
                                    style: TextStyle(
                                        color: colors.primary, fontSize: 14)),
                              ],
                              const Spacer(),
                              Text(note.naturalDatetime,
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12.5)),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: FurHtmlWidget(
                          note.htmlMessageWithoutWarning,
                          style: TextStyle(
                              color: colors.onSurface,
                              fontSize: 14,
                              height: 1.55),
                        ),
                      ),
                      if (note.answerKey != null) ...[
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _replyCtrl,
                                minLines: 1,
                                maxLines: 5,
                                style: TextStyle(
                                    color: colors.onSurface, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Write a reply...',
                                  hintStyle: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 14),
                                  filled: true,
                                  fillColor: colors.surfaceContainerLow,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _isSending
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2)),
                                  )
                                : IconButton.filled(
                                    onPressed: _sendReply,
                                    icon: const Icon(Icons.send),
                                  ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 20),
                        Text('Reply form unavailable for this note.',
                            style: TextStyle(
                                color: colors.onSurfaceVariant, fontSize: 13)),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}
