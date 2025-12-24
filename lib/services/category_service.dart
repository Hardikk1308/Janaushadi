import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:jan_aushadi/models/master_category.dart';

class CategoryService {
  static final Dio _dio = Dio();
  static const String _baseUrl = 'https://www.onlineaushadhi.in/myadmin/UserApis/';
  
  // Cache to avoid repeated API calls
  static List<MasterCategory>? _cachedCategories;
  
  /// Fetch all categories from the API
  static Future<List<MasterCategory>> fetchAllCategories() async {
    if (_cachedCategories != null) {
      return _cachedCategories!;
    }
    
    try {
      final response = await _dio.post(
        '$_baseUrl/get_master_data',
        data: {'M1_TYPE': 'Category', 'M1_CODE': '69'},
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        var data = response.data;
        
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success' && data['data'] is List) {
          _cachedCategories = (data['data'] as List)
              .map((item) => MasterCategory.fromJson(item))
              .toList();
          
          return _cachedCategories!;
        }
      }
      throw Exception('Failed to load categories');
    } catch (e) {
      print('Error fetching categories: $e');
      rethrow;
    }
  }
  
  /// Get a specific category by cat_id
  static Future<MasterCategory?> getCategoryById(String catId) async {
    try {
      final categories = await fetchAllCategories();
      return categories.firstWhere(
        (category) => category.id == catId,
        orElse: () => throw Exception('Category not found'),
      );
    } catch (e) {
      print('Error getting category by ID $catId: $e');
      return null;
    }
  }
  
  /// Get category name by cat_id
  static Future<String> getCategoryName(String catId) async {
    final category = await getCategoryById(catId);
    return category?.name ?? 'Unknown Category';
  }
  
  /// Clear the cache (useful when you need fresh data)
  static void clearCache() {
    _cachedCategories = null;
  }
}
