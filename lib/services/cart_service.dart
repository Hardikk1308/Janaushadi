import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CartService {
  static const String _cartKey = 'jan_aushadhi_cart';
  static Map<String, int> _cartItems = {};
  static List<Function> _listeners = [];

  // Get current cart items
  static Map<String, int> get cartItems => Map.from(_cartItems);

  // Get total items count
  static int get totalItems =>
      _cartItems.values.fold(0, (sum, qty) => sum + qty);

  // Initialize cart from storage
  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Always start with empty cart on app restart
      _cartItems = {};
      await prefs.remove(_cartKey);
      await prefs.remove('clear_cart_on_init');
      print('🧹 Cart initialized as empty (fresh start)');
      
      _notifyListeners();
    } catch (e) {
      print('❌ Error initializing cart: $e');
      _cartItems = {};
    }
  }

  // Save cart to storage
  static Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(_cartItems);
      await prefs.setString(_cartKey, cartJson);
      print('✅ Cart saved to storage: $_cartItems');
    } catch (e) {
      print('❌ Error saving cart: $e');
    }
  }

  // Clear entire cart
  static Future<void> clearCart() async {
    _cartItems.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
    await prefs.setBool('clear_cart_on_init', true); // Set flag for next app start
    _notifyListeners();
    print('🧹 Cart cleared and will remain empty on next app start');
  }

  // Add item to cart
  static Future<void> addItem(String productId, int quantity) async {
    final previousQuantity = _cartItems[productId] ?? 0;
    _cartItems[productId] = quantity;
    await _saveToStorage();
    _notifyListeners();

    print('🛒 Added/Updated item $productId: $previousQuantity → $quantity');
  }

  // Update item quantity
  static Future<void> updateQuantity(String productId, int quantity) async {
    if (quantity <= 0) {
      await removeItem(productId);
    } else {
      _cartItems[productId] = quantity;
      await _saveToStorage();
      _notifyListeners();
      print('🔄 Updated item $productId quantity: $quantity');
    }
  }

  // Remove item from cart
  static Future<void> removeItem(String productId) async {
    _cartItems.remove(productId);
    await _saveToStorage();
    _notifyListeners();
    print('🗑️ Removed item $productId from cart');
  }

  // Get quantity for specific product
  static int getQuantity(String productId) {
    return _cartItems[productId] ?? 0;
  }

  // Check if product is in cart
  static bool hasItem(String productId) {
    return _cartItems.containsKey(productId) && _cartItems[productId]! > 0;
  }

  // Add listener for cart changes
  static void addListener(Function callback) {
    _listeners.add(callback);
  }

  // Remove listener
  static void removeListener(Function callback) {
    _listeners.remove(callback);
  }

  // Notify all listeners
  static void _notifyListeners() {
    for (var listener in _listeners) {
      try {
        listener();
      } catch (e) {
        print('❌ Error notifying cart listener: $e');
      }
    }
  }

  // Get cart summary
  static Map<String, dynamic> getCartSummary() {
    final totalItems = _cartItems.values.fold(0, (sum, qty) => sum + qty);
    final uniqueItems = _cartItems.length;

    return {
      'totalItems': totalItems,
      'uniqueItems': uniqueItems,
      'isEmpty': _cartItems.isEmpty,
    };
  }
}
