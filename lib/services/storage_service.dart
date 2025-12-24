import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _addressesKey = 'user_addresses';
  static const String _defaultAddressKey = 'default_address';
  static const String _userPreferencesKey = 'user_preferences';
  static const String _orderHistoryKey = 'order_history';
  static const String _recentSearchesKey = 'recent_searches';
  static const String _favoriteProductsKey = 'favorite_products';

  late SharedPreferences _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    print('✅ StorageService initialized');
  }

  Future<void> saveAddresses(List<Map<String, dynamic>> addresses) async {
    try {
      final json = jsonEncode(addresses);
      await _prefs.setString(_addressesKey, json);
      print('✅ Addresses saved: ${addresses.length} addresses');
    } catch (e) {
      print('❌ Error saving addresses: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAddresses() async {
    try {
      final json = _prefs.getString(_addressesKey);
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Error loading addresses: $e');
      return [];
    }
  }

  Future<void> addAddress(Map<String, dynamic> address) async {
    try {
      final addresses = await getAddresses();
      addresses.add(address);
      await saveAddresses(addresses);
      print('✅ Address added');
    } catch (e) {
      print('❌ Error adding address: $e');
    }
  }

  Future<void> updateAddress(int index, Map<String, dynamic> address) async {
    try {
      final addresses = await getAddresses();
      if (index >= 0 && index < addresses.length) {
        addresses[index] = address;
        await saveAddresses(addresses);
        print('✅ Address updated at index $index');
      }
    } catch (e) {
      print('❌ Error updating address: $e');
    }
  }

  Future<void> deleteAddress(int index) async {
    try {
      final addresses = await getAddresses();
      if (index >= 0 && index < addresses.length) {
        addresses.removeAt(index);
        await saveAddresses(addresses);
        print('✅ Address deleted at index $index');
      }
    } catch (e) {
      print('❌ Error deleting address: $e');
    }
  }

  Future<void> setDefaultAddress(String addressId) async {
    try {
      await _prefs.setString(_defaultAddressKey, addressId);
      print('✅ Default address set: $addressId');
    } catch (e) {
      print('❌ Error setting default address: $e');
    }
  }

  Future<String?> getDefaultAddress() async {
    try {
      return _prefs.getString(_defaultAddressKey);
    } catch (e) {
      print('❌ Error getting default address: $e');
      return null;
    }
  }

  Future<void> saveUserPreferences(Map<String, dynamic> preferences) async {
    try {
      final json = jsonEncode(preferences);
      await _prefs.setString(_userPreferencesKey, json);
      print('✅ User preferences saved');
    } catch (e) {
      print('❌ Error saving preferences: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserPreferences() async {
    try {
      final json = _prefs.getString(_userPreferencesKey);
      if (json != null) {
        return jsonDecode(json) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('❌ Error loading preferences: $e');
      return null;
    }
  }

  Future<void> saveOrderHistory(List<Map<String, dynamic>> orders) async {
    try {
      final json = jsonEncode(orders);
      await _prefs.setString(_orderHistoryKey, json);
      print('✅ Order history saved: ${orders.length} orders');
    } catch (e) {
      print('❌ Error saving order history: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getOrderHistory() async {
    try {
      final json = _prefs.getString(_orderHistoryKey);
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ Error loading order history: $e');
      return [];
    }
  }

  Future<void> addToOrderHistory(Map<String, dynamic> order) async {
    try {
      final orders = await getOrderHistory();
      orders.add(order);
      await saveOrderHistory(orders);
      print('✅ Order added to history');
    } catch (e) {
      print('❌ Error adding to order history: $e');
    }
  }

  Future<void> saveRecentSearches(List<String> searches) async {
    try {
      await _prefs.setStringList(_recentSearchesKey, searches);
      print('✅ Recent searches saved: ${searches.length} items');
    } catch (e) {
      print('❌ Error saving recent searches: $e');
    }
  }

  Future<List<String>> getRecentSearches() async {
    try {
      return _prefs.getStringList(_recentSearchesKey) ?? [];
    } catch (e) {
      print('❌ Error loading recent searches: $e');
      return [];
    }
  }

  Future<void> addRecentSearch(String query) async {
    try {
      final searches = await getRecentSearches();
      if (searches.contains(query)) {
        searches.remove(query);
      }
      searches.insert(0, query);
      if (searches.length > 10) {
        searches.removeLast();
      }
      await saveRecentSearches(searches);
      print('✅ Recent search added: $query');
    } catch (e) {
      print('❌ Error adding recent search: $e');
    }
  }

  Future<void> saveFavoriteProducts(List<int> productIds) async {
    try {
      await _prefs.setString(_favoriteProductsKey, jsonEncode(productIds));
      print('✅ Favorite products saved: ${productIds.length} items');
    } catch (e) {
      print('❌ Error saving favorite products: $e');
    }
  }

  Future<List<int>> getFavoriteProducts() async {
    try {
      final json = _prefs.getString(_favoriteProductsKey);
      if (json != null) {
        final List<dynamic> decoded = jsonDecode(json);
        return decoded.cast<int>();
      }
      return [];
    } catch (e) {
      print('❌ Error loading favorite products: $e');
      return [];
    }
  }

  Future<void> addFavoriteProduct(int productId) async {
    try {
      final favorites = await getFavoriteProducts();
      if (!favorites.contains(productId)) {
        favorites.add(productId);
        await saveFavoriteProducts(favorites);
        print('✅ Product added to favorites: $productId');
      }
    } catch (e) {
      print('❌ Error adding favorite product: $e');
    }
  }

  Future<void> removeFavoriteProduct(int productId) async {
    try {
      final favorites = await getFavoriteProducts();
      favorites.remove(productId);
      await saveFavoriteProducts(favorites);
      print('✅ Product removed from favorites: $productId');
    } catch (e) {
      print('❌ Error removing favorite product: $e');
    }
  }

  Future<bool> isFavoriteProduct(int productId) async {
    try {
      final favorites = await getFavoriteProducts();
      return favorites.contains(productId);
    } catch (e) {
      print('❌ Error checking favorite product: $e');
      return false;
    }
  }

  Future<void> clearAllData() async {
    try {
      await _prefs.clear();
      print('✅ All local data cleared');
    } catch (e) {
      print('❌ Error clearing data: $e');
    }
  }

  Future<int> getTotalStoredData() async {
    try {
      final keys = _prefs.getKeys();
      return keys.length;
    } catch (e) {
      print('❌ Error getting stored data count: $e');
      return 0;
    }
  }

  void debugPrintAllData() {
    try {
      final keys = _prefs.getKeys();
      print('=== LocalStorage Debug Info ===');
      for (var key in keys) {
        final value = _prefs.get(key);
        print('$key: $value');
      }
      print('================================');
    } catch (e) {
      print('❌ Error printing debug info: $e');
    }
  }
}
