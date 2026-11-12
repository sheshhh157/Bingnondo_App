import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';
import 'notifications_settings_service.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'bingnondo_notifications',
    'Bingnondo notifications',
    description: 'Order, payment, and support updates.',
    importance: Importance.high,
  );

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _tapSubscription;
  StreamSubscription<String>? _tokenSubscription;
  VoidCallback? _notificationTapHandler;
  bool _initialized = false;
  bool _pendingNotificationTap = false;
  String? _registeredToken;

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    if (!DefaultFirebaseOptions.isConfigured) {
      debugPrint(
        '[PushNotifications] Firebase client settings are not configured.',
      );
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _localNotifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => _handleNotificationTap(),
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_channel);

      final messaging = FirebaseMessaging.instance;
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
      _tapSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        (_) => _handleNotificationTap(),
      );
      _tokenSubscription = messaging.onTokenRefresh.listen(_registerToken);
      _initialized = true;

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap();
    } catch (error, stackTrace) {
      debugPrint('[PushNotifications] Firebase initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void setNotificationTapHandler(VoidCallback? handler) {
    _notificationTapHandler = handler;
    if (handler != null && _pendingNotificationTap) {
      _pendingNotificationTap = false;
      scheduleMicrotask(handler);
    }
  }

  Future<void> registerCurrentDevice() async {
    if (!_initialized) return;

    try {
      final permission = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint(
          '[PushNotifications] Notification permission was denied; '
          'still attempting to register the device token.',
        );
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('[PushNotifications] Firebase returned no device token.');
        return;
      }
      await _registerToken(token);
    } catch (error, stackTrace) {
      debugPrint('[PushNotifications] Device registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> unregisterCurrentDevice() async {
    if (!_initialized) return;

    try {
      final token =
          _registeredToken ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await NotificationsSettingsService.instance.removeDeviceToken(token);
      _registeredToken = null;
    } catch (error, stackTrace) {
      debugPrint('[PushNotifications] Device removal failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _registerToken(String token) async {
    if (!_initialized || token.isEmpty || token == _registeredToken) return;

    try {
      await NotificationsSettingsService.instance.registerDeviceToken(
        token: token,
        platform: Platform.isAndroid ? 'android' : 'ios',
      );
      _registeredToken = token;
      debugPrint('[PushNotifications] Device token registered with backend.');
    } catch (error, stackTrace) {
      debugPrint('[PushNotifications] Device token upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'Bingnondo Cafe',
      body: notification.body ?? message.data['message'] as String? ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'bingnondo_notifications',
          'Bingnondo notifications',
          channelDescription: 'Order, payment, and support updates.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  void _handleNotificationTap() {
    final handler = _notificationTapHandler;
    if (handler == null) {
      _pendingNotificationTap = true;
      return;
    }
    scheduleMicrotask(handler);
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _tapSubscription?.cancel();
    await _tokenSubscription?.cancel();
  }
}
