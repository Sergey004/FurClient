import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Initialize with a default channel for download progress/status.
Future<void> initNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const WindowsInitializationSettings initializationSettingsWindows =
      WindowsInitializationSettings(
    appName: 'FurClient',
    appUserModelId: '{A5B8C1D2-4E3F-5678-9012-3456789ABCDE}',
    guid: '{A5B8C1D2-4E3F-5678-9012-3456789ABCDE}',
  );
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    windows: initializationSettingsWindows,
  );

  await notificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {},
  );
}

Future<void> requestNotificationPermissions() async {
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin = notificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidPlugin != null) {
    await androidPlugin.requestNotificationsPermission();
  }
}

Future<void> showFavoriteNotification({required String title}) async {
  final androidDetails = AndroidNotificationDetails(
    'download_channel',
    'Favorites',
    channelDescription: 'Post favorites',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    onlyAlertOnce: true,
  );
  final windowsDetails = WindowsNotificationDetails();
  final details = NotificationDetails(
    android: androidDetails,
    windows: windowsDetails,
  );
  await notificationsPlugin.show(
    1,
    'Added to favorites',
    title,
    details,
  );
}

Future<void> showDownloadNotification({
  required String title,
  required String body,
  bool showProgress = false,
  int progress = 0,
  int maxProgress = 100,
}) async {
  final androidDetails = AndroidNotificationDetails(
    'download_channel',
    'Downloads',
    channelDescription: 'Image download progress and results',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    showProgress: showProgress,
    progress: progress,
    maxProgress: maxProgress,
    onlyAlertOnce: true,
  );
  final windowsDetails = WindowsNotificationDetails();
  final details = NotificationDetails(
    android: androidDetails,
    windows: windowsDetails,
  );
  await notificationsPlugin.show(
    0,
    title,
    body,
    details,
  );
}
