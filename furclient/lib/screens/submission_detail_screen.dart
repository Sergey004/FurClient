import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';

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
        builder: (_) => _ProfilePlaceholder(username: username, client: widget.client),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: AppColors.textDim, fontSize: 14)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadSubmission, child: const Text('Retry')),
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final sub = _submission!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          backgroundColor: AppColors.bg,
          foregroundColor: AppColors.text,
          elevation: 0,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sub.imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: sub.imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => Container(
                    height: 300,
                    color: AppColors.bgInput,
                    child: const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: AppColors.bgInput,
                    child: const Icon(Icons.broken_image, color: AppColors.textMuted, size: 48),
                  ),
                )
              else
                Container(
                  height: 200,
                  color: AppColors.bgInput,
                  child: const Center(child: Icon(Icons.image, color: AppColors.textMuted, size: 48)),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: sub.author.isNotEmpty ? () => _navigateToProfile(sub.author) : null,
                      child: Text(
                        sub.author.isNotEmpty ? sub.author : 'Unknown',
                        style: const TextStyle(
                          color: AppColors.accentLight,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _statChip(Icons.visibility, '${sub.views}', 'Views'),
                        const SizedBox(width: 12),
                        _statChip(Icons.favorite, '${sub.faves}', 'Faves'),
                        const SizedBox(width: 12),
                        _statChip(Icons.comment, '${sub.commentsCount}', 'Comments'),
                      ],
                    ),
                    if (sub.description.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text('Description', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text(
                        sub.description,
                        style: const TextStyle(color: AppColors.textDim, fontSize: 14, height: 1.6),
                      ),
                    ],
                    if (sub.tags.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Text('Tags', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sub.tags.map((tag) {
                          return Chip(
                            label: Text(tag),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text('Comments', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (_isLoadingComments)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
                        ),
                      )
                    else if (_comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No comments yet', style: TextStyle(color: AppColors.textMuted, fontSize: 14))),
                      )
                    else
                      ..._comments.map((comment) => _buildComment(comment)),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textDim),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                ? CachedNetworkImageProvider(comment.avatarUrl)
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
                      style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      comment.time,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(color: AppColors.textDim, fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePlaceholder extends StatelessWidget {
  final String username;
  final FAClient client;
  const _ProfilePlaceholder({required this.username, required this.client});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(username)),
      body: Center(
        child: Text('Profile: $username', style: const TextStyle(color: AppColors.textDim)),
      ),
    );
  }
}
