import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'package:jan_aushadi/models/coupon_model.dart';
import 'package:jan_aushadi/screens/coupons_screen.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/services/cart_service.dart';
import 'package:jan_aushadi/models/Product_model.dart' as product_model;
import 'package:jan_aushadi/screens/order_success_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef Product = product_model.Product;

class PaymentOptionsScreen extends StatefulWidget {
  final double totalAmount;
  final Function(String) onPaymentSelected;
  final Map? cartItems;
  final List? products;
  final Coupon? appliedCoupon;
  final double couponDiscount;

  const PaymentOptionsScreen({
    super.key,
    required this.totalAmount,
    required this.onPaymentSelected,
    this.cartItems,
    this.products,
    this.appliedCoupon,
    this.couponDiscount = 0.0,
  });

  @override
  State<PaymentOptionsScreen> createState() => _PaymentOptionsScreenState();
}

class _PaymentOptionsScreenState extends State<PaymentOptionsScreen> {
  String? _selectedPaymentMethod;
  late Razorpay _razorpay;
  bool _isProcessing = false;
  bool _isPlacingOrder = false;

  final TextEditingController _upiIdController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _couponController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  double _couponDiscount = 0.0;
  String? _appliedCoupon;
  bool _isCouponApplying = false;

  double get _totalMrpPrice {
    try {
      return _calculateTotalMrp();
    } catch (e) {
      print('❌ Error calculating MRP: $e');
      return widget.totalAmount * 1.2;
    }
  }

  double get _totalSalePrice {
    try {
      return _calculateTotalSale();
    } catch (e) {
      print('❌ Error calculating sale price: $e');
      return widget.totalAmount;
    }
  }

  double get _savings {
    try {
      final savings = _totalMrpPrice - _totalSalePrice;
      return savings > 0 ? savings : 0;
    } catch (e) {
      print('❌ Error calculating savings: $e');
      return 0;
    }
  }

  double get _finalTotal {
    try {
      return _totalSalePrice - _couponDiscount;
    } catch (e) {
      print('❌ Error calculating final total: $e');
      return widget.totalAmount;
    }
  }

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadCouponData();
  }

  Future<void> _loadCouponData() async {
    try {
      // First check if coupon was passed from cart screen
      if (widget.appliedCoupon != null && widget.couponDiscount > 0) {
        setState(() {
          _appliedCoupon = widget.appliedCoupon!.code;
          _couponDiscount = widget.couponDiscount;
          _couponController.text = widget.appliedCoupon!.code;
        });
        print('✅ Loaded coupon from cart: $_appliedCoupon - ₹$_couponDiscount');
        return;
      }

      // Otherwise load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedCoupon = prefs.getString('applied_coupon_code');
      final savedDiscount = prefs.getDouble('applied_coupon_discount') ?? 0.0;

      if (savedCoupon != null && savedCoupon.isNotEmpty) {
        setState(() {
          _appliedCoupon = savedCoupon;
          _couponDiscount = savedDiscount;
          _couponController.text = savedCoupon;
        });
        print(
          '✅ Loaded coupon from storage: $_appliedCoupon - ₹$_couponDiscount',
        );
      }
    } catch (e) {
      print('❌ Error loading coupon data: $e');
    }
  }

  Future<void> _saveCouponData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_appliedCoupon != null && _appliedCoupon!.isNotEmpty) {
        await prefs.setString('applied_coupon_code', _appliedCoupon!);
        await prefs.setDouble('applied_coupon_discount', _couponDiscount);
        print('✅ Saved coupon to storage: $_appliedCoupon - ₹$_couponDiscount');
      }
    } catch (e) {
      print('❌ Error saving coupon data: $e');
    }
  }

  Future<void> _clearCouponData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('applied_coupon_code');
      await prefs.remove('applied_coupon_discount');
      print('✅ Cleared coupon from storage');
    } catch (e) {
      print('❌ Error clearing coupon data: $e');
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    _upiIdController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _couponController.dispose();
    super.dispose();
  }

  String _formatCurrency(double amount) {
    try {
      if (!amount.isFinite || amount.isNaN) {
        return '₹0.00';
      }
      return '₹${amount.toStringAsFixed(2)}';
    } catch (e) {
      print('❌ Error formatting currency: $e');
      return '₹0.00';
    }
  }

  void _removeCoupon() {
    setState(() {
      _appliedCoupon = null;
      _couponDiscount = 0.0;
      _couponController.clear();
    });

    // Clear coupon from SharedPreferences
    _clearCouponData();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coupon removed'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  double _calculateTotalSale() {
    if (widget.cartItems == null ||
        widget.products == null ||
        widget.products!.isEmpty) {
      return widget.totalAmount;
    }
    double total = 0;
    for (final entry in widget.cartItems!.entries) {
      try {
        final product = widget.products!.firstWhere(
          (p) => int.parse(p.id) == entry.key,
        );
        total += product.salePrice * entry.value;
      } catch (e) {
        print('⚠️ Product not found for ID: ${entry.key}');
        continue;
      }
    }
    return total > 0 ? total : widget.totalAmount;
  }

  double _calculateTotalMrp() {
    if (widget.cartItems == null ||
        widget.products == null ||
        widget.products!.isEmpty) {
      return widget.totalAmount * 1.2;
    }
    double total = 0;
    for (final entry in widget.cartItems!.entries) {
      try {
        final product = widget.products!.firstWhere(
          (p) => int.parse(p.id) == entry.key,
        );
        final mrpPrice = product.originalPrice > 0
            ? product.originalPrice
            : product.salePrice;
        total += mrpPrice * entry.value;
      } catch (e) {
        print('⚠️ Product not found for MRP calculation, ID: ${entry.key}');
        continue;
      }
    }
    return total > 0 ? total : widget.totalAmount * 1.2;
  }

  void _debugPrintValues() {
    try {
      print('🔍 PaymentOptionsScreen Debug Info:');
      print(' widget.totalAmount: ${widget.totalAmount}');
      print(' widget.cartItems: ${widget.cartItems}');
      print(' widget.products length: ${widget.products?.length ?? 0}');
      print(' _totalMrpPrice: $_totalMrpPrice');
      print(' _totalSalePrice: $_totalSalePrice');
      print(' _savings: $_savings');
      print(' _finalTotal: $_finalTotal');
    } catch (e) {
      print('❌ Error in debug print: $e');
    }
  }

  Future<Map<String, dynamic>?> _trackOrder({
    required String orderNumber,
    required String m1Code,
  }) async {
    try {
      final dio = Dio();
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: true,
          responseHeader: true,
        ),
      );
      print('📋 Tracking order: $orderNumber for user: $m1Code');
      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/track_order',
        data: {'F4_PARTY': m1Code, 'F4_NO': orderNumber},
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
      print('📋 Track Order API Response Status: ${response.statusCode}');
      print('📋 Track Order API Response Data: ${response.data}');
      if (response.statusCode == 200 && response.data != null) {
        var trackingData = response.data;
        if (trackingData is String) {
          try {
            trackingData = jsonDecode(trackingData);
          } catch (e) {
            print('❌ Failed to parse tracking JSON: $e');
            return null;
          }
        }
        if (trackingData is Map) {
          final isSuccess =
              trackingData['response']?.toString().toLowerCase() == 'success';
          if (isSuccess) {
            print('✅ Order tracking data retrieved successfully');
            return trackingData.cast<String, dynamic>();
          } else {
            print('❌ Tracking failed: ${trackingData['message']}');
          }
        }
      }
      return null;
    } catch (e) {
      print('⚠️ Error tracking order: $e');
      return null;
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessing = true);
    final paymentMethod = _selectedPaymentMethod ?? 'online';
    final paymentId = response.paymentId ?? '';
    final orderNo = await _placeOrder(
      paymentMethod: paymentMethod,
      onlineTransId: paymentId,
      isPaid: true,
    );
    setState(() => _isProcessing = false);

    if (orderNo == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to place order. Please contact support.'),
          ),
        );
      }
      return;
    }

    await _clearCart();

    final m1Code = await AuthService.getM1Code();
    Map<String, dynamic>? trackingData;
    if (m1Code != null && m1Code.isNotEmpty) {
      trackingData = await _trackOrder(orderNumber: orderNo, m1Code: m1Code);
    }

    String displayPaymentMethod = _getPaymentMethodDisplayName(paymentMethod);
    Map<String, dynamic> enhancedTrackingData = trackingData ?? {};

    String customerName = 'Customer';
    String customerPhone = '';
    String deliveryAddress = '';
    try {
      final userData = await AuthService.getUserData();
      if (userData != null) {
        final userDataMap = jsonDecode(userData);
        customerName = userDataMap['M1_NAME'] ?? 'Customer';
        customerPhone = userDataMap['M1_MOBILE'] ?? '';
        if (userDataMap['M1_ADD1'] != null) {
          deliveryAddress = userDataMap['M1_ADD1'].toString();
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }

    if (widget.cartItems != null && widget.products != null) {
      List<Map<String, dynamic>> productsList = [];
      for (final entry in widget.cartItems!.entries) {
        final productId = entry.key;
        final quantity = entry.value;

        // Find product or use first available
        Product? product;
        try {
          product = widget.products!.firstWhere((p) => p.id == productId);
        } catch (e) {
          // If product not found, skip this item
          print('⚠️ Product not found for ID: $productId');
          continue;
        }

        productsList.add({
          'F5_ITEM': product?.name,
          'F5_QTY': quantity.toString(),
          'F5_RATE': product?.salePrice.toString(),
          'F5_MRP': product?.originalPrice.toString(),
          'F5_ITEM_CODE': product?.id.toString(),
        });
      }

      if (enhancedTrackingData['data'] is List &&
          (enhancedTrackingData['data'] as List).isNotEmpty) {
        (enhancedTrackingData['data'] as List)[0]['products'] = productsList;
        (enhancedTrackingData['data'] as List)[0]['F4_PARTY_NAME'] =
            customerName;
        (enhancedTrackingData['data'] as List)[0]['F4_MOBILE'] = customerPhone;
        (enhancedTrackingData['data'] as List)[0]['F4_ADD1'] = deliveryAddress;
        (enhancedTrackingData['data'] as List)[0]['F4_PAYMENT_MODE'] =
            displayPaymentMethod;
      } else {
        enhancedTrackingData['data'] = [
          {
            'F4_NO': orderNo,
            'products': productsList,
            'F4_PARTY_NAME': customerName,
            'F4_MOBILE': customerPhone,
            'F4_ADD1': deliveryAddress,
            'F4_PAYMENT_MODE': displayPaymentMethod,
          },
        ];
      }
      print('📦 Enhanced tracking data with ${productsList.length} products');
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderSuccessScreen(
            orderId: orderNo,
            totalAmount: widget.totalAmount,
            paymentMethod: displayPaymentMethod,
            cartItems: widget.cartItems?.cast<int, int>() ?? {},
            trackingData: enhancedTrackingData,
            onBackPressed: () => Navigator.pop(context, {}),
          ),
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
    setState(() => _isProcessing = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {}

  Future<void> _processPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    if (_selectedPaymentMethod == 'cod') {
      final capturedCartItems = Map.from(widget.cartItems ?? {});
      final capturedProducts = List.from(widget.products ?? []);

      final orderNo = await _placeOrder(
        paymentMethod: 'COD',
        onlineTransId: null,
        isPaid: false,
      );

      setState(() => _isProcessing = false);

      if (orderNo == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to place order. Please try again.'),
            ),
          );
        }
        return;
      }

      final m1Code = await AuthService.getM1Code();
      Map<String, dynamic>? trackingData;
      if (m1Code != null && m1Code.isNotEmpty) {
        trackingData = await _trackOrder(orderNumber: orderNo, m1Code: m1Code);
      }

      await _clearCart();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Order placed successfully!',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      Map<String, dynamic> enhancedTrackingData = trackingData ?? {};
      String customerName = 'Customer';
      String customerPhone = '';
      String deliveryAddress = '';

      try {
        final userData = await AuthService.getUserData();
        if (userData != null) {
          final userDataMap = jsonDecode(userData);
          customerName = userDataMap['M1_NAME'] ?? 'Customer';
          customerPhone = userDataMap['M1_MOBILE'] ?? '';
          if (userDataMap['M1_ADD1'] != null) {
            deliveryAddress = userDataMap['M1_ADD1'].toString();
          }
        }
      } catch (e) {
        print('Error fetching user data: $e');
      }

      if (capturedCartItems.isNotEmpty && capturedProducts.isNotEmpty) {
        List<Map<String, dynamic>> productsList = [];
        for (final entry in capturedCartItems.entries) {
          final productId = entry.key;
          final quantity = entry.value;
          try {
            final product = capturedProducts.firstWhere(
              (p) => int.tryParse(p.id) == productId,
            );
            productsList.add({
              'F5_ITEM': product.name,
              'F5_QTY': quantity.toString(),
              'F5_RATE': product.salePrice.toString(),
              'F5_MRP': product.originalPrice.toString(),
              'F5_ITEM_CODE': product.id.toString(),
            });
          } catch (e) {
            print('⚠️ Product $productId not found');
          }
        }

        if (enhancedTrackingData['data'] is List &&
            (enhancedTrackingData['data'] as List).isNotEmpty) {
          (enhancedTrackingData['data'] as List)[0]['products'] = productsList;
          (enhancedTrackingData['data'] as List)[0]['F4_PARTY_NAME'] =
              customerName;
          (enhancedTrackingData['data'] as List)[0]['F4_MOBILE'] =
              customerPhone;
          (enhancedTrackingData['data'] as List)[0]['F4_ADD1'] =
              deliveryAddress;
          (enhancedTrackingData['data'] as List)[0]['F4_PAYMENT_MODE'] = 'COD';
        } else {
          enhancedTrackingData['data'] = [
            {
              'F4_NO': orderNo,
              'products': productsList,
              'F4_PARTY_NAME': customerName,
              'F4_MOBILE': customerPhone,
              'F4_ADD1': deliveryAddress,
              'F4_PAYMENT_MODE': 'COD',
            },
          ];
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSuccessScreen(
              orderId: orderNo,
              totalAmount: widget.totalAmount,
              paymentMethod: 'COD',
              cartItems: capturedCartItems.cast<int, int>(),
              trackingData: enhancedTrackingData,
              onBackPressed: () => Navigator.pop(context, {}),
            ),
          ),
        );
      }
      return;
    }

    var options = {
      'key': 'rzp_live_irPiip7JaRitDG',
      'amount': (_finalTotal.isFinite && _finalTotal > 0
          ? (_finalTotal * 100).toInt()
          : 100),
      'name': 'Jan Aushadhi',
      'description': 'Order Payment',
      'prefill': {'contact': '', 'email': ''},
      'theme': {'color': AppConstants.primaryColor.toARGB32()},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  String _getPaymentMethodDisplayName(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'cod':
        return 'Cash on Delivery';
      case 'upi':
        return 'UPI Payment';
      case 'card':
        return 'Card Payment';
      case 'netbanking':
        return 'Net Banking';
      default:
        return 'Online Payment';
    }
  }

  Future<void> _clearCart() async {
    try {
      await CartService.clearCart();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cart_items');
      await prefs.remove('cart_products');
      await prefs.setDouble('cart_total', 0.0);
      // Clear coupon after successful order
      await prefs.remove('applied_coupon_code');
      await prefs.remove('applied_coupon_discount');
      final cartKeys = prefs
          .getKeys()
          .where((key) => key.startsWith('cart_'))
          .toList();
      for (String key in cartKeys) {
        await prefs.remove(key);
      }
      print('🛒 Cart cleared successfully');
      print('🎟️ Coupon cleared after order placement');
    } catch (e) {
      print('⚠️ Error clearing cart: $e');
    }
  }

  Future<String?> _placeOrder({
    required String paymentMethod,
    String? onlineTransId,
    required bool isPaid,
  }) async {
    if (_isPlacingOrder) return null;
    _isPlacingOrder = true;

    try {
      final dio = Dio();
      final cookieJar = CookieJar();
      dio.interceptors.add(CookieManager(cookieJar));

      final m1Code = await AuthService.getM1Code();
      if (m1Code == null || m1Code.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login first'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      String? addressId;

      try {
        final prefs = await SharedPreferences.getInstance();
        final addressJson = prefs.getString('checkout_selected_address');
        if (addressJson != null && addressJson.isNotEmpty) {
          final decodedData = jsonDecode(addressJson);
          if (decodedData is Map) {
            addressId = decodedData['M1_ADD_ID']?.toString();
          }
        }
      } catch (e) {
        print('⚠️ Error fetching address: $e');
      }

      if (addressId == null || addressId.isEmpty || addressId == 'null') {
        try {
          final addressResponse = await dio.post(
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_user_address',
            data: {'M1_CODE': m1Code},
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

          if (addressResponse.statusCode == 200 &&
              addressResponse.data != null) {
            var addressData = addressResponse.data;
            if (addressData is String) {
              addressData = jsonDecode(addressData);
            }
            if (addressData is Map &&
                addressData['response']?.toString().toLowerCase() ==
                    'success') {
              var dataArray = addressData['data'];
              if (dataArray is List && dataArray.isNotEmpty) {
                var firstAddress = dataArray[0];
                if (firstAddress is Map) {
                  addressId = firstAddress['M1_ADD_ID']?.toString();
                }
              }
            }
          }
        } catch (e) {
          print('⚠️ Error fetching address: $e');
        }
      }

      if (addressId == null || addressId.isEmpty || addressId == 'null') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please add a delivery address first'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      try {
        await dio.post(
          'https://www.onlineaushadhi.in/myadmin/UserApis/select_delivery_address',
          data: {'M1_CODE': m1Code, 'M1_ADD_ID': addressId},
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
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        print('❌ Error selecting address: $e');
      }

      final orderData = <String, dynamic>{
        'M1_CODE': m1Code,
        'F4_PARTY': m1Code,
        'F4_BT': 'Placed',
        'M1_ADD_ID': addressId,
        'F4_GTOT': '0.00',
      };

      // Add coupon information if applied
      if (_appliedCoupon != null && _appliedCoupon!.isNotEmpty) {
        orderData['F4_TRP'] = _appliedCoupon; // Coupon ID
        orderData['F4_DIS'] = _couponDiscount.toStringAsFixed(
          2,
        ); // Coupon Discount Amount
      } else {
        orderData['F4_TRP'] = '';
        orderData['F4_DIS'] = '0';
      }

      if (paymentMethod.toLowerCase() != 'cod' && onlineTransId != null) {
        orderData['payment_method'] = paymentMethod;
        orderData['razorpay_order_id'] = onlineTransId;
        orderData['payment_status'] = 'paid';
      } else {
        orderData['payment_method'] = 'COD';
        orderData['payment_status'] = 'pending';
      }

      if (widget.cartItems != null && widget.cartItems!.isNotEmpty) {
        int index = 0;
        double grandTotal = 0.0;

        for (final entry in widget.cartItems!.entries) {
          final productId = entry.key;
          final quantity = entry.value;

          if (quantity <= 0) continue;

          Product? product;
          if (widget.products != null) {
            try {
              product = widget.products!.firstWhere(
                (p) => p.id.isNotEmpty && int.tryParse(p.id) == productId,
              );
            } catch (e) {
              print('⚠️ Product $productId not found');
            }
          }

          double salePrice =
              product?.salePrice ??
              (widget.totalAmount /
                  (widget.cartItems!.length > 0
                      ? widget.cartItems!.length
                      : 1));
          double mrpPrice = product?.originalPrice ?? salePrice;

          final totalSaleAmount = salePrice * quantity;
          if (totalSaleAmount <= 0) continue;

          grandTotal += totalSaleAmount;

          orderData['F4_F1[$index]'] = productId.toString();
          orderData['F4_QTOT[$index]'] = quantity.toString();
          orderData['F4_AMT1[$index]'] = mrpPrice.toStringAsFixed(2);
          orderData['F4_AMT2[$index]'] = salePrice.toStringAsFixed(2);
          orderData['F4_AMT3[$index]'] = (mrpPrice * quantity).toStringAsFixed(
            2,
          );
          orderData['F4_AMT4[$index]'] = totalSaleAmount.toStringAsFixed(2);

          index++;
        }

        if (grandTotal <= 0)
          grandTotal = widget.totalAmount > 0 ? widget.totalAmount : 1.0;

        // Apply coupon discount to grand total
        double finalTotal = grandTotal - _couponDiscount;
        if (finalTotal < 0) finalTotal = 0;

        orderData['F4_STOT'] = grandTotal.toStringAsFixed(2);
        orderData['F4_GTOT'] = finalTotal.toStringAsFixed(2);
      }

      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/place_order',
        data: orderData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Jan-Aushadhi-App/1.0',
          },
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      if (response.statusCode == 200) {
        var responseData = response.data;
        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (e) {
            if (responseData.toLowerCase().contains('success')) {
              return 'ORDER-${DateTime.now().millisecondsSinceEpoch}';
            }
            return null;
          }
        }

        if (responseData is Map) {
          final isSuccess =
              responseData['response']?.toString().toLowerCase() == 'success' ||
              responseData['status']?.toString().toLowerCase() == 'success';

          if (isSuccess) {
            final orderNumber =
                responseData['F4_NO']?.toString() ??
                responseData['order_id']?.toString();
            if (orderNumber != null &&
                orderNumber.isNotEmpty &&
                orderNumber != 'null') {
              return orderNumber;
            }
            return 'ORDER-${DateTime.now().millisecondsSinceEpoch}';
          }
        }
      }
      return null;
    } catch (e) {
      print('💥 Exception in order placement: $e');
      return null;
    } finally {
      _isPlacingOrder = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    _debugPrintValues();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Payment Method',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Summary',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow(
                        'Total MRP Price',
                        _formatCurrency(_totalMrpPrice),
                      ),
                      const SizedBox(height: 6),
                      if (_savings > 0) ...[
                        _buildSummaryRow(
                          'Discount',
                          '-${_formatCurrency(_savings)}',
                          isDiscount: true,
                        ),
                        const SizedBox(height: 6),
                      ],
                      _buildSummaryRow(
                        'Total Sale Price',
                        _formatCurrency(_totalSalePrice),
                        isSpecial: true,
                      ),
                      if (_couponDiscount > 0) ...[
                        const SizedBox(height: 6),
                        _buildSummaryRow(
                          'Coupon Discount',
                          '-${_formatCurrency(_couponDiscount)}',
                          isDiscount: true,
                        ),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.grey[200]),
                      ),
                      _buildSummaryRow(
                        'Total Pay',
                        _formatCurrency(_finalTotal),
                        isTotal: true,
                      ),
                      if (_savings > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          '🎉 Discount ${_formatCurrency(_savings)} on this order!',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (_appliedCoupon != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green[200]!),
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
                                  'Coupon $_appliedCoupon applied',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Coupon Section
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_offer,
                            color: Colors.orange[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Apply Coupon',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_appliedCoupon == null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push<Coupon>(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CouponsScreen(
                                    cartTotal: widget.totalAmount,
                                    onCouponSelected: (coupon) {
                                      Navigator.pop(context, coupon);
                                    },
                                  ),
                                ),
                              );

                              if (result != null) {
                                setState(() {
                                  _appliedCoupon = result.code;
                                  _couponDiscount =
                                      double.tryParse(result.amount) ?? 0.0;
                                  _couponController.text = result.code;
                                });
                                await _saveCouponData();

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Coupon applied! Discount: ₹${_couponDiscount.toStringAsFixed(2)}',
                                      ),
                                      backgroundColor: Colors.green,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            },
                            // icon: const Icon(Icons.add),
                            label: const Text('Apply Coupon'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green[700],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Coupon Applied',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$_appliedCoupon - Discount ${_formatCurrency(_couponDiscount)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: _removeCoupon,
                                child: Text(
                                  'Remove',
                                  style: TextStyle(
                                    color: Colors.red[600],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Choose Payment Method',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              _buildPaymentOption(
                icon: Icons.money,
                title: 'Cash on Delivery (COD)',
                subtitle: 'Pay when you receive your order',
                value: 'cod',
                isSelected: _selectedPaymentMethod == 'cod',
                onChanged: (value) =>
                    setState(() => _selectedPaymentMethod = value),
              ),
              _buildPaymentOption(
                icon: Icons.credit_card,
                title: 'Online Payment',
                subtitle: 'Pay using UPI, Card, or Net Banking',
                value: 'online',
                isSelected: _selectedPaymentMethod == 'online',
                onChanged: (value) =>
                    setState(() => _selectedPaymentMethod = value),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.green[600],
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your payment is secure and encrypted',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selectedPaymentMethod == null
                        ? null
                        : (_isProcessing ? null : _processPayment),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _selectedPaymentMethod == 'cod'
                                ? 'PLACE ORDER'
                                : 'CONFIRM & PAY',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isDiscount = false,
    bool isFree = false,
    bool isTotal = false,
    bool isSpecial = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDiscount ? Colors.green[700] : Colors.grey[600],
              fontWeight: isTotal || isDiscount
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
          Text(
            isFree ? 'FREE' : value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              color: isDiscount
                  ? Colors.green[700]
                  : isTotal
                  ? const Color(0xFF1976D2)
                  : isSpecial
                  ? const Color(0xFF1976D2)
                  : Colors.black87,
              fontWeight: isTotal || isDiscount || isSpecial
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required bool isSelected,
    required ValueChanged<String> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppConstants.primaryColor : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppConstants.primaryColor
                      : Colors.grey[300]!,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              icon,
              color: isSelected ? AppConstants.primaryColor : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
