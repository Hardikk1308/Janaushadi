import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jan_aushadi/services/order_service.dart';
import 'package:jan_aushadi/services/cart_service.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'package:jan_aushadi/screens/product_details_screen.dart' hide Product;
import 'package:jan_aushadi/models/Product_model.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final double totalAmount;
  final String paymentMethod;
  final Map<int, int>? cartItems;
  final Map<String, dynamic>? trackingData; // Add tracking data parameter

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.paymentMethod,
    this.cartItems,
    this.trackingData, // Add tracking data parameter
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen>
    with TickerProviderStateMixin {
  late Map<String, dynamic> orderData;
  late List<String> statuses;
  int currentStatusIndex = 0;
  late AnimationController _pulseController;
  late AnimationController _slideController;

  Map<String, dynamic>? _currentTrackingData;
  String customerName = 'Customer';
  String customerPhone = '';
  String deliveryAddress = '';
  int totalItemsCount = 0;
  String paymentMode = '';
  bool _isLoadingTrackingData = false;
  bool _isLoadingAddress = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeOrder();

    _currentTrackingData = widget.trackingData;
    
    // Extract details from initial tracking data if available
    if (_currentTrackingData != null) {
      _extractTrackingDetails();
    }

    // Load user data immediately as fallback
    _loadUserDataAsFallback();

    // Clear cart immediately when order tracking screen is shown
    _clearCartImmediately();

    // Fetch tracking data to get all details
    _refreshTrackingData();
    
    // Set up periodic refresh of tracking data every 30 seconds
    Future.delayed(const Duration(seconds: 30), _setupPeriodicRefresh);
  }

  void _setupPeriodicRefresh() {
    if (mounted) {
      _refreshTrackingData();
      // Schedule next refresh
      Future.delayed(const Duration(seconds: 30), _setupPeriodicRefresh);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController.repeat(reverse: true);
    _slideController.forward();
  }

  void _initializeOrder() async {
    statuses = ['Order placed', 'Dispatch', 'Delivery'];

    orderData = {
      'orderId': widget.orderId,
      'totalAmount': widget.totalAmount,
      'paymentMethod': widget.paymentMethod,
      'cartItems': widget.cartItems ?? {},
      'currentStatus': 'Order placed',
      'statusIndex': 0,
      'createdAt': DateTime.now().toString(),
      'timeline': [
        {
          'status': 'Order placed',
          'timestamp': DateTime.now().toString(),
          'message': 'Your order has been placed successfully',
          'icon': Icons.check_circle,
          'completed': true,
        },
        {
          'status': 'Dispatch',
          'timestamp': null,
          'message': 'Waiting for dispatch',
          'icon': Icons.local_shipping,
          'completed': false,
        },
        {
          'status': 'Delivery',
          'timestamp': null,
          'message': 'Expected delivery date',
          'icon': Icons.location_on,
          'completed': false,
        },
      ],
    };

    await _saveOrder();
    setState(() {});
  }

  Future<void> _loadUserDataAsFallback() async {
    try {
      print('📋 Loading user data from personal details...');
      final userData = await AuthService.getUserData();
      if (userData != null) {
        final userDataMap = jsonDecode(userData);

        print('📋 User data map: $userDataMap');

        // Always load name if not already set properly
        if (customerName == 'Customer' || customerName.isEmpty) {
          customerName =
              userDataMap['M1_NAME'] ?? userDataMap['name'] ?? 'Customer';
        }

        // Always load phone if not already set
        if (customerPhone.isEmpty) {
          customerPhone =
              userDataMap['M1_TEL'] ??
              userDataMap['M1_MOBILE'] ??
              userDataMap['phone'] ??
              userDataMap['M1_IT'] ?? // Sometimes email is stored here
              '';
        }

        // Load address if not already set
        if (deliveryAddress.isEmpty) {
          // First, try to get address from the address array (saved addresses)
          if (userDataMap['address'] is List && (userDataMap['address'] as List).isNotEmpty) {
            print('📍 Found address array in user data');
            final addressArray = userDataMap['address'] as List;
            
            // Get the first active address, or the first address if none are active
            Map<String, dynamic>? selectedAddress;
            for (var addr in addressArray) {
              if (addr['M1_BT']?.toString().toLowerCase() == 'active') {
                selectedAddress = addr;
                break;
              }
            }
            
            // If no active address found, use the first one
            selectedAddress ??= addressArray.first;
            
            if (selectedAddress != null) {
              final add1 = selectedAddress['M1_ADD1']?.toString() ?? '';
              if (add1.isNotEmpty) {
                deliveryAddress = add1;
                print('📍 Extracted address from address array: $deliveryAddress');
              }
            }
          } else {
            // Fallback to M1_ADD1 from main user data
            final add1 = userDataMap['M1_ADD1']?.toString() ?? '';
            if (add1.isNotEmpty &&
                int.tryParse(add1) != null &&
                add1.length < 10) {
              // It's likely an address ID, fetch the full address
              print('📍 Detected address ID in user data: $add1');
              _fetchAddressById(add1);
            } else if (add1.isNotEmpty) {
              // It's a full address, use it directly
              deliveryAddress = add1;
            }
          }
        }

        print('✅ Loaded user data from personal details:');
        print('   Name: $customerName');
        print('   Phone: $customerPhone');
        print('   Address: $deliveryAddress');

        if (mounted) {
          setState(() {});
        }
      } else {
        print('⚠️ No user data found in storage');
      }
    } catch (e) {
      print('❌ Error loading user data as fallback: $e');
    }
  }

  Future<void> _fetchAddressById(String addressId) async {
    if (mounted) {
      setState(() {
        _isLoadingAddress = true;
      });
    }

    try {
      print('📍 Fetching address details for ID: $addressId');

      final m1Code = await AuthService.getM1Code();
      if (m1Code == null || m1Code.isEmpty) {
        print('❌ No M1_CODE available');
        if (mounted) {
          setState(() {
            _isLoadingAddress = false;
          });
        }
        return;
      }

      final dio = Dio();
      final response = await dio.post(
        'https://webdevelopercg.com/janaushadhi/myadmin/UserApis/get_user_address',
        data: {'M1_CODE': m1Code},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Jan-Aushadhi-App/1.0',
          },
        ),
      );

      print('✅ Address response status: ${response.statusCode}');
      print('📥 Address response data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        var addressData = response.data;

        if (addressData is String) {
          try {
            addressData = jsonDecode(addressData);
          } catch (e) {
            print('❌ Failed to parse address JSON: $e');
            if (mounted) {
              setState(() {
                _isLoadingAddress = false;
              });
            }
            return;
          }
        }

        if (addressData is Map && addressData['response'] == 'success') {
          final addresses = addressData['data'] as List?;

          if (addresses != null && addresses.isNotEmpty) {
            print(
              '📍 Found ${addresses.length} addresses, looking for ID: $addressId',
            );

            // Find the address with matching ID
            Map<String, dynamic>? matchedAddress;
            for (var addr in addresses) {
              print('   Checking address: ${addr['M2_CODE']}');
              if (addr['M2_CODE']?.toString() == addressId) {
                matchedAddress = addr;
                break;
              }
            }

            // Fallback to first address if no match
            final address = matchedAddress ?? addresses.first;
            print('📍 Using address: ${address['M2_CODE']}');

            // Build full address from address fields
            List<String> addressParts = [];

            if (address['M2_ADD1']?.toString().isNotEmpty ?? false) {
              addressParts.add(address['M2_ADD1'].toString());
            }
            if (address['M2_ADD2']?.toString().isNotEmpty ?? false) {
              addressParts.add(address['M2_ADD2'].toString());
            }
            if (address['M2_ADD3']?.toString().isNotEmpty ?? false) {
              addressParts.add(address['M2_ADD3'].toString());
            }
            if (address['M2_CITY']?.toString().isNotEmpty ?? false) {
              addressParts.add(address['M2_CITY'].toString());
            }
            if (address['M2_STATE']?.toString().isNotEmpty ?? false) {
              addressParts.add(address['M2_STATE'].toString());
            }
            if (address['M2_PIN']?.toString().isNotEmpty ?? false) {
              addressParts.add(address['M2_PIN'].toString());
            }

            deliveryAddress = addressParts.join(', ');

            print('✅ Fetched address: $deliveryAddress');

            if (mounted) {
              setState(() {
                _isLoadingAddress = false;
              });
            }
          } else {
            print('⚠️ No addresses found in response');
            if (mounted) {
              setState(() {
                _isLoadingAddress = false;
              });
            }
          }
        } else {
          print('⚠️ Address response not successful');
          if (mounted) {
            setState(() {
              _isLoadingAddress = false;
            });
          }
        }
      } else {
        print('⚠️ Invalid response status or data');
        if (mounted) {
          setState(() {
            _isLoadingAddress = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching address by ID: $e');
      if (mounted) {
        setState(() {
          _isLoadingAddress = false;
        });
      }
    }
  }

  Future<void> _saveOrder() async {
    try {
      await OrderService().saveOrder(widget.orderId, orderData);
    } catch (e) {
      print('❌ Error saving order: $e');
    }
  }

  // Add immediate cart clearing method
  Future<void> _clearCartImmediately() async {
    try {
      // Clear cart immediately when order tracking screen loads
      await CartService.clearCart();
      print('✅ Cart cleared immediately on order tracking screen load');

      // Also clear any cached cart data
      if (widget.cartItems != null) {
        widget.cartItems!.clear();
      }

      // Force a rebuild of any cart-dependent widgets
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Error clearing cart immediately: $e');
    }
  }

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.headset_mic, color: AppConstants.primaryColor),
            const SizedBox(width: 8),
            const Text('Contact Support'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('How can we help you with your order?'),
            const SizedBox(height: 16),
            _buildSupportOption('Track my order', Icons.location_on),
            _buildSupportOption('Cancel my order', Icons.cancel),
            _buildSupportOption('Payment issues', Icons.payment),
            _buildSupportOption('Product questions', Icons.help),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportOption(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Support request for: $title')),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppConstants.primaryColor),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              const Spacer(),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _cancelOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator

              try {
                final dio = Dio();
                final m1Code = await AuthService.getM1Code();

                if (m1Code == null || m1Code.isEmpty) {
                  throw Exception('User not authenticated');
                }

                print('🚫 Cancelling order: ${widget.orderId}');

                // Call the cancel order API - using update_order_status instead
                final response = await dio.post(
                  'https://webdevelopercg.com/janaushadhi/myadmin/UserApis/update_order_status',
                  data: {
                    'M1_CODE': m1Code,
                    'F4_NO': widget.orderId,
                    'F4_BT': 'Cancelled',
                  },
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
                  '🚫 Cancel order response: ${response.statusCode} - ${response.data}',
                );

                // Handle both success response and potential error cases
                bool isCancelled = false;

                if (response.statusCode == 200) {
                  var responseData = response.data;

                  if (responseData is String) {
                    try {
                      responseData = jsonDecode(responseData);
                    } catch (e) {
                      // If JSON parsing fails, check if string contains success indicator
                      if (responseData.toLowerCase().contains('success') ||
                          responseData.toLowerCase().contains('cancelled')) {
                        isCancelled = true;
                      }
                    }
                  }

                  if (responseData is Map) {
                    if (responseData['response']?.toString().toLowerCase() ==
                            'success' ||
                        responseData['status']?.toString().toLowerCase() ==
                            'success' ||
                        responseData['message']!
                            .toString()
                            .toLowerCase()
                            .contains('cancel')) {
                      isCancelled = true;
                    }
                  }

                  // If no clear success indicator but status 200, assume success
                  if (!isCancelled && response.statusCode == 200) {
                    isCancelled = true;
                  }
                }

                if (isCancelled) {
                  // Update local order data
                  setState(() {
                    orderData['currentStatus'] = 'Cancelled';
                    orderData['statusIndex'] = -1;
                  });

                  // Save updated order locally
                  await _saveOrder();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Order cancelled successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  throw Exception('Failed to cancel order');
                }
              } catch (e) {
                print('❌ Error cancelling order: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to cancel order: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {}
              }
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshTrackingData() async {
    if (mounted) {
      setState(() {
        _isLoadingTrackingData = true;
      });
    }

    try {
      final m1Code = await AuthService.getM1Code();
      if (m1Code != null && m1Code.isNotEmpty) {
        print('🔍 Fetching tracking data for order: ${widget.orderId}');

        final trackingData = await _trackOrder(
          orderNumber: widget.orderId,
          m1Code: m1Code,
        );

        if (trackingData != null && mounted) {
          print('✅ Tracking data received successfully');
          
          // Animate the status update
          await _animateStatusUpdate(trackingData);
          
          setState(() {
            _currentTrackingData = trackingData;
            _extractTrackingDetails();
            _isLoadingTrackingData = false;
          });
        } else {
          print('⚠️ No tracking data received');
          if (mounted) {
            setState(() {
              _isLoadingTrackingData = false;
            });
          }
        }
      }
    } catch (e) {
      print('❌ Error refreshing tracking data: $e');
      if (mounted) {
        setState(() {
          _isLoadingTrackingData = false;
        });
      }
    }
  }

  Future<void> _animateStatusUpdate(Map<String, dynamic> trackingData) async {
    try {
      final data = trackingData['data'];
      if (data is! List || data.isEmpty) return;

      final orderInfo = data[0];
      final newStatus = orderInfo['F4_BT']?.toString() ?? 'Placed';
      
      print('📊 Current status: ${orderData['currentStatus']}, New status: $newStatus');
      
      // Only animate if status has changed
      if (newStatus != orderData['currentStatus']) {
        print('🎬 Status changed! Animating update...');
        
        // Play pulse animation
        _pulseController.forward();
        await Future.delayed(const Duration(milliseconds: 500));
        _pulseController.reverse();
        
        // Update status with animation
        if (mounted) {
          setState(() {
            orderData['currentStatus'] = newStatus;
            _updateStatusIndex(newStatus);
          });
        }
        
        // Show success snackbar with animation
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Order status updated to: $newStatus',
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
      }
    } catch (e) {
      print('❌ Error animating status update: $e');
    }
  }

  void _updateStatusIndex(String status) {
    final statusMap = {
      'Placed': 0,
      'Dispatch': 1,
      'Delivery': 2,
      'Delivered': 3,
    };
    
    orderData['statusIndex'] = statusMap[status] ?? 0;
  }

  void _extractTrackingDetails() {
    if (_currentTrackingData == null) {
      print('⚠️ No tracking data available');
      _loadUserDataAsFallback();
      return;
    }

    print(
      '📦 Raw tracking data structure: ${_currentTrackingData!.keys.toList()}',
    );

    final data = _currentTrackingData!['data'];
    if (data is! List || data.isEmpty) {
      print('⚠️ Tracking data is not a list or is empty');
      _loadUserDataAsFallback();
      return;
    }

    final orderInfo = data[0];
    print('📦 Order info keys: ${orderInfo.keys.toList()}');
    print('📦 Full order info: $orderInfo');

    // Extract customer details - try multiple field names
    customerName =
        orderInfo['F4_PARTY_NAME']?.toString() ??
        orderInfo['M1_NAME']?.toString() ??
        orderInfo['customer_name']?.toString() ??
        'Customer';

    customerPhone =
        orderInfo['F4_MOBILE']?.toString() ??
        orderInfo['M1_TEL']?.toString() ??
        orderInfo['phone']?.toString() ??
        '';

    // Build full address from multiple address fields
    List<String> addressParts = [];
    String? addressId;

    if (orderInfo['F4_ADD1']?.toString().isNotEmpty ?? false) {
      final add1 = orderInfo['F4_ADD1'].toString();
      // Check if F4_ADD1 is just a numeric ID (address ID)
      if (int.tryParse(add1) != null && add1.length < 10) {
        // It's likely an address ID, fetch the full address
        addressId = add1;
        print('📍 Detected address ID: $addressId');
        // Don't add the ID to address parts, we'll fetch the real address
      } else {
        addressParts.add(add1);
      }
    }
    if (orderInfo['F4_ADD2']?.toString().isNotEmpty ?? false) {
      addressParts.add(orderInfo['F4_ADD2'].toString());
    }
    if (orderInfo['F4_ADD3']?.toString().isNotEmpty ?? false) {
      addressParts.add(orderInfo['F4_ADD3'].toString());
    }

    // Only set deliveryAddress if we have actual address parts (not just an ID)
    if (addressParts.isNotEmpty) {
      deliveryAddress = addressParts.join(', ');
    } else {
      deliveryAddress = ''; // Will be filled by _fetchAddressById
    }

    paymentMode =
        orderInfo['F4_PAYMENT_MODE']?.toString() ??
        orderInfo['payment_method']?.toString() ??
        widget.paymentMethod;

    // If we have an address ID, fetch the full address
    if (addressId != null) {
      print('🔄 Calling _fetchAddressById with ID: $addressId');
      _fetchAddressById(addressId);
    }
    // If still no customer data, load from user storage
    else if (customerName == 'Customer' || deliveryAddress.isEmpty) {
      print('🔄 No address ID detected, loading user data as fallback');
      print('   customerName: $customerName');
      print('   deliveryAddress: $deliveryAddress');
      _loadUserDataAsFallback();
    } else {
      print('✅ Address already set: $deliveryAddress');
    }

    // Extract products and calculate total items count
    // Try both 'items' and 'products' keys
    final products =
        orderInfo['items'] as List? ?? orderInfo['products'] as List?;
    if (products != null && products.isNotEmpty) {
      print('✅ Found ${products.length} items in order data');
      totalItemsCount = 0;
      for (var product in products) {
        // Handle multiple quantity field names
        final qty =
            int.tryParse(
              product['F4_QTY']?.toString() ??
                  product['F5_QTY']?.toString() ??
                  product['F4_QTOT']?.toString() ??
                  '0',
            ) ??
            0;
        totalItemsCount += qty;
        final itemName =
            product['M1_NAME']?.toString() ??
            product['F4_IT']?.toString() ??
            product['F5_ITEM']?.toString() ??
            'Item';
        print('   - $itemName: Qty $qty');
      }
      print('✅ Total items calculated: $totalItemsCount');
    } else {
      print('⚠️ No items/products array found in order info');
      totalItemsCount = 0;
    }

    // Update timeline based on actual order status
    _updateTimelineBasedOnStatus(orderInfo['F4_BT']?.toString() ?? 'Placed');

    print('📦 Extracted tracking details:');
    print('   Customer: $customerName');
    print('   Phone: $customerPhone');
    print('   Address: $deliveryAddress');
    print('   Payment Mode: $paymentMode');
    print('   Total Items: $totalItemsCount');
  }

  void _updateTimelineBasedOnStatus(String status) {
    print('🔄 Updating timeline based on status: $status');
    
    final statusLower = status.toLowerCase();
    
    // Reset all timeline items
    for (var item in orderData['timeline']) {
      item['completed'] = false;
    }
    
    // Mark completed items based on status
    if (statusLower == 'placed' || statusLower == 'dispatch' || statusLower == 'delivery' || statusLower == 'delivered') {
      orderData['timeline'][0]['completed'] = true; // Order placed
    }
    
    if (statusLower == 'dispatch' || statusLower == 'delivery' || statusLower == 'delivered') {
      orderData['timeline'][1]['completed'] = true; // Dispatch
    }
    
    if (statusLower == 'delivery' || statusLower == 'delivered') {
      orderData['timeline'][2]['completed'] = true; // Delivery
      // Update the delivery message for delivered orders
      orderData['timeline'][2]['message'] = 'Order delivered successfully';
    }
    
    print('✅ Timeline updated');
  }

  Future<Map<String, dynamic>?> _trackOrder({
    required String orderNumber,
    required String m1Code,
  }) async {
    try {
      final dio = Dio();

      print(
        '🔍 Fetching order details with M1_CODE: $m1Code, Order: $orderNumber',
      );

      final response = await dio.post(
        'https://webdevelopercg.com/janaushadhi/myadmin/UserApis/order_details',
        data: {'M1_CODE': m1Code, 'F4_NO': orderNumber},
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

      print('✅ Order details response status: ${response.statusCode}');
      print('📥 Order details response data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        var orderDetailsData = response.data;

        if (orderDetailsData is String) {
          try {
            orderDetailsData = jsonDecode(orderDetailsData);
          } catch (e) {
            print('❌ Failed to parse order details JSON: $e');
            return null;
          }
        }

        if (orderDetailsData is Map<String, dynamic>) {
          final isSuccess =
              orderDetailsData['response']?.toString().toLowerCase() ==
              'success';
          if (isSuccess) {
            print('✅ Order details retrieved successfully');
            print(
              '📦 Items in response: ${orderDetailsData['data']?[0]?['items']?.length ?? 0}',
            );
            return orderDetailsData;
          } else {
            print(
              '⚠️ Order details response not successful: ${orderDetailsData['response']}',
            );
          }
        }
      }

      return null;
    } catch (e) {
      print('❌ Error fetching order details: $e');
      return null;
    }
  }

  String _getOrderDate() {
    if (_currentTrackingData != null) {
      final data = _currentTrackingData!['data'];
      if (data is List && data.isNotEmpty) {
        final orderInfo = data[0];
        if (orderInfo is Map) {
          final dateStr = orderInfo['F4_DATE']?.toString();
          if (dateStr != null && dateStr.isNotEmpty) {
            try {
              // Parse the date format from API (assuming format: 2025-12-06 01:05:00)
              final dateTime = DateTime.parse(dateStr.replaceAll(' ', 'T'));
              return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
            } catch (e) {
              return dateStr; // Return as-is if parsing fails
            }
          }
        }
      }
    }

    // Fallback to current date
    final now = DateTime.now();
    return '${now.day}/${now.month}/${now.year} at ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isOrderPlaced = orderData['statusIndex'] >= 0;
    final isCancelled = orderData['currentStatus'] == 'Cancelled';

    return WillPopScope(
      onWillPop: () async {
        // When back button is pressed, go to MainApp (home with bottom nav)
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // When back arrow is pressed, go to MainApp (home with bottom nav)
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
          ),
          title: Text(
            'Order #${widget.orderId}',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.black87),
          actions: [
            TextButton.icon(
              onPressed: () => _contactSupport(),
              icon: const Icon(Icons.headset_mic_outlined, size: 18),
              label: const Text('Help'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isCancelled
                                ? Colors.red[50]
                                : const Color(0xFF1976D2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isCancelled
                                ? Icons.cancel_outlined
                                : Icons.receipt_long_outlined,
                            color: isCancelled
                                ? Colors.red
                                : const Color(0xFF1976D2),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                orderData['currentStatus'] ?? 'Order Placed',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ordered by $customerName',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Placed on ${_getOrderDate()}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Icon(
                          Icons.payment_outlined,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Total: ₹${widget.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Ordered Products Section - Show prominently at the top
              _buildOrderedProducts(),

              const SizedBox(height: 20),

              // Order Progress
              if (isOrderPlaced && !isCancelled) _buildSimpleTimeline(),

              const SizedBox(height: 20),

              // Delivery Details Section
              if (!_isLoadingTrackingData) _buildDeliveryDetails(),

              if (!_isLoadingTrackingData) const SizedBox(height: 20),

              // Price Details Section
              if (!_isLoadingTrackingData) _buildPriceDetails(),

              const SizedBox(height: 20),

              // Order Details Card
              if (!_isLoadingTrackingData) _buildOrderDetailsCard(),

              const SizedBox(height: 20),

              // Action Buttons
              if (isOrderPlaced && !isCancelled)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancelOrder,
                        icon: const Icon(Icons.cancel_outlined, size: 18),
                        label: const Text('Cancel Order'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.red[300]!),
                          foregroundColor: Colors.red[700],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _contactSupport,
                        icon: const Icon(Icons.headset_mic_outlined, size: 18),
                        label: const Text('Contact Support'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),

              // Always show Continue Shopping button even for cancelled orders
              if (isCancelled)
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _continueShopping,
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                        label: const Text('Continue Shopping'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrderedProducts() {
    List<dynamic>? products;
    int itemCount = totalItemsCount; // Use the extracted total items count

    print('🔍 Building ordered products section...');
    print('   Has tracking data: ${_currentTrackingData != null}');
    print('   Total items count from extraction: $totalItemsCount');

    // Try to get products from tracking data
    if (_currentTrackingData != null) {
      print('   📦 FULL Tracking data: $_currentTrackingData');
      print('   Tracking data keys: ${_currentTrackingData!.keys.toList()}');
      final data = _currentTrackingData!['data'];
      print('   Data is List: ${data is List}');
      if (data is List && data.isNotEmpty) {
        print('   Data length: ${data.length}');
        print('   📦 FULL First item: ${data[0]}');
        print('   First item keys: ${data[0].keys.toList()}');

        // Try 'products' first (from enhanced tracking data)
        products = data[0]['products'] as List?;
        print('   Products array: $products');

        // If no 'products', try 'items' (from backend API)
        if (products == null || products.isEmpty) {
          products = data[0]['items'] as List?;
          print('   Items array: $products');
          print('   Using items array instead of products');
        }

        print('   Products/Items found: ${products?.length ?? 0}');
        if (products != null && products.isNotEmpty) {
          print('   📦 First product/item: ${products[0]}');
        }
      } else {
        print('   ⚠️ Data is not a list or is empty');
      }
    } else {
      print('   ⚠️ No tracking data available at all');
    }

    // Calculate item count from products if available
    if (products != null && products.isNotEmpty) {
      itemCount = 0;
      for (var product in products) {
        // Handle multiple quantity field names
        final qty =
            int.tryParse(
              product['F4_QTY']?.toString() ??
                  product['F4_QTOT']?.toString() ??
                  product['F5_QTY']?.toString() ??
                  '0',
            ) ??
            0;
        itemCount += qty;
      }
      print('✅ Total items to display: $itemCount');
    } else {
      print('⚠️ No products to display, using extracted count: $itemCount');
    }

    // If no products from API, show appropriate message but still show the count
    if (products == null || products.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: AppConstants.primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Ordered Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (itemCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    if (_isLoadingTrackingData) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        'Loading product details...',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ] else ...[
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Product details not available',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order details will be updated soon',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    color: AppConstants.primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Ordered Products',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...products.map((product) => _buildProductItem(product)).toList(),
        ],
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> product) {
    print('📦 Raw product data: $product');

    // Handle multiple field name formats from different API responses
    // F4_IT = item code/name from order_details API
    // M1_NAME = product name from items array
    // F5_ITEM = item name from enhanced tracking
    final name =
        product['M1_NAME']?.toString() ??
        product['F4_IT']?.toString() ??
        product['F5_ITEM']?.toString() ??
        'Product';

    // F4_RATE = rate from order_details
    // F4_AMT2 = sale price from items array
    // F5_RATE = rate from enhanced tracking
    final price =
        double.tryParse(
          product['F4_RATE']?.toString() ??
              product['F4_AMT2']?.toString() ??
              product['F5_RATE']?.toString() ??
              '0',
        ) ??
        0;

    // F4_QTY = quantity from order_details
    // F4_QTOT = total quantity from items array
    // F5_QTY = quantity from enhanced tracking
    final qty =
        int.tryParse(
          product['F4_QTY']?.toString() ??
              product['F4_QTOT']?.toString() ??
              product['F5_QTY']?.toString() ??
              '1',
        ) ??
        1;

    // F4_MRP = MRP from order_details
    // F4_AMT1 = MRP from items array
    // F5_MRP = MRP from enhanced tracking
    final mrp =
        double.tryParse(
          product['F4_MRP']?.toString() ??
              product['F4_AMT1']?.toString() ??
              product['F5_MRP']?.toString() ??
              '0',
        ) ??
        0;

    final discount = mrp > 0 && price > 0
        ? ((mrp - price) / mrp * 100).round()
        : 0;

    // Extract image URL from the image object
    String? imageUrl;
    print('🖼️ Checking for image in product data...');
    print('   Has image key: ${product.containsKey('image')}');
    print('   Image value: ${product['image']}');
    print('   Image type: ${product['image']?.runtimeType}');

    if (product['image'] != null && product['image'] is Map) {
      final imageData = product['image'] as Map<String, dynamic>;
      print('   Image data keys: ${imageData.keys.toList()}');

      final imageName =
          imageData['M1_DC1']?.toString() ??
          imageData['M1_DC2']?.toString() ??
          imageData['M1_DC3']?.toString() ??
          imageData['M1_DC4']?.toString();

      print('   Extracted image name: $imageName');

      if (imageName != null && imageName.isNotEmpty) {
        imageUrl =
            'https://webdevelopercg.com/janaushadhi/myadmin/uploads/product/$imageName';
        print('   ✅ Image URL: $imageUrl');
      } else {
        print('   ⚠️ No valid image name found');
      }
    } else {
      print('   ⚠️ No image object found or wrong type');
    }

    // Extract product ID for navigation
    final productId =
        product['F4_F1']?.toString() ?? product['product_id']?.toString() ?? '';

    print(
      '📦 Displaying product: $name, Qty: $qty, Price: ₹$price, MRP: ₹$mrp, Discount: $discount%, Image: $imageUrl, ID: $productId',
    );

    return GestureDetector(
      onTap: () async {
        if (productId.isNotEmpty) {
          print('🔍 Fetching product details for ID: $productId');
          await _navigateToProductDetails(productId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product details not available'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          print('❌ Failed to load image: $imageUrl');
                          print('   Error: $error');
                          return Container(
                            color: Colors.grey[100],
                            child: Icon(
                              Icons.medication_outlined,
                              color: Colors.grey[400],
                              size: 30,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            print('✅ Image loaded successfully: $imageUrl');
                            return child;
                          }
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: AppConstants.primaryColor,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[100],
                        child: Icon(
                          Icons.medication_outlined,
                          color: Colors.grey[400],
                          size: 30,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '₹${price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      if (mrp > price) ...[
                        const SizedBox(width: 8),
                        Text(
                          '₹${mrp.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$discount% OFF',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Qty: $qty',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _navigateToProductDetails(String productId) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final dio = Dio();
      final response = await dio.post(
        'https://webdevelopercg.com/janaushadhi/myadmin/UserApis/product_details',
        data: {'product_id': productId},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Jan-Aushadhi-App/1.0',
          },
        ),
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (response.statusCode == 200 && response.data != null) {
        var productData = response.data;

        if (productData is String) {
          productData = jsonDecode(productData);
        }

        if (productData is Map && productData['response'] == 'success') {
          final data = productData['data'];
          if (data != null && data is List && data.isNotEmpty) {
            final productJson = data[0];
            final product = Product.fromJson(productJson);

            // Get current cart items
            final cartItems = CartService.cartItems.map(
              (key, value) => MapEntry(int.parse(key), value),
            );

            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailsScreen(
                    product: product,
                    cartItems: cartItems,
                  ),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      print('❌ Error fetching product details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load product details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDeliveryDetails() {
    // Show delivery details - always show the section
    final address = deliveryAddress.isNotEmpty ? deliveryAddress : '';
    final name = customerName.isNotEmpty && customerName != 'Customer'
        ? customerName
        : '';
    final phone = customerPhone.isNotEmpty ? customerPhone : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (name.isNotEmpty) ...[
            Text(
              name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (phone.isNotEmpty) ...[
            Text(
              phone,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
          ],
          const Divider(height: 24),
          const Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingAddress) ...[
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Loading address...'),
              ],
            ),
          ] else if (address.isNotEmpty) ...[
            Text(
              address,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[700], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Delivery address will be updated soon',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.amber[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceDetails() {
    if (_currentTrackingData == null) {
      return const SizedBox.shrink();
    }

    final data = _currentTrackingData!['data'];
    if (data is! List || data.isEmpty) {
      return const SizedBox.shrink();
    }

    final orderInfo = data[0];
    final products = orderInfo['products'] as List?;

    if (products == null || products.isEmpty) {
      return const SizedBox.shrink();
    }

    // Calculate totals
    double listingPrice = 0;
    double specialPrice = 0;
    double totalFees = 0;

    for (var product in products) {
      final qty = int.tryParse(product['F5_QTY']?.toString() ?? '1') ?? 1;
      final mrp = double.tryParse(product['F5_MRP']?.toString() ?? '0') ?? 0;
      final rate = double.tryParse(product['F5_RATE']?.toString() ?? '0') ?? 0;

      listingPrice += mrp * qty;
      specialPrice += rate * qty;
    }

    final totalAmount = specialPrice + totalFees;
    final savings = listingPrice - specialPrice;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildPriceRow('Listing price', listingPrice),
          const SizedBox(height: 8),
          _buildPriceRow('Special price', specialPrice, isSpecial: true),
          const SizedBox(height: 8),
          _buildPriceRow('Total fees', totalFees, expandable: true),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[300], height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total amount',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              Text(
                '₹${totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          if (savings > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'You saved ₹${savings.toStringAsFixed(0)} on this order',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                size: 18,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'Payment method',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const Spacer(),
              Icon(Icons.money, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                paymentMode.isNotEmpty ? paymentMode : widget.paymentMethod,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement download invoice
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice download coming soon')),
                );
              },
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Download Invoice'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.grey[300]!),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isSpecial = false,
    bool expandable = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            if (expandable) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: Colors.grey[500],
              ),
            ],
          ],
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSpecial ? FontWeight.w600 : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderDetailsCard() {
    // Get order info from tracking data

    String trackingNumber = widget.orderId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: AppConstants.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Text(
                'Order Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Order ID
          _buildDetailRowWithIcon(
            Icons.tag_outlined,
            'Order ID',
            '#$trackingNumber',
            showCopy: true,
          ),

          // const SizedBox(height: 12),

          // Order Status
          // _buildDetailRowWithIcon(
          //   Icons.info_outline,
          //   'Status',
          //   orderStatus,
          //   valueColor: _getStatusColor(orderStatus),
          // ),

          // const SizedBox(height: 12),

          // // Order Date & Time
          // _buildDetailRowWithIcon(
          //   Icons.calendar_today_outlined,
          //   'Order Date',
          //   orderDate,
          // ),

          // if (orderTime.isNotEmpty) ...[
          //   const SizedBox(height: 12),
          //   _buildDetailRowWithIcon(
          //     Icons.access_time_outlined,
          //     'Order Time',
          //     orderTime,
          //   ),
          // ],
          const SizedBox(height: 12),

          // Total Items
          _buildDetailRowWithIcon(
            Icons.shopping_bag_outlined,
            'Total Items',
            '${totalItemsCount > 0 ? totalItemsCount : (widget.cartItems?.values.fold<int>(0, (sum, qty) => sum + qty) ?? 0)} item(s)',
          ),

          const SizedBox(height: 12),

          // Total Amount
          _buildDetailRowWithIcon(
            Icons.currency_rupee,
            'Total Amount',
            '₹${widget.totalAmount.toStringAsFixed(2)}',
            valueColor: AppConstants.primaryColor,
            valueBold: true,
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDetailRowWithIcon(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    bool valueBold = false,
    bool showCopy = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: valueBold
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: valueColor ?? Colors.black87,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    if (showCopy) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order ID copied to clipboard'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.copy_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildSimpleTimeline() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Progress',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          ...List.generate(orderData['timeline'].length, (index) {
            final timelineItem = orderData['timeline'][index];
            final isCompleted = timelineItem['completed'];
            final isLast = index == orderData['timeline'].length - 1;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status indicator
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF1976D2)
                            : Colors.grey[200],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCompleted ? Icons.check : timelineItem['icon'],
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 40,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        color: isCompleted
                            ? const Color(0xFF1976D2).withOpacity(0.3)
                            : Colors.grey[200],
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Status content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          timelineItem['status'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? Colors.black87
                                : Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timelineItem['message'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (!isLast) const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  void _continueShopping() {
    // Navigate back to MainApp (home with bottom nav) and clear all previous routes
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home', // Navigate to MainApp with bottom navigation
      (route) => false, // Remove all previous routes
    );
  }
}
