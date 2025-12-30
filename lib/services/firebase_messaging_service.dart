import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:jan_aushadi/services/in_app_notification_service.dart';

class FirebaseMessagingService {
  static final FirebaseMessagingService _instance =
      FirebaseMessagingService._internal();

  factory FirebaseMessagingService() {
    return _instance;
  }

  FirebaseMessagingService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final InAppNotificationService _inAppNotificationService =
      InAppNotificationService();

  /// Initialize Firebase Messaging
  Future<void> initializeMessaging() async {
    try {
      print('🔥 Initializing Firebase Messaging...');

      // Request notification permissions
      try {
        final settings = await _firebaseMessaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        print('📱 User notification permission status: ${settings.authorizationStatus}');
      } catch (e) {
        print('⚠️ Could not request notification permissions: $e');
      }

      // Handle foreground messages
      try {
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          print('🔔 Got a message whilst in the foreground!');
          print('Message data: ${message.data}');

          if (message.notification != null) {
            print('Message also contained a notification:');
            print('  Title: ${message.notification!.title}');
            print('  Body: ${message.notification!.body}');

            // Show in-app notification
            _inAppNotificationService.showInfo(
              title: message.notification!.title ?? 'Notification',
              message: message.notification!.body ?? '',
              duration: const Duration(seconds: 5),
            );
          }
        });
      } catch (e) {
        print('⚠️ Could not set up foreground message handler: $e');
      }

      // Handle notification tap when app is in background
      try {
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          print('🔔 A new onMessageOpenedApp event was published!');
          print('Message data: ${message.data}');

          if (message.notification != null) {
            print('Notification:');
            print('  Title: ${message.notification!.title}');
            print('  Body: ${message.notification!.body}');
          }

          // Handle navigation based on message data
          _handleMessageTap(message);
        });
      } catch (e) {
        print('⚠️ Could not set up message opened handler: $e');
      }

      // Get initial message if app was terminated
      try {
        final initialMessage = await _firebaseMessaging.getInitialMessage();
        if (initialMessage != null) {
          print('🔔 App opened from terminated state with message');
          _handleMessageTap(initialMessage);
        }
      } catch (e) {
        print('⚠️ Could not get initial message: $e');
      }

      print('✅ Firebase Messaging initialized successfully');
    } catch (e) {
      print('❌ Error initializing Firebase Messaging: $e');
      print('ℹ️ App will continue without Firebase Messaging');
    }
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      print('🔥 FCM Token: $token');
      return token;
    } catch (e) {
      print('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Handle message tap
  void _handleMessageTap(RemoteMessage message) {
    // Extract data from message
    final data = message.data;

    // Example: Navigate based on message type
    if (data.containsKey('type')) {
      final type = data['type'];
      print('📍 Message type: $type');

      switch (type) {
        case 'order':
          print('📦 Navigating to order: ${data['orderId']}');
          // Navigate to order details
          break;
        case 'promotion':
          print('🎁 Navigating to promotion: ${data['promotionId']}');
          // Navigate to promotion
          break;
        default:
          print('📍 Unknown message type: $type');
      }
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      print('✅ Subscribed to topic: $topic');
    } catch (e) {
      print('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      print('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      print('❌ Error unsubscribing from topic: $e');
    }
  }
}
