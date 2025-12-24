import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/models/Product_model.dart' as product_model;
import 'product_details_screen.dart' as product_details;
import 'cart_screen.dart';

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
      // Only log if using fallback URLs
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

class AllProductsScreen extends StatefulWidget {
  const AllProductsScreen({super.key});

  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends State<AllProductsScreen>
    with TickerProviderStateMixin {
  late Future<List<Product>> _productsFuture;
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  Map<int, int> _cartItems = {};
  final TextEditingController _searchController = TextEditingController();
  final Map<int, AnimationController> _buttonAnimations = {};
  bool _isSearching = false;
  String? _m1Code;
  late AnimationController _searchAnimationController;
  bool _cartLoaded = false;
  String? _categoryId;
  String? _categoryName;

  @override
  void initState() {
    super.initState();
    _initializeM1Code();
    _productsFuture = _fetchAllProducts();
    _loadCartFromStorage();
    _searchController.addListener(_filterProducts);

    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get category ID from route arguments if provided
    // This is called after initState and is safe to use ModalRoute
    if (_categoryId == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _categoryId = args['categoryId'] as String?;
        _categoryName = args['categoryName'] as String?;
        print('📂 Category filter: $_categoryName (ID: $_categoryId)');
        
        // Refresh products with the new category ID
        setState(() {
          _productsFuture = _fetchAllProducts();
        });
      }
    }
  }

  void _initializeM1Code() async {
    _m1Code = await AuthService.getM1Code();
    if (mounted) setState(() {});
  }

  void _preloadImages(List<Product> products) {
    // Preload first 10 product images for faster initial display
    for (int i = 0; i < products.length && i < 10; i++) {
      final urls = _generateImageUrls(products[i]);
      if (urls.isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(
            urls.first,
            headers: {
              'Accept': 'image/*',
              'Cache-Control': 'public, max-age=86400',
              if (_m1Code != null && _m1Code!.isNotEmpty) 'M1_CODE': _m1Code!,
            },
          ),
          context,
        ).catchError((error) {
          // Silently handle preload errors
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchAnimationController.dispose();
    for (var controller in _buttonAnimations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCartFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');
      if (cartJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(cartJson);
        setState(() {
          _cartItems = decoded.map(
            (key, value) => MapEntry(int.parse(key), value as int),
          );
        });
        print('✅ Cart loaded from storage: $_cartItems');
      }
      setState(() {
        _cartLoaded = true;
      });
    } catch (e) {
      print('❌ Error loading cart: $e');
      setState(() {
        _cartLoaded = true;
      });
    }
  }

  Future<void> _saveCartToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(
        _cartItems.map((key, value) => MapEntry(key.toString(), value)),
      );
      await prefs.setString('cart_items', cartJson);
      print('✅ Cart saved to storage: $_cartItems');
    } catch (e) {
      print('❌ Error saving cart: $e');
    }
  }

  AnimationController _getOrCreateButtonAnimation(int productId) {
    if (!_buttonAnimations.containsKey(productId)) {
      _buttonAnimations[productId] = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      
      if (_cartLoaded && _cartItems.containsKey(productId) && _cartItems[productId]! > 0) {
        _buttonAnimations[productId]!.forward();
      }
    }
    return _buttonAnimations[productId]!;
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

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts
            .where(
              (product) =>
                  product.name.toLowerCase().contains(query) ||
                  product.brand.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  Future<List<Product>> _fetchAllProducts() async {
    try {
      final dio = Dio();
      
      final catId = _categoryId ?? '';
      print('📦 Fetching products with cat_id: "$catId"');
      if (_categoryName != null) {
        print('📂 Category: $_categoryName');
      }

      final response = await dio
          .post(
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_all_product',
            data: {
              'cat_id': catId,
              'subcat_id': '',
            },
            options: Options(contentType: 'application/x-www-form-urlencoded'),
          )
          .timeout(const Duration(seconds: 30));

      print('✅ Products Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success' && data['data'] is List) {
          List<Product> products = [];
          for (var item in data['data']) {
            products.add(Product.fromJson(item));
          }
          print('✅ Fetched ${products.length} products');
          setState(() {
            _allProducts = products;
            _filteredProducts = products;
          });
          _preloadImages(products);
          return products;
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching products: $e');
      rethrow;
    }
  }

  double _calculateCartTotal() {
    double total = 0;
    for (final entry in _cartItems.entries) {
      try {
        final product = _allProducts.firstWhere(
          (p) => int.parse(p.id) == entry.key,
        );
        total += product.salePrice * entry.value;
      } catch (e) {}
    }
    return total;
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (_isSearching) {
        _searchAnimationController.forward();
        Future.delayed(const Duration(milliseconds: 100), () {
          FocusScope.of(context).requestFocus(FocusNode());
        });
      } else {
        _searchAnimationController.reverse();
        _searchController.clear();
      }
    });
  }

  Widget _buildAnimatedSearchBar() {
    return AnimatedBuilder(
      animation: _searchAnimationController,
      builder: (context, child) {
        return SizeTransition(
          sizeFactor: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: _searchAnimationController,
              curve: Curves.easeOut,
            ),
          ),
          child: Container(
            color: const Color(0xFF1976D2),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                autofocus: _isSearching,
                style: const TextStyle(color: Colors.black87, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF1976D2),
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                          },
                          child: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 18,
                          ),
                        )
                      : null,
                  // border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _cartItems.values.fold<int>(0, (sum, qty) => sum + qty);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('All Products'),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_isSearching) {
              _toggleSearch();
            } else {
              Navigator.pop(context, _cartItems);
            }
          },
        ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _toggleSearch,
            ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CartScreen(
                        cartItems: _cartItems,
                        products: _allProducts,
                      ),
                    ),
                  ).then((result) {
                    if (result is Map) {
                      setState(() {
                        _cartItems = Map<int, int>.from(result);
                      });
                      _saveCartToStorage();
                    }
                  });
                },
              ),
              if (totalItems > 0)
                Positioned(
                  right: 8,
                  top: 8,
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
                      '$totalItems',
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
        ],
      ),
      body: Column(
        children: [
          if (_isSearching) _buildAnimatedSearchBar(),
          Expanded(
            child: Stack(
              children: [
                FutureBuilder<List<Product>>(
                  future: _productsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1976D2),
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Error loading products',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _productsFuture = _fetchAllProducts();
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1976D2),
                                side: const BorderSide(
                                  color: Color(0xFF1976D2),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else if (_filteredProducts.isNotEmpty) {
                      return GridView.builder(
                        padding: EdgeInsets.only(
                          left: 12,
                          right: 12,
                          top: 12,
                          bottom: totalItems > 0 ? 100 : 12,
                        ),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.4,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = _filteredProducts[index];
                          return _buildProductCard(product);
                        },
                      );
                    } else {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isSearching
                                  ? 'No products found'
                                  : 'No Products Found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isSearching
                                  ? 'Try different keywords'
                                  : 'Try searching or browsing categories',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
                if (totalItems > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _buildCartBar(totalItems, _calculateCartTotal()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartBar(int totalItems, double totalPrice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  CartScreen(cartItems: _cartItems, products: _allProducts),
            ),
          ).then((result) {
            if (result is Map) {
              setState(() {
                _cartItems = Map<int, int>.from(result);
              });
              _saveCartToStorage();
            }
          });
        },
        child: Row(
          children: [
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
                  if (totalItems > 0)
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
                          '$totalItems',
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '₹${totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$totalItems item${totalItems > 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'View cart',
                style: TextStyle(
                  color: Color(0xFF1976D2),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final quantity = _cartItems[int.parse(product.id)] ?? 0;

    return GestureDetector(
      onTap: () {
        Navigator.push<Map<int, int>>(
          context,
          MaterialPageRoute(
            builder: (context) => product_details.ProductDetailsScreen(
              product: product as dynamic,
              cartItems: _cartItems,
            ),
          ),
        ).then((result) {
          if (result != null) {
            setState(() {
              _cartItems = Map<int, int>.from(result);
            });
            _saveCartToStorage();
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: Container(
                      color: Colors.blue[50],
                      width: double.infinity,
                      child: _ImageLoaderWidget(
                        imageUrlVariants: _generateImageUrls(product),
                        fit: BoxFit.cover,
                        m1Code: _m1Code,
                      ),
                    ),
                  ),
                  if (product.discountPercent > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.discountPercent}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'In Stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.brand,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${product.rating}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '₹${product.salePrice}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                            if (product.originalPrice > product.salePrice)
                              Text(
                                '₹${product.originalPrice}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            const SizedBox(height: 10),
                            AnimatedCrossFade(
                              firstChild: SizedBox(
                                width: 40,
                                height: 40,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.8, end: 1.0)
                                      .animate(
                                        CurvedAnimation(
                                          parent: _getOrCreateButtonAnimation(
                                            int.parse(product.id),
                                          ),
                                          curve: Curves.elasticOut,
                                        ),
                                      ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _cartItems[int.parse(product.id)] = 1;
                                        _getOrCreateButtonAnimation(
                                          int.parse(product.id),
                                        ).forward(from: 0.0);
                                      });
                                      _saveCartToStorage();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1976D2),
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Icon(Icons.add, size: 18),
                                  ),
                                ),
                              ),
                              secondChild: SizedBox(
                                width: 120,
                                height: 40,
                                child: SlideTransition(
                                  position:
                                      Tween<Offset>(
                                        begin: const Offset(0.3, 0.0),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: _getOrCreateButtonAnimation(
                                            int.parse(product.id),
                                          ),
                                          curve: Curves.easeOutCubic,
                                        ),
                                      ),
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.8, end: 1.0)
                                        .animate(
                                          CurvedAnimation(
                                            parent: _getOrCreateButtonAnimation(
                                              int.parse(product.id),
                                            ),
                                            curve: Curves.elasticOut,
                                          ),
                                        ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF1976D2),
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  if (quantity > 1) {
                                                    _cartItems[int.parse(
                                                          product.id,
                                                        )] =
                                                        quantity - 1;
                                                  } else {
                                                    _cartItems.remove(
                                                      int.parse(product.id),
                                                    );
                                                  }
                                                });
                                                _saveCartToStorage();
                                              },
                                              child: const Center(
                                                child: Icon(
                                                  Icons.remove,
                                                  size: 14,
                                                  color: Color(0xFF1976D2),
                                                ),
                                              ),
                                            ),
                                          ),
                                          ScaleTransition(
                                            scale:
                                                Tween<double>(
                                                  begin: 0.9,
                                                  end: 1.1,
                                                ).animate(
                                                  CurvedAnimation(
                                                    parent:
                                                        _getOrCreateButtonAnimation(
                                                          int.parse(product.id),
                                                        ),
                                                    curve: Curves.elasticInOut,
                                                  ),
                                                ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                              child: Text(
                                                '$quantity',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF1976D2),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _cartItems[int.parse(
                                                        product.id,
                                                      )] =
                                                      quantity + 1;
                                                  _getOrCreateButtonAnimation(
                                                    int.parse(product.id),
                                                  ).forward(from: 0.0);
                                                });
                                                _saveCartToStorage();
                                              },
                                              child: const Center(
                                                child: Icon(
                                                  Icons.add,
                                                  size: 14,
                                                  color: Color(0xFF1976D2),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              crossFadeState: quantity == 0
                                  ? CrossFadeState.showFirst
                                  : CrossFadeState.showSecond,
                              duration: const Duration(milliseconds: 300),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
