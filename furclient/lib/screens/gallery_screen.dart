import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../widgets/submission_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import 'submission_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  final FAClient client;
  final bool sfwMode;

  const GalleryScreen({super.key, required this.client, this.sfwMode = false});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  List<Submission> _submissions = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _selectedCategory = 'all';

  static const _categories = ['all', 'digital', 'traditional', 'writing'];
  static const _categoryLabels = {
    'all': 'All',
    'digital': 'Digital',
    'traditional': 'Traditional',
    'writing': 'Writing',
  };

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
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final results = await widget.client.getSubmissions(1, _selectedCategory);
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
    if (_isLoadingMore || _isLoading || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    _currentPage += 1;

    try {
      final results = await widget.client.getSubmissions(_currentPage, _selectedCategory);
      if (mounted) {
        setState(() {
          _submissions.addAll(results);
          _isLoadingMore = false;
          _hasMore = results.isNotEmpty;
        });
      }
    } catch (_) {
      _currentPage -= 1;
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadSubmissions();
  }

  void _onCategoryChanged(String category) {
    if (category == _selectedCategory) return;
    setState(() => _selectedCategory = category);
    _loadSubmissions();
  }

  void _navigateToDetail(Submission submission) {
    Navigator.of(context).push(
      MaterialPageRoute(
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
      ),
      body: Column(
        children: [
          _buildCategoryChips(),
          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildCategoryChips() {
    final isDesktop = MediaQuery.of(context).size.width >= AppBreakpoints.desktop;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final selected = cat == _selectedCategory;
          return FilterChip(
            label: Text(_categoryLabels[cat] ?? cat),
            selected: selected,
            onSelected: (_) => _onCategoryChanged(cat),
            selectedColor: isDesktop
                ? AppColors.fluentCyanBg
                : AppColors.materialLavenderBg,
            checkmarkColor: isDesktop
                ? AppColors.fluentCyan
                : AppColors.materialLavender,
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading gallery...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadSubmissions);
    }

    if (_submissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            const Text('No submissions found', style: TextStyle(color: AppColors.textDim, fontSize: 16)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadSubmissions, child: const Text('Refresh')),
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
                  child: Center(child: CircularProgressIndicator(color: AppColors.fluentCyan, strokeWidth: 2)),
                );
              }
              final sub = _submissions[index];
              return SubmissionCard(
                submission: sub,
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
