import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isWatching = false;
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
          _isWatching = profile?.isWatching ?? false;
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

  Future<void> _toggleWatch() async {
    if (_profile == null) return;
    final wasWatching = _isWatching;
    setState(() => _isWatching = !wasWatching);
    try {
      await widget.client.toggleWatch(_username, wasWatching);
    } catch (e) {
      debugPrint('=== toggleWatch error: $e');
      if (mounted) setState(() => _isWatching = wasWatching);
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
    final c = Palette.of(context);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= AppBreakpoints.desktop;

    return RefreshIndicator(
      color: AppColors.materialLavender,
      backgroundColor: c.bgCard,
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
        if (p.commissions.hasInfo) ...[
          const SizedBox(height: 20),
          _buildCommissions(p),
        ],
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
    final c = Palette.of(context);
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.translate(
            offset: const Offset(0, -40),
            child: Column(
              children: [
                _buildAvatarCircle(p, radius: 56),
                 const SizedBox(height: 12),

                Text(
                  p.displayName,
                  style: TextStyle(
                      color: c.text,
                      fontSize: 22,
                      fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: p.profileUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile URL copied'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Text(
                    '@${p.username}',
                    style: const TextStyle(
                        color: AppColors.materialLavender, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
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
          if (p.commissions.hasInfo) ...[
            _buildCommissions(p),
            const SizedBox(height: 20),
          ],
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

  Widget _buildAvatarCircle(FAUser p, {required double radius}) {
    final c = Palette.of(context);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.bg, width: 4),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: c.bgInput,
        child: p.avatarUrl.isNotEmpty
            ? FAImage(
                url: p.avatarUrl,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorWidget: CircleAvatar(
                  radius: radius,
                  backgroundColor: c.bgInput,
                  child: Text(
                    p.username.isNotEmpty ? p.username[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppColors.fluentCyan,
                      fontSize: radius * 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            : CircleAvatar(
                radius: radius,
                backgroundColor: c.bgInput,
                child: Text(
                  p.username.isNotEmpty ? p.username[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: AppColors.fluentCyan,
                    fontSize: radius * 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader(FAUser p) {
    final c = Palette.of(context);
    return Transform.translate(
      offset: const Offset(0, -40),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildAvatarCircle(p, radius: 44),

            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.displayName,
                    style: TextStyle(
                        color: c.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: p.profileUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile URL copied'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text(
                      '@${p.username}',
                      style: const TextStyle(
                          color: AppColors.materialLavender, fontSize: 14),
                    ),
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
    final c = Palette.of(context);
    final watching = _isWatching;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _toggleWatch,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: watching ? c.bgInput : AppColors.materialLavenderDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: watching ? c.border : AppColors.materialLavender),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                watching ? Icons.visibility : Icons.visibility_off,
                size: 16,
                color: watching ? c.textDim : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                watching ? 'Watching' : 'Watch',
                style: TextStyle(
                  fontSize: 14,
                  color: watching ? c.textDim : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
        childAspectRatio: 1.6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        children: [
          _statCard(Icons.visibility, '${p.stats.views}', 'Views',
              AppColors.fluentCyan),
          _statCard(Icons.collections, '${p.stats.submissions}', 'Submissions',
              AppColors.materialGreen),
          _statCard(Icons.favorite, '${p.stats.favorites}', 'Faves',
              AppColors.notifFave),
          _statCard(Icons.people, '${p.stats.watchers}', 'Watchers',
              AppColors.materialLavender),
          _statCard(Icons.comment, '${p.stats.comments}', 'Comments',
              AppColors.fluentCyan),
          _statCard(Icons.book, '${p.stats.journals}', 'Journals',
              AppColors.notifJournal),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    final c = Palette.of(context);
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
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: c.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          Text(label,
              style:
                  TextStyle(color: color.withValues(alpha: 0.7), fontSize: 11)),
        ],
      ),
    );
  }

  // ── Commission Section ──────────────────────────────────────────────

  Widget _buildCommissions(FAUser p) {
    final c = Palette.of(context);
    final comm = p.commissions;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status badge
            Row(
              children: [
                const Icon(Icons.palette, color: AppColors.fluentCyan, size: 20),
                const SizedBox(width: 8),
                Text('Commissions',
                    style: TextStyle(
                        color: c.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                if (comm.status.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: comm.isOpen
                          ? AppColors.materialGreen.withValues(alpha: 0.15)
                          : comm.status.toLowerCase().contains('trade')
                              ? AppColors.materialLavenderBg
                              : AppColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      comm.status,
                      style: TextStyle(
                        color: comm.isOpen
                            ? AppColors.materialGreen
                            : comm.status.toLowerCase().contains('trade')
                                ? AppColors.materialLavender
                                : AppColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Slots table
            if (comm.slots.isNotEmpty) ...[
              _buildCommissionSlots(comm),
              const SizedBox(height: 12),
            ],

            // Notes (if there's meaningful text beyond status/slots)
            if (comm.notes.length > 10 &&
                comm.notes.toLowerCase() != comm.status.toLowerCase()) ...[
              Text(
                comm.notes,
                style: TextStyle(
                    color: c.textDim, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 12),
            ],

            // TOS link
            if (comm.tosUrl.isNotEmpty)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    // Open TOS — navigate to journal page if available
                    if (comm.tosUrl.contains('/journal/')) {
                      // Could navigate to journal view, for now just show
                      _openLink(comm.tosUrl, 'Terms of Service');
                    } else {
                      _openLink(comm.tosUrl, 'Terms of Service');
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.description_outlined,
                          color: AppColors.fluentCyan, size: 16),
                      const SizedBox(width: 6),
                      Text('View Terms of Service',
                          style: const TextStyle(
                              color: AppColors.fluentCyan,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommissionSlots(FACommissionInfo comm) {
    final c = Palette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: c.bgCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Expanded(
                    flex: 2,
                    child: Text('Type',
                        style: TextStyle(
                            color: AppColors.textDim,
                            fontSize: 12,
                            fontWeight: FontWeight.w600))),
                const Expanded(
                    child: Text('Price',
                        style: TextStyle(
                            color: AppColors.textDim,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right)),
                if (comm.slots.any((s) => s.details.isNotEmpty))
                  const SizedBox(width: 12),
                if (comm.slots.any((s) => s.details.isNotEmpty))
                  const Expanded(
                      flex: 2,
                      child: Text('Details',
                          style: TextStyle(
                              color: AppColors.textDim,
                              fontSize: 12,
                              fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          // Slot rows
          for (final slot in comm.slots)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                    top: BorderSide(color: c.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(slot.type,
                        style: const TextStyle(
                            color: AppColors.text, fontSize: 14))),
                  Expanded(
                    child: Text(slot.price,
                        style: const TextStyle(
                            color: AppColors.fluentCyan,
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right)),
                  if (slot.details.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Text(slot.details,
                          style: const TextStyle(
                              color: AppColors.textDim, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _openLink(String url, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _LinkPlaceholder(title: title, url: url),
      ),
    );
  }

  // ── Bio Section ─────────────────────────────────────────────────────

  Widget _buildBio(FAUser p) {
    final c = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About',
              style: TextStyle(
                  color: c.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.border),
            ),
            child: Text(
              p.description,
              style: TextStyle(
                  color: c.textDim, fontSize: 14, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Links ────────────────────────────────────────────────────

  Widget _buildLinks(FAUser p) {
    final c = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Links',
              style: TextStyle(
                  color: c.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _linkTile(Icons.collections, 'Gallery', FAUrls.gallery(p.username),
              AppColors.fluentCyan),
          _linkTile(Icons.favorite, 'Favorites', FAUrls.favorites(p.username),
              AppColors.materialGreen),
          _linkTile(Icons.book, 'Journals', FAUrls.journals(p.username),
              AppColors.notifJournal),
          _linkTile(Icons.person, 'User Page', FAUrls.user(p.username),
              AppColors.materialLavender),
        ],
      ),
    );
  }

  Widget _linkTile(IconData icon, String title, String url, Color color) {
    final c = Palette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(icon, color: color, size: 22),
          title: Text(title,
              style: TextStyle(
                  color: c.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          trailing: Icon(Icons.chevron_right,
              color: c.textMuted, size: 20),
          onTap: () => _openLink(url, title),
        ),
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
