import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/fa_client.dart';
import '../screens/profile_screen.dart';
import '../widgets/adaptive/adaptive.dart';
import '../utils/platform_utils.dart';
import '../utils/fa_image_loader.dart';
import '../widgets/fullscreen_image_viewer.dart';
import '../services/download_service.dart';
import '../services/search_history.dart';
import '../widgets/flash_player_widget.dart';
import '../widgets/fur_html_widget.dart';
//import '../utils/notifications.dart';

class SubmissionDetailScreen extends StatefulWidget {
  final FAClient client;
  final String submissionId;
  final bool sfwMode;

  const SubmissionDetailScreen({
    super.key,
    required this.client,
    required this.submissionId,
    this.sfwMode = false,
  });

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  Submission? _submission;
  List<FAComment> _comments = [];
  bool _isLoading = true;
  bool _isFaving = false;
  bool _isDownloading = false;
  bool _isSendingComment = false;
  final TextEditingController _commentCtrl = TextEditingController();

  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSubmission();
  }

  Future<void> _loadSubmission() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Single fetch for both submission details and comments
      final result =
          await widget.client.getSubmissionWithComments(widget.submissionId);
      if (mounted) {
        setState(() {
          _submission = result.submission;
          _comments = result.comments;
          _isLoading = false;
        });
        debugPrint('=== Comments: parsed ${result.comments.length} comments');
        for (final c in result.comments) {
          debugPrint('=== Comment: ${c.author}: ${c.text.length} chars');
        }
        if (_submission == null) {
          setState(() {
            _error = 'Failed to parse submission page. Empty or invalid HTML.';
          });
        }
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

  void _navigateToProfile(String username) {
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

  void _navigateToSearch(String query) {
    // Go back to main shell and trigger search in the Search tab
    Navigator.of(context).popUntil((route) => route.isFirst);
    SearchHistory.triggerSearch(query);
  }

  Future<void> _toggleFavorite() async {
    final sub = _submission;
    if (sub == null || sub.favoriteUrl.isEmpty || _isFaving) return;
    setState(() => _isFaving = true);
    bool success = false;
    try {
      final updated =
          await widget.client.toggleFavorite(sub.favoriteUrl, sub.id);
      if (mounted && updated != null) {
        success = true;
        setState(() {
          // Use server-parsed state: isFavorite, faves, and the fresh
          // favoriteUrl (with updated ?key=) so a second toggle works.
          _submission = Submission(
            id: sub.id,
            title: sub.title,
            author: sub.author,
            category: sub.category,
            imageUrl: sub.imageUrl,
            views: sub.views,
            faves: updated.faves,
            commentsCount: sub.commentsCount,
            description: sub.description,
            tags: sub.tags,
            date: sub.date,
            isNsfw: sub.isNsfw,
            rating: sub.rating,
            url: sub.url,
            isFavorite: updated.isFavorite,
            favoriteUrl: updated.favoriteUrl,
          );
        });
      }
    } catch (e) {
      debugPrint('=== toggleFavorite error: $e');
    } finally {
      if (mounted) setState(() => _isFaving = false);
    }

    // Auto-download on fave
    if (success && mounted) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final autoDownload = prefs.getBool('auto_download_on_fave') ?? false;
        if (autoDownload) {
          await _downloadImage();
        }
        // Auto-close on fave (check mounted again after async download)
        final autoClose = prefs.getBool('auto_close_on_fave') ?? true;
        if (autoClose && mounted) {
          Navigator.of(context).maybePop();
        }
      } catch (e) {
        debugPrint('=== post-fave auto actions error: $e');
      }
    }
  }

  void _showMessage(String message, Color color) {
    try {
      if (isWindows) {
        fluent.displayInfoBar(context, builder: (_, close) {
          return fluent.InfoBar(
            title: Text(message),
            severity: color == AppColors.materialGreen
                ? fluent.InfoBarSeverity.success
                : fluent.InfoBarSeverity.error,
            onClose: close,
          );
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
            backgroundColor: color,
          ),
        );
      }
    } catch (e) {
      debugPrint('=== _showMessage error: $e');
    }
  }

  FAComment? _findCommentById(List<FAComment> comments, String id) {
    for (final c in comments) {
      if (c.id == id) return c;
      final found = _findCommentById(c.replies, id);
      if (found != null) return found;
    }
    return null;
  }

  Future<void> _showCommentEditor({int? parentCid}) async {
    _commentCtrl.clear();
    final parentComment = parentCid != null
        ? _findCommentById(_comments, parentCid.toString())
        : null;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          bottom: false,
          minimum: const EdgeInsets.only(top: 8, bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    Flexible(
                      child: Text(
                        parentComment != null ? 'Reply' : 'Comment',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                    IconButton(
                      icon: _isSendingComment
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : Icon(Icons.send,
                              size: 20,
                              color: Theme.of(context).colorScheme.onSurface),
                      onPressed:
                          _isSendingComment || _commentCtrl.text.trim().isEmpty
                              ? null
                              : () => _submitComment(ctx, parentCid),
                    ),
                  ],
                ),
                if (parentComment != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: IgnorePointer(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            child: parentComment.avatarUrl.isNotEmpty
                                ? FAImage(
                                    url: parentComment.avatarUrl,
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.cover,
                                  )
                                : Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  parentComment.author,
                                  style: TextStyle(
                                    color: parentComment.author.isNotEmpty &&
                                            parentComment.author != 'Anonymous'
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  parentComment.text,
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Expanded(
                  child: TextField(
                    controller: _commentCtrl,
                    maxLines: null,
                    minLines: 3,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      filled: true,
                      fillColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitComment(BuildContext ctx, int? parentCid) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _submission == null) return;
    setState(() => _isSendingComment = true);
    try {
      final success = await widget.client.postComment(
        _submission!.url,
        text,
        replyToCid: parentCid,
      );
      if (success) {
        _commentCtrl.clear();
        Navigator.of(ctx).pop();
        _showMessage('Comment posted', AppColors.materialGreen);
        await _loadSubmission();
      } else {
        _showMessage('Failed to post comment', AppColors.danger);
      }
    } catch (e) {
      debugPrint('=== postComment error: $e');
      _showMessage('Error: $e', AppColors.danger);
    } finally {
      if (mounted) setState(() => _isSendingComment = false);
    }
  }

  Future<void> _downloadImage() async {
    await _saveImage();
  }

  Future<String?> _saveImage() async {
    final sub = _submission;
    if (sub == null || sub.imageUrl.isEmpty || _isDownloading) return null;
    setState(() => _isDownloading = true);
    String? path;
    try {
      path = await DownloadService.instance.downloadImage(
        imageUrl: sub.imageUrl,
        title: sub.title,
        author: sub.author,
        rating: sub.rating,
      );
      if (mounted) {
        if (path != null) {
          _showMessage(
              'Saved: ${path.split('/').last}', AppColors.materialGreen);
        } else {
          _showMessage('Download failed', AppColors.danger);
        }
      }
    } catch (e) {
      debugPrint('=== downloadImage error: $e');
      if (mounted) {
        _showMessage('Error: $e', AppColors.danger);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
    return path;
  }

  Future<void> _shareLink() async {
    final sub = _submission;
    if (sub == null || sub.url.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(
        uri: Uri.tryParse(sub.url),
        subject: sub.title,
      ),
    );
  }

  Future<void> _shareImage() async {
    final path = await _saveImage();
    if (path == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: _submission?.title,
      ),
    );
  }

  Future<void> _openInBrowser() async {
    final sub = _submission;
    if (sub == null || sub.url.isEmpty) return;
    final uri = Uri.tryParse(sub.url);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _showActionMenu(Submission sub) async {
    final colorScheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser),
              title: const Text('Open in browser'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openInBrowser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Share link'),
              onTap: () {
                Navigator.pop(sheetContext);
                _shareLink();
              },
            ),
            if (sub.imageUrl.isNotEmpty) ...[
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Save image'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _saveImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.ios_share_outlined),
                title: const Text('Share image'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _shareImage();
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.comment_outlined),
              title: const Text('Comment'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showCommentEditor(parentCid: null);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;

    if (isWindows) {
      final colorScheme = Theme.of(context).colorScheme;
      final fluentTheme = colorScheme.brightness == Brightness.dark
          ? AppTheme.fluentFromSystemAccent(colorScheme.primary)
          : AppTheme.fluentLightTheme(accent: colorScheme.primary);

      return fluent.FluentTheme(
        data: fluentTheme,
        child: fluent.ScaffoldPage(
          content: _buildBody(isDesktop),
        ),
      );
    }

    return AdaptiveScaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: _buildBody(isDesktop),
      ),
    );
  }

  Widget _buildBody(bool isDesktop) {
    if (_isLoading) return const Center(child: AdaptiveProgress());
    if (_error != null) return _buildError();
    if (_submission == null) return _buildError();
    return _buildContent(isDesktop);
  }

  Widget _buildError() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style:
                  TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            AdaptiveButton(label: 'Retry', onPressed: _loadSubmission),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDesktop) {
    final sub = _submission!;
    if (isDesktop) return _buildDesktopLayout(sub);
    return _buildMobileLayout(sub);
  }

  // ── Desktop layout ────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(Submission sub) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Кнопка назад — только на desktop где нет AppBar
        _buildDesktopTopBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildImageSection(sub)),
              Container(width: 1, color: colorScheme.outlineVariant),
              Expanded(flex: 2, child: _buildDetailsPanel(sub)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopTopBar() {
    if (isWindows) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Row(
          children: [
            fluent.Button(
              onPressed: () => Navigator.of(context).maybePop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  fluent.Icon(fluent.FluentIcons.back, size: 14),
                  SizedBox(width: 6),
                  fluent.Text('Back'),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // macOS / Linux desktop
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(Icons.arrow_back,
                color: Theme.of(context).colorScheme.onSurface),
            tooltip: 'Back',
          ),
        ],
      ),
    );
  }

  // ── Mobile layout ─────────────────────────────────────────────────────────

  Widget _buildMobileLayout(Submission sub) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: Icon(Icons.arrow_back,
                    color: Theme.of(context).colorScheme.onSurface),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(sub),
              _buildDetailsPanel(sub),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared widgets ────────────────────────────────────────────────────────

  Widget _buildImageSection(Submission sub) {
    final colorScheme = Theme.of(context).colorScheme;
    // Flash submission — use Ruffle player instead of image
    if (sub.isFlash && sub.flashUrl.isNotEmpty) {
      return Container(
        color: colorScheme.surfaceContainerLowest,
        child: SizedBox(
          height: 400,
          width: double.infinity,
          child: FlashPlayerWidget(
            swfUrl: sub.flashUrl,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: sub.imageUrl.isNotEmpty
          ? () => FullscreenImageViewer.open(
                context,
                imageUrl: sub.imageUrl,
                title: sub.title,
                author: sub.author,
              )
          : null,
      child: MouseRegion(
        cursor: sub.imageUrl.isNotEmpty
            ? SystemMouseCursors.zoomIn
            : SystemMouseCursors.basic,
        child: Container(
          color: colorScheme.surfaceContainerLowest,
          child: sub.imageUrl.isNotEmpty
              ? FAImage(
                  url: sub.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: Container(
                    height: 300,
                    color: colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: AdaptiveProgress(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: Container(
                    height: 200,
                    color: colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.broken_image,
                      color: colorScheme.onSurfaceVariant,
                      size: 48,
                    ),
                  ),
                )
              : Container(
                  height: 200,
                  color: colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Icon(Icons.image,
                        color: colorScheme.onSurfaceVariant, size: 48),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel(Submission sub) {
    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.desktop;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sub.title,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: isDesktop ? 24 : 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: sub.author.isNotEmpty
                ? () => _navigateToProfile(sub.author)
                : null,
            child: Row(
              children: [
                FAAvatar(username: sub.author, size: 28),
                const SizedBox(width: 8),
                Text(
                  sub.author.isNotEmpty ? sub.author : 'Unknown',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _statChip(Icons.visibility, '${sub.views}', 'Views',
                        colorScheme.primary),
                    _statChip(Icons.comment, '${sub.commentsCount}', 'Comments',
                        colorScheme.secondary),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'More actions',
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showActionMenu(sub),
              ),
              const SizedBox(width: 4),
              // Download button
              GestureDetector(
                onTap: _isDownloading ? null : _downloadImage,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: _isDownloading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: AdaptiveProgress(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      : Icon(
                          Icons.download,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              // Fave button
              GestureDetector(
                onTap: _isFaving ? null : _toggleFavorite,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sub.isFavorite
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sub.isFavorite
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isFaving)
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: AdaptiveProgress(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        )
                      else
                        Icon(
                          sub.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 16,
                          color: sub.isFavorite
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      const SizedBox(width: 6),
                      Text(
                        '${sub.faves}',
                        style: TextStyle(
                          color: sub.isFavorite
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (sub.description.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Description',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: FurHtmlWidget(
                sub.description,
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.6),
              ),
            ),
          ],
          if (sub.tags.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Tags',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sub.tags.map((tag) {
                return GestureDetector(
                  onTap: () => _navigateToSearch(tag),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: colorScheme.onSecondaryContainer,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          Divider(color: colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Comments',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Comment'),
                onPressed: () => _showCommentEditor(parentCid: null),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_comments.length}',
                  style: TextStyle(
                    color: colorScheme.onTertiaryContainer,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_comments.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No comments yet',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ..._comments.map((c) => _buildComment(c)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(FAComment comment) {
    final colorScheme = Theme.of(context).colorScheme;
    // Indent replies visually (max 4 levels, 24px each)
    final indent = (comment.indentLevel.clamp(0, 4)) * 24.0;
    return Padding(
      padding: EdgeInsets.only(
        bottom: 16,
        left: indent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: comment.avatarUrl.isNotEmpty
                ? FAImage(
                    url: comment.avatarUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorWidget: Icon(
                      Icons.person,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : Icon(
                    Icons.person,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: comment.author.isNotEmpty &&
                              comment.author != 'Anonymous'
                          ? () => _navigateToProfile(comment.author)
                          : null,
                      child: Text(
                        comment.author,
                        style: TextStyle(
                          color: comment.author.isNotEmpty &&
                                  comment.author != 'Anonymous'
                              ? AppColors.fluentCyan
                              : colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.time,
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        Icons.reply,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      tooltip: 'Reply',
                      onPressed: () => _showCommentEditor(
                          parentCid: int.tryParse(comment.id)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FurHtmlWidget(
                  comment.text,
                  compact: true,
                  style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
