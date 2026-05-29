import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../screens/profile_screen.dart';
import '../widgets/adaptive/adaptive.dart';
import '../utils/platform_utils.dart';
import '../utils/fa_image_loader.dart';

class SubmissionDetailScreen extends StatefulWidget {

  final OnlineFASession session;
  final FASubmissionPreview submission;
  final bool sfwMode;

  const SubmissionDetailScreen({
    super.key,
    required this.session,
    required this.submission,
    this.sfwMode = false,
  });

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  FASubmission? _submission;
  bool _isLoading = true;
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
      final submission =
          await widget.session.submissionForPreview(widget.submission);
      if (mounted) {
        setState(() {
          _submission = submission;
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

  void _navigateToProfile(String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          session: widget.session,
          targetUsername: username,
        ),
      ),
    );
  }

  List<FAComment> _flattenComments() {
    final result = <FAComment>[];
    if (_submission == null) return result;
    for (final comment in _submission!.comments) {
      comment.recursiveForEach(result.add);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;

    if (isWindows) {
      return fluent.ScaffoldPage(
        content: _buildBody(isDesktop),
      );
    }

    return AdaptiveScaffold(
      backgroundColor: AppColors.bg,
      body: _buildBody(isDesktop),
    );
  }

  Widget _buildBody(bool isDesktop) {
    if (_isLoading) return const Center(child: AdaptiveProgress());
    if (_error != null) return _buildError();
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

  Widget _buildDesktopLayout(FASubmission sub) {
    return Column(
      children: [
        _buildDesktopTopBar(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildImageSection(sub)),
              Container(width: 1, color: AppColors.border),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: AppColors.text),
            tooltip: 'Back',
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(FASubmission sub) {
    return CustomScrollView(
      slivers: [
        const SliverAppBar(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.text,
          elevation: 0,
          pinned: true,
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

  Widget _buildImageSection(FASubmission sub) {
    final imageUrl = (sub.fullResolutionMediaUrl ?? sub.previewImageUrl).toString();
    return Container(
      color: AppColors.bgDeep,
      child: imageUrl.isNotEmpty
          ? FAImage(
              url: imageUrl,
              fit: BoxFit.contain,
              mode: ExtendedImageMode.gesture,
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
                child: Icon(Icons.image, color: AppColors.textMuted, size: 48),
              ),
            ),
    );
  }

  Widget _buildDetailsPanel(FASubmission sub) {
    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.desktop;
    final author = sub.metadata.author;
    final flatComments = _flattenComments();

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sub.metadata.title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: isDesktop ? 24 : 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: author.isNotEmpty
                ? () => _navigateToProfile(author)
                : null,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.bgInput,
                  child: Text(
                    author.isNotEmpty
                        ? author[0].toUpperCase()
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
                  author.isNotEmpty ? author : 'Unknown',
                  style: const TextStyle(
                    color: AppColors.fluentCyan,
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
              _statChip(Icons.visibility, '${sub.metadata.viewCount}', 'Views',
                  AppColors.fluentCyan),
              const SizedBox(width: 8),
              _statChip(Icons.favorite, '${sub.metadata.favoriteCount}', 'Faves',
                  AppColors.notifFave),
              const SizedBox(width: 8),
              _statChip(Icons.comment, '${sub.metadata.commentCount}', 'Comments',
                  AppColors.materialGreen),
            ],
          ),
          if (sub.htmlDescription.isNotEmpty) ...[
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
                _stripHtml(sub.htmlDescription),
                style: const TextStyle(
                  color: AppColors.textDim,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          ],
          if (sub.metadata.keywords.isNotEmpty) ...[
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
              children: sub.metadata.keywords.map((tag) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.materialLavenderBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: AppColors.materialLavender,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
                  '${flatComments.length}',
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
          if (flatComments.isEmpty)
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
            ...flatComments.map((c) => _buildComment(c)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
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
    final visible = comment is FAVisibleComment ? comment : null;
    final author = visible?.author ?? 'Hidden';
    final time = visible?.naturalDatetime ?? '';
    final text = _stripHtml(comment.htmlMessage);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.bgInput,
            child: visible != null
                ? const Icon(
                    Icons.person,
                    size: 18,
                    color: AppColors.textMuted,
                  )
                : const Icon(
                    Icons.block,
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
                    Text(
                      author,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  text,
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
