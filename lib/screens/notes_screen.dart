import 'package:material_ui/material_ui.dart';
import 'package:fa_kit/fa_kit.dart' as fa;
import '../services/fa_client.dart';
import '../utils/fa_image_loader.dart';
import '../utils/haptics.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/adaptive/adaptive.dart';
import 'note_detail_screen.dart';
import 'new_note_screen.dart';

/// Инбокс нотесов (PM). Чтение — в NoteDetailScreen; композ для ответа
/// живёт там же (replyKey из страницы нотеса).
class NotesScreen extends StatefulWidget {
  final FAClient client;

  const NotesScreen({super.key, required this.client});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<fa.FANotePreview> _notes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {});
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final notes = await widget.client.getNotes();
      if (mounted) {
        setState(() {
          _notes = notes;
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

  void _openNote(fa.FANotePreview note) async {
    await Navigator.of(context).push(
      adaptiveRoute(
        builder: (_) => NoteDetailScreen(
          client: widget.client,
          url: note.noteUrl.toString(),
        ),
      ),
    );
    // Прочитанное на сервере — обновляем список (unread-флаги).
    if (mounted) _loadNotes(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AdaptiveScaffold(
      appBar: AppBar(title: const Text('Notes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => NewNoteSheet.show(context, widget.client),
        child: const Icon(Icons.edit_outlined),
      ),
      body: _isLoading
          ? const LoadingIndicator(message: 'Loading notes...')
          : _error != null
              ? ErrorView(message: _error!, onRetry: () => _loadNotes())
              : RefreshIndicator(
                  color: colors.primary,
                  onRefresh: () => _loadNotes(isRefresh: true),
                  child: _notes.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                              height: MediaQuery.sizeOf(context).height * 0.6,
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.mail_outline,
                                        color: colors.onSurfaceVariant,
                                        size: 48),
                                    const SizedBox(height: 16),
                                    Text('No notes',
                                        style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: _notes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final note = _notes[index];
                            return _noteTile(context, note, colors);
                          },
                        ),
                ),
    );
  }

  Widget _noteTile(
      BuildContext context, fa.FANotePreview note, ColorScheme colors) {
    final unread = note.unread;
    return Card(
      color: unread
          ? colors.surfaceContainerHighest
          : colors.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: FAAvatar(username: note.author, size: 42),
        title: Text(
          note.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.onSurface,
            fontSize: 14.5,
            fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${note.displayAuthor.isNotEmpty ? note.displayAuthor : note.author}'
          ' · ${note.naturalDatetime}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
        ),
        trailing: unread
            ? Container(
                width: 10,
                height: 10,
                decoration:
                    BoxDecoration(color: colors.primary, shape: BoxShape.circle),
              )
            : null,
        onTap: () {
          FHaptics.light();
          _openNote(note);
        },
      ),
    );
  }
}
