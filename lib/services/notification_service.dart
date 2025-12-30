import 'package:dio/dio.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final Dio _dio = Dio();

  /// Update FCM token on the server
  Future<bool> updateFcmToken(String fcmToken) async {
    try {
      final m1Code = await AuthService.getM1Code();

      if (m1Code == null || m1Code.isEmpty) {
        print('❌ User not logged in');
        return false;
      }

      if (fcmToken.isEmpty) {
        print('❌ FCM Token is empty');
        return false;
      }

      print('📱 Updating FCM token for user: $m1Code');
      print('   M1_CODE: $m1Code');
      print('   FCM Token: $fcmToken');
      print('   Token Length: ${fcmToken.length}');

      final response = await _dio.post(
        '${AppConstants.baseUrl}/update_fcm_token',
        data: {
          'M1_CODE': m1Code,
          'M1_PACC': fcmToken,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Jan-Aushadhi-App/1.0',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('✅ FCM token update response: ${response.statusCode}');
      print('📥 Response: ${response.data}');

      if (response.statusCode == 200) {
        var responseData = response.data;

        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (e) {
            print('Error parsing response: $e');
          }
        }

        if (responseData is Map &&
            responseData['response']?.toString().toLowerCase() == 'success') {
          print('✅ FCM token updated successfully');
          return true;
        } else {
          print('⚠️ Server returned 200 but response indicates failure');
          print('   Response: $responseData');
        }
      } else {
        print('⚠️ Server returned status ${response.statusCode}');
        print('   This may indicate the token is not registered with Firebase');
        print('   Verify google-services.json matches your Firebase project');
      }

      return false;
    } catch (e) {
      print('❌ Error updating FCM token: $e');
      return false;
    }
  }

  /// Send push notification
  Future<bool> sendPushNotification({
    required String title,
    required String description,
  }) async {
    try {
      final m1Code = await AuthService.getM1Code();

      if (m1Code == null || m1Code.isEmpty) {
        print('❌ User not logged in');
        return false;
      }

      print('🔔 Sending push notification');
      print('   Title: $title');
      print('   Description: $description');

      final response = await _dio.post(
        '${AppConstants.baseUrl}/send_push_notification',
        data: {
          'M1_CODE': m1Code,
          'title': title,
          'description': description,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Jan-Aushadhi-App/1.0',
          },
        ),
      );

      print('✅ Push notification response: ${response.statusCode}');
      print('📥 Response: ${response.data}');

      if (response.statusCode == 200) {
        var responseData = response.data;

        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (e) {
            print('Error parsing response: $e');
          }
        }

        if (responseData is Map &&
            responseData['response']?.toString().toLowerCase() == 'success') {
          print('✅ Push notification sent successfully');
          return true;
        }
      }

      return false;
    } catch (e) {
      print('❌ Error sending push notification: $e');
      return false;
    }
  }

  /// Get all order notifications
  Future<List<Map<String, dynamic>>> getOrderNotifications() async {
    try {
      final m1Code = await AuthService.getM1Code();

      if (m1Code == null || m1Code.isEmpty) {
        print('❌ User not logged in');
        return [];
      }

      print('📬 Fetching order notifications for user: $m1Code');

      final response = await _dio.post(
        '${AppConstants.baseUrl}/get_all_notification',
        data: {
          'M1_CODE': m1Code,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Jan-Aushadhi-App/1.0',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      print('✅ Notifications response: ${response.statusCode}');

      if (response.statusCode == 200) {
        var responseData = response.data;

        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (e) {
            print('Error parsing response: $e');
            return [];
          }
        }

        if (responseData is Map && responseData['data'] is List) {
          final notifications = List<Map<String, dynamic>>.from(
            responseData['data'].map((item) => Map<String, dynamic>.from(item as Map)),
          );
          print('✅ Retrieved ${notifications.length} notifications');
          return notifications;
        }
      }

      print('⚠️ No notifications found or error in response');
      return [];
    } catch (e) {
      print('❌ Error fetching notifications: $e');
      return [];
    }
  }
}
