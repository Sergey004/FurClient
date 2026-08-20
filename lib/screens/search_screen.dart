import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../services/fa_urls.dart';
import '../services/search_history.dart';
import '../widgets/submission_card.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/adaptive/adaptive.dart';
import '../utils/platform_utils.dart';
import 'submission_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final FAClient client;
  final bool sfwMode;
  final VoidCallback? onLogout;
  final String? initialQuery;

  const SearchScreen({
    super.key,
    required this.client,
    this.sfwMode = false,
    this.onLogout,
    this.initialQuery,
  });

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
  String _sortBy = 'relevancy';
  String _sortDirection = 'desc';
  String _author = '';
  String _dateRange = '5years';
  final Set<String> _ratings = {...FAUrls.allSearchRatings};
  final Set<String> _contentTypes = {...FAUrls.allSearchContentTypes};
  final Set<String> _genders = {};
  List<String> _tags = [];
  bool _hasSearched = false;
  bool _historyLoaded = false;

  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initHistory();
    SearchHistory.externalQuery.addListener(_onExternalQuery);
    // If initial query provided, search immediately
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _search(widget.initialQuery!));
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  Future<void> _initHistory() async {
    await _searchHistory.init();
    if (mounted) setState(() => _historyLoaded = true);
  }

  void _onExternalQuery() {
    final q = SearchHistory.externalQuery.value;
    if (q != null && q.isNotEmpty) {
      SearchHistory.externalQuery.value = null;
      _searchController.text = q;
      _search(q);
    }
  }

  @override
  void dispose() {
    SearchHistory.externalQuery.removeListener(_onExternalQuery);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _authorController.dispose();
    _tagsController.dispose();
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
        ratings: _ratings.toList(),
        contentTypes: _contentTypes.toList(),
        range: _dateRange,
        author: _author,
        tags: _tags,
        genders: _genders.toList(),
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
        ratings: _ratings.toList(),
        contentTypes: _contentTypes.toList(),
        range: _dateRange,
        author: _author,
        tags: _tags,
        genders: _genders.toList(),
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

  bool get _hasActiveFilters =>
      _author.isNotEmpty ||
      _tags.isNotEmpty ||
      _genders.isNotEmpty ||
      _dateRange != '5years' ||
      _ratings.length != FAUrls.allSearchRatings.length ||
      _contentTypes.length != FAUrls.allSearchContentTypes.length;

  Future<void> _showSearchFilters() async {
    final previousAuthor = _author;
    final previousDateRange = _dateRange;
    final previousRatings = {..._ratings};
    final previousContentTypes = {..._contentTypes};
    final previousGenders = {..._genders};
    final previousTags = [..._tags];
    _authorController.text = _author;
    _tagsController.text = _tags.join(', ');

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottom = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Search filters',
                              style: Theme.of(context).textTheme.titleLarge),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _authorController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'User',
                        helperText: 'Match submissions from this username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tagsController,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'wolf, !watermark',
                        helperText: 'Use !tag to exclude a tag',
                        prefixIcon: Icon(Icons.sell_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _dateRange,
                      decoration: const InputDecoration(
                        labelText: 'Date range',
                        prefixIcon: Icon(Icons.date_range_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: '1day', child: Text('Past day')),
                        DropdownMenuItem(
                            value: '7days', child: Text('Past week')),
                        DropdownMenuItem(
                            value: '30days', child: Text('Past 30 days')),
                        DropdownMenuItem(
                            value: '1year', child: Text('Past year')),
                        DropdownMenuItem(
                            value: '3years', child: Text('Past 3 years')),
                        DropdownMenuItem(
                            value: '5years', child: Text('Past 5 years')),
                        DropdownMenuItem(value: 'all', child: Text('All time')),
                      ],
                      onChanged: (value) {
                        if (value != null)
                          setSheetState(() => _dateRange = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    _filterSectionLabel('Rating'),
                    ...[
                      ('general', 'General'),
                      ('mature', 'Mature'),
                      ('adult', 'Adult'),
                    ].map((entry) => CheckboxListTile(
                          value: _ratings.contains(entry.$1),
                          title: Text(entry.$2),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          onChanged: (value) => setSheetState(() {
                            value == true
                                ? _ratings.add(entry.$1)
                                : _ratings.remove(entry.$1);
                          }),
                        )),
                    _filterSectionLabel('Content type'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        ('art', 'Art'),
                        ('music', 'Music'),
                        ('flash', 'Flash'),
                        ('story', 'Story'),
                        ('photo', 'Photo'),
                        ('poetry', 'Poetry'),
                      ]
                          .map((entry) => FilterChip(
                                label: Text(entry.$2),
                                selected: _contentTypes.contains(entry.$1),
                                onSelected: (selected) => setSheetState(() {
                                  selected
                                      ? _contentTypes.add(entry.$1)
                                      : _contentTypes.remove(entry.$1);
                                }),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    _filterSectionLabel('Gender keywords'),
                    Wrap(
                      spacing: 8,
                      children: [
                        ('male', 'Male'),
                        ('female', 'Female'),
                        ('trans_male', 'Trans male'),
                        ('trans_female', 'Trans female'),
                        ('intersex', 'Intersex'),
                        ('non_binary', 'Non-binary'),
                      ]
                          .map((entry) => FilterChip(
                                label: Text(entry.$2),
                                selected: _genders.contains(entry.$1),
                                onSelected: (selected) => setSheetState(() {
                                  selected
                                      ? _genders.add(entry.$1)
                                      : _genders.remove(entry.$1);
                                }),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => setSheetState(() {
                            _authorController.clear();
                            _tagsController.clear();
                            _author = '';
                            _tags = [];
                            _dateRange = '5years';
                            _ratings
                              ..clear()
                              ..addAll(FAUrls.allSearchRatings);
                            _contentTypes
                              ..clear()
                              ..addAll(FAUrls.allSearchContentTypes);
                            _genders.clear();
                          }),
                          child: const Text('Reset'),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(sheetContext, true),
                          icon: const Icon(Icons.check),
                          label: const Text('Apply filters'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == true && mounted) {
      _author = _authorController.text.trim();
      _tags = _tagsController.text
          .split(RegExp(r'[,\s]+'))
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty)
          .toList();
      if (_query.isNotEmpty) {
        await _search(_query);
      } else {
        setState(() {});
      }
    } else if (mounted) {
      setState(() {
        _author = previousAuthor;
        _dateRange = previousDateRange;
        _ratings
          ..clear()
          ..addAll(previousRatings);
        _contentTypes
          ..clear()
          ..addAll(previousContentTypes);
        _genders
          ..clear()
          ..addAll(previousGenders);
        _tags = previousTags;
      });
    }
  }

  Widget _filterSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;

    if (isWindows) {
      return _buildFluentLayout(isDesktop);
    }
    return _buildMaterialLayout(isDesktop);
  }

  // ── Windows: Fluent UI layout (no Material widgets) ─────────────────────

  Widget _buildFluentLayout(bool isDesktop) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: fluent.TextBox(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  placeholder: 'Search submissions...',
                  style: TextStyle(color: colors.onSurface, fontSize: 14),
                  prefix: Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Icon(Icons.search, size: 16, color: colors.primary),
                  ),
                  suffix: _searchController.text.isNotEmpty
                      ? fluent.IconButton(
                          icon: const Icon(Icons.clear, size: 14),
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
                  onSubmitted: _search,
                ),
              ),
            ],
          ),
        ),
        _buildSortBar(),
        Expanded(child: _buildBody(isDesktop)),
      ],
    );
  }

  // ── Android / other: Material layout ─────────────────────────────────────

  Widget _buildMaterialLayout(bool isDesktop) {
    final colors = Theme.of(context).colorScheme;
    return AdaptiveScaffold(
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          IconButton(
            tooltip: 'Search filters',
            icon: Badge(
              isLabelVisible: _hasActiveFilters,
              smallSize: 8,
              child: const Icon(Icons.tune_outlined),
            ),
            onPressed: _showSearchFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AdaptiveTextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              hintText: 'Search submissions...',
              style: TextStyle(color: colors.onSurface, fontSize: 14),
              onSubmitted: _search,
              suffix: _searchController.text.isNotEmpty
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
          _buildSortBar(),
          Expanded(child: _buildBody(isDesktop)),
        ],
      ),
    );
  }

  // ── Sort bar (shared, no platform-specific widgets) ─────────────────────

  Widget _buildSortBar() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Row(
        children: [
          Icon(Icons.sort, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 6),
          Text('Sort:',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
          const SizedBox(width: 8),
          _sortChip('Relevance', 'relevancy'),
          const SizedBox(width: 6),
          _sortChip('Newest', 'date'),
          const SizedBox(width: 6),
          _sortChip('Popular', 'popularity'),
          const Spacer(),
          if (_sortBy != 'relevancy')
            GestureDetector(
              onTap: () => _toggleSortDirection(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _sortDirection == 'desc'
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 14,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _sortDirection == 'desc' ? 'Desc' : 'Asc',
                      style: TextStyle(
                          color: colors.onSurfaceVariant, fontSize: 11),
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
    final colors = Theme.of(context).colorScheme;
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
          color: active ? colors.secondaryContainer : colors.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? colors.secondary : colors.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                active ? colors.onSecondaryContainer : colors.onSurfaceVariant,
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

  // ── Body (shared) ────────────────────────────────────────────────────────

  Widget _buildBody(bool isDesktop) {
    final colors = Theme.of(context).colorScheme;
    if (_isLoading) {
      return const LoadingIndicator(message: 'Searching...');
    }

    if (_error != null) {
      return ErrorView(
          message: _error!,
          onRetry: () => _search(_query),
          onRelogin: widget.onLogout);
    }

    if (!_hasSearched) {
      return _buildRecentSearches();
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, color: colors.onSurfaceVariant, size: 48),
            const SizedBox(height: 16),
            Text('No results for "$_query"',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
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
              return Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: AdaptiveProgress(
                        color: colors.primary, strokeWidth: 2)),
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

  // ── Recent searches (platform-adaptive) ─────────────────────────────────

  Widget _buildRecentSearches() {
    final colors = Theme.of(context).colorScheme;
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
                color: colors.primary.withValues(alpha: 0.6), size: 48),
            const SizedBox(height: 16),
            Text('Search for submissions',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 16)),
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
              Text('Recent Searches',
                  style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (!isWindows)
                TextButton(
                  onPressed: () async {
                    await _searchHistory.clear();
                    setState(() {});
                  },
                  child: const Text('Clear All'),
                )
              else
                GestureDetector(
                  onTap: () async {
                    await _searchHistory.clear();
                    setState(() {});
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Clear All',
                        style: TextStyle(color: colors.primary, fontSize: 12)),
                  ),
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
              return _buildRecentSearchItem(term);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearchItem(String term) {
    final colors = Theme.of(context).colorScheme;
    if (isWindows) {
      return GestureDetector(
        onTap: () {
          _searchController.text = term;
          _search(term);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.history, color: colors.primary, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(term,
                    style: TextStyle(
                        color: colors.onSurfaceVariant, fontSize: 14)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  await _searchHistory.remove(term);
                  setState(() {});
                },
                child:
                    Icon(Icons.close, color: colors.onSurfaceVariant, size: 16),
              ),
            ],
          ),
        ),
      );
    }
    // Material
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(Icons.history, color: colors.primary, size: 20),
      title: Text(term,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 14)),
      trailing: IconButton(
        icon: Icon(Icons.close, color: colors.onSurfaceVariant, size: 18),
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
  }
}
