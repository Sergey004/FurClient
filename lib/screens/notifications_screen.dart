import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/adaptive/adaptive.dart';
import '../utils/fa_image_loader.dart';
import 'submission_detail_screen.dart';
import 'journal_detail_screen.dart';
import 'profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final FAClient client;
  final VoidCallback? onLogout;

  const NotificationsScreen({super.key, required this.client, this.onLogout});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with AutomaticKeepAliveClientMixin {
  List<FANotification> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final notifications = await widget.client.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notifications;
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

  void _onNotificationTap(FANotification notification) {
    if (notification.url.isEmpty) return;

    // Submission: /view/123456/
    final viewMatch = RegExp(r'/view/(\d+)').firstMatch(notification.url);
    if (viewMatch != null) {
      Navigator.of(context).push(
        adaptiveRoute(
          builder: (_) => SubmissionDetailScreen(
            client: widget.client,
            submissionId: viewMatch.group(1)!,
          ),
        ),
      );
      return;
    }

    // Journal: /journal/123456/
    final journalMatch = RegExp(r'/journal/(\d+)').firstMatch(notification.url);
    if (journalMatch != null) {
      Navigator.of(context).push(
        adaptiveRoute(
          builder: (_) => JournalDetailScreen(
            client: widget.client,
            journalId: journalMatch.group(1)!,
          ),
        ),
      );
      return;
    }

    // User profile: /user/username/
    final userMatch =
        RegExp(r'/user/([a-zA-Z][a-zA-Z0-9_]+)/').firstMatch(notification.url);
    if (userMatch != null) {
      Navigator.of(context).push(
        adaptiveRoute(
          builder: (_) => ProfileScreen(
            client: widget.client,
            session: widget.client.session!,
            targetUsername: userMatch.group(1)!,
          ),
        ),
      );
      return;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'fave':
        return AppColors.notifFave;
      case 'comment':
        return AppColors.notifComment;
      case 'watch':
        return AppColors.notifWatch;
      case 'journal':
        return AppColors.notifJournal;
      default:
        return AppColors.textDim;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'fave':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'watch':
        return Icons.visibility;
      case 'journal':
        return Icons.book;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AdaptiveScaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const LoadingIndicator(message: 'Loading notifications...');
    }

    if (_error != null) {
      return ErrorView(
          message: _error!,
          onRetry: _loadNotifications,
          onRelogin: widget.onLogout);
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            const Text('No notifications',
                style: TextStyle(color: AppColors.textDim, fontSize: 16)),
            const SizedBox(height: 8),
            AdaptiveButton(label: 'Refresh', onPressed: _loadNotifications),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.cupertinoPurple,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppColors.border, indent: 62),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          return _buildNotificationTile(notif);
        },
      ),
    );
  }

  Widget _buildNotificationTile(FANotification notif) {
    final color = _typeColor(notif.type);

    return GestureDetector(
      onTap: () => _onNotificationTap(notif),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.1),
                border:
                    Border.all(color: color.withValues(alpha: 0.2), width: 1),
              ),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: Colors.transparent,
                child: notif.avatarUrl.isNotEmpty
                    ? FAImage(
                        url: notif.avatarUrl,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget:
                            Icon(_typeIcon(notif.type), color: color, size: 22),
                      )
                    : Icon(_typeIcon(notif.type), color: color, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: const TextStyle(
                          color: AppColors.textDim, fontSize: 14, height: 1.4),
                      children: [
                        TextSpan(
                          text: notif.author,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600),
                        ),
                        if (notif.title.isNotEmpty)
                          TextSpan(text: ' ${notif.title}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_typeIcon(notif.type), color: color, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              notif.type.toUpperCase(),
                              style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notif.datetime,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
