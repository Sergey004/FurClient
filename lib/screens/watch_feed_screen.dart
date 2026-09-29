import 'package:flutter/material.dart';
import '../utils/haptics.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../widgets/submission_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/adaptive/adaptive.dart';
import 'submission_detail_screen.dart';
import '../utils/scroll_to_top.dart';

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

  /// Индекс вкладки в шелле — для сигнала «скролл наверх».
  final int tabIndex;

  const WatchFeedScreen(
      {super.key,
      required this.client,
      this.sfwMode = false,
      this.onLogout,
      this.tabIndex = 1});

  @override
  State<WatchFeedScreen> createState() => _WatchFeedScreenState();
}

class _WatchFeedScreenState extends State<WatchFeedScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  late final VoidCallback _scrollToTopCancel;

  /// Submissions loaded so far, kept across refreshes. New refresh results
  /// are merged at the top (newest-first via descending sid order, matching
  /// FA's listing order).
  List<Submission> _submissions = [];
  Set<String> _favIds = {};
  bool _isInitialLoading = false;
  bool _isRefreshing = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollToTopCancel = ScrollToTopBus.subscribe(widget.tabIndex, () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic);
      }
    });
    _initialLoad();
  }

  @override
  void dispose() {
    _scrollToTopCancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Красит сердечки у карточек, чьи id есть в [_favIds]. Только добавляет:
  /// вручную зафавканное в этой сессии не снимаем.
  void _applyFavs() {
    setState(() {
      _submissions = _submissions
          .map((s) => s.isFavorite || !_favIds.contains(s.id)
              ? s
              : s.copyWith(isFavorite: true))
          .toList();
    });
  }

  Future<void> _initialLoad() async {
    if (_isInitialLoading) return;
    setState(() {
      _isInitialLoading = true;
      _error = null;
    });

    try {
      // Лента показывается СРАЗУ; fav-фетч живёт в отдельном async-потоке и
      // докрашивает сердечки по мере поступления страниц избранного.
      final feedFuture = widget.client.getWatchSubmissions();
      final favFuture = widget.client.loadFavoriteIds(onPartial: (ids) {
        if (!mounted) return;
        _favIds.addAll(ids);
        _applyFavs();
      });
      final result = await feedFuture;
      if (mounted) {
        setState(() {
          // fav-волны могли прийти РАНЬШЕ ленты — применяем накопленные
          // _favIds, иначе сердечки терялись из-за гонки.
          _submissions = result.submissions
              .map((s) => _favIds.contains(s.id) && !s.isFavorite
                  ? s.copyWith(isFavorite: true)
                  : s)
              .toList();
          _isInitialLoading = false;
        });
      }
      await favFuture; // ошибки внутри loadFavoriteIds уже проглочены
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
    FHaptics.light();
    setState(() => _isRefreshing = true);

    try {
      // Лента мержится сразу; fav-фетч — отдельный поток, сердечки
      // докрашиваются прогрессивно через onPartial.
      final feedFuture = widget.client.getWatchSubmissions();
      final favFuture = widget.client.loadFavoriteIds(onPartial: (ids) {
        if (!mounted) return;
        _favIds.addAll(ids);
        _applyFavs();
      });
      final result = await feedFuture;
      if (!mounted) return;

      if (_submissions.isEmpty) {
        setState(() {
          _submissions = result.submissions;
          _isRefreshing = false;
        });
        await favFuture;
        return;
      }

      // Merge: keep only newly fetched submissions whose sid is *newer* than
      // the current top. FA returns sids in descending order, so a simple
      // "newer than the current head" filter is enough. Свежие карточки
      // сразу получают сердечки из уже накопленного множества.
      final currentTopSid = int.tryParse(_submissions.first.id) ?? 0;
      final fresh = result.submissions
          .where((s) => (int.tryParse(s.id) ?? 0) > currentTopSid)
          .map((s) => _favIds.contains(s.id) && !s.isFavorite
              ? s.copyWith(isFavorite: true)
              : s);
      if (fresh.isEmpty) {
        setState(() => _isRefreshing = false);
        await favFuture;
        return;
      }
      setState(() {
        _submissions = [...fresh, ..._submissions];
        _isRefreshing = false;
      });
      await favFuture;
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
          onSubmissionUpdated: (updated) {
            if (!mounted) return;
            setState(() {
              _submissions = _submissions
                  .map((s) => s.id == updated.id
                      ? s.copyWith(
                          isFavorite: updated.isFavorite,
                          faves: updated.faves,
                          favoriteUrl: updated.favoriteUrl,
                        )
                      : s)
                  .toList();
            });
          },
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
