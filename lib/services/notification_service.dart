import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Сервис уведомлений о загрузках.
/// Показывает прогресс-уведомление пока идёт загрузка,
/// и финальное уведомление об успехе/ошибке.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  static const String _channelId = 'easy_loader_downloads';
  static const String _channelName = 'Загрузки';
  static const String _channelDesc = 'Прогресс и завершение загрузок';

  Future<void> init() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Create high-importance channel for Android
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDesc,
              importance: Importance.low, // low = silent progress
              playSound: false,
              enableVibration: false,
            ),
          );
    }

    _initialized = true;
  }

  /// Показывает прогресс-уведомление (0–100).
  /// [id] — уникальный идентификатор элемента очереди (int).
  Future<void> showProgress({
    required int id,
    required String title,
    required int progressPercent,
  }) async {
    await init();

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progressPercent,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      id,
      'Загрузка: $title',
      '$progressPercent%',
      NotificationDetails(android: androidDetails),
    );
  }

  /// Завершает уведомление о прогрессе и показывает итоговое.
  Future<void> showComplete({
    required int id,
    required String title,
  }) async {
    await init();
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.stopForegroundService();
    }
    await _plugin.cancel(id);

    final androidDetails = AndroidNotificationDetails(
      '${_channelId}_done',
      'Завершённые загрузки',
      channelDescription: 'Уведомления о завершённых загрузках',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      id + 10000,
      'Загружено',
      title,
      NotificationDetails(android: androidDetails),
    );
  }

  /// Показывает уведомление об ошибке.
  Future<void> showError({
    required int id,
    required String title,
    required String error,
  }) async {
    await init();
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.stopForegroundService();
    }
    await _plugin.cancel(id);

    final androidDetails = AndroidNotificationDetails(
      '${_channelId}_error',
      'Ошибки загрузки',
      channelDescription: 'Уведомления об ошибках загрузки',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _plugin.show(
      id + 20000,
      'Ошибка загрузки',
      title,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancel(int id) async {
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.stopForegroundService();
    }
    await _plugin.cancel(id);
  }
}
