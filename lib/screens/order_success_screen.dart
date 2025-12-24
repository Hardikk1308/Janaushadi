import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class OrderSuccessScreen extends StatefulWidget {
  final String orderId;
  final double totalAmount;
  final String paymentMethod;
  final Map<int, int>? cartItems;
  final Map<String, dynamic>? trackingData;
  final VoidCallback? onBackPressed;

  const OrderSuccessScreen({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.paymentMethod,
    this.cartItems,
    this.trackingData,
    this.onBackPressed,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _scaleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCOD = widget.paymentMethod.toLowerCase() == 'cod';

    return WillPopScope(
      onWillPop: () async {
        // Navigate to MainApp (home with bottom nav) when back is pressed
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.black26, size: 28),
            onPressed: () {
              // Navigate to MainApp (home with bottom nav) and  all previous routes
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
            tooltip: 'Close',
          ),
        ),
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // Success Icon and Message
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Column(
                            children: [
                              // Success Lottie Animation
                              Lottie.asset(
                                'assets/lottie/order_success.json',
                                width: 200,
                                height: 200,
                                fit: BoxFit.contain,
                                repeat: false,
                              ),

                              const SizedBox(height: 20),

                              // Order Placed Text
                              Text(
                                'Order placed',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[600],
                                  letterSpacing: -0.5,
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Subtitle Message
                              Text(
                                isCOD
                                    ? 'Pay once your order is packed'
                                    : 'Payment successful! Your order is being processed',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Next Steps Section
                      SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.green[400]!, Colors.green[600]!],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 40),

                              // NEXT STEPS Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Text(
                                  'NEXT STEPS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 40),

                              // Progress Steps
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 40,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildProgressStep(
                                      icon: Icons.inventory_2_rounded,
                                      title: 'Order packed',
                                      isCompleted: false,
                                      isActive: true,
                                    ),

                                    // Connecting Line
                                    Expanded(
                                      child: Container(
                                        height: 2,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.3),
                                        ),
                                        child: Row(
                                          children: List.generate(
                                            20,
                                            (index) => Expanded(
                                              child: Container(
                                                height: 2,
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: index.isEven
                                                      ? Colors.white
                                                            .withOpacity(0.6)
                                                      : Colors.transparent,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    _buildProgressStep(
                                      icon: isCOD
                                          ? Icons.payment_rounded
                                          : Icons.credit_card_rounded,
                                      title: isCOD
                                          ? 'Make payment'
                                          : 'Payment done',
                                      isCompleted: !isCOD,
                                      isActive: isCOD,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 60),

                              // Order Details Card
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Order ID',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          widget.orderId,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Total Amount',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          '₹${widget.totalAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Payment Method',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          widget.paymentMethod.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Track Order Button
              // Container(
              //   width: double.infinity,
              //   padding: const EdgeInsets.all(20),
              //   decoration: const BoxDecoration(
              //     color: Colors.white,
              //     boxShadow: [
              //       BoxShadow(
              //         color: Colors.black12,
              //         blurRadius: 10,
              //         offset: Offset(0, -2),
              //       ),
              //     ],
              //   ),
              //   child: ElevatedButton(
              //     onPressed: () {
              //       Navigator.pushReplacement(
              //         context,
              //         MaterialPageRoute(
              //           builder: (context) => OrderTrackingScreen(
              //             orderId: widget.orderId,
              //             totalAmount: widget.totalAmount,
              //             paymentMethod: widget.paymentMethod,
              //             cartItems: widget.cartItems,
              //             trackingData: widget.trackingData,
              //           ),
              //         ),
              //       );
              //     },
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: AppConstants.primaryColor,
              //       foregroundColor: Colors.white,
              //       padding: const EdgeInsets.symmetric(vertical: 16),
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(12),
              //       ),
              //       elevation: 2,
              //     ),
              //     child: const Text(
              //       'Track order',
              //       style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep({
    required IconData icon,
    required String title,
    required bool isCompleted,
    required bool isActive,
  }) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.white
                : isActive
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isActive
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check_rounded : icon,
            color: isCompleted
                ? Colors.green[600]
                : isActive
                ? Colors.white
                : Colors.white.withOpacity(0.6),
            size: 36,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: TextStyle(
            color: isCompleted || isActive
                ? Colors.white
                : Colors.white.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
