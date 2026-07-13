import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _kHighImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Pickup updates',
  description: 'Request status, collector location, and pickup receipts.',
  importance: Importance.max,
  playSound: true,
);

class FcmService {
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  FcmService(this._messaging);

  Future<void> initialize({
    required void Function(String? payload) onNotificationTap,
  }) async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap(response.payload);
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_kHighImportanceChannel);

    // Show a real heads-up notification for messages that arrive while
    // the app is open — this is the piece that was missing. Without it,
    // foreground pushes are invisible outside the notification tray.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // iOS: also show banners while foregrounded.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _kHighImportanceChannel.id,
          _kHighImportanceChannel.name,
          channelDescription: _kHighImportanceChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<String?> getToken() async {
    if (Platform.isIOS) {
      final apnsToken = await _waitForApnsToken();
      if (apnsToken == null) return null;
    }
    return _messaging.getToken();
  }

  Future<String?> _waitForApnsToken({
    Duration timeout = const Duration(seconds: 10),
    Duration pollInterval = const Duration(milliseconds: 300),
  }) async {
    final deadline = DateTime.now().add(timeout);
    String? apnsToken = await _messaging.getAPNSToken();

    while (apnsToken == null && DateTime.now().isBefore(deadline)) {
      await Future.delayed(pollInterval);
      apnsToken = await _messaging.getAPNSToken();
    }

    return apnsToken;
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (_) {
      // Best-effort — don't block sign-out over this.
    }
  }

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;
}


Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {

}