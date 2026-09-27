import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Notification channels for Android system settings. Each FA notification
/// type gets its own channel so users can disable them selectively.
const _channels = {
  'favorite': AndroidNotificationDetails(
    'favorite_channel',
    'Favorites',
    channelDescription: 'When someone favorites your submission',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  ),
  'submission_comment': AndroidNotificationDetails(
    'submission_comment_channel',
    'Submission Comments',
    channelDescription: 'Comments on your submissions',
    importance: Importance.high,
    priority: Priority.high,
  ),
  'journal_comment': AndroidNotificationDetails(
    'journal_comment_channel',
    'Journal Comments',
    channelDescription: 'Comments on your journals',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  ),
  'shout': AndroidNotificationDetails(
    'shout_channel',
    'Shouts',
    channelDescription: 'Shouts from users',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  ),
  'journal': AndroidNotificationDetails(
    'journal_channel',
    'Journals',
    channelDescription: 'New journal entries from watched users',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  ),
  'download': AndroidNotificationDetails(
    'download_channel',
    'Downloads',
    channelDescription: 'Image download progress and results',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  ),
  'submission': AndroidNotificationDetails(
    'submission_channel',
    'New Submissions',
    channelDescription: 'New submissions from watched users',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  ),
  'note': AndroidNotificationDetails(
    'note_channel',
    'Notes',
    channelDescription: 'New private messages (notes)',
    importance: Importance.high,
    priority: Priority.high,
  ),
  'system': AndroidNotificationDetails(
    'system_channel',
    'System',
    channelDescription: 'Service statuses like Cloudflare checks',
    importance: Importance.high,
    priority: Priority.high,
  ),
};

/// Обработчик тапа по уведомлению — main.dart подписывает свой deep-link
/// роутер (FATarget) сюда при старте.
void Function(String url)? onNotificationTap;

// ignore: unused_element
AndroidNotificationDetails _androidDetails(String channelId) {
  return _channels[channelId] ?? _channels['download']!;
}

/// Initialize with all notification channels.
Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const WindowsInitializationSettings initializationSettingsWindows =
      WindowsInitializationSettings(
    appName: 'FurClient',
    appUserModelId: 'A5B8C1D2-4E3F-5678-9012-3456789ABCDE',
    guid: 'd49b0314-ee7a-4626-bf79-97cdb8a991bb',
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    windows: initializationSettingsWindows,
  );

  await notificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        onNotificationTap?.call(payload);
      }
    },
  );
}

Future<void> requestNotificationPermissions() async {
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.requestNotificationsPermission();
  }
}

/// Show a notification for a specific FA notification type.
Future<void> showNotification({
  required String type,
  required String title,
  String body = '',
  int notificationId = 0,
  bool showProgress = false,
  int progress = 0,
  int maxProgress = 100,
  String? payload,
}) async {
  final android = AndroidNotificationDetails(
    '${type}_channel',
    type.toUpperCase(),
    channelDescription: 'FA $type notifications',
    importance: _channels['${type}_channel']?.importance ??
        Importance.defaultImportance,
    priority:
        _channels['${type}_channel']?.priority ?? Priority.defaultPriority,
    onlyAlertOnce: true,
    showProgress: showProgress,
    progress: progress,
    maxProgress: maxProgress,
  );
  final windowsDetails = WindowsNotificationDetails();
  final details = NotificationDetails(
    android: android,
    windows: windowsDetails,
  );
  await notificationsPlugin.show(
    notificationId,
    title,
    body,
    details,
    payload: payload,
  );
}

Future<void> showFavoriteNotification({required String title}) async {
  await showNotification(
    type: 'favorite',
    title: title,
    body: 'Added to favorites',
    notificationId: 1,
  );
}

Future<void> showDownloadNotification({
  required String title,
  required String body,
  bool showProgress = false,
  int progress = 0,
  int maxProgress = 100,
}) async {
  await showNotification(
    type: 'download',
    title: title,
    body: body,
    notificationId: 0,
    showProgress: showProgress,
    progress: progress,
    maxProgress: maxProgress,
  );
}
