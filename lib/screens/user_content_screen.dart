import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../widgets/submission_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/adaptive/adaptive.dart';
import 'submission_detail_screen.dart';
import 'journal_detail_screen.dart';

/// What kind of user content to display.
enum UserContentType {
  gallery,
  favorites,
  journals,
}

/// Native screen for viewing a user's gallery, favorites, or journals.
class UserContentScreen extends StatefulWidget {
  final FAClient client;
  final String username;
  final UserContentType contentType;
  final String? title;

  const UserContentScreen({
    super.key,
    required this.client,
    required this.username,
    required this.contentType,
    this.title,
  });

  @override
  State<UserContentScreen> createState() => _UserContentScreenState();
}

class _UserContentScreenState extends State<UserContentScreen> {
  List<Submission> _submissions = [];
  List<FAJournalPreview> _journals = [];
  int _currentPage = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadContent();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  String get _pageTitle {
    if (widget.title != null) return widget.title!;
    final user = widget.username;
    switch (widget.contentType) {
      case UserContentType.gallery:
        return '$user\'s Gallery';
      case UserContentType.favorites:
        return '$user\'s Favorites';
      case UserContentType.journals:
        return '$user\'s Journals';
    }
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _submissions = [];
      _journals = [];
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      switch (widget.contentType) {
        case UserContentType.gallery:
          _submissions = await widget.client.getGallery(widget.username);
          break;
        case UserContentType.favorites:
          _submissions = await widget.client.getUserFavorites(widget.username);
          break;
        case UserContentType.journals:
          _journals = await widget.client.getUserJournals(widget.username);
          break;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasMore = widget.contentType == UserContentType.journals
              ? false
              : _submissions.isNotEmpty;
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

  Future<void> _loadMore() async {
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    if (widget.contentType == UserContentType.journals) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    try {
      final more = widget.contentType == UserContentType.gallery
          ? await widget.client.getGallery(widget.username, page: _currentPage)
          : await widget.client.getUserFavorites(
              widget.username, page: _currentPage);
      if (mounted) {
        setState(() {
          _submissions.addAll(more);
          _isLoadingMore = false;
          _hasMore = more.isNotEmpty;
        });
      }
    } catch (_) {
      _currentPage--;
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async => _loadContent();

  void _navigateToDetail(Submission submission) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubmissionDetailScreen(
          client: widget.client,
          submissionId: submission.id,
          sfwMode: false,
        ),
      ),
    );
  }

  void _navigateToJournal(FAJournalPreview journal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JournalDetailScreen(
          client: widget.client,
          journalId: journal.id,
        ),
      ),
    );
  }

  int _getCrossAxisCount(double width) {
    if (width >= 1200) return 5;
    if (width >= 900) return 4;
    if (width >= AppBreakpoints.desktop) return 3;
    if (width >= AppBreakpoints.tablet) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading...');
    }
    if (_error != null) {
      return ErrorView(
        message: _error!,
        onRetry: _loadContent,
      );
    }

    switch (widget.contentType) {
      case UserContentType.gallery:
      case UserContentType.favorites:
        return _buildSubmissionGrid();
      case UserContentType.journals:
        return _buildJournalList();
    }
  }

  // ── Submissions grid (gallery / favorites) ─────────────────────────

  Widget _buildSubmissionGrid() {
    if (_submissions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.photo_library_outlined,
                  color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              Text('No submissions found',
                  style: TextStyle(color: AppColors.textDim, fontSize: 16)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadContent,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.fluentCyan,
      backgroundColor: AppColors.bgCard,
      onRefresh: _onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);
          final isDesktop = constraints.maxWidth >= AppBreakpoints.desktop;

          return GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: isDesktop ? 0.7 : 0.65,
              crossAxisSpacing: isDesktop ? 16 : 12,
              mainAxisSpacing: isDesktop ? 16 : 12,
            ),
            itemCount: _submissions.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _submissions.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              return SubmissionCard(
                submission: _submissions[index],
                client: widget.client,
                sfwMode: false,
                onTap: () =>
                    _navigateToDetail(_submissions[index]),
              );
            },
          );
        },
      ),
    );
  }

  // ── Journals list ───────────────────────────────────────────────────

  Widget _buildJournalList() {
    if (_journals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.book_outlined,
                  color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              Text('No journals found',
                  style: TextStyle(color: AppColors.textDim, fontSize: 16)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadContent,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.fluentCyan,
      backgroundColor: AppColors.bgCard,
      onRefresh: _onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _journals.length,
        separatorBuilder: (_, __) =>
            const Divider(color: AppColors.border, height: 1),
        itemBuilder: (context, index) {
          final j = _journals[index];
          return _journalTile(j);
        },
      ),
    );
  }

  Widget _journalTile(FAJournalPreview j) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _navigateToJournal(j),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                j.title,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (j.date.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  j.date,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
