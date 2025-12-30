import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'dart:convert';

class AuthService {
  static const _storage = FlutterSecureStorage();

  static Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConstants.keyIsLoggedIn);
    return token == 'true';
  }

  static Future<void> setLoggedIn(bool value, {String? userData}) async {
    await _storage.write(
      key: AppConstants.keyIsLoggedIn,
      value: value.toString(),
    );
    if (userData != null) {
      await _storage.write(key: AppConstants.keyUserData, value: userData);
      // Extract and save M1_CODE from user data
      try {
        print('DEBUG: Raw userData: $userData');
        final userDataMap = jsonDecode(userData);
        print('DEBUG: Decoded userDataMap: $userDataMap');
        final m1Code = userDataMap['M1_CODE'] ?? '';
        print('DEBUG: Extracted M1_CODE: $m1Code');
        if (m1Code.isNotEmpty) {
          await _storage.write(key: AppConstants.keyM1Code, value: m1Code);
          print('M1_CODE saved successfully: $m1Code');
        } else {
          print('ERROR: M1_CODE is empty from userDataMap');
        }
      } catch (e) {
        print('Error saving M1_CODE: $e');
      }
    }
  }

  static Future<String?> getM1Code() async {
    var m1Code = await _storage.read(key: AppConstants.keyM1Code);
    print('DEBUG getM1Code: Retrieved value: $m1Code');

    // If M1Code not found, try to extract from userData (for backward compatibility)
    if (m1Code == null || m1Code.isEmpty) {
      print('DEBUG getM1Code: M1_CODE not found, extracting from userData');
      try {
        final userData = await _storage.read(key: AppConstants.keyUserData);
        if (userData != null) {
          final userDataMap = jsonDecode(userData);
          m1Code = userDataMap['M1_CODE'] ?? '';
          print('DEBUG getM1Code: Extracted M1_CODE from userData: $m1Code');

          // Save it for future use
          if (m1Code!.isNotEmpty) {
            await _storage.write(key: AppConstants.keyM1Code, value: m1Code);
            print('DEBUG getM1Code: Saved M1_CODE to storage for future use');
          }
        }
      } catch (e) {
        print('DEBUG getM1Code: Error extracting from userData: $e');
      }
    }

    return m1Code;
  }

  static Future<void> debugPrintAllStoredData() async {
    final isLoggedIn = await _storage.read(key: AppConstants.keyIsLoggedIn);
    final userData = await _storage.read(key: AppConstants.keyUserData);
    final m1Code = await _storage.read(key: AppConstants.keyM1Code);
    print('=== DEBUG: All Stored Data ===');
    print('keyIsLoggedIn: $isLoggedIn');
    print('keyUserData: $userData');
    print('keyM1Code: $m1Code');
    print('==============================');
  }

  static Future<String?> getUserData() async {
    return await _storage.read(key: AppConstants.keyUserData);
  }

  static Future<void> saveUserData(Map<String, dynamic> data) async {
    final userData = await getUserData();
    Map<String, dynamic> newUserData = {};

    if (userData != null) {
      newUserData = jsonDecode(userData);
    }

    newUserData.addAll(data);
    await _storage.write(key: AppConstants.keyUserData, value: jsonEncode(newUserData));
  }

  static Future<void> logout() async {
    await _storage.deleteAll();
  }

  // Custom API URL methods
  static Future<void> setCustomApiUrl(String url) async {
    await _storage.write(key: AppConstants.keyCustomApiUrl, value: url);
    print('Custom API URL saved: $url');
  }

  static Future<String?> getCustomApiUrl() async {
    return await _storage.read(key: AppConstants.keyCustomApiUrl);
  }

  static Future<void> clearCustomApiUrl() async {
    await _storage.delete(key: AppConstants.keyCustomApiUrl);
    print('Custom API URL cleared');
  }

  static Future<String?> getM1Pacc() async {
    try {
      final userData = await _storage.read(key: AppConstants.keyUserData);
      if (userData != null) {
        final userDataMap = jsonDecode(userData);
        return userDataMap['M1_PACC']?.toString() ?? '';
      }
    } catch (e) {
      print('Error getting M1_PACC: $e');
    }
    return null;
  }
}
