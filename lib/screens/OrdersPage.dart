import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'package:jan_aushadi/screens/order_tracking_screen.dart';
import 'package:jan_aushadi/screens/product_details_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage>
    with SingleTickerProviderStateMixin {
  int _selectedTab = 0; // 0: All Orders, 1: Placed, 2: Delivered
  late TabController _tabController;
  bool _isLoading = true;
  String customerName = 'Customer';

  List<Order> placedOrders = [];
  List<Order> deliveredOrders = [];
  List<Order> cancelledOrders = [];

  // Date filter variables
  DateTime? _selectedDate;
  final int _itemsPerPage = 5;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTab = _tabController.index;
        _currentPage = 1; // Reset to first page when changing tabs
      });
    });
    _loadCustomerName();
    _fetchOrders();
  }

  Future<void> _loadCustomerName() async {
    try {
      final userData = await AuthService.getUserData();
      if (userData != null) {
        final userDataMap = jsonDecode(userData);
        setState(() {
          customerName = userDataMap['M1_NAME'] ?? 'Customer';
        });
      }
    } catch (e) {
      print('Error loading customer name: $e');
    }
  }

  Future<void> _fetchOrders() async {
    print('🔄 Starting to fetch orders...');
    setState(() {
      _isLoading = true;
    });

    try {
      final dio = Dio();
      final m1Code = await AuthService.getM1Code();

      print('👤 User M1_CODE: $m1Code');

      if (m1Code == null || m1Code.isEmpty) {
        print('❌ User not logged in');
        throw Exception('User not logged in');
      }

      // Fetch all orders at once (API returns all orders)
      // Note: Not including F4_BT to get all orders without status filter
      print('\n📦 Fetching all orders...');

      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/order_list',
        data: {'M1_CODE': m1Code},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Jan-Aushadhi-App/1.0',
          },
        ),
      );

      print('✅ Response Status: ${response.statusCode}');
      print('📥 Response Data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        var responseData = response.data;

        // Parse JSON string if needed
        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (e) {
            print('❌ Failed to parse JSON: $e');
            throw Exception('Failed to parse response');
          }
        }

        if (responseData is Map) {
          if (responseData['response'] == 'success') {
            print('\n✅ Parsing and categorizing orders...');
            final data = responseData['data'] as List?;

            if (data != null && data.isNotEmpty) {
              final allOrders = data
                  .map((item) => Order.fromJson(item))
                  .toList();

              // Categorize orders by status
              // "Placed" includes both "placed" and "confirmed" statuses
              placedOrders = allOrders
                  .where((order) => 
                      order.status.toLowerCase() == 'placed' ||
                      order.status.toLowerCase() == 'confirmed')
                  .toList();

              deliveredOrders = allOrders
                  .where((order) => order.status.toLowerCase() == 'delivered')
                  .toList();

              cancelledOrders = allOrders
                  .where((order) => order.status.toLowerCase() == 'cancelled')
                  .toList();

              print(
                '📊 Placed: ${placedOrders.length}, Delivered: ${deliveredOrders.length}, Cancelled: ${cancelledOrders.length}',
              );
            } else {
              print('⚠️ No data array found in response or empty');
              // Set empty lists
              placedOrders = [];
              deliveredOrders = [];
              cancelledOrders = [];
            }
          } else if (responseData['response'] == 'error' &&
              responseData['message']?.toString().toLowerCase().contains(
                    'no data',
                  ) ==
                  true) {
            // Handle "No Data Found" case - this is not an error, just no orders yet
            print('ℹ️ No orders found for this user');
            placedOrders = [];
            deliveredOrders = [];
            cancelledOrders = [];
          } else {
            print('❌ Invalid response format');
            print('   Response keys: ${responseData.keys.toList()}');
            print('   Response["response"]: ${responseData['response']}');
            print('   Response["message"]: ${responseData['message']}');
            throw Exception(
              'API Error: ${responseData['message'] ?? 'Unknown error'}',
            );
          }
        } else {
          throw Exception('Invalid response format: Response is not a map');
        }
      } else {
        throw Exception('Failed to fetch orders: ${response.statusCode}');
      }

      setState(() {
        _isLoading = false;
      });
      print('\n✅ All orders fetched successfully!');
    } catch (e) {
      print('\n❌ Error fetching orders: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load orders: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Filter orders based on selected date
  List<Order> _getFilteredOrders(List<Order> orders) {
    if (_selectedDate == null) {
      return orders;
    }

    return orders.where((order) {
      try {
        final orderDate = DateTime.parse(order.date.replaceAll(' ', 'T'));
        // Compare only the date part (ignore time)
        return orderDate.year == _selectedDate!.year &&
            orderDate.month == _selectedDate!.month &&
            orderDate.day == _selectedDate!.day;
      } catch (e) {
        return true;
      }
    }).toList();
  }

  // Get paginated orders
  List<Order> _getPaginatedOrders(List<Order> orders) {
    final filteredOrders = _getFilteredOrders(orders);
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    if (startIndex >= filteredOrders.length) {
      return [];
    }

    return filteredOrders.sublist(
      startIndex,
      endIndex > filteredOrders.length ? filteredOrders.length : endIndex,
    );
  }

  // Get total pages for current tab
  int _getTotalPages(List<Order> orders) {
    final filteredOrders = _getFilteredOrders(orders);
    return (filteredOrders.length / _itemsPerPage).ceil();
  }

  // Show date picker
  Future<void> _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1976D2),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _currentPage = 1; // Reset to first page
      });
    }
  }

  // Clear date filter
  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
      _currentPage = 1;
    });
  }

  // Download invoice
  Future<void> _downloadInvoice(Order order) async {
    if (order.invoiceUrl == null || order.invoiceUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice URL not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Import url_launcher at the top of the file
      // import 'package:url_launcher/url_launcher.dart';
      
      final Uri invoiceUri = Uri.parse(order.invoiceUrl!);
      
      if (await canLaunchUrl(invoiceUri)) {
        await launchUrl(
          invoiceUri,
          mode: LaunchMode.externalApplication,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Opening invoice...'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw 'Could not launch invoice URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open invoice: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _trackOrder(Order order) {
    // For cancelled orders, show details screen instead of tracking
    if (order.status.toLowerCase() == 'cancelled') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailsScreen(order: order),
        ),
      ).then((_) {
        // Refresh orders when returning from details screen
        _fetchOrders();
      });
      return;
    }

    // Convert orderItems to the format expected by tracking screen
    List<Map<String, dynamic>> itemsData = order.orderItems.map((item) {
      return {
        'M1_NAME': item.productName,
        'F4_QTOT': item.quantity.toString(),
        'F4_AMT1': item.mrpPrice.toString(),
        'F4_AMT2': item.salePrice.toString(),
        'F4_AMT3': item.totalMrp.toString(),
        'F4_AMT4': item.totalSale.toString(),
        'F4_F1': item.productId,
        'image': item.imageUrl,
      };
    }).toList();

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            OrderTrackingScreen(
              orderId: order.orderNumber,
              totalAmount: order.total,
              paymentMethod: order.paymentMethod ?? 'Unknown',
              trackingData: {
                'response': 'success',
                'data': [
                  {
                    'F4_NO': order.orderNumber,
                    'F4_BT': order.status,
                    'F4_DATE': order.date,
                    'F4_GTOT': order.total.toString(),
                    'F4_STOT': order.subtotal.toString(),
                    'F4_DIS': order.discount.toString(),
                    'payment_method': order.paymentMethod,
                    'items': itemsData,
                  },
                ],
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      // Refresh orders when returning from tracking screen
      _fetchOrders();
    });
  }

  // Cancel order
  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text(
          'Are you sure you want to cancel order #${order.orderNumber}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Keep It'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Cancel Order',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
      final dio = Dio();
      final m1Code = await AuthService.getM1Code();

      if (m1Code == null || m1Code.isEmpty) {
        throw Exception('User not authenticated');
      }

      print('🚫 Cancelling order: ${order.orderNumber}');

      // Call the cancel order API
      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/cancel_order',
        data: {'M1_CODE': m1Code, 'F4_NO': order.orderNumber},
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

      // Close loading dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (response.statusCode == 200) {
        var responseData = response.data;

        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (e) {
            print('Error parsing cancel response: $e');
          }
        }

        if (responseData is Map &&
            responseData['response']?.toString().toLowerCase() == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order cancelled successfully'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
            // Add a small delay to ensure backend updates the status
            await Future.delayed(const Duration(milliseconds: 500));
            // Refresh orders
            _fetchOrders();
          }
        } else {
          throw Exception(responseData['message'] ?? 'Failed to cancel order');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error cancelling order: $e');

      // Close loading dialog if still open
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (e) {
          print('⚠️ Could not close dialog: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel order: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/home',
              (route) => false,
            );
          },
        ),
      ),
      backgroundColor: const Color(0xFFFAFAFA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
              ),
            )
          : Column(
              children: [
                // Date Filter Section
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1976D2).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: Color(0xFF1976D2),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Filter Orders by Date',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: _showDatePicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedDate != null
                                  ? const Color(0xFF1976D2)
                                  : Colors.grey[300]!,
                              width: _selectedDate != null ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                            color: _selectedDate != null
                                ? const Color(0xFF1976D2).withOpacity(0.05)
                                : Colors.white,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.event,
                                color: _selectedDate != null
                                    ? const Color(0xFF1976D2)
                                    : Colors.grey[400],
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _selectedDate != null
                                          ? '${_selectedDate!.day} ${_getMonthName(_selectedDate!.month)} ${_selectedDate!.year}'
                                          : 'Tap to select a date',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedDate != null
                                            ? const Color(0xFF1976D2)
                                            : Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_selectedDate != null) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: _clearDateFilter,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.red[600],
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ] else
                                Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey[400],
                                  size: 16,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 14,
                  ),
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTabButton(
                          'All Orders',
                          0,
                          placedOrders.length + deliveredOrders.length,
                        ),
                      ),
                      Expanded(
                        child: _buildTabButton(
                          'Placed',
                          1,
                          placedOrders.length,
                        ),
                      ),
                      Expanded(
                        child: _buildTabButton(
                          'Delivered',
                          2,
                          deliveredOrders.length,
                        ),
                      ),
                    ],
                  ),
                ),
                // Sliding Tab View
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchOrders,
                    color: const Color(0xFF1976D2),
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOrdersList([
                          ...placedOrders,
                          ...deliveredOrders,
                        ], 'No orders'),
                        _buildOrdersList(placedOrders, 'No placed orders'),
                        _buildOrdersList(
                          deliveredOrders,
                          'No delivered orders',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOrdersList(List<Order> orders, String emptyMessage) {
    final paginatedOrders = _getPaginatedOrders(orders);
    final totalPages = _getTotalPages(orders);
    final filteredCount = _getFilteredOrders(orders).length;

    if (filteredCount == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(
                  Icons.receipt_outlined,
                  size: 40,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                emptyMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: paginatedOrders.length,
            itemBuilder: (context, index) =>
                _buildOrderCard(paginatedOrders[index]),
          ),
        ),
        // Pagination controls
        if (totalPages > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _currentPage > 1
                      ? () => setState(() => _currentPage--)
                      : null,
                  style: ElevatedButton.styleFrom(
                    maximumSize: const Size(120, 40),
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  // label: const Text('Previous'),
                ),
                Text(
                  'Page $_currentPage of $totalPages',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  onPressed: _currentPage < totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTabButton(String title, int index, int count) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        _tabController.animateTo(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            count > 0 ? '$title ($count)' : title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? const Color(0xFF1976D2) : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header with Customer Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order.orderNumber}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ordered by $customerName',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.status,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Order Info Row
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(order.date),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(width: 20),
              Icon(
                Icons.shopping_bag_outlined,
                size: 16,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 6),
              Text(
                '${order.items} item(s)',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Amount Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '₹${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Single Action Button
          SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _trackOrder(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      order.status.toLowerCase() == 'cancelled'
                          ? 'View Details'
                          : 'Track Order',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Download Invoice button - only show for delivered orders
                if (order.status.toLowerCase() == 'delivered' &&
                    order.invoiceUrl != null &&
                    order.invoiceUrl!.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadInvoice(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[50],
                        foregroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.green[200]!),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(Icons.download, size: 18, color: Colors.green[700]),
                      label: const Text(
                        'Invoice',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ] else if (order.status.toLowerCase() == 'placed') ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _cancelOrder(order),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Cancel Order',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final hour12 = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.day}/${date.month}/${date.year} at ${hour12.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Colors.blue;
      case 'confirmed':
        return Colors.orange;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class Order {
  final String orderNumber;
  final String date;
  final int items;
  final double total;
  final String status;
  final String? address;
  final List<OrderItem> orderItems;
  final double discount;
  final double subtotal;
  final String customerName;
  final String customerPhone;
  final String? paymentMethod;
  final String? invoiceUrl;
  final String? discountType; // 'Flat' or 'Percent'
  final double? discountPercentage; // For percent discounts

  Order({
    required this.orderNumber,
    required this.date,
    required this.items,
    required this.total,
    required this.status,
    this.address,
    this.orderItems = const [],
    this.discount = 0.0,
    this.subtotal = 0.0,
    this.customerName = 'Customer',
    this.customerPhone = '',
    this.paymentMethod,
    this.invoiceUrl,
    this.discountType,
    this.discountPercentage,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    print('🔍 Parsing Order JSON: $json');

    // Parse order items if available
    List<OrderItem> items = [];
    if (json['items'] != null && json['items'] is List) {
      print('📦 Found ${(json['items'] as List).length} items in order');
      items = (json['items'] as List)
          .map((item) => OrderItem.fromJson(item))
          .toList();
    }

    // Calculate total items count
    int itemCount = items.fold(0, (sum, item) => sum + item.quantity);
    if (itemCount == 0 && items.isNotEmpty) {
      itemCount = items.length;
    }

    // Parse monetary values
    double totalAmount =
        double.tryParse(json['F4_GTOT']?.toString() ?? '0') ?? 0.0;
    double subtotal =
        double.tryParse(json['F4_STOT']?.toString() ?? '0') ?? 0.0;
    
    // Parse discount - check discount type
    double discount = 0.0;
    String? discountType = json['M1_DC']?.toString(); // 'Flat' or 'Percent'
    
    if (discountType?.toLowerCase() == 'flat') {
      // For flat discount, use M1_AMT1 as the discount amount
      discount = double.tryParse(json['M1_AMT1']?.toString() ?? '0') ?? 0.0;
    } else if (discountType?.toLowerCase() == 'percent') {
      // For percentage discount, calculate from subtotal
      double percentValue = double.tryParse(json['M1_AMT1']?.toString() ?? '0') ?? 0.0;
      discount = (subtotal * percentValue) / 100;
    } else {
      // Fallback to F4_DIS
      discount = double.tryParse(json['F4_DIS']?.toString() ?? '0') ?? 0.0;
    }

    // Parse payment method - check multiple possible fields
    String? paymentMethod =
        json['payment_method']?.toString() ??
        json['F4_PAYMENT']?.toString() ??
        json['PAYMENT_TYPE']?.toString() ??
        json['PAY_MODE']?.toString();

    // If no payment method found, try to determine from other fields
    if (paymentMethod == null || paymentMethod.isEmpty) {
      // Check if there's any indication of COD in other fields
      String? paymentInfo =
          json['F4_REMARK']?.toString() ?? json['F4_NOTE']?.toString() ?? '';
      if (paymentInfo.toLowerCase().contains('cod') ||
          paymentInfo.toLowerCase().contains('cash on delivery')) {
        paymentMethod = 'COD';
      } else {
        paymentMethod = 'Online Payment'; // Default fallback
      }
    }

    final order = Order(
      orderNumber: json['F4_NO']?.toString() ?? 'N/A',
      date: json['F4_DATE']?.toString() ?? 'N/A',
      items: itemCount,
      total: totalAmount,
      status: json['F4_BT']?.toString() ?? 'Unknown',
      orderItems: items,
      discount: discount,
      subtotal: subtotal,
      customerName:
          json['customer_name']?.toString() ??
          json['M1_NAME']?.toString() ??
          'Customer',
      paymentMethod: paymentMethod,
      invoiceUrl: json['invoice']?.toString(),
      discountType: discountType,
      discountPercentage: discountType?.toLowerCase() == 'percent'
          ? double.tryParse(json['M1_AMT1']?.toString() ?? '0')
          : null,
    );

    print(
      '✅ Order parsed: ${order.orderNumber} - ${order.status} - Payment: ${order.paymentMethod}',
    );
    return order;
  }
}

class OrderItem {
  final String productId;
  final String productName;
  final int quantity;
  final double mrpPrice;
  final double salePrice;
  final double totalMrp;
  final double totalSale;
  final String? imageUrl;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.mrpPrice,
    required this.salePrice,
    required this.totalMrp,
    required this.totalSale,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['F4_F1']?.toString() ?? '',
      productName: json['M1_NAME']?.toString() ?? 'Unknown Product',
      quantity: int.tryParse(json['F4_QTOT']?.toString() ?? '0') ?? 1,
      mrpPrice: double.tryParse(json['F4_AMT1']?.toString() ?? '0') ?? 0.0,
      salePrice: double.tryParse(json['F4_AMT2']?.toString() ?? '0') ?? 0.0,
      totalMrp: double.tryParse(json['F4_AMT3']?.toString() ?? '0') ?? 0.0,
      totalSale: double.tryParse(json['F4_AMT4']?.toString() ?? '0') ?? 0.0,
      imageUrl: json['image']?.toString(),
    );
  }
}

// Order Details Screen
class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isCancelling = false;

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);

    try {
      final dio = Dio();
      final m1Code = await AuthService.getM1Code();

      if (m1Code == null || m1Code.isEmpty) {
        throw Exception('User not authenticated');
      }

      print('🚫 Cancelling order: ${widget.order.orderNumber}');

      // Call the cancel order API
      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/cancel_order',
        data: {
          'M1_CODE': m1Code,
          'F4_NO': widget.order.orderNumber,
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

      if (response.statusCode == 200) {
        var responseData = response.data;

        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (e) {
            print('Error parsing cancel response: $e');
          }
        }

        if (responseData is Map &&
            responseData['response']?.toString().toLowerCase() == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order cancelled successfully'),
                backgroundColor: Colors.green,
              ),
            );
            // Go back to orders page which will refresh the list
            Navigator.pop(context);
          }
        } else {
          throw Exception(responseData['message'] ?? 'Failed to cancel order');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
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
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.black87,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Order ${widget.order.orderNumber}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.order.status.toLowerCase() == 'cancelled'
                      ? [Colors.red[400]!, Colors.red[600]!]
                      : [
                          AppConstants.primaryColor,
                          AppConstants.primaryColor.withOpacity(0.8),
                        ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.order.status.toLowerCase() == 'cancelled'
                            ? Icons.cancel_rounded
                            : Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.order.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Order placed on ${_formatDate(widget.order.date)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Order Items
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Items Ordered',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ...widget.order.orderItems.map(
                    (item) => _buildOrderItem(item),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Price Breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Price Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildPriceRow('Subtotal', widget.order.subtotal),
                  const SizedBox(height: 8),
                  if (widget.order.discount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.order.discountType?.toLowerCase() == 'percent'
                                      ? 'Discount Applied'
                                      : 'Discount',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (widget.order.discountType?.toLowerCase() == 'percent')
                                  Text(
                                    '${widget.order.discountPercentage?.toStringAsFixed(1)}% off',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '- ₹${widget.order.discount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildPriceRow('Delivery', 0.0, isFree: true),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey[300]!),
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: _buildPriceRow('Total Amount', widget.order.total, isTotal: true),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            if (widget.order.status.toLowerCase() != 'cancelled' &&
                widget.order.status.toLowerCase() != 'delivered')
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCancelling ? null : _cancelOrder,
                      icon: _isCancelling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cancel_outlined, size: 18),
                      label: Text(
                        _isCancelling ? 'Cancelling...' : 'Cancel Order',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[50],
                        foregroundColor: Colors.red[700],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.red[200]!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),

            // Continue Shopping button for all orders
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Navigate to all products page
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/all_products', // Make sure this route exists in your app
                    (route) => route.isFirst,
                  );
                },
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
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
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
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
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        );
                      },
                    )
                  : Icon(
                      Icons.medication_outlined,
                      color: Colors.grey[400],
                      size: 30,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quantity: ${item.quantity}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (item.mrpPrice != item.salePrice) ...[
                      Text(
                        '₹${item.mrpPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '₹${item.salePrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            '₹${item.totalSale.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isDiscount = false,
    bool isFree = false,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey[600],
            ),
          ),
          Text(
            isFree ? 'FREE' : '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isDiscount
                  ? Colors.green
                  : (isTotal ? Colors.black : Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr.replaceAll(' ', 'T'));
      final hour12 = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final period = date.hour >= 12 ? 'PM' : 'AM';
      return '${date.day}/${date.month}/${date.year} at ${hour12.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return dateStr;
    }
  }
}
