import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../services/fa_urls.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/adaptive/adaptive.dart';
import '../utils/fa_image_loader.dart';

class ProfileScreen extends StatefulWidget {
  final FAClient client;
  final UserSession session;
  final String? targetUsername;
  final VoidCallback? onLogout;

  const ProfileScreen({
    super.key,
    required this.client,
    required this.session,
    this.targetUsername,
    this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
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

  String get _username => widget.targetUsername ?? widget.session.username;

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await widget.client.getUser(_username);
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
    return AdaptiveScaffold(
      appBar: AppBar(title: Text(widget.targetUsername != null ? _username : 'Profile')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading profile...');
    }

    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _loadProfile, onRelogin: widget.onLogout);
    }

    if (_profile == null) {
      return const ErrorView(message: 'Failed to load profile');
    }

    final p = _profile!;
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;

    return RefreshIndicator(
      color: AppColors.materialLavender,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadProfile,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: isDesktop ? _buildDesktopLayout(p) : _buildMobileLayout(p),
      ),
    );
  }

  Widget _buildMobileLayout(FAUser p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBanner(p),
        _buildHeader(p),
        const SizedBox(height: 16),
        _buildStats(p, crossAxisCount: 3),
        if (p.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildBio(p),
        ],
        const SizedBox(height: 20),
        _buildLinks(p),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildDesktopLayout(FAUser p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBanner(p, height: 200),
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDesktopSidebar(p),
              const SizedBox(width: 32),
              Expanded(child: _buildDesktopContent(p)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSidebar(FAUser p) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(0, -40),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.bg, width: 4),
                  ),
                  child: CircleAvatar(
                    radius: 56,
                    backgroundColor: AppColors.bgInput,
                    child: p.avatarUrl.isNotEmpty
                        ? FAImage(
                            url: p.avatarUrl,
                            client: widget.client,
                            width: 112,
                            height: 112,
                            fit: BoxFit.cover,
                            errorWidget: const Icon(
                              Icons.person,
                              color: AppColors.textMuted,
                              size: 56,
                            ),
                          )
                        : const Icon(Icons.person,
                            color: AppColors.textMuted, size: 56),
                  ),
                 ),
                 const SizedBox(height: 12),

                Text(
                  p.displayName,
                  style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '@${p.username}',
                  style: const TextStyle(
                      color: AppColors.materialLavender, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                _buildWatchButton(p),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildStats(p, crossAxisCount: 2),
        ],
      ),
    );
  }

  Widget _buildDesktopContent(FAUser p) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.description.isNotEmpty) ...[
            _buildBio(p),
            const SizedBox(height: 20),
          ],
          _buildLinks(p),
        ],
      ),
    );
  }

  Widget _buildBanner(FAUser p, {double height = 160}) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: p.bannerUrl.isNotEmpty
          ? FAImage(
              url: p.bannerUrl,
              client: widget.client,
              height: height,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: Container(color: AppColors.bgInput),
              errorWidget: Container(
                color: AppColors.bgInput,
                child: const Icon(Icons.image,
                    color: AppColors.textMuted, size: 48),
              ),
            )
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.materialLavender.withValues(alpha: 0.2),
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
                        child: p.avatarUrl.isNotEmpty
                            ? FAImage(
                                url: p.avatarUrl,
                                client: widget.client,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                errorWidget: const Icon(
                                  Icons.person,
                                  color: AppColors.textMuted,
                                  size: 44,
                                ),
                              )
                            : const Icon(Icons.person,
                                color: AppColors.textMuted, size: 44),
                      ),
                    ),

            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.displayName,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '@${p.username}',
                    style: const TextStyle(
                        color: AppColors.materialLavender, fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildWatchButton(p),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchButton(FAUser p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color:
            p.isWatching ? AppColors.bgInput : AppColors.materialLavenderDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                p.isWatching ? AppColors.border : AppColors.materialLavender),
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
    );
  }

  Widget _buildStats(FAUser p, {int crossAxisCount = 3}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.0,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          _statCard(Icons.visibility, '${p.stats.views}', 'Views',
              AppColors.fluentCyan),
          _statCard(Icons.collections, '${p.stats.submissions}', 'Submissions',
              AppColors.materialGreen),
          _statCard(Icons.favorite, '${p.stats.favorites}', 'Faves',
              AppColors.notifFave),
          _statCard(Icons.comment, '${p.stats.comments}', 'Comments',
              AppColors.materialLavender),
          _statCard(Icons.book, '${p.stats.journals}', 'Journals',
              AppColors.notifJournal),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          Text(label,
              style:
                  TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
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
          const Text('About',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
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
              style: const TextStyle(
                  color: AppColors.textDim, fontSize: 14, height: 1.6),
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
          const Text('Quick Links',
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _linkTile(Icons.collections, 'Gallery', FAUrls.gallery(p.username),
              AppColors.fluentCyan),
          _linkTile(Icons.favorite, 'Favorites', FAUrls.favorites(p.username),
              AppColors.materialGreen),
          _linkTile(Icons.book, 'Journals', FAUrls.journals(p.username),
              AppColors.notifJournal),
        ],
      ),
    );
  }

  Widget _linkTile(IconData icon, String title, String url, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icon, color: color, size: 22),
        title: Text(title,
            style: const TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.chevron_right,
            color: AppColors.textMuted, size: 20),
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
    return AdaptiveScaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(url, style: const TextStyle(color: AppColors.textDim))),
    );
  }
}
