import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:jan_aushadi/widgets/secure_image_widget.dart';
import 'package:jan_aushadi/models/Product_model.dart' as product_model;
import 'package:jan_aushadi/screens/product_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jan_aushadi/services/cart_service.dart';

typedef Product = product_model.Product;

List<String> _getCategoryImageUrls(String? imageFilename) {
  if (imageFilename == null || imageFilename.isEmpty) {
    print('⚠️ Category image filename is null or empty');
    return [];
  }

  if (imageFilename.startsWith('http')) {
    print('✅ Category image is full URL: $imageFilename');
    return [imageFilename];
  }

  print('🔍 Trying multiple paths for category image: $imageFilename');

  // Try multiple possible paths for category images
  return [
    'https://webdevelopercg.com/janaushadhi/myadmin/uploads/category/$imageFilename',
    'https://webdevelopercg.com/janaushadhi/uploads/category/$imageFilename',
    'https://webdevelopercg.com/janaushadhi/uploads/categories/$imageFilename',
    'https://webdevelopercg.com/janaushadhi/public/uploads/category/$imageFilename',
    'https://webdevelopercg.com/janaushadhi/assets/category/$imageFilename',
    'https://webdevelopercg.com/janaushadhi/myadmin/uploads/categories/$imageFilename',
  ];
}

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late Future<List<MasterCategory>> _categoriesFuture;
  bool _initialized = false;
  int _selectedCategoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCategories();
  }

  Future<void> _initializeCategories() async {
    setState(() {
      _categoriesFuture = _fetchCategories();
      _initialized = true;
    });
  }

  Future<List<MasterCategory>> _fetchCategories() async {
    try {
      final dio = Dio();
      // Use a fixed valid category code (69 = Digestive Aid)
      final categoryCode = '69';
      final response = await dio
          .post(
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_master_data',
            data: {'M1_TYPE': 'Category', 'M1_CODE': categoryCode},
            options: Options(contentType: 'application/x-www-form-urlencoded'),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        var data = response.data;

        // Parse JSON string if response.data is a string
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success' && data['data'] is List) {
          final categories = (data['data'] as List)
              .map((item) => MasterCategory.fromJson(item))
              .toList();

          // Sort by category name
          categories.sort((a, b) => a.name.compareTo(b.name));

          return categories;
        }
      }
      throw Exception('Failed to load categories');
    } catch (e) {
      print('Error fetching categories: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [],
      ),
      body: !_initialized
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1976D2)),
            )
          : FutureBuilder<List<MasterCategory>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1976D2)),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Data Not Found'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _categoriesFuture = _fetchCategories();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.category_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No categories available',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _categoriesFuture = _fetchCategories();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final categories = snapshot.data!;
                return Row(
                  children: [
                    // Left Sidebar - Categories List
                    Container(
                      width: 120,
                      color: Colors.grey[50],
                      child: ListView.builder(
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = _selectedCategoryIndex == index;
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCategoryIndex = index;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue[50]
                                    : Colors.transparent,
                                border: isSelected
                                    ? Border(
                                        right: BorderSide(
                                          color: const Color(0xFF1976D2),
                                          width: 3,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child:
                                        category.imageUrl != null &&
                                            category.imageUrl!.isNotEmpty
                                        ? SecureImageWidget(
                                            imageUrls: _getCategoryImageUrls(
                                              category.imageUrl,
                                            ),
                                            width: 50,
                                            height: 50,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.blue[50],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.category,
                                              size: 24,
                                              color: Color(0xFF1976D2),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    category.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF1976D2)
                                          : Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Right Content - Products Grid
                    Expanded(
                      child: CategoryProductsContent(
                        category: categories[_selectedCategoryIndex],
                        categoryId: categories[_selectedCategoryIndex].id,
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class SubCategoriesScreen extends StatefulWidget {
  final MasterCategory category;
  final String m1Code;

  const SubCategoriesScreen({
    super.key,
    required this.category,
    required this.m1Code,
  });

  @override
  State<SubCategoriesScreen> createState() => _SubCategoriesScreenState();
}

class _SubCategoriesScreenState extends State<SubCategoriesScreen> {
  late Future<List<MasterCategory>> _subCategoriesFuture;

  @override
  void initState() {
    super.initState();
    _subCategoriesFuture = _fetchSubCategories();
  }

  Future<List<MasterCategory>> _fetchSubCategories() async {
    try {
      final dio = Dio();
      print(
        'DEBUG: SubCategoriesScreen fetching with M1_CODE: ${widget.m1Code}',
      );

      final response = await dio
          .post(
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_master_by_id',
            data: {'M1_TYPE': 'SubCategory', 'M1_CODE': widget.m1Code},
            options: Options(
              contentType: 'application/x-www-form-urlencoded',
              validateStatus: (status) =>
                  status! < 500, // Accept all status codes < 500
            ),
          )
          .timeout(const Duration(seconds: 30));

      print(
        'DEBUG: SubCategoriesScreen response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        var data = response.data;

        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success' && data['data'] is List) {
          final subCategories = (data['data'] as List)
              .map((item) => MasterCategory.fromJson(item))
              .toList();

          subCategories.sort((a, b) => a.name.compareTo(b.name));
          return subCategories;
        } else if (data['response'] == 'error' ||
            (data['data'] is List && (data['data'] as List).isEmpty)) {
          print('DEBUG: No subcategories found for M1_CODE: ${widget.m1Code}');
          return [];
        }
      } else if (response.statusCode == 401) {
        print(
          'DEBUG: 401 error - No subcategories available for M1_CODE: ${widget.m1Code}',
        );
        return [];
      }

      return [];
    } catch (e) {
      print('Error fetching subcategories: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.category.name),
        backgroundColor: const Color(0xFF1976D2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<MasterCategory>>(
        future: _subCategoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1976D2)),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Data Not Found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _subCategoriesFuture = _fetchSubCategories();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No subcategories found'));
          }

          final subCategories = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: subCategories.length,
            itemBuilder: (context, index) {
              final subCategory = subCategories[index];
              return _buildSubCategoryCard(subCategory);
            },
          );
        },
      ),
    );
  }

  Widget _buildSubCategoryCard(MasterCategory subCategory) {
    return GestureDetector(
      onTap: () {
        // Navigate to all products screen with subcategory filter
        Navigator.pushNamed(
          context,
          '/all_products',
          arguments: {
            'categoryId': subCategory.id,
            'categoryName': subCategory.name,
          },
        );
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Container(
                  color: Colors.blue[50],
                  child:
                      subCategory.imageUrl != null &&
                          subCategory.imageUrl!.isNotEmpty
                      ? SizedBox.expand(
                          child: SecureImageWidget(
                            imageUrls: _getCategoryImageUrls(
                              subCategory.imageUrl,
                            ),
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(
                          Icons.category,
                          size: 48,
                          color: Color(0xFF1976D2),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                subCategory.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryProductsContent extends StatefulWidget {
  final MasterCategory category;
  final String categoryId;

  const CategoryProductsContent({
    super.key,
    required this.category,
    required this.categoryId,
  });

  @override
  State<CategoryProductsContent> createState() =>
      _CategoryProductsContentState();
}

class _CategoryProductsContentState extends State<CategoryProductsContent> {
  late Future<List<CategoryProduct>> _productsFuture;
  late Map<int, int> _cartItems;

  @override
  void initState() {
    super.initState();
    _cartItems = {};
    _productsFuture = _fetchCategoryProducts();
  }

  @override
  void didUpdateWidget(CategoryProductsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) {
      print(
        '📂 Category changed from ${oldWidget.categoryId} to ${widget.categoryId}',
      );
      setState(() {
        _productsFuture = _fetchCategoryProducts();
      });
    }
  }

  Future<List<CategoryProduct>> _fetchCategoryProducts() async {
    try {
      final dio = Dio();
      print('📦 Fetching products for category: ${widget.categoryId}');

      final response = await dio
          .post(
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_all_product',
            data: {'cat_id': widget.categoryId, 'subcat_id': ''},
            options: Options(contentType: 'application/x-www-form-urlencoded'),
          )
          .timeout(const Duration(seconds: 30));

      print('✅ Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success' && data['data'] is List) {
          final products = (data['data'] as List)
              .map((item) => CategoryProduct.fromJson(item))
              .toList();
          print('✅ Fetched ${products.length} products');
          return products;
        }
      }
      return [];
    } catch (e) {
      print('❌ Error fetching products: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.category.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<CategoryProduct>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1976D2),
                      ),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        const Text('Failed to load products'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _productsFuture = _fetchCategoryProducts();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final products = snapshot.data!;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildProductCard(product);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<String> _generateProductImageUrls(String imageFilename) {
    if (imageFilename.isEmpty) return [];

    if (imageFilename.startsWith('http')) {
      return [imageFilename];
    }

    String filename = imageFilename;
    if (filename.contains('/')) {
      filename = filename.split('/').last;
    }

    return [
      'https://webdevelopercg.com/janaushadhi/myadmin/uploads/product/$filename',
      'https://webdevelopercg.com/janaushadhi/uploads/product/$filename',
      'https://webdevelopercg.com/janaushadhi/uploads/product_images/$filename',
      'https://webdevelopercg.com/janaushadhi/public/uploads/product/$filename',
    ];
  }

  Future<void> _saveCartToSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = jsonEncode(
        _cartItems.map((key, value) => MapEntry(key.toString(), value)),
      );
      await prefs.setString('cart_items', cartJson);
      print('✅ Cart saved to SharedPreferences from Categories: $_cartItems');

      // Also update CartService to notify listeners
      for (final entry in _cartItems.entries) {
        await CartService.addItem(entry.key.toString(), entry.value);
      }
    } catch (e) {
      print('❌ Error saving cart to SharedPreferences: $e');
    }
  }

  Widget _buildProductCard(CategoryProduct product) {
    final productId = int.parse(product.id);
    final isInCart = _cartItems.containsKey(productId);
    final quantity = _cartItems[productId] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              final productModel = product_model.Product(
                id: product.id,
                name: product.name,
                brand: product.brandName,
                originalPrice: double.tryParse(product.mrpPrice) ?? 0,
                salePrice: double.tryParse(product.salePrice) ?? 0,
                rating: 0,
                discountPercent: int.tryParse(product.discountPercent) ?? 0,
                imageUrl: product.imageUrl,
                description: product.genericName,
                composition: product.composition,
                hsn_code: product.hsnCode,
                unit: '',
                description1: product.description1,
                description2: product.description2,
                description3: product.description3,
                description4: product.description4,
                description5: product.description5,
                description6: product.description6,
                description7: product.description7,
              );

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailsScreen(
                    product: productModel,
                    cartItems: _cartItems,
                  ),
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
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      _generateProductImageUrls(product.imageUrl).first,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.medical_information,
                          color: Colors.grey[400],
                          size: 30,
                        );
                      },
                    )
                  : Icon(
                      Icons.medical_information,
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
                GestureDetector(
                  onTap: () {
                    final productModel = product_model.Product(
                      id: product.id,
                      name: product.name,
                      brand: product.brandName,
                      originalPrice: double.tryParse(product.mrpPrice) ?? 0,
                      salePrice: double.tryParse(product.salePrice) ?? 0,
                      rating: 0,
                      discountPercent:
                          int.tryParse(product.discountPercent) ?? 0,
                      imageUrl: product.imageUrl,
                      description: product.genericName,
                      composition: product.composition,
                      hsn_code: product.hsnCode,
                      unit: '',
                      description1: product.description1,
                      description2: product.description2,
                      description3: product.description3,
                      description4: product.description4,
                      description5: product.description5,
                      description6: product.description6,
                      description7: product.description7,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailsScreen(
                          product: productModel,
                          cartItems: _cartItems,
                        ),
                      ),
                    ).then((result) {
                      if (result is Map<int, int>) {
                        setState(() {
                          _cartItems = result;
                        });
                      }
                    });
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.genericName,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '₹${product.salePrice}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (product.mrpPrice != product.salePrice)
                            Flexible(
                              child: Text(
                                '₹${product.mrpPrice}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  decoration: TextDecoration.lineThrough,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ADD Button or Quantity Selector
                if (!isInCart)
                  GestureDetector(
                    onTap: () async {
                      _cartItems[productId] = 1;
                      await _saveCartToSharedPreferences();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product.name} added to cart'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text(
                            'ADD',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF1976D2),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () async {
                            if (quantity > 1) {
                              _cartItems[productId] = quantity - 1;
                            } else {
                              _cartItems.remove(productId);
                            }
                            await _saveCartToSharedPreferences();
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: const Icon(
                              Icons.remove,
                              size: 14,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            _cartItems[productId] = quantity + 1;
                            await _saveCartToSharedPreferences();
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 14,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryProduct {
  final String id;
  final String name;
  final String genericName;
  final String salePrice;
  final String mrpPrice;
  final String imageUrl;
  final String brandName;
  final String hsnCode;
  final String composition;
  final String erpDate;
  final String expiryDate;
  final String discountPercent;
  final String description1;
  final String description2;
  final String description3;
  final String description4;
  final String description5;
  final String description6;
  final String description7;

  CategoryProduct({
    required this.id,
    required this.name,
    required this.genericName,
    required this.salePrice,
    required this.mrpPrice,
    required this.imageUrl,
    required this.brandName,
    required this.hsnCode,
    required this.composition,
    required this.erpDate,
    required this.expiryDate,
    required this.discountPercent,
    required this.description1,
    required this.description2,
    required this.description3,
    required this.description4,
    required this.description5,
    required this.description6,
    required this.description7,
  });

  factory CategoryProduct.fromJson(Map<String, dynamic> json) {
    // Extract image from nested object
    String imageUrl = '';
    if (json['image'] is Map) {
      final imageMap = json['image'] as Map<String, dynamic>;
      imageUrl = imageMap['M1_DC1']?.toString() ?? '';
    } else if (json['image'] is String) {
      imageUrl = json['image']?.toString() ?? '';
    }

    return CategoryProduct(
      id: json['product_id']?.toString() ?? '',
      name: json['product_name']?.toString() ?? '',
      genericName: json['generic_name']?.toString() ?? '',
      salePrice: json['sale_price']?.toString() ?? '0',
      mrpPrice: json['mrp']?.toString() ?? '0',
      imageUrl: imageUrl,
      brandName: json['brand_name']?.toString() ?? '',
      hsnCode: json['hsn_code']?.toString() ?? '',
      composition: json['composition']?.toString() ?? '',
      erpDate: json['erp_date']?.toString() ?? '',
      expiryDate: json['expiry_date']?.toString() ?? '',
      discountPercent: json['discount_percent']?.toString() ?? '0',
      description1: json['description1']?.toString() ?? '',
      description2: json['description2']?.toString() ?? '',
      description3: json['description3']?.toString() ?? '',
      description4: json['description4']?.toString() ?? '',
      description5: json['description5']?.toString() ?? '',
      description6: json['description6']?.toString() ?? '',
      description7: json['description7']?.toString() ?? '',
    );
  }
}

class MasterCategory {
  final String id;
  final String name;
  final String? imageUrl;
  final String? description;

  MasterCategory({
    required this.id,
    required this.name,
    this.imageUrl,
    this.description,
  });

  factory MasterCategory.fromJson(Map<String, dynamic> json) {
    return MasterCategory(
      id: json['M1_CODE']?.toString() ?? '',
      name: json['M1_NAME']?.toString() ?? '',
      imageUrl: json['M1_DC1']?.toString(),
      description: json['M1_SHNA']?.toString(),
    );
  }
}

class SubCategoriesContent extends StatefulWidget {
  final MasterCategory category;
  final String m1Code;

  const SubCategoriesContent({
    super.key,
    required this.category,
    required this.m1Code,
  });

  @override
  State<SubCategoriesContent> createState() => _SubCategoriesContentState();
}

class _SubCategoriesContentState extends State<SubCategoriesContent> {
  late Future<List<MasterCategory>> _subCategoriesFuture;

  @override
  void initState() {
    super.initState();
    _subCategoriesFuture = _fetchSubCategories();
  }

  @override
  void didUpdateWidget(SubCategoriesContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh subcategories when the category or m1Code changes
    if (oldWidget.m1Code != widget.m1Code ||
        oldWidget.category.id != widget.category.id) {
      print(
        'DEBUG: Category changed from ${oldWidget.m1Code} to ${widget.m1Code}',
      );
      setState(() {
        _subCategoriesFuture = _fetchSubCategories();
      });
    }
  }

  Future<List<MasterCategory>> _fetchSubCategories() async {
    try {
      final dio = Dio();
      print(
        'DEBUG: SubCategoriesContent fetching with M1_CODE: ${widget.m1Code}',
      );

      final response = await dio
          .post(
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_master_by_id',
            data: {'M1_TYPE': 'SubCategory', 'M1_CODE': widget.m1Code},
            options: Options(
              contentType: 'application/x-www-form-urlencoded',
              validateStatus: (status) =>
                  status! < 500, // Accept all status codes < 500
            ),
          )
          .timeout(const Duration(seconds: 30));

      print(
        'DEBUG: SubCategoriesContent response status: ${response.statusCode}',
      );

      if (response.statusCode == 200) {
        var data = response.data;

        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success' && data['data'] is List) {
          final subCategories = (data['data'] as List)
              .map((item) => MasterCategory.fromJson(item))
              .toList();

          subCategories.sort((a, b) => a.name.compareTo(b.name));
          return subCategories;
        } else if (data['response'] == 'error' ||
            (data['data'] is List && (data['data'] as List).isEmpty)) {
          // No subcategories found - return empty list instead of throwing error
          print('DEBUG: No subcategories found for M1_CODE: ${widget.m1Code}');
          return [];
        }
      } else if (response.statusCode == 401) {
        // Handle 401 - return empty list
        print(
          'DEBUG: 401 error - No subcategories available for M1_CODE: ${widget.m1Code}',
        );
        return [];
      }

      return [];
    } catch (e) {
      print('Error fetching subcategories: $e');
      // Return empty list instead of rethrowing
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MasterCategory>>(
      future: _subCategoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1976D2)),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No subcategories available\nfor ${widget.category.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.category_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 16),
                Text(
                  'No subcategories found\nfor ${widget.category.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        final subCategories = snapshot.data!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  widget.category.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: subCategories.length,
                itemBuilder: (context, index) {
                  final subCategory = subCategories[index];
                  return GestureDetector(
                    onTap: () {
                      // Navigate to all products screen with category filter
                      Navigator.pushNamed(
                        context,
                        '/all_products',
                        arguments: {
                          'categoryId': subCategory.id,
                          'categoryName': subCategory.name,
                        },
                      );
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                              child: Container(
                                color: Colors.blue[50],
                                child:
                                    subCategory.imageUrl != null &&
                                        subCategory.imageUrl!.isNotEmpty
                                    ? SizedBox.expand(
                                        child: SecureImageWidget(
                                          imageUrls: _getCategoryImageUrls(
                                            subCategory.imageUrl,
                                          ),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.category,
                                        size: 40,
                                        color: Color(0xFF1976D2),
                                      ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              subCategory.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
