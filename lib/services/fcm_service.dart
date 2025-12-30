import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jan_aushadi/services/notification_service.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final _storage = const FlutterSecureStorage();
  final _notificationService = NotificationService();

  static const String _fcmKey = 'fcm_token';

  /// 🔔 Initialize FCM
  Future<void> initializeFCM() async {
    try {
      print('🔔 Initializing FCM...');

      final token = await _getRealFCMToken();

      if (token.isEmpty) {
        print('❌ FCM token empty — Firebase not ready');
        return;
      }

      await _saveToken(token);
      await updateFCMTokenOnServer(token);

      // 🔄 Token refresh listener
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        print('🔄 FCM Token refreshed: $newToken');
        await _saveToken(newToken);
        await updateFCMTokenOnServer(newToken);
      });
    } catch (e) {
      print('❌ FCM init error: $e');
    }
  }

  /// 🔥 REAL Firebase token
  Future<String> _getRealFCMToken() async {
    try {
      print('🔥 Attempting to get Firebase token...');
      final token = await FirebaseMessaging.instance.getToken();
      
      if (token != null && token.isNotEmpty) {
        print('🔥 REAL FCM TOKEN: $token');
        return token;
      } else {
        print('⚠️ Firebase returned null or empty token');
        print('ℹ️ Possible causes:');
        print('   1. Google Play Services not installed');
        print('   2. Firebase not properly initialized');
        print('   3. No internet connection');
        print('   4. Firebase project misconfigured');
        return '';
      }
    } catch (e) {
      print('❌ Token fetch error: $e');
      print('ℹ️ Firebase may not be available on this device');
      return '';
    }
  }

  Future<void> _saveToken(String token) async {
    await _storage.write(key: _fcmKey, value: token);
  }

  Future<bool> updateFCMTokenOnServer(String token) async {
    print('📤 Sending FCM token to server...');
    return await _notificationService.updateFcmToken(token);
  }

  Future<String?> getSavedToken() async {
    return _storage.read(key: _fcmKey);
  }
}
