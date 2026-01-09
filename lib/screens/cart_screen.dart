import 'package:flutter/material.dart';
import 'package:jan_aushadi/models/Product_model.dart' as product_model;
import 'package:jan_aushadi/models/coupon_model.dart';
import 'package:jan_aushadi/screens/manage_addresses_screen.dart';
import 'package:jan_aushadi/screens/your_details_screen.dart';
import 'package:jan_aushadi/screens/payment_options_screen.dart';
import 'package:jan_aushadi/screens/order_success_screen.dart';
import 'package:jan_aushadi/widgets/secure_image_widget.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/services/cart_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

typedef Product = product_model.Product;

class CartScreen extends StatefulWidget {
  final Map<int, int> cartItems;
  final List<Product> products;

  const CartScreen({
    super.key,
    required this.cartItems,
    required this.products,
  });

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Map<int, int> _cartItems;
  String _selectedAddress = '';
  Address? _selectedAddressObject;
  // 'cod' or 'online'
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  late Razorpay _razorpay;
  bool _isProcessingPayment = false;
  bool _isPlacingOrder = false; // Guard against multiple order placements

  static const String _checkoutAddressKey = 'checkout_selected_address';
  static const String _appliedCouponKey = 'applied_coupon_code';
  static const String _couponDiscountKey = 'applied_coupon_discount';

  // Coupon state
  Coupon? _appliedCoupon;
  double _couponDiscount = 0.0;

  // Bill details
  double get _totalMrpPrice => _calculateTotalMrp();
  double get _totalSalePrice => _calculateTotal();
  double get _savings => _totalMrpPrice - _totalSalePrice;
  double get _total => _totalSalePrice - _couponDiscount;

  // New method to show payment method selection

  @override
  void initState() {
    super.initState();
    _cartItems = Map.from(widget.cartItems);
    _initializeRazorpay();
    _loadCartFromSharedPreferences();
    _loadSelectedAddress();
    _loadAppliedCoupon();
  }

  Future<void> _loadAppliedCoupon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final couponCode = prefs.getString(_appliedCouponKey);
      final discount = prefs.getDouble(_couponDiscountKey) ?? 0.0;

      if (couponCode != null && couponCode.isNotEmpty) {
        setState(() {
          _appliedCoupon = Coupon(
            code: couponCode,
            name: couponCode,
            discountType: 'Flat',
            amount: discount.toString(),
            minAmount: '0',
            expiryDate: '',
            description: 'Applied Coupon',
          );
          _couponDiscount = discount;
        });
        print('✅ Loaded coupon from storage: $couponCode - ₹$discount');
      }
    } catch (e) {
      print('❌ Error loading coupon: $e');
    }
  }

  Future<void> _loadSelectedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressJson = prefs.getString(_checkoutAddressKey);
      if (addressJson != null) {
        final addressData = jsonDecode(addressJson);
        setState(() {
          _selectedAddressObject = Address.fromJson(addressData);
          _selectedAddress = _selectedAddressObject!.fullAddress;
        });
        print('✅ Loaded checkout address: ${_selectedAddressObject?.id}');
      }
    } catch (e) {
      print('❌ Error loading checkout address: $e');
    }
  }

  Future<void> _saveSelectedAddress(Address address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressJson = jsonEncode(address.toJson());
      await prefs.setString(_checkoutAddressKey, addressJson);
      setState(() {
        _selectedAddressObject = address;
        _selectedAddress = address.fullAddress;
      });
      print('✅ Saved checkout address: ${address.id}');
    } catch (e) {
      print('❌ Error saving checkout address: $e');
    }
  }

  Future<void> _loadCartFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');
      if (cartJson != null && cartJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(cartJson);
        setState(() {
          _cartItems = decoded.map(
            (key, value) => MapEntry(int.parse(key), value as int),
          );
        });
        print('✅ Cart reloaded from SharedPreferences: $_cartItems');
      } else {
        // Cart is empty in SharedPreferences
        setState(() {
          _cartItems.clear();
        });
        print('🛒 Cart is empty - cleared from state');
      }
    } catch (e) {
      print('❌ Error loading cart from SharedPreferences: $e');
    }
  }

  void _initializeRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _nameController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    print('✅ Payment Success: ${response.paymentId}');
    print('✅ Order ID: ${response.orderId}');
    print('✅ Signature: ${response.signature}');

    // Place order after successful payment
    _placeOrder('Online Payment', response.orderId, response.signature);
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('❌ Payment Error: ${response.code} - ${response.message}');
    setState(() {
      _isProcessingPayment = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment Failed: ${response.message}'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('🔗 External Wallet: ${response.walletName}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('External Wallet: ${response.walletName}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  double _calculateTotal() {
    double total = 0;

    // If no products available, return 0
    if (widget.products.isEmpty) {
      print('⚠️ No products available for calculation');
      return 0;
    }

    for (final entry in _cartItems.entries) {
      try {
        final product = widget.products.firstWhere((p) {
          try {
            return int.parse(p.id) == entry.key;
          } catch (e) {
            print('⚠️ Invalid product ID: ${p.id}');
            return false;
          }
        });
        total += product.salePrice * entry.value;
      } catch (e) {
        print('⚠️ Product not found for cart item: ${entry.key}');
        // Skip this item if product not found
        continue;
      }
    }
    return total;
  }

  double _calculateTotalMrp() {
    double total = 0;

    // If no products available, return 0
    if (widget.products.isEmpty) {
      print('⚠️ No products available for calculation');
      return 0;
    }

    for (final entry in _cartItems.entries) {
      try {
        final product = widget.products.firstWhere((p) {
          try {
            return int.parse(p.id) == entry.key;
          } catch (e) {
            print('⚠️ Invalid product ID: ${p.id}');
            return false;
          }
        });
        // Use originalPrice as MRP, fallback to salePrice if not available
        final mrpPrice = product.originalPrice > 0
            ? product.originalPrice
            : product.salePrice;
        total += mrpPrice * entry.value;
      } catch (e) {
        print('⚠️ Product not found for cart item: ${entry.key}');
        // Skip this item if product not found
        continue;
      }
    }
    return total;
  }

  Widget _buildBillRow(String label, String value, {bool isTotal = false}) {
    final isSavings = label.contains('You Saved') || value.startsWith('-');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isSavings ? Colors.green[700] : Colors.grey[600],
              fontWeight: isTotal || isSavings
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal || isSavings
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isTotal
                  ? const Color(0xFF1976D2)
                  : isSavings
                  ? Colors.green[700]
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _applyCoupon(Coupon coupon) {
    setState(() {
      _appliedCoupon = coupon;
      _couponDiscount = double.tryParse(coupon.amount) ?? 0.0;
    });

    _saveCouponToPreferences(coupon);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Coupon ${coupon.code} applied! Discount: ₹${_couponDiscount.toStringAsFixed(2)}',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0.0;
    });

    _clearCouponFromPreferences();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coupon removed'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveCouponToPreferences(Coupon coupon) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_appliedCouponKey, coupon.code);
      await prefs.setDouble(_couponDiscountKey, _couponDiscount);
      print('✅ Coupon saved: ${coupon.code} - ₹$_couponDiscount');
    } catch (e) {
      print('❌ Error saving coupon: $e');
    }
  }

  Future<void> _clearCouponFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_appliedCouponKey);
      await prefs.remove(_couponDiscountKey);
      print('✅ Coupon cleared from preferences');
    } catch (e) {
      print('❌ Error clearing coupon: $e');
    }
  }

  Future<void> _navigateToPaymentOptions() async {
    if (_selectedAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a delivery address'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to payment options screen
    final result = await Navigator.push<Map<int, int>>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentOptionsScreen(
          totalAmount: _calculateTotal(),
          cartItems: _cartItems,
          products: widget.products, // Pass products list for real pricing
          onPaymentSelected: (paymentMethod) async {
            if (paymentMethod == 'upi' ||
                paymentMethod == 'card' ||
                paymentMethod == 'netbanking') {
              // For online payments, navigate to personal details first
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => YourDetailsScreen(
                    products: widget.products,
                    cartItems: _cartItems,
                  ),
                ),
              );

              if (result == true) {
                await _initiatePayment();
              }
            } else {
              // For other payment methods like COD
              await _placeOrder('COD', null, null);
            }
          },
        ),
      ),
    );

    // If order was placed successfully, refresh cart from SharedPreferences
    if (result != null && result.isEmpty) {
      print('✅ Order placed - refreshing cart from SharedPreferences');
      await _loadCartFromSharedPreferences();
    }
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _isProcessingPayment = true;
    });

    try {
      final total = _calculateTotal();
      final amountInPaise = (total * 100).toInt(); // Convert to paise

      var options = {
        'key': 'rzp_live_irPiip7JaRitDG',
        'amount': amountInPaise,
        'name': 'Jan Aushadhi',
        'description': 'Order Payment',
        'prefill': {
          'contact': _phoneController.text.isNotEmpty
              ? _phoneController.text
              : '',
          'email': '',
        },
        'theme': {'color': '#1976D2'},
      };

      _razorpay.open(options);
    } catch (e) {
      print('❌ Error initiating payment: $e');
      setState(() {
        _isProcessingPayment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _placeOrder(
    String paymentMethod,
    String? orderId,
    String? signature,
  ) async {
    // CRITICAL: Prevent multiple simultaneous order placements
    if (_isPlacingOrder) {
      print(
        '⚠️ CART: Order placement already in progress, ignoring duplicate call',
      );
      return;
    }

    _isPlacingOrder = true;
    print('🔒 CART: Order placement locked - preventing duplicate calls');

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
          ),
        ),
      );
    }

    try {
      // Create Dio instance with cookie management
      final dio = Dio();
      final cookieJar = CookieJar();
      dio.interceptors.add(CookieManager(cookieJar));
      final m1Code = await AuthService.getM1Code();

      if (m1Code == null || m1Code.isEmpty) {
        throw Exception('User not logged in');
      }

      // CRITICAL: Validate that an address is selected
      if (_selectedAddressObject == null || _selectedAddressObject!.id.isEmpty) {
        throw Exception('No delivery address selected. Please select an address before placing order.');
      }

      print('📍 Cart: Selected address ID: ${_selectedAddressObject!.id}');
      print('📍 Cart: Selected address: ${_selectedAddressObject!.fullAddress}');

      // IMPORTANT: Call select_delivery_address API first to register the address selection
      print('📍 Cart: Calling select_delivery_address API...');
      print('📍 Cart: Sending M1_CODE: $m1Code, M1_ADD_ID: ${_selectedAddressObject!.id}');
      try {
        final selectAddressResponse = await dio.post(
          'https://www.onlineaushadhi.in/myadmin/UserApis/select_delivery_address',
          data: {'M1_CODE': m1Code, 'M1_ADD_ID': _selectedAddressObject!.id},
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

        print(
          '📍 Cart: Select Address API Response: ${selectAddressResponse.statusCode}',
        );
        print(
          '📍 Cart: Select Address API Data: ${selectAddressResponse.data}',
        );

        if (selectAddressResponse.statusCode == 200) {
          var responseData = selectAddressResponse.data;
          if (responseData is String) {
            responseData = jsonDecode(responseData);
          }
          
          if (responseData is Map && responseData['response'] == 'success') {
            print('✅ Cart: Address successfully selected on backend');
            print('✅ Cart: Backend confirmed address selection');
          } else {
            print(
              '⚠️ Cart: Backend response not success: ${responseData['response']}',
            );
            throw Exception('Backend failed to select address: ${responseData['message']}');
          }
        } else {
          print(
            '⚠️ Cart: Failed to select address (HTTP ${selectAddressResponse.statusCode})',
          );
          throw Exception('Failed to select delivery address on backend');
        }
      } catch (e) {
        print('❌ Cart: Error calling select_delivery_address: $e');
        throw Exception('Failed to select delivery address: $e');
      }

      // Add a small delay to ensure backend processes the address selection
      await Future.delayed(const Duration(milliseconds: 500));

      // Prepare order data
      final orderData = {
        'M1_CODE': m1Code, // Add M1_CODE as well
        'F4_PARTY': m1Code,
        'F4_BT': 'Placed',
        'M1_ADD_ID': _selectedAddressObject!.id.toString(), // Primary address ID parameter
        'address_id': _selectedAddressObject!.id.toString(), // Alternative parameter name
        'F4_M1_ADD_ID': _selectedAddressObject!.id.toString(), // Another alternative
        // Also send address details directly to ensure backend uses correct address
        'F4_ADD1': _selectedAddressObject!.houseNumber ?? '',
        'F4_ADD2': _selectedAddressObject!.city ?? '',
        'F4_ADD3': _selectedAddressObject!.state ?? '',
        'F4_ADD4': _selectedAddressObject!.pincode ?? '',
        'F4_ADD5': _selectedAddressObject!.latitude ?? '',
        'F4_ADD6': _selectedAddressObject!.longitude ?? '',
        'F4_ADD7': _selectedAddressObject!.street ?? '',
        'F4_ADD8': _selectedAddressObject!.landmark ?? '',
        'payment_method': paymentMethod,
        'payment_status': paymentMethod.toUpperCase() == 'COD'
            ? 'pending'
            : 'paid',
      };

      // Add payment info for online payments
      if (paymentMethod.toUpperCase() != 'COD') {
        orderData['payment_id'] = '';
        orderData['razorpay_order_id'] = orderId ?? '';
        orderData['razorpay_signature'] = signature ?? '';
      }

      // Add products to order - matching API expectation (F4_F1, F4_QTOT, F4_AMT1, etc.)
      int index = 0;
      double subTotal = 0.0;
      for (final entry in _cartItems.entries) {
        try {
          final product = widget.products.firstWhere((p) {
            try {
              return int.parse(p.id) == entry.key;
            } catch (e) {
              print('⚠️ Invalid product ID: ${p.id}');
              return false;
            }
          });

          final quantity = entry.value;
          final mrpPrice = product.originalPrice > 0
              ? product.originalPrice
              : product.salePrice;
          final salePrice = product.salePrice;
          final totalMrp = mrpPrice * quantity;
          final totalSale = salePrice * quantity;

          orderData['F4_F1[$index]'] = product.id;
          orderData['F4_QTOT[$index]'] = quantity.toString();
          orderData['F4_AMT1[$index]'] = mrpPrice.toStringAsFixed(2);
          orderData['F4_AMT2[$index]'] = salePrice.toStringAsFixed(2);
          orderData['F4_AMT3[$index]'] = totalMrp.toStringAsFixed(2);
          orderData['F4_AMT4[$index]'] = totalSale.toStringAsFixed(2);

          subTotal += totalSale;
          index++;
        } catch (e) {
          print('⚠️ Error processing cart item ${entry.key}: $e');
          continue;
        }
      }

      // Add totals
      orderData['F4_STOT'] = subTotal.toStringAsFixed(2);
      orderData['F4_DAMT'] = '0'; // Delivery amount (removed)
      orderData['F4_TRP'] = ''; // Transport/Coupon ID
      orderData['F4_DIS'] = '0'; // Discount
      orderData['F4_GTOT'] = subTotal.toStringAsFixed(2);

      // Payment method details
      orderData['F4_USERMOD'] = paymentMethod.toUpperCase() == 'COD'
          ? 'COD'
          : 'Online';
      orderData['F4_PAYMOD'] = paymentMethod.toUpperCase() == 'COD'
          ? ''
          : paymentMethod; // UPI, Card, etc.
      orderData['F4_USERORDER_ID'] = orderId ?? ''; // Razorpay order ID
      orderData['F4_USERTRANS_ID'] = signature ?? ''; // Razorpay payment ID
      orderData['F4_USERMOD_ST'] = ''; // User modification status

      print('🚀 ========================================');
      print('🚀 CART: PLACING ORDER - SINGLE API CALL');
      print('🚀 ========================================');
      print('📍 ADDRESS DETAILS BEING SENT:');
      print('   M1_ADD_ID: ${_selectedAddressObject!.id}');
      print('   F4_ADD1 (House): ${_selectedAddressObject!.houseNumber}');
      print('   F4_ADD2 (City): ${_selectedAddressObject!.city}');
      print('   F4_ADD3 (State): ${_selectedAddressObject!.state}');
      print('   F4_ADD4 (Pincode): ${_selectedAddressObject!.pincode}');
      print('   F4_ADD5 (Lat): ${_selectedAddressObject!.latitude}');
      print('   F4_ADD6 (Long): ${_selectedAddressObject!.longitude}');
      print('   F4_ADD7 (Street): ${_selectedAddressObject!.street}');
      print('   F4_ADD8 (Landmark): ${_selectedAddressObject!.landmark}');
      print('📤 Cart: Order data:');
      orderData.forEach((key, value) {
        print('   $key = $value');
      });
      print('🚀 ========================================');

      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/place_order',
        data: orderData,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      print('🚀 ========================================');
      print('📥 CART: BACKEND RESPONSE RECEIVED');
      print('🚀 ========================================');
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response data: ${response.data}');
      print('🚀 ========================================');

      setState(() {
        _isProcessingPayment = false;
      });

      // Check HTTP status first
      print('📥 Cart: HTTP Status Code: ${response.statusCode}');
      print('📥 Cart: Response headers: ${response.headers}');

      if (response.statusCode == 401) {
        print('🔐 CART: 401 UNAUTHORIZED ERROR detected!');
        print('   - Authentication failed');
        print('   - Check API credentials');
        print('   - Response: ${response.data}');
        throw Exception('401 Unauthorized: Authentication failed');
      } else if (response.statusCode == 403) {
        print('🚫 CART: 403 FORBIDDEN ERROR detected!');
        print('   - Access denied');
        print('   - Response: ${response.data}');
        throw Exception('403 Forbidden: Access denied');
      } else if (response.statusCode != 200) {
        print('❌ CART: HTTP Error ${response.statusCode}');
        print('   - Response: ${response.data}');
        throw Exception(
          'HTTP Error ${response.statusCode}: ${response.statusMessage}',
        );
      }

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          print('📥 Cart: Response is string, decoding JSON...');
          try {
            data = jsonDecode(data);
          } catch (jsonError) {
            print('❌ Cart: JSON decode error: $jsonError');
            print('❌ Cart: Raw content: $data');
            throw Exception('Invalid JSON response: $jsonError');
          }
        }

        print('📥 Cart: Parsed response: $data');
        print('📥 Cart: Response type: ${data.runtimeType}');

        if (data is Map) {
          print('📥 Cart: Response keys: ${data.keys.toList()}');
          print('📥 Cart: Response[\'response\']: ${data['response']}');
        }

        if (data['response'] == 'success') {
          print('✅ Cart: Order placement successful');
          // Clear cart using CartService to ensure SharedPreferences and listeners are updated
          _cartItems.clear();
          await CartService.clearCart();

          // Close loading dialog using root navigator
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          // Small delay to ensure dialog is closed
          await Future.delayed(const Duration(milliseconds: 300));

          // Navigate to order success screen
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OrderSuccessScreen(
                  orderId: data['order_id']?.toString() ?? orderId ?? 'N/A',
                  totalAmount: _calculateTotal(),
                  paymentMethod: paymentMethod,
                ),
              ),
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Order placed successfully! Cart has been cleared.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          print(
            '❌ Cart: Order placement failed - ${data['message'] ?? 'Unknown error'}',
          );
          // Close loading dialog using root navigator
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
          }
          throw Exception(data['message'] ?? 'Failed to place order');
        }
      }
    } catch (e) {
      print('💥 CART EXCEPTION:');
      print('   Exception type: ${e.runtimeType}');
      print('   Exception message: $e');

      if (e.toString().contains('401')) {
        print('🔐 CART: 401 ERROR detected in exception!');
      } else if (e.toString().contains('403')) {
        print('🚫 CART: 403 ERROR detected in exception!');
      }

      print('📍 Cart stack trace: ${StackTrace.current}');

      // Close loading dialog using root navigator
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (e) {
          print('⚠️ Could not close dialog: $e');
        }
      }

      setState(() {
        _isProcessingPayment = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error placing order: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isPlacingOrder = false;
      print('🔓 CART: Order placement unlocked');
    }
  }

  void _updateQuantity(int productId, int newQuantity) async {
    setState(() {
      if (newQuantity <= 0) {
        _cartItems.remove(productId);
      } else {
        _cartItems[productId] = newQuantity;
      }
    });

    // Save cart changes to SharedPreferences immediately
    await _saveCartToSharedPreferences();
  }

  Future<void> _saveCartToSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(
        _cartItems.map((key, value) => MapEntry(key.toString(), value)),
      );
      await prefs.setString('cart_items', cartJson);
      print('✅ Cart saved to SharedPreferences: $_cartItems');
    } catch (e) {
      print('❌ Error saving cart to SharedPreferences: $e');
    }
  }

  void _showAddressForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageAddressesScreen(isSelectMode: true),
      ),
    ).then((selectedAddress) async {
      if (selectedAddress != null && selectedAddress is Address) {
        // Save the selected address for future checkouts
        await _saveSelectedAddress(selectedAddress);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _calculateTotal();
    final cartItemsList = _cartItems.entries.toList();

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _cartItems);  
        return false;
      },
      child: SafeArea(
        child: Scaffold(
          // resizeToAvoidBottomInset: true,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context, _cartItems),
            ),
            title: const Text(
              'Shopping Cart',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: _cartItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your cart is empty',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Cart Items List with Address and Bill Details at the end
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount:
                            cartItemsList.length +
                            1, // +1 for address and bill details
                        itemBuilder: (context, index) {
                          // Show products first
                          if (index < cartItemsList.length) {
                            final entry = cartItemsList[index];
                            final productId = entry.key;
                            final quantity = entry.value;

                            // Try to find the product
                            Product? product;
                            try {
                              product = widget.products.firstWhere((p) {
                                try {
                                  return int.parse(p.id) == productId;
                                } catch (e) {
                                  return false;
                                }
                              });
                            } catch (e) {
                              print('⚠️ Product not found for ID: $productId');
                              product = null;
                            }

                            // If product not found, show a placeholder
                            if (product == null) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.shopping_bag,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Product #$productId',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Qty: $quantity',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Product details loading...',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.orange[700],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            final itemTotal = product.salePrice * quantity;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product Image
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: product.imageUrl.isNotEmpty
                                          ? SecureImageWidget(
                                              imageUrls: [
                                                'https://webdevelopercg.com/janaushadhi/myadmin/uploads/product/${product.imageUrl}',
                                                'https://webdevelopercg.com/janaushadhi/uploads/product/${product.imageUrl}',
                                                'https://webdevelopercg.com/janaushadhi/uploads/product_images/${product.imageUrl}',
                                                'https://webdevelopercg.com/janaushadhi/public/uploads/product/${product.imageUrl}',
                                                'https://webdevelopercg.com/janaushadhi/assets/product/${product.imageUrl}',
                                              ],
                                              width: 80,
                                              height: 80,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              width: 80,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[200],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.shopping_bag,
                                                color: Colors.grey,
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Product Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  product.name,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                onPressed: () async {
                                                  setState(() {
                                                    _cartItems.remove(
                                                      productId,
                                                    );
                                                  });

                                                  // Save cart changes immediately
                                                  await _saveCartToSharedPreferences();

                                                  if (mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          '${product?.name} removed from cart',
                                                        ),
                                                        duration:
                                                            const Duration(
                                                              seconds: 2,
                                                            ),
                                                        backgroundColor:
                                                            Colors.red,
                                                      ),
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                  size: 20,
                                                ),
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                          // const SizedBox(height: 4),
                                          Text(
                                            product.brand,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          // const SizedBox(height: 4),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '₹$itemTotal',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1976D2),
                                                ),
                                              ),
                                              // Quantity Controls
                                              Container(
                                                decoration: BoxDecoration(
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF1976D2,
                                                    ),
                                                    width: 1.5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  children: [
                                                    GestureDetector(
                                                      onTap: () {
                                                        _updateQuantity(
                                                          productId,
                                                          quantity - 1,
                                                        );
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 6,
                                                            ),
                                                        child: const Icon(
                                                          Icons.remove,
                                                          size: 14,
                                                          color: Color(
                                                            0xFF1976D2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                          ),
                                                      child: Text(
                                                        '$quantity',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                            0xFF1976D2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    GestureDetector(
                                                      onTap: () {
                                                        _updateQuantity(
                                                          productId,
                                                          quantity + 1,
                                                        );
                                                      },
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 6,
                                                            ),
                                                        child: const Icon(
                                                          Icons.add,
                                                          size: 14,
                                                          color: Color(
                                                            0xFF1976D2,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } else {
                            // Show address and bill details at the end
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                // Address Display
                                if (_selectedAddress.isEmpty)
                                  GestureDetector(
                                    onTap: _showAddressForm,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF1976D2),
                                          width: 2,
                                          style: BorderStyle.solid,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            color: Color(0xFF1976D2),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Add Delivery Address',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF1976D2),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Delivery Address',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          border: Border.all(
                                            color: Colors.green,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedAddress,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            GestureDetector(
                                              onTap: _showAddressForm,
                                              child: const Text(
                                                'Change Address',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Color(0xFF1976D2),
                                                  fontWeight: FontWeight.w600,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 16),

                                // Bill Details
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Bill Details',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildBillRow(
                                        'Total MRP Price',
                                        '₹${_totalMrpPrice.toStringAsFixed(2)}',
                                      ),
                                      if (_savings > 0)
                                        _buildBillRow(
                                          'Discount',
                                          '-₹${_savings.toStringAsFixed(2)}',
                                        ),
                                      _buildBillRow(
                                        'Total Sale Price',
                                        '₹${_totalSalePrice.toStringAsFixed(2)}',
                                      ),
                                      if (_couponDiscount > 0) ...[
                                        const SizedBox(height: 8),
                                        _buildBillRow(
                                          'Coupon Discount',
                                          '-₹${_couponDiscount.toStringAsFixed(2)}',
                                        ),
                                      ],
                                      const Divider(height: 24, thickness: 1),
                                      _buildBillRow(
                                        'Total',
                                        '₹${_total.toStringAsFixed(2)}',
                                        isTotal: true,
                                      ),
                                      const SizedBox(height: 8),
                                      if (_savings > 0)
                                        Text(
                                          '🎉 You saved ₹${_savings.toStringAsFixed(2)}!',
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      if (_appliedCoupon != null) ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green[50],
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.green[200]!,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.local_offer,
                                                color: Colors.green[700],
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  'Coupon ${_appliedCoupon!.code} applied',
                                                  style: TextStyle(
                                                    color: Colors.green[700],
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: _removeCoupon,
                                                child: Icon(
                                                  Icons.close,
                                                  color: Colors.green[700],
                                                  size: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          }
                        },
                      ),
                    ),
                    // Sticky Checkout Button at Bottom
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total (${_cartItems.length} items)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '₹${_total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _isProcessingPayment
                                ? null
                                : _navigateToPaymentOptions,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isProcessingPayment
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Proceed to Checkout',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
