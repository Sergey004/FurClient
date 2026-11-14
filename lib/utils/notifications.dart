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

final List<String> _pendingNotificationTaps = <String>[];

void dispatchNotificationTap(String payload) {
  final handler = onNotificationTap;
  if (handler == null) {
    // initialize() выполняется до runApp: callback холодного запуска может
    // прийти раньше, чем главный экран успеет назначить deep-link роутер.
    _pendingNotificationTaps.add(payload);
    return;
  }
  handler(payload);
}

/// Отдаёт нажатия, пришедшие до подписки главного экрана.
void flushPendingNotificationTaps() {
  final handler = onNotificationTap;
  if (handler == null || _pendingNotificationTaps.isEmpty) return;
  final pending = List<String>.of(_pendingNotificationTaps);
  _pendingNotificationTaps.clear();
  for (final payload in pending) {
    handler(payload);
  }
}

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
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final payload = response.payload;
      if (payload != null && payload.isNotEmpty) {
        dispatchNotificationTap(payload);
      }
    },
  );

  // Создаём весь набор сразу: иначе Android показывает в настройках только
  // каналы, которые уже успели показать первое уведомление.
  final androidPlugin =
      notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    for (final entry in _channels.entries) {
      final details = entry.value;
      await androidPlugin.createNotificationChannel(AndroidNotificationChannel(
        '${entry.key}_channel',
        details.channelName,
        description: details.channelDescription,
        importance: details.importance,
      ));
    }
  }
}

Future<void> requestNotificationPermissions() async {
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.requestNotificationsPermission();
  }
}

/// Стабильный системный ID для логически одного события. Повторный показ с
/// тем же ключом обновляет уведомление, а разные события не перезаписываются.
int notificationIdFor(String key) => key.hashCode & 0x7fffffff;

AndroidNotificationDetails androidNotificationDetailsForType(
  String type, {
  bool showProgress = false,
  int progress = 0,
  int maxProgress = 100,
}) {
  final channel = _channels[type] ?? _channels['download']!;
  return AndroidNotificationDetails(
    '${type}_channel',
    channel.channelName,
    channelDescription: channel.channelDescription,
    importance: channel.importance,
    priority: channel.priority,
    onlyAlertOnce: true,
    showProgress: showProgress,
    progress: progress,
    maxProgress: maxProgress,
  );
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
  final android = androidNotificationDetailsForType(
    type,
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
    id: notificationId,
    title: title,
    body: body,
    notificationDetails: details,
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
  int? notificationId,
  bool showProgress = false,
  int progress = 0,
  int maxProgress = 100,
}) async {
  await showNotification(
    type: 'download',
    title: title,
    body: body,
    notificationId: notificationId ?? 0,
    showProgress: showProgress,
    progress: progress,
    maxProgress: maxProgress,
  );
}
