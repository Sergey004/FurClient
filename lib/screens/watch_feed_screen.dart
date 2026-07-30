import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../widgets/submission_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/adaptive/adaptive.dart';
import 'submission_detail_screen.dart';

/// Watch feed — submissions from artists the logged-in user watches.
///
/// Mirrors FurAffinityApp's `SubmissionsFeedView` backed by
/// `/msg/submissions/`. Like the Swift app, this loads a single batch of the
/// latest 72 submissions (no infinite scroll downward) — pull-to-refresh
/// fetches the latest 72 again and merges any *new* submission ids at the
/// top, leaving the previously seen items in place so the scroll position
/// stays meaningful. Older items can be reached via the `Gallery` tab which
/// uses `/browse/` (page-numbered) instead.
class WatchFeedScreen extends StatefulWidget {
  final FAClient client;
  final bool sfwMode;
  final VoidCallback? onLogout;

  const WatchFeedScreen(
      {super.key, required this.client, this.sfwMode = false, this.onLogout});

  @override
  State<WatchFeedScreen> createState() => _WatchFeedScreenState();
}

class _WatchFeedScreenState extends State<WatchFeedScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  /// Submissions loaded so far, kept across refreshes. New refresh results
  /// are merged at the top (newest-first via descending sid order, matching
  /// FA's listing order).
  List<Submission> _submissions = [];
  bool _isInitialLoading = false;
  bool _isRefreshing = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initialLoad();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialLoad() async {
    if (_isInitialLoading) return;
    setState(() {
      _isInitialLoading = true;
      _error = null;
    });

    try {
      final result = await widget.client.getWatchSubmissions();
      if (mounted) {
        setState(() {
          _submissions = result.submissions;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isInitialLoading = false;
        });
      }
    }
  }

  /// Pull-to-refresh — re-fetches the latest 72 and merges any unseen
  /// submission ids at the top, leaving existing items in place. FA lists
  /// submissions newest-first, so `_submissions` is kept in descending sid
  /// order and any new sid must land before the current top.
  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final result = await widget.client.getWatchSubmissions();
      if (!mounted) return;

      if (_submissions.isEmpty) {
        setState(() {
          _submissions = result.submissions;
          _isRefreshing = false;
        });
        return;
      }

      // Merge: keep only newly fetched submissions whose sid is *newer* than
      // the current top. FA returns sids in descending order, so a simple
      // "newer than the current head" filter is enough.
      final currentTopSid = int.tryParse(_submissions.first.id) ?? 0;
      final fresh = result.submissions
          .where((s) => (int.tryParse(s.id) ?? 0) > currentTopSid);
      if (fresh.isEmpty) {
        setState(() => _isRefreshing = false);
        return;
      }
      setState(() {
        _submissions = [...fresh, ..._submissions];
        _isRefreshing = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _navigateToDetail(Submission submission) {
    Navigator.of(context).push(
      adaptiveRoute(
        builder: (_) => SubmissionDetailScreen(
          client: widget.client,
          submissionId: submission.id,
          sfwMode: widget.sfwMode,
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
    super.build(context);
    return AdaptiveScaffold(
      appBar: AppBar(title: const Text('Watch Feed')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isInitialLoading) {
      return const LoadingIndicator(message: 'Loading watch feed...');
    }

    if (_error != null) {
      return ErrorView(
        message: _error!,
        onRetry: _initialLoad,
        onRelogin: widget.onLogout,
      );
    }

    if (_submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.subscriptions_outlined,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            const Text('Nothing here yet',
                style: TextStyle(color: AppColors.textDim, fontSize: 16)),
            const SizedBox(height: 8),
            AdaptiveButton(label: 'Refresh', onPressed: _onRefresh),
          ],
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: isDesktop ? 0.7 : 0.65,
              crossAxisSpacing: isDesktop ? 16 : 12,
              mainAxisSpacing: isDesktop ? 16 : 12,
            ),
            itemCount: _submissions.length + (_isRefreshing ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _submissions.length) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: AdaptiveProgress(strokeWidth: 2)),
                );
              }
              final sub = _submissions[index];
              return SubmissionCard(
                submission: sub,
                client: widget.client,
                sfwMode: widget.sfwMode,
                onTap: () => _navigateToDetail(sub),
              );
            },
          );
        },
      ),
    );
  }
}
