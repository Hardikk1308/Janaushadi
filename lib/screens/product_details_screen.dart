import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jan_aushadi/models/Product_model.dart' as product_model;
import 'package:jan_aushadi/screens/cart_screen.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/utils/html_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

typedef Product = product_model.Product;

class _ImageLoaderWidget extends StatefulWidget {
  final List<String> imageUrlVariants;
  final BoxFit fit;
  final String? m1Code;

  const _ImageLoaderWidget({
    required this.imageUrlVariants,
    required this.fit,
    this.m1Code,
  });

  @override
  State<_ImageLoaderWidget> createState() => _ImageLoaderWidgetState();
}

class _ImageLoaderWidgetState extends State<_ImageLoaderWidget> {
  int _currentUrlIndex = 0;
  bool _hasError = false;
  bool _initialLoad = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _currentUrlIndex >= widget.imageUrlVariants.length) {
      return Container(
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
            const SizedBox(height: 4),
            Text(
              'Image not found',
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_initialLoad) {
      _initialLoad = false;
      if (_currentUrlIndex > 0) {
        print(
          '🔄 Fallback URL [${_currentUrlIndex + 1}/${widget.imageUrlVariants.length}]',
        );
      }
    }

    final currentUrl = widget.imageUrlVariants[_currentUrlIndex];
    print('🖼️ Loading image: $currentUrl');

    return CachedNetworkImage(
      imageUrl: currentUrl,
      fit: widget.fit,
      maxHeightDiskCache: 400,
      maxWidthDiskCache: 400,
      memCacheHeight: 400,
      memCacheWidth: 400,
      fadeInDuration: const Duration(milliseconds: 150),
      fadeOutDuration: const Duration(milliseconds: 50),
      httpHeaders: {
        'Accept': 'image/*',
        'Cache-Control': 'public, max-age=86400',
        'User-Agent': 'Jan-Aushadhi-App/1.0',
        if (widget.m1Code != null && widget.m1Code!.isNotEmpty)
          'M1_CODE': widget.m1Code!,
      },
      placeholder: (context, url) => Container(
        color: Colors.grey[50],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Loading...',
                style: TextStyle(fontSize: 8, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        if (_currentUrlIndex < widget.imageUrlVariants.length - 1) {
          Future.microtask(() {
            if (mounted) {
              setState(() {
                _currentUrlIndex++;
                _initialLoad = true;
              });
            }
          });
          return Container(
            color: Colors.grey[100],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        } else {
          _hasError = true;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[50]!, Colors.blue[100]!],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.local_pharmacy,
                    color: Color(0xFF1976D2),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Jan Aushadhi',
                  style: TextStyle(
                    fontSize: 8,
                    color: Color(0xFF1976D2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Medicine',
                  style: TextStyle(
                    fontSize: 7,
                    color: Colors.grey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  final Map<int, int> cartItems;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.cartItems,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late int quantity;
  String? _m1Code;
  late Map<int, int> _cartItems;

  @override
  void initState() {
    super.initState();
    _loadCartFromSharedPreferences();
    _initializeM1Code();
  }

  Future<void> _loadCartFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');
      if (cartJson != null && cartJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(cartJson);
        _cartItems = decoded.map(
          (key, value) => MapEntry(int.parse(key), value as int),
        );
        print('✅ Cart loaded from SharedPreferences: $_cartItems');
      } else {
        _cartItems = Map<int, int>.from(widget.cartItems);
        print('📦 Using cart from widget: $_cartItems');
      }

      // Initialize quantity from cart if product already exists, otherwise 0
      quantity = _cartItems[int.parse(widget.product.id)] ?? 0;
      if (quantity == 0) quantity = 1; // Start with 1 for new additions

      if (mounted) setState(() {});
    } catch (e) {
      print('❌ Error loading cart: $e');
      _cartItems = Map<int, int>.from(widget.cartItems);
      quantity = _cartItems[int.parse(widget.product.id)] ?? 0;
      if (quantity == 0) quantity = 1;
    }
  }

  void _initializeM1Code() async {
    _m1Code = await AuthService.getM1Code();
    if (mounted) setState(() {});
  }

  List<String> _generateImageUrls(Product product) {
    List<String> urls = [];

    print('🔍 Generating URLs for product: ${product.name}');
    print('   Image filename: ${product.imageUrl}');

    if (product.imageUrl.isNotEmpty) {
      String filename = product.imageUrl;

      if (filename.contains('/')) {
        filename = filename.split('/').last;
      }

      if (filename.contains('?')) {
        filename = filename.split('?').first;
      }
      if (filename.contains('#')) {
        filename = filename.split('#').first;
      }

      if (filename.isNotEmpty) {
        print('   Using filename: $filename');

        urls.addAll([
          'https://webdevelopercg.com/janaushadhi/myadmin/uploads/product/$filename',
          'https://webdevelopercg.com/janaushadhi/uploads/product/$filename',
          'https://webdevelopercg.com/janaushadhi/uploads/product_images/$filename',
          'https://webdevelopercg.com/janaushadhi/public/uploads/product/$filename',
          'https://webdevelopercg.com/janaushadhi/assets/product/$filename',
        ]);
      }

      if (product.imageUrl.startsWith('http')) {
        urls.add(product.imageUrl);
      }
    }

    return urls;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context, _cartItems),
          ),
          title: Text(
            widget.product.name,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          //
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  _buildProductImage(),

                  // Product Basic Info
                  _buildProductBasicInfo(),

                  // Product Descriptions
                  _buildProductDescriptions(),

                  const SizedBox(height: 100), // Space for bottom bar
                ],
              ),
            ),
            // Floating Cart Bar
            Positioned(
              left: 15,
              right: 15,
              bottom: 15,
              child: _buildFloatingCartBar(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildProductImage() {
    // Use imageUrls if available, otherwise fallback to single imageUrl
    final imagesToDisplay = widget.product.imageUrls.isNotEmpty
        ? widget.product.imageUrls
        : [widget.product.imageUrl];

    final hasMultipleImages = imagesToDisplay.length > 1;

    return Container(
      height: 350,
      width: double.infinity,
      color: Colors.grey[50],
      child: Stack(
        children: [
          // Always use PageView for consistent UI
          PageView.builder(
            itemCount: imagesToDisplay.length,
            itemBuilder: (context, index) {
              final imageFilename = imagesToDisplay[index];
              return Container(
                color: Colors.white,
                child: _ImageLoaderWidget(
                  imageUrlVariants: _generateImageUrlsFromFilename(
                    imageFilename,
                  ),
                  fit: BoxFit.contain,
                  m1Code: _m1Code,
                ),
              );
            },
          ),
          // Discount badge
          if (widget.product.discountPercent > 0)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.product.discountPercent}% OFF',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          // Image indicator dots - only show for multiple images
          if (hasMultipleImages)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imagesToDisplay.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.8),
                      border: Border.all(
                        color: const Color(0xFF1976D2),
                        width: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _generateImageUrlsFromFilename(String filename) {
    List<String> urls = [];

    if (filename.isEmpty) return urls;

    if (filename.contains('/')) {
      filename = filename.split('/').last;
    }
    if (filename.contains('?')) {
      filename = filename.split('?').first;
    }
    if (filename.contains('#')) {
      filename = filename.split('#').first;
    }

    if (filename.isNotEmpty) {
      urls.addAll([
        'https://webdevelopercg.com/janaushadhi/myadmin/uploads/product/$filename',
        'https://webdevelopercg.com/janaushadhi/uploads/product/$filename',
        'https://webdevelopercg.com/janaushadhi/uploads/product_images/$filename',
        'https://webdevelopercg.com/janaushadhi/public/uploads/product/$filename',
        'https://webdevelopercg.com/janaushadhi/assets/product/$filename',
      ]);
    }

    return urls;
  }

  Widget _buildProductBasicInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.product.brand,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.product.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                '${widget.product.rating}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(124 reviews)',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '₹${widget.product.salePrice}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 8),
              if (widget.product.originalPrice > widget.product.salePrice)
                Text(
                  '₹${widget.product.originalPrice}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductDescriptions() {
    final descriptions = [
      {
        'title': 'Short Description',
        'content': widget.product.description1,
        'icon': Icons.description,
      },
      {
        'title': 'Product Information',
        'content': widget.product.description2,
        'icon': Icons.info,
      },
      {
        'title': 'Key Uses',
        'content': widget.product.description3,
        'icon': Icons.medical_services,
      },
      {
        'title': 'Safety Information',
        'content': widget.product.description4,
        'icon': Icons.security,
      },
      {
        'title': 'Side Effects',
        'content': widget.product.description5,
        'icon': Icons.warning,
      },
      {
        'title': 'How To Use',
        'content': widget.product.description6,
        'icon': Icons.help,
      },
      {
        'title': 'Additional Information',
        'content': widget.product.description7,
        'icon': Icons.add_circle,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: descriptions
            .where((desc) => desc['content']!.toString().isNotEmpty)
            .map(
              (desc) => _buildDescriptionCard(
                desc['title']!.toString(),
                desc['content']!.toString(),
                desc['icon']! as IconData,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildDescriptionCard(String title, String content, IconData icon) {
    final parsedContent = HtmlParser.stripHtmlTags(content);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Icon(icon, color: const Color(0xFF1976D2)),
        title: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                parsedContent,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateCartTotal() {
    double total = 0;
    final currentProductId = int.parse(widget.product.id);

    for (final entry in _cartItems.entries) {
      final productId = entry.key;
      final quantity = entry.value;

      print(
        '🛒 Cart item - ID: $productId, Qty: $quantity, Current Product ID: $currentProductId',
      );

      // Calculate total for current product
      if (productId == currentProductId) {
        final itemTotal = widget.product.salePrice * quantity;
        print(
          '💰 Calculating total: ${widget.product.salePrice} * $quantity = $itemTotal',
        );
        total += itemTotal;
      }
    }

    print('📊 Final cart total: $total');
    return total;
  }

  Widget _buildFloatingCartBar() {
    final cartCount = _cartItems.length;
    final cartTotal = _calculateCartTotal();

    return GestureDetector(
      onTap: () {
        // Navigate to cart screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CartScreen(cartItems: _cartItems, products: [widget.product]),
          ),
        ).then((result) {
          if (result is Map<int, int>) {
            setState(() {
              _cartItems = result;
            });
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 52, 136, 220),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1976D2).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Cart Icon with item count
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 20,
                  ),
                  if (cartCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          '$cartCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Price and item count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '₹${cartTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$cartCount item${cartCount > 1 ? 's' : ''} in cart',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // View Cart Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'View',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quantity Selector
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1976D2)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, color: Color(0xFF1976D2)),
                  onPressed: () {
                    if (quantity > 1) {
                      setState(() {
                        quantity--;
                      });
                    }
                  },
                ),
                Text(
                  '$quantity',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFF1976D2)),
                  onPressed: () {
                    setState(() {
                      quantity++;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Add to Cart Button
          Expanded(
            child: ElevatedButton(
              onPressed: () async {
                final productId = int.parse(widget.product.id);
                _cartItems[productId] = quantity;

                print(
                  '🛒 Adding to cart - Product ID: $productId, Quantity: $quantity',
                );
                print('📦 Cart items after add: $_cartItems');

                // Save cart to SharedPreferences
                await _saveCartToSharedPreferences();

                // Update UI to reflect cart changes
                setState(() {});

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$quantity ${widget.product.name} added to cart',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Add to Cart - ₹${(widget.product.salePrice * quantity).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCartToSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(
        _cartItems.map((key, value) => MapEntry(key.toString(), value)),
      );
      await prefs.setString('cart_items', cartJson);
      print(
        '✅ Cart saved to SharedPreferences from ProductDetails: $_cartItems',
      );
    } catch (e) {
      print('❌ Error saving cart to SharedPreferences: $e');
    }
  }
}
