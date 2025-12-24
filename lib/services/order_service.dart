import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OrderService {
  static const String _ordersKey = 'jan_aushadhi_orders';

  // Save order to local storage
  Future<void> saveOrder(String orderId, Map<String, dynamic> orderData) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing orders
      final ordersJson = prefs.getString(_ordersKey) ?? '{}';
      final Map<String, dynamic> allOrders = jsonDecode(ordersJson);

      // Add new order
      allOrders[orderId] = orderData;

      // Save back to storage
      await prefs.setString(_ordersKey, jsonEncode(allOrders));

      print('✅ Order $orderId saved successfully');
    } catch (e) {
      print('❌ Error saving order $orderId: $e');
    }
  }

  // Get order from local storage
  Future<Map<String, dynamic>?> getOrder(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString(_ordersKey);

      if (ordersJson != null) {
        final Map<String, dynamic> allOrders = jsonDecode(ordersJson);
        return allOrders[orderId];
      }

      return null;
    } catch (e) {
      print('❌ Error getting order $orderId: $e');
      return null;
    }
  }

  // Get all orders from local storage
  Future<Map<String, dynamic>> getAllOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString(_ordersKey) ?? '{}';
      return jsonDecode(ordersJson);
    } catch (e) {
      print('❌ Error getting all orders: $e');
      return {};
    }
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final orderData = await getOrder(orderId);
      if (orderData != null) {
        orderData['currentStatus'] = status;
        orderData['updatedAt'] = DateTime.now().toString();
        await saveOrder(orderId, orderData);
        print('✅ Order $orderId status updated to $status');
      }
    } catch (e) {
      print('❌ Error updating order status: $e');
    }
  }

  // Delete order from local storage
  Future<void> deleteOrder(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString(_ordersKey);

      if (ordersJson != null) {
        final Map<String, dynamic> allOrders = jsonDecode(ordersJson);
        allOrders.remove(orderId);
        await prefs.setString(_ordersKey, jsonEncode(allOrders));
        print('✅ Order $orderId deleted successfully');
      }
    } catch (e) {
      print('❌ Error deleting order $orderId: $e');
    }
  }

  // Clear all orders
  Future<void> clearAllOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_ordersKey);
      print('✅ All orders cleared');
    } catch (e) {
      print('❌ Error clearing all orders: $e');
    }
  }
}
