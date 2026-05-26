import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../services/fa_urls.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';

class ProfileScreen extends StatefulWidget {
  final FAClient client;
  final UserSession session;

  const ProfileScreen({super.key, required this.client, required this.session});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  FAUser? _profile;
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await widget.client.getUser(widget.session.username);
      if (mounted) {
        setState(() {
          _profile = profile;
          _isLoading = false;
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading profile...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadProfile);
    }

    if (_profile == null) {
      return const ErrorView(message: 'Failed to load profile');
    }

    final p = _profile!;
    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBanner(p),
            _buildHeader(p),
            const SizedBox(height: 16),
            _buildStats(p),
            if (p.description.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildBio(p),
            ],
            const SizedBox(height: 20),
            _buildLinks(p),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner(FAUser p) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: p.bannerUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: p.bannerUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppColors.bgInput),
              errorWidget: (context, url, error) => Container(
                color: AppColors.bgInput,
                child: const Icon(Icons.image, color: AppColors.textMuted, size: 48),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accent.withOpacity(0.3),
                    AppColors.bgInput,
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(FAUser p) {
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.bg, width: 4),
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.bgInput,
                backgroundImage: p.avatarUrl.isNotEmpty
                    ? CachedNetworkImageProvider(p.avatarUrl)
                    : null,
                child: p.avatarUrl.isEmpty
                    ? const Icon(Icons.person, color: AppColors.textMuted, size: 44)
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.displayName,
                    style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${p.username}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: p.isWatching ? AppColors.bgInput : AppColors.accent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.isWatching ? AppColors.border : AppColors.accent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    p.isWatching ? Icons.visibility : Icons.visibility_off,
                    size: 16,
                    color: p.isWatching ? AppColors.textDim : Colors.white,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    p.isWatching ? 'Watching' : 'Watch',
                    style: TextStyle(
                      fontSize: 14,
                      color: p.isWatching ? AppColors.textDim : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(FAUser p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.0,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          _statCard(Icons.visibility, '${p.stats.views}', 'Views'),
          _statCard(Icons.collections, '${p.stats.submissions}', 'Submissions'),
          _statCard(Icons.favorite, '${p.stats.favorites}', 'Faves'),
          _statCard(Icons.comment, '${p.stats.comments}', 'Comments'),
          _statCard(Icons.book, '${p.stats.journals}', 'Journals'),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.accentLight, size: 18),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildBio(FAUser p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('About', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
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
              p.description,
              style: const TextStyle(color: AppColors.textDim, fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinks(FAUser p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Links', style: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _linkTile(Icons.collections, 'Gallery', FAUrls.gallery(p.username)),
          _linkTile(Icons.favorite, 'Favorites', FAUrls.favorites(p.username)),
          _linkTile(Icons.book, 'Journals', FAUrls.journals(p.username)),
        ],
      ),
    );
  }

  Widget _linkTile(IconData icon, String title, String url) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: AppColors.accentLight, size: 22),
        title: Text(title, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _LinkPlaceholder(title: title, url: url),
            ),
          );
        },
      ),
    );
  }
}

class _LinkPlaceholder extends StatelessWidget {
  final String title;
  final String url;
  const _LinkPlaceholder({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(url, style: const TextStyle(color: AppColors.textDim))),
    );
  }
}
