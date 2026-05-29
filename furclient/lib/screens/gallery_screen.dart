import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/submission_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/adaptive/adaptive.dart';
import 'submission_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  final OnlineFASession session;
  final bool sfwMode;
  final VoidCallback? onLogout;

  const GalleryScreen(
      {super.key, required this.session, this.sfwMode = false, this.onLogout});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  List<FASubmissionPreview> _submissions = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSubmissions();
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

  Future<void> _loadSubmissions() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _submissions = [];
      _hasMore = true;
    });

    try {
      final results = await widget.session.submissionPreviews();
      if (mounted) {
        setState(() {
          _submissions = results;
          _isLoading = false;
          _hasMore = results.isNotEmpty;
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
    if (_isLoadingMore || _isLoading || !_hasMore || _submissions.isEmpty) return;
    setState(() => _isLoadingMore = true);

    try {
      final lastSid = _submissions.last.sid;
      final results =
          await widget.session.submissionPreviews(fromSid: lastSid);
      if (mounted) {
        setState(() {
          _submissions.addAll(results);
          _isLoadingMore = false;
          _hasMore = results.isNotEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadSubmissions();
  }

  void _navigateToDetail(FASubmissionPreview submission) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubmissionDetailScreen(
          session: widget.session,
          submission: submission,
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
      appBar: AppBar(
        title: const Text('Latest'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading gallery...');
    }

    if (_error != null) {
      return ErrorView(
          message: _error!,
          onRetry: _loadSubmissions,
          onRelogin: widget.onLogout);
    }

    if (_submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            const Text('No submissions found',
                style: TextStyle(color: AppColors.textDim, fontSize: 16)),
            const SizedBox(height: 8),
            TextButton(
                onPressed: _loadSubmissions, child: const Text('Refresh')),
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
                  child: Center(child: AdaptiveProgress(strokeWidth: 2)),
                );
              }
              final sub = _submissions[index];
               return SubmissionCard(
                 submission: sub,
                 session: widget.session,
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
