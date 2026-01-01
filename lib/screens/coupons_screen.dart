import 'package:flutter/material.dart';
import 'package:jan_aushadi/models/coupon_model.dart';
import 'package:jan_aushadi/services/coupon_service.dart';

class CouponsScreen extends StatefulWidget {
  final double cartTotal;
  final Function(Coupon)? onCouponSelected;

  const CouponsScreen({
    super.key,
    required this.cartTotal,
    this.onCouponSelected,
  });

  @override
  State<CouponsScreen> createState() => _CouponsScreenState();
}

class _CouponsScreenState extends State<CouponsScreen> {
  late Future<List<Coupon>> _couponsFuture;
  Coupon? _selectedCoupon;
  final TextEditingController _couponCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _couponsFuture = CouponService.getCoupons();
  }

  @override
  void dispose() {
    _couponCodeController.dispose();
    super.dispose();
  }

  bool _isCouponApplicable(Coupon coupon) {
    final minAmount = double.tryParse(coupon.minAmount) ?? 0;
    return widget.cartTotal >= minAmount;
  }

  double _calculateDiscount(Coupon coupon) {
    final amount = double.tryParse(coupon.amount) ?? 0;
    if (coupon.discountType == 'Percentage') {
      return (widget.cartTotal * amount) / 100;
    }
    return amount;
  }

  void _applyCoupon(Coupon coupon) {
    if (!_isCouponApplicable(coupon)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum order amount of ₹${coupon.minAmount} required',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _selectedCoupon = coupon;
    });

    widget.onCouponSelected?.call(coupon);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coupon ${coupon.code} applied successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // Return to previous screen with selected coupon
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context, coupon);
      }
    });
  }

  void _searchCoupon(String code, List<Coupon> coupons) {
    final coupon = coupons.firstWhere(
      (c) => c.code.toUpperCase() == code.toUpperCase(),
      orElse: () => Coupon(
        code: '',
        name: '',
        discountType: '',
        amount: '',
        minAmount: '',
        expiryDate: '',
        description: '',
      ),
    );

    if (coupon.code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Coupon not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _applyCoupon(coupon);
    _couponCodeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Apply Coupons',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Coupon>>(
        future: _couponsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load coupons',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _couponsFuture = CouponService.getCoupons();
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final coupons = snapshot.data ?? [];

          if (coupons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No coupons available',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter Coupon Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _couponCodeController,
                              decoration: InputDecoration(
                                hintText: 'Enter coupon code',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              if (_couponCodeController.text.isNotEmpty) {
                                _searchCoupon(
                                  _couponCodeController.text,
                                  coupons,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1976D2),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: const Text(
                              'Apply',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Selected Coupon Display
                if (_selectedCoupon != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        border: Border.all(color: Colors.green, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[700]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Applied: ${_selectedCoupon!.code}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                                Text(
                                  'Discount: ₹${_calculateDiscount(_selectedCoupon!).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _selectedCoupon = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                // Available Coupons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Available Coupons (${coupons.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: coupons.length,
                  itemBuilder: (context, index) {
                    final coupon = coupons[index];
                    final isApplicable = _isCouponApplicable(coupon);
                    final discount = _calculateDiscount(coupon);
                    final isSelected = _selectedCoupon?.code == coupon.code;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: isSelected ? 4 : 1,
                      color: isSelected ? Colors.blue[50] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Text(
                                      //   coupon.code,
                                      //   style: const TextStyle(
                                      //     fontSize: 16,
                                      //     fontWeight: FontWeight.bold,
                                      //     color: Color(0xFF1976D2),
                                      //   ),
                                      // ),
                                      const SizedBox(height: 4),
                                      Text(
                                        coupon.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
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
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    coupon.discountType == 'Percentage'
                                        ? '${coupon.amount}% OFF'
                                        : '₹${coupon.amount} OFF',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // const SizedBox(height: 4),
                            if (coupon.description.isNotEmpty)
                              Text(
                                coupon.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            // const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Min. Order: ₹${coupon.minAmount}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    Text(
                                      'Valid till: ${coupon.expiryDate}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton(
                                  onPressed: isApplicable
                                      ? () => _applyCoupon(coupon)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    fixedSize: const Size(100, 50),
                                    backgroundColor: isSelected
                                        ? Colors.green
                                        : const Color(0xFF1976D2),
                                    disabledBackgroundColor: Colors.grey[300],
                                  ),
                                  child: Text(
                                    isSelected ? 'Applied' : 'Apply',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!isApplicable)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Minimum order of ₹${coupon.minAmount} required',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}
