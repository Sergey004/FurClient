import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../services/search_history.dart';
import '../widgets/submission_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/adaptive/adaptive.dart';
import 'submission_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final FAClient client;
  final bool sfwMode;
  final VoidCallback? onLogout;

  const SearchScreen({super.key, required this.client, this.sfwMode = false, this.onLogout});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final SearchHistory _searchHistory = SearchHistory();

  List<Submission> _results = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  String _query = '';
  String _sortBy = 'relevancyt';
  String _sortDirection = 'desc';
  bool _hasSearched = false;
  bool _historyLoaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  Future<void> _initHistory() async {
    await _searchHistory.init();
    if (mounted) setState(() => _historyLoaded = true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    setState(() {
      _query = trimmed;
      _isLoading = true;
      _error = null;
      _results = [];
      _currentPage = 1;
      _hasMore = true;
      _hasSearched = true;
    });

    _searchFocusNode.unfocus();
    await _searchHistory.add(trimmed);

    try {
      final results = await widget.client.search(
        trimmed,
        page: 1,
        sortBy: _sortBy,
        sortDirection: _sortDirection,
      );
      if (mounted) {
        setState(() {
          _results = results;
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
    if (_isLoadingMore || _isLoading || !_hasMore || _query.isEmpty) return;
    setState(() => _isLoadingMore = true);
    _currentPage += 1;

    try {
      final results = await widget.client.search(
        _query,
        page: _currentPage,
        sortBy: _sortBy,
        sortDirection: _sortDirection,
      );
      if (mounted) {
        setState(() {
          _results.addAll(results);
          _isLoadingMore = false;
          _hasMore = results.isNotEmpty;
        });
      }
    } catch (_) {
      _currentPage -= 1;
      if (mounted) setState(() => _isLoadingMore = false);
    }
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
    final isDesktop =
        MediaQuery.of(context).size.width >= AppBreakpoints.desktop;

    return AdaptiveScaffold(
      appBar: AppBar(
        title: const Text('Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search submissions...',
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: AppColors.materialGreen),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                            _hasSearched = false;
                            _results = [];
                          });
                          _searchFocusNode.requestFocus();
                        },
                      )
                    : null,
              ),
            ),
          ),
          _buildSortBar(),
          Expanded(child: _buildBody(isDesktop)),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          const Icon(Icons.sort, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text('Sort:', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(width: 8),
          _sortChip('Relevance', 'relevancyt'),
          const SizedBox(width: 6),
          _sortChip('Newest', 'datet'),
          const SizedBox(width: 6),
          _sortChip('Popular', 'popularityt'),
          const Spacer(),
          if (_sortBy != 'relevancyt')
            GestureDetector(
              onTap: () => _toggleSortDirection(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sortDirection == 'desc'
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 14,
                      color: AppColors.textDim,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortDirection == 'desc' ? 'Desc' : 'Asc',
                      style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String sortKey) {
    final active = _sortBy == sortKey;
    return GestureDetector(
      onTap: () {
        if (_sortBy == sortKey) return;
        setState(() => _sortBy = sortKey);
        if (_query.isNotEmpty) _search(_query);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active
              ? AppColors.materialGreen.withValues(alpha: 0.15)
              : AppColors.bgCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.materialGreen : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.materialGreen : AppColors.textDim,
            fontSize: 11,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _toggleSortDirection() {
    setState(() {
      _sortDirection = _sortDirection == 'desc' ? 'asc' : 'desc';
    });
    if (_query.isNotEmpty) _search(_query);
  }

  Widget _buildBody(bool isDesktop) {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Searching...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: () => _search(_query), onRelogin: widget.onLogout);
    }

    if (!_hasSearched) {
      return _buildRecentSearches();
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            Text('No results for "$_query"',
                style: const TextStyle(color: AppColors.textDim, fontSize: 16)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _getCrossAxisCount(constraints.maxWidth);

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: isDesktop ? 0.7 : 0.65,
            crossAxisSpacing: isDesktop ? 16 : 12,
            mainAxisSpacing: isDesktop ? 16 : 12,
          ),
          itemCount: _results.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _results.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
          child: Center(
              child: AdaptiveProgress(
                color: AppColors.materialGreen, strokeWidth: 2)),
              );
            }
            final sub = _results[index];
            return SubmissionCard(
              submission: sub,
              client: widget.client,
              sfwMode: widget.sfwMode,
              onTap: () => _navigateToDetail(sub),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    if (!_historyLoaded) {
      return const LoadingIndicator();
    }
    final recent = _searchHistory.recent;
    if (recent.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search,
                color: AppColors.materialGreen.withValues(alpha: 0.5),
                size: 48),
            const SizedBox(height: 16),
            const Text('Search for submissions',
                style: TextStyle(color: AppColors.textDim, fontSize: 16)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text('Recent Searches',
                  style: TextStyle(
                      color: AppColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  await _searchHistory.clear();
                  setState(() {});
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recent.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final term = recent[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.history,
                    color: AppColors.materialGreen, size: 20),
                title: Text(term,
                    style: const TextStyle(
                        color: AppColors.textDim, fontSize: 14)),
                trailing: IconButton(
                  icon: const Icon(Icons.close,
                      color: AppColors.textMuted, size: 18),
                  onPressed: () async {
                    await _searchHistory.remove(term);
                    setState(() {});
                  },
                ),
                onTap: () {
                  _searchController.text = term;
                  _search(term);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
