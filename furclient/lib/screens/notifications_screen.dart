import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import '../widgets/adaptive/adaptive.dart';
import 'submission_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final OnlineFASession session;
  final VoidCallback? onLogout;

  const NotificationsScreen({super.key, required this.session, this.onLogout});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with AutomaticKeepAliveClientMixin {
  FANotificationPreviews? _notifications;
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
      final notifications = await widget.session.notificationPreviews();
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

  void _onNotificationTap(FANotificationPreview notification) {
    final viewMatch = RegExp(r'/view/(\d+)').firstMatch(notification.url.toString());
    if (viewMatch != null) {
      // Navigate to submission
      final sid = int.parse(viewMatch.group(1)!);
      final preview = FASubmissionPreview(
        sid: sid,
        url: notification.url,
        thumbnailUrl: Uri.parse(''),
        thumbnailWidthOnHeightRatio: 1.0,
        title: notification.title,
        author: notification.author,
        displayAuthor: notification.displayAuthor,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SubmissionDetailScreen(
            session: widget.session,
            submission: preview,
          ),
        ),
      );
    }
  }

  List<_NotificationGroup> _buildGroups() {
    final groups = <_NotificationGroup>[];
    if (_notifications == null) return groups;

    if (_notifications!.submissionComments.isNotEmpty) {
      groups.add(_NotificationGroup(
        label: 'Submission Comments',
        notifications: _notifications!.submissionComments,
      ));
    }
    if (_notifications!.journalComments.isNotEmpty) {
      groups.add(_NotificationGroup(
        label: 'Journal Comments',
        notifications: _notifications!.journalComments,
      ));
    }
    if (_notifications!.shouts.isNotEmpty) {
      groups.add(_NotificationGroup(
        label: 'Shouts',
        notifications: _notifications!.shouts,
      ));
    }
    if (_notifications!.journals.isNotEmpty) {
      groups.add(_NotificationGroup(
        label: 'Journals',
        notifications: _notifications!.journals,
      ));
    }
    return groups;
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
      return ErrorView(message: _error!, onRetry: _loadNotifications, onRelogin: widget.onLogout);
    }

    final groups = _buildGroups();
    if (groups.isEmpty) {
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
            TextButton(
                onPressed: _loadNotifications, child: const Text('Refresh')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.cupertinoPurple,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  group.label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ...group.notifications.map((n) => _buildNotificationTile(n)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(FANotificationPreview notif) {
    final color = AppColors.notifFave;

    return InkWell(
      onTap: () => _onNotificationTap(notif),
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
                child: Icon(Icons.notifications, color: color, size: 22),
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
                          text: notif.displayAuthor,
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
                  Text(
                    notif.naturalDatetime,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
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

class _NotificationGroup {
  final String label;
  final List<FANotificationPreview> notifications;

  const _NotificationGroup({
    required this.label,
    required this.notifications,
  });
}
