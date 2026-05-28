import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../services/fa_urls.dart';
import '../screens/profile_screen.dart';
import '../widgets/adaptive/adaptive.dart';

const _imageHeaders = {'Referer': FAUrls.baseUrl};

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
  bool _isLoadingComments = false;
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
      final submission = await widget.client.getSubmission(widget.submissionId);
      if (mounted) {
        setState(() {
          _submission = submission;
          _isLoading = false;
        });
        _loadComments();
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

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    try {
      final comments = await widget.client.getComments(widget.submissionId);
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoadingComments = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingComments = false);
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

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;

  return AdaptiveScaffold(
    backgroundColor: AppColors.bg,
    body: _isLoading
    ? const Center(child: AdaptiveProgress())
    : _error != null
      ? Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.danger, size: 48),
                const SizedBox(height: 16),
                Text(_error!,
                    style: const TextStyle(
                        color: AppColors.textDim, fontSize: 14),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                AdaptiveButton(
                  label: 'Retry',
                  onPressed: _loadSubmission,
                ),
              ],
            ),
          ),
        )
              : _buildContent(isDesktop),
    );
  }

  Widget _buildContent(bool isDesktop) {
    final sub = _submission!;

    if (isDesktop) {
      return _buildDesktopLayout(sub);
    }
    return _buildMobileLayout(sub);
  }

  Widget _buildDesktopLayout(Submission sub) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: _buildImageSection(sub),
        ),
        Container(width: 1, color: AppColors.border),
        Expanded(
          flex: 2,
          child: _buildDetailsPanel(sub),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(Submission sub) {
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

  Widget _buildImageSection(Submission sub) {
    return Container(
      color: AppColors.bgDeep,
      child: sub.imageUrl.isNotEmpty
        ? CachedNetworkImage(
          imageUrl: sub.imageUrl,
          httpHeaders: _imageHeaders,
          fit: BoxFit.contain,
              placeholder: (context, url) => Container(
                height: 300,
                color: AppColors.bgInput,
        child: const Center(
          child: AdaptiveProgress(strokeWidth: 2)),
              ),
              errorWidget: (context, url, error) => Container(
                height: 200,
                color: AppColors.bgInput,
                child: const Icon(Icons.broken_image,
                    color: AppColors.textMuted, size: 48),
              ),
            )
          : Container(
              height: 200,
              color: AppColors.bgInput,
              child: const Center(
                  child:
                      Icon(Icons.image, color: AppColors.textMuted, size: 48)),
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
          GestureDetector(
            onTap: sub.author.isNotEmpty
                ? () => _navigateToProfile(sub.author)
                : null,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.bgInput,
                  child: Text(
                    sub.author.isNotEmpty ? sub.author[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: AppColors.fluentCyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
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
          const SizedBox(height: 16),
          Row(
            children: [
              _statChip(Icons.visibility, '${sub.views}', 'Views',
                  AppColors.fluentCyan),
              const SizedBox(width: 8),
              _statChip(
                  Icons.favorite, '${sub.faves}', 'Faves', AppColors.notifFave),
              const SizedBox(width: 8),
              _statChip(Icons.comment, '${sub.commentsCount}', 'Comments',
                  AppColors.materialGreen),
            ],
          ),
          if (sub.description.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            const Text('Description',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
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
                    color: AppColors.textDim, fontSize: 14, height: 1.6),
              ),
            ),
          ],
          if (sub.tags.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            const Text('Tags',
                style: TextStyle(
                    color: AppColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sub.tags.map((tag) {
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
                        fontWeight: FontWeight.w500),
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
              const Text('Comments',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.materialGreenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_comments.length}',
                  style: const TextStyle(
                      color: AppColors.materialGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingComments)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
        child: AdaptiveProgress(strokeWidth: 2),
              ),
            )
          else if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                  child: Text('No comments yet',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 14))),
            )
          else
            ..._comments.map((comment) => _buildComment(comment)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label, Color color) {
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
          Text(value,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(label,
              style:
                  TextStyle(color: color.withValues(alpha: 0.7), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildComment(FAComment comment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.bgInput,
              backgroundImage: comment.avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(comment.avatarUrl,
                      httpHeaders: _imageHeaders)
                  : null,
            child: comment.avatarUrl.isEmpty
                ? const Icon(Icons.person, size: 18, color: AppColors.textMuted)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.author,
                      style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
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
                      color: AppColors.textDim, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
