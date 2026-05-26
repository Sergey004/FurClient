import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../services/fa_client.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import 'submission_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final FAClient client;

  const NotificationsScreen({super.key, required this.client});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with AutomaticKeepAliveClientMixin {
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
    if (notification.url.isNotEmpty) {
      final viewMatch = RegExp(r'/view/(\d+)').firstMatch(notification.url);
      if (viewMatch != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SubmissionDetailScreen(
              client: widget.client,
              submissionId: viewMatch.group(1)!,
            ),
          ),
        );
      }
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

  Color _typeColor(String type) {
    switch (type) {
      case 'fave':
        return AppColors.accentLight;
      case 'comment':
        return AppColors.success;
      case 'watch':
        return const Color(0xFFa78bfa);
      case 'journal':
        return const Color(0xFFf59e0b);
      default:
        return AppColors.textDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
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
      return ErrorView(message: _error!, onRetry: _loadNotifications);
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_none, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 16),
            const Text('No notifications', style: TextStyle(color: AppColors.textDim, fontSize: 16)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadNotifications, child: const Text('Refresh')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.bgCard,
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _notifications.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final notif = _notifications[index];
          return _buildNotificationTile(notif);
        },
      ),
    );
  }

  Widget _buildNotificationTile(FANotification notif) {
    return InkWell(
      onTap: () => _onNotificationTap(notif),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.bgInput,
              backgroundImage: notif.avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(notif.avatarUrl)
                  : null,
              child: notif.avatarUrl.isEmpty
                  ? Icon(_typeIcon(notif.type), color: _typeColor(notif.type), size: 22)
                  : null,
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
                      style: const TextStyle(color: AppColors.textDim, fontSize: 14, height: 1.4),
                      children: [
                        TextSpan(
                          text: notif.author,
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600),
                        ),
                        if (notif.title.isNotEmpty)
                          TextSpan(text: ' ${notif.title}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(_typeIcon(notif.type), color: _typeColor(notif.type), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        notif.type.toUpperCase(),
                        style: TextStyle(color: _typeColor(notif.type), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notif.datetime,
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
