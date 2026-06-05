import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../widgets/adaptive/adaptive.dart';
import '../widgets/caption_buttons.dart';
import '../utils/platform_utils.dart';
import '../utils/fa_image_loader.dart';
import 'profile_screen.dart';

/// Native screen for viewing a journal's full content and comments.
class JournalDetailScreen extends StatefulWidget {
  final FAClient client;
  final String journalId;

  const JournalDetailScreen({
    super.key,
    required this.client,
    required this.journalId,
  });

  @override
  State<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends State<JournalDetailScreen> {
  FAJournal? _journal;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadJournal();
  }

  Future<void> _loadJournal() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final journal = await widget.client.getJournal(widget.journalId);
      if (mounted) {
        setState(() {
          _journal = journal;
          _isLoading = false;
          if (journal == null) {
            _error = 'Failed to parse journal page';
          }
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
          client: widget.client,
          session: widget.client.session!,
          targetUsername: username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isWindows) {
      return fluent.ScaffoldPage(
        content: Column(
          children: [
            _buildWindowTitleBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }

    return AdaptiveScaffold(
      appBar: AppBar(title: Text(_journal?.title ?? 'Journal')),
      body: _buildBody(),
    );
  }

  /// Custom title bar for Windows — always visible, supports drag.
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
      title: _journal != null
          ? Text(
              _journal!.title,
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

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: AdaptiveProgress());
    }
    if (_error != null || _journal == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.danger, size: 48),
              const SizedBox(height: 16),
              Text(
                _error ?? 'Failed to load journal',
                style: const TextStyle(
                    color: AppColors.textDim, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              AdaptiveButton(
                  label: 'Retry', onPressed: _loadJournal),
            ],
          ),
        ),
      );
    }
    return _buildContent();
  }

  Widget _buildContent() {
    final j = _journal!;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──────────────────────────────────────────────────
          Text(
            j.title,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),

          // ── Author (clickable) + date ─────────────────────────────
          Row(
            children: [
              if (j.author.isNotEmpty) ...[
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _navigateToProfile(j.author),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.bgInput,
                          child: Text(
                            j.author[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.fluentCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          j.author,
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
                const SizedBox(width: 12),
              ],
              if (j.date.isNotEmpty)
                Text(
                  j.date,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: AppColors.border),
          const SizedBox(height: 16),

          // ── Journal body ───────────────────────────────────────────
          const Text(
            'Journal',
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
              j.content,
              style: const TextStyle(
                color: AppColors.textDim,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),

          // ── Comments ──────────────────────────────────────────────
          if (j.comments.isNotEmpty) ...[
            const SizedBox(height: 24),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.materialGreenBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${j.comments.length}',
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
            ...j.comments.map((c) => _buildComment(c)),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildComment(FAComment comment) {
    final indent = (comment.indentLevel.clamp(0, 4)) * 24.0;
    final isClickable = comment.author.isNotEmpty &&
        comment.author != 'Anonymous';

    return Padding(
      padding: EdgeInsets.only(bottom: 16, left: indent),
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
                    errorWidget: const Icon(Icons.person,
                        size: 18, color: AppColors.textMuted),
                  )
                : const Icon(Icons.person,
                    size: 18, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
