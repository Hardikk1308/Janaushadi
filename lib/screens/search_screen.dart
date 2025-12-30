import 'package:flutter/material.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'package:jan_aushadi/models/Product_model.dart' as product_model;
import 'package:jan_aushadi/screens/product_details_screen.dart';
import 'package:jan_aushadi/widgets/secure_image_widget.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

typedef Product = product_model.Product;

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<String> _trendingSearches = [
    'DIGI-CURE',
    'JNT-COMF',
    'LIV-FIX',
    'PARACETAMOL DY 30 ML',
  ];

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  Map<int, int> _cartItems = {}; // product_id -> quantity

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadInitialData() async {
    try {
      await Future.wait([_fetchProducts(), _loadCartFromStorage()]);
    } catch (e) {
      print('Error loading initial data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchProducts() async {
    try {
      final dio = Dio();
      print('🔍 Fetching products for search...');

      final response = await dio
          .post(
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_all_product',
            data: {'cat_id': '', 'subcat_id': ''},
            options: Options(contentType: 'application/x-www-form-urlencoded'),
          )
          .timeout(const Duration(seconds: 30));

      print('✅ Products API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }

        print('📦 Response data: ${data['response']}');

        if (data['response'] == 'success' && data['data'] is List) {
          final products = (data['data'] as List)
              .map((item) => Product.fromJson(item))
              .toList();
          products.sort((a, b) => a.name.compareTo(b.name));

          print('✅ Loaded ${products.length} products');

          if (mounted) {
            setState(() {
              _allProducts = products;
              _filteredProducts = products;
            });
          }
        } else {
          print('❌ Unexpected response format');
        }
      } else {
        print('❌ API returned status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error fetching products: $e');
      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadCartFromStorage() async {
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
      }
    } catch (e) {
      // Ignore for now
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredProducts = _allProducts;
      } else {
        _filteredProducts = _allProducts.where((product) {
          final name = product.name.toLowerCase();
          final brand = product.brand.toLowerCase();
          return name.contains(query) || brand.contains(query);
        }).toList();
      }
    });
  }


  void _navigateToProductDetails(Product product) async {
    // Add a subtle haptic feedback
    // HapticFeedback.lightImpact(); // Uncomment if you want haptic feedback

    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ProductDetailsScreen(product: product, cartItems: _cartItems),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

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
    );

    // Reload cart items when returning from product details
    await _loadCartFromStorage();
    if (mounted) {
      setState(() {});
    }
  }


  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _searchController,
                  builder: (context, value, child) {
                    return TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search for medicines',
                        border: InputBorder.none,
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged();
                                },
                              )
                            : null,
                      ),
                      textInputAction: TextInputAction.search,
                    );
                  },
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, child) {
                if (value.text.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Trending searches',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _trendingSearches
                              .map(
                                (item) => ActionChip(
                                  label: Text(item),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.text = item;
                                    });
                                    // Trigger search immediately
                                    _onSearchChanged();
                                  },
                                  backgroundColor: const Color(0xFFF5F5F5),
                                  labelStyle: const TextStyle(
                                    fontSize: 13,
                                    color: Colors.black38,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    '${_filteredProducts.length} result${_filteredProducts.length != 1 ? 's' : ''} found',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading products...'),
                        ],
                      ),
                    )
                  : ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, child) {
                        // Show popular products when search is empty
                        if (value.text.isEmpty) {
                          return _allProducts.isEmpty
                              ? Center(
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
                                        'No products available',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _allProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = _allProducts[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: ListTile(
                                        onTap: () =>
                                            _navigateToProductDetails(product),
                                        leading: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            color: Colors.grey[100],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: product.imageUrl.isNotEmpty
                                                ? SecureImageWidget(
                                                    imageUrls: [
                                                      'https://www.onlineaushadhi.in/myadmin/uploads/product/${product.imageUrl}',
                                                      'https://webdevelopercg.com/janaushadhi/myadmin/uploads/product/${product.imageUrl}',
                                                      'https://webdevelopercg.com/janaushadhi/uploads/product/${product.imageUrl}',
                                                      'https://webdevelopercg.com/janaushadhi/uploads/product_images/${product.imageUrl}',
                                                      'https://webdevelopercg.com/janaushadhi/public/uploads/product/${product.imageUrl}',
                                                      'https://webdevelopercg.com/janaushadhi/assets/product/${product.imageUrl}',
                                                    ],
                                                    width: 50,
                                                    height: 50,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Icon(
                                                    Icons.local_pharmacy,
                                                    color: Color(
                                                      AppConstants
                                                          .primaryColorValue,
                                                    ),
                                                    size: 24,
                                                  ),
                                          ),
                                        ),
                                        title: Text(
                                          product.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (product.brand.isNotEmpty)
                                              Text(
                                                product.brand,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  '₹${product.salePrice.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    color: Color(
                                                      AppConstants
                                                          .primaryColorValue,
                                                    ),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                if (product.originalPrice >
                                                    product.salePrice) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '₹${product.originalPrice.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                      fontSize: 12,
                                                      decoration: TextDecoration
                                                          .lineThrough,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                        trailing:
                                            _cartItems.containsKey(
                                              int.parse(product.id),
                                            )
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Color(
                                                    AppConstants
                                                        .primaryColorValue,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.shopping_cart,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${_cartItems[int.parse(product.id)]}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            : const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                        contentPadding: const EdgeInsets.all(
                                          12,
                                        ),
                                      ),
                                    );
                                  },
                                );
                        }

                        // Show search results when text is entered
                        if (_filteredProducts.isEmpty &&
                            value.text.isNotEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No products found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Try searching with different keywords',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                onTap: () => _navigateToProductDetails(product),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: Colors.grey[100],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: product.imageUrl.isNotEmpty
                                        ? SecureImageWidget(
                                            imageUrls: [
                                              'https://www.onlineaushadhi.in/myadmin/uploads/product/${product.imageUrl}',
                                              'https://webdevelopercg.com/janaushadhi/myadmin/uploads/product/${product.imageUrl}',
                                              'https://webdevelopercg.com/janaushadhi/uploads/product/${product.imageUrl}',
                                              'https://webdevelopercg.com/janaushadhi/uploads/product_images/${product.imageUrl}',
                                              'https://webdevelopercg.com/janaushadhi/public/uploads/product/${product.imageUrl}',
                                              'https://webdevelopercg.com/janaushadhi/assets/product/${product.imageUrl}',
                                            ],
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                          )
                                        : Icon(
                                            Icons.local_pharmacy,
                                            color: Color(
                                              AppConstants.primaryColorValue,
                                            ),
                                            size: 24,
                                          ),
                                  ),
                                ),
                                title: Text(
                                  product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (product.brand.isNotEmpty)
                                      Text(
                                        product.brand,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '₹${product.salePrice.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            color: Color(
                                              AppConstants.primaryColorValue,
                                            ),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (product.originalPrice >
                                            product.salePrice) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            '₹${product.originalPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing:
                                    _cartItems.containsKey(
                                      int.parse(product.id),
                                    )
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Color(
                                            AppConstants.primaryColorValue,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.shopping_cart,
                                              color: Colors.white,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${_cartItems[int.parse(product.id)]}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                contentPadding: const EdgeInsets.all(12),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
