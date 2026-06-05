import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:window_manager/window_manager.dart';
import '../widgets/caption_buttons.dart';
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
      final result = await widget.client.getSubmissionWithComments(widget.submissionId);
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
      MaterialPageRoute(
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
      success = await widget.client.toggleFavorite(sub.favoriteUrl);
      if (mounted && success) {
        setState(() {
          // Toggle local state: swap between /fav/ and /unfav/
          final wasFav = sub.isFavorite;
          final sid = sub.id;
          _submission = Submission(
            id: sub.id,
            title: sub.title,
            author: sub.author,
            category: sub.category,
            imageUrl: sub.imageUrl,
            views: sub.views,
            faves: sub.faves + (wasFav ? -1 : 1),
            commentsCount: sub.commentsCount,
            description: sub.description,
            tags: sub.tags,
            date: sub.date,
            isNsfw: sub.isNsfw,
            rating: sub.rating,
            url: sub.url,
            isFavorite: !wasFav,
            favoriteUrl: wasFav ? '/fav/$sid/' : '/unfav/$sid/',
          );
        });
      }
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to toggle favorite'),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      debugPrint('=== toggleFavorite error: $e');
    } finally {
      if (mounted) setState(() => _isFaving = false);
    }

    // Auto-download on fave
    if (success && mounted) {
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
    }
  }

  Future<void> _downloadImage() async {
    final sub = _submission;
    if (sub == null || sub.imageUrl.isEmpty || _isDownloading) return;
    setState(() => _isDownloading = true);
    try {
      final path = await DownloadService.instance.downloadImage(
        imageUrl: sub.imageUrl,
        title: sub.title,
        author: sub.author,
        rating: sub.rating,
      );
      if (mounted) {
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved: ${path.split('/').last}'),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.materialGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download failed'),
              duration: Duration(seconds: 2),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('=== downloadImage error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 2),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;

    if (isWindows) {
      // On Windows: use a custom title bar so it persists when
      // this screen is pushed on top of FluentShell
      return fluent.ScaffoldPage(
        content: Column(
          children: [
            _buildWindowTitleBar(),
            Expanded(child: _buildBody(isDesktop)),
          ],
        ),
      );
    }

    return AdaptiveScaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: _buildBody(isDesktop),
      ),
    );
  }

  /// Custom title bar for Windows — always visible, supports drag.
  /// Uses the same pattern as FluentShell: fluent.TitleBar with onDragStarted.
  Widget _buildWindowTitleBar() {
    return fluent.TitleBar(
      isBackButtonVisible: false,
      icon: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(fluent.FluentIcons.back, size: 14),
              SizedBox(width: 6),
              Text('Back', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
      title: _submission != null
          ? Text(
              _submission!.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            )
          : const Text('Loading...', style: TextStyle(fontSize: 13)),
      captionControls: SizedBox(
        width: 138,
        height: 46,
        child: CaptionButtons(
          brightness: fluent.FluentTheme.of(context).brightness,
        ),
      ),
      onDragStarted: () => windowManager.startDragging(),
      onDoubleTap: () async {
        final isMax = await windowManager.isMaximized();
        if (isMax) {
          windowManager.restore();
        } else {
          windowManager.maximize();
        }
      },
    );
  }

  Widget _buildBody(bool isDesktop) {
    if (_isLoading) return const Center(child: AdaptiveProgress());
    if (_error != null) return _buildError();
    if (_submission == null) return _buildError();
    return _buildContent(isDesktop);
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.textDim, fontSize: 14),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: _buildImageSection(sub)),
        Container(width: 1, color: AppColors.border),
        Expanded(flex: 2, child: _buildDetailsPanel(sub)),
      ],
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
                icon: const Icon(Icons.arrow_back, color: AppColors.text),
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
          color: AppColors.bgDeep,
          child: sub.imageUrl.isNotEmpty
              ? FAImage(
                  url: sub.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: Container(
                    height: 300,
                    color: AppColors.bgInput,
                    child: const Center(
                      child: AdaptiveProgress(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: Container(
                    height: 200,
                    color: AppColors.bgInput,
                    child: const Icon(
                      Icons.broken_image,
                      color: AppColors.textMuted,
                      size: 48,
                    ),
                  ),
                )
              : Container(
                  height: 200,
                  color: AppColors.bgInput,
                  child: const Center(
                    child:
                        Icon(Icons.image, color: AppColors.textMuted, size: 48),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanel(Submission sub) {
    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.desktop;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sub.title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: isDesktop ? 24 : 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          // Author name — clickable with hover cursor
          MouseRegion(
            cursor: sub.author.isNotEmpty
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: sub.author.isNotEmpty
                  ? () => _navigateToProfile(sub.author)
                  : null,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.bgInput,
                    child: Text(
                      sub.author.isNotEmpty
                          ? sub.author[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.fluentCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sub.author.isNotEmpty ? sub.author : 'Unknown',
                    style: const TextStyle(
                      color: AppColors.fluentCyan,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
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
                        AppColors.fluentCyan),
                    _statChip(Icons.comment, '${sub.commentsCount}', 'Comments',
                        AppColors.materialGreen),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Download button — hover cursor
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _isDownloading ? null : _downloadImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _isDownloading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.fluentCyan,
                            ),
                          )
                        : const Icon(
                            Icons.download,
                            size: 16,
                            color: AppColors.textDim,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Fave button — hover cursor
              MouseRegion(
                cursor: _isFaving ? SystemMouseCursors.wait : SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _isFaving ? null : _toggleFavorite,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sub.isFavorite
                          ? AppColors.notifFave.withValues(alpha: 0.15)
                          : AppColors.bgInput,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sub.isFavorite
                            ? AppColors.notifFave
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isFaving)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.notifFave,
                            ),
                          )
                        else
                          Icon(
                            sub.isFavorite ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: sub.isFavorite
                                ? AppColors.notifFave
                                : AppColors.textDim,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          '${sub.faves}',
                          style: TextStyle(
                            color: sub.isFavorite
                                ? AppColors.notifFave
                                : AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (sub.description.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              'Description',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                sub.description,
                style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ],
          if (sub.tags.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            const Text(
              'Tags',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sub.tags.map((tag) {
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _navigateToSearch(tag),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.materialLavenderBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.materialLavender.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AppColors.materialLavender,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                'Comments',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.materialGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_comments.length}',
                  style: const TextStyle(
                    color: AppColors.materialGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No comments yet',
                  style: TextStyle(
                    color: AppColors.textMuted,
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

  Widget _statChip(
      IconData icon, String value, String label, Color color) {
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
            style: const TextStyle(
              color: AppColors.text,
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
    // Indent replies visually (max 4 levels, 24px each)
    final indent = (comment.indentLevel.clamp(0, 4)) * 24.0;
    final isClickable = comment.author.isNotEmpty && comment.author != 'Anonymous';
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
            backgroundColor: AppColors.bgInput,
            child: comment.avatarUrl.isNotEmpty
                ? FAImage(
                    url: comment.avatarUrl,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorWidget: const Icon(
                      Icons.person,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  )
                : const Icon(
                    Icons.person,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Comment author — clickable with hover cursor
                    MouseRegion(
                      cursor: isClickable
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: GestureDetector(
                        onTap: isClickable
                            ? () => _navigateToProfile(comment.author)
                            : null,
                        child: Text(
                          comment.author,
                          style: TextStyle(
                            color: isClickable
                                ? AppColors.fluentCyan
                                : AppColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.time,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: AppColors.textDim,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
