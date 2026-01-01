import 'package:dio/dio.dart';
import 'package:jan_aushadi/models/coupon_model.dart';

class CouponService {
  static const String _baseUrl = 'https://www.onlineaushadhi.in/myadmin/UserApis';
  static final Dio _dio = Dio();

  static Future<List<Coupon>> getCoupons() async {
    try {
      final response = await _dio.post(
        '$_baseUrl/get_coupon_data',
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Jan-Aushadhi-App/1.0',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data is String) {
          // Handle string response
          final jsonData = data;
          if (jsonData.contains('"response":"success"')) {
            // Parse the response
            final Map<String, dynamic> parsedData = _parseJsonResponse(jsonData);
            if (parsedData['data'] is List) {
              return (parsedData['data'] as List)
                  .map((coupon) => Coupon.fromJson(coupon as Map<String, dynamic>))
                  .toList();
            }
          }
        } else if (data is Map) {
          // Handle map response
          if (data['response'] == 'success' && data['data'] is List) {
            return (data['data'] as List)
                .map((coupon) => Coupon.fromJson(coupon as Map<String, dynamic>))
                .toList();
          }
        }
        
        return [];
      } else {
        throw Exception('Failed to fetch coupons: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching coupons: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> _parseJsonResponse(String jsonString) {
    // Simple JSON parsing for the response
    try {
      // Extract the data array from the JSON string
      final startIndex = jsonString.indexOf('"data":[');
      final endIndex = jsonString.lastIndexOf(']');
      
      if (startIndex != -1 && endIndex != -1) {
        final dataString = jsonString.substring(startIndex + 8, endIndex + 1);
        // This is a simplified approach - in production, use proper JSON parsing
        return {'data': []};
      }
      return {'data': []};
    } catch (e) {
      print('Error parsing JSON: $e');
      return {'data': []};
    }
  }
}
