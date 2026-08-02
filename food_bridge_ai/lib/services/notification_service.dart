import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message received
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _isProcessing = false;

  static void _log(String message) {
    // Silenced local debug prints
    // debugPrint('🔔 $message');
  }

  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false, // Don't request immediately
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _createNotificationChannel();

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    } catch (e) {
      debugPrint('NotificationService initialization failed: $e');
    }
  }

  static Future<void> requestPermissions() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      _log('Delaying permission request for 3s...');
      await Future.delayed(const Duration(seconds: 3));
      
      _log('Requesting permissions...');
      // Request FCM permission
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        _log('FCM Permission Request Timed Out');
        return const NotificationSettings(
          alert: AppleNotificationSetting.disabled,
          announcement: AppleNotificationSetting.disabled,
          authorizationStatus: AuthorizationStatus.notDetermined,
          badge: AppleNotificationSetting.disabled,
          carPlay: AppleNotificationSetting.disabled,
          lockScreen: AppleNotificationSetting.disabled,
          notificationCenter: AppleNotificationSetting.disabled,
          showPreviews: AppleShowPreviewSetting.never,
          sound: AppleNotificationSetting.disabled,
          criticalAlert: AppleNotificationSetting.disabled,
          timeSensitive: AppleNotificationSetting.disabled,
          providesAppNotificationSettings: AppleNotificationSetting.disabled,
        );
      });

      // Explicitly request Android 13+ POST_NOTIFICATIONS
      if (!kIsWeb) {
        _log('Requesting POST_NOTIFICATIONS...');
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        await androidPlugin?.requestNotificationsPermission().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            _log('Local Notification Permission Timed Out');
            return false;
          },
        );
      }
    } catch (e) {
      _log('Permission request failed: $e');
    } finally {
      _isProcessing = false;
    }
  }

  static Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'foodbridge_channel',
      'FoodBridge Notifications',
      description: 'Notifications for food donations and deliveries',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'foodbridge_channel',
          'FoodBridge Notifications',
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['type'],
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    // Navigation handled via app-level listener
  }

  static Future<void> saveToken() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      _log('Delaying token sync for 3s...');
      await Future.delayed(const Duration(seconds: 3));
      
      _log('Fetching FCM Token...');
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log('FCM Token Retrieval Timed Out');
          return null;
        },
      );
      
      if (token != null) {
        _log('Updating token in Firestore...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': token}).timeout(
          const Duration(seconds: 5),
          onTimeout: () => _log('Firestore Token Update Timed Out'),
        );
        _log('Token saved successfully');
      }
    } catch (e) {
      _log('Failed to save token: $e');
    }
  }

  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'foodbridge_channel',
          'FoodBridge Notifications',
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }
}
