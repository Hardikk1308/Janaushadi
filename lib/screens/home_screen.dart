// import 'package:flutter/material.dart';
// import 'package:dio/dio.dart';
// import 'dart:convert';
// import 'package:jan_aushadi/services/image_service.dart';
// import 'package:jan_aushadi/constants/app_constants.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   List<Map<String, dynamic>> _featuredProducts = [];
//   bool _isLoading = true;
//   List<Map<String, dynamic>> _offersSections = [];

//   @override
//   void initState() {
//     super.initState();
//     _fetchFeaturedProducts();
//     _loadOffers();
//   }

//   void _loadOffers() {
//     _offersSections = [
//       {
//         'M1_CODE': '231',
//         'M1_TYPE': 'Offers',
//         'M1_PM': 'Product',
//         'M1_NAME': '40 % Offer',
//         'M1_TXT1': '40 % Offer Discount',
//         'M1_CR': 'Horizontal',
//         'M1_DC1': 'b6bf54965ccfc11839158f5cc472dca0.webp',
//         'items': [
//           {
//             'product_id': '184',
//             'product_name': 'Paracetamol Dy 30 ML',
//             'mrp': '185',
//             'sale_price': '170',
//             'image': {
//               'M1_DC1': 'a92867d6dd2b3c3829579ea88f5c761e.jpg',
//               'M1_DC2': '7653541d2ca836677fc89eed0b20178f.jpg',
//               'M1_DC3': 'e7c765e5337ea4f11001c387095efda3.jpg',
//             },
//           },
//           {
//             'product_id': '183',
//             'product_name': 'Sinarest AF 15 ML',
//             'mrp': '100',
//             'sale_price': '95',
//             'image': {
//               'M1_DC1': '609f07c259778c0652a6bfb0328252d9.png',
//               'M1_DC2': '1a2e2461581ebf870d36da83ff875be6.png',
//             },
//           },
//         ],
//       },
//       {
//         'M1_CODE': '230',
//         'M1_TYPE': 'Offers',
//         'M1_PM': 'Category',
//         'M1_NAME': '20 % Off',
//         'M1_TXT1': '20 Discount Flat Offer',
//         'M1_CR': 'Horizontal',
//         'M1_DC1': 'e697683e3cb5dae77ec9d7da0dc18e61.png',
//         'items': [
//           {
//             'M1_CODE': '69',
//             'M1_NAME': 'Digestive Aid',
//             'M1_SHNA': 'digestive-aid',
//             'M1_DC1': 'e9a030e2b08a18a2def9e04a9dff579f.webp',
//           },
//           {
//             'M1_CODE': '68',
//             'M1_NAME': 'Liver Care',
//             'M1_SHNA': 'liver-care',
//             'M1_DC1': '77b35018415699d03e88ebadf2c8294b.webp',
//           },
//         ],
//       },
//     ];
//   }

//   Future<void> _fetchFeaturedProducts() async {
//     try {
//       final dio = Dio();
//       final response = await dio.post(
//         'https://webdevelopercg.com/janaushadhi/myadmin/UserApis/get_products',
//         data: {'limit': '10'}, // Fetch only 10 featured products for homepage
//         options: Options(contentType: Headers.formUrlEncodedContentType),
//       );

//       if (response.statusCode == 200) {
//         var responseData = response.data;
//         if (responseData is String) {
//           responseData = jsonDecode(responseData);
//         }

//         if (responseData['response'] == 'success') {
//           setState(() {
//             _featuredProducts = List<Map<String, dynamic>>.from(
//               responseData['data'] ?? [],
//             );
//             _isLoading = false;
//           });
//         }
//       }
//     } catch (e) {
//       print('Error fetching featured products: $e');
//       setState(() {
//         _isLoading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F9FA),
//       body: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Header Section
//             Container(
//               padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     AppConstants.primaryColor,
//                     AppConstants.primaryColor.withOpacity(0.8),
//                   ],
//                 ),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Welcome to Jan Aushadhi',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 24,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(height: 8),
//                   const Text(
//                     'Quality medicines at affordable prices',
//                     style: TextStyle(color: Colors.white70, fontSize: 16),
//                   ),
//                   const SizedBox(height: 20),
//                   // Search Bar
//                   Container(
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     child: TextField(
//                       decoration: InputDecoration(
//                         hintText: 'Search medicines...',
//                         prefixIcon: const Icon(Icons.search),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide.none,
//                         ),
//                         filled: true,
//                         fillColor: Colors.white,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 24),

//             // Featured Products Section
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   const Text(
//                     'Featured Products',
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.black87,
//                     ),
//                   ),
//                   TextButton(
//                     onPressed: () {
//                       Navigator.pushNamed(context, '/all_products');
//                     },
//                     child: const Text('View All'),
//                   ),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Products Grid
//             _isLoading
//                 ? const Center(
//                     child: Padding(
//                       padding: EdgeInsets.all(32),
//                       child: CircularProgressIndicator(),
//                     ),
//                   )
//                 : _featuredProducts.isEmpty
//                 ? const Center(
//                     child: Padding(
//                       padding: EdgeInsets.all(32),
//                       child: Text(
//                         'No products available',
//                         style: TextStyle(color: Colors.grey),
//                       ),
//                     ),
//                   )
//                 : GridView.builder(
//                     shrinkWrap: true,
//                     physics: const NeverScrollableScrollPhysics(),
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     gridDelegate:
//                         const SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 2,
//                           childAspectRatio: 0.75,
//                           crossAxisSpacing: 12,
//                           mainAxisSpacing: 12,
//                         ),
//                     itemCount: _featuredProducts.length,
//                     itemBuilder: (context, index) {
//                       final product = _featuredProducts[index];
//                       return _buildProductCard(product);
//                     },
//                   ),

//             const SizedBox(height: 24),

//             _buildOffersSection(),

//             const SizedBox(height: 32),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildOffersSection() {
//     if (_offersSections.isEmpty) {
//       return const SizedBox.shrink();
//     }

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: _offersSections.map((section) {
//         final String type = section['M1_PM']?.toString() ?? '';
//         final String heading = section['M1_NAME']?.toString() ?? '';
//         final String direction = section['M1_CR']?.toString() ?? 'Horizontal';
//         final List<dynamic> items = section['items'] as List<dynamic>? ?? [];

//         final bool isHorizontal = direction.toLowerCase() == 'horizontal';

//         return Padding(
//           padding: const EdgeInsets.only(bottom: 24),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16),
//                 child: Text(
//                   heading,
//                   style: const TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.black87,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 12),
//               SizedBox(
//                 height: isHorizontal ? 200 : null,
//                 child: isHorizontal
//                     ? SingleChildScrollView(
//                         scrollDirection: Axis.horizontal,
//                         padding: const EdgeInsets.symmetric(horizontal: 16),
//                         child: Row(
//                           children: items
//                               .map<Widget>((item) => _buildOfferItemCard(
//                                   type, item as Map<String, dynamic>))
//                               .toList(),
//                         ),
//                       )
//                     : Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 16),
//                         child: Column(
//                           children: items
//                               .map<Widget>((item) => _buildOfferItemCard(
//                                   type, item as Map<String, dynamic>))
//                               .toList(),
//                         ),
//                       ),
//               ),
//             ],
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildOfferItemCard(String type, Map<String, dynamic> item) {
//     if (type.toLowerCase() == 'product') {
//       final String name = item['product_name']?.toString() ?? '';
//       final double mrp =
//           double.tryParse(item['mrp']?.toString() ?? '0') ?? 0;
//       final double salePrice =
//           double.tryParse(item['sale_price']?.toString() ?? '0') ?? 0;
//       final Map<String, dynamic> image =
//           item['image'] as Map<String, dynamic>? ?? {};
//       final String imagePath = image['M1_DC1']?.toString() ?? '';

//       return Container(
//         width: 150,
//         margin: const EdgeInsets.only(right: 12, bottom: 12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 6,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             ImageService.buildProductImage(
//               imageUrl: imagePath,
//               width: double.infinity,
//               height: 90,
//               fit: BoxFit.cover,
//             ),
//             const SizedBox(height: 8),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 8),
//               child: Text(
//                 name,
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//             const Spacer(),
//             Padding(
//               padding:
//                   const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//               child: Row(
//                 children: [
//                   Text(
//                     '₹${salePrice.toStringAsFixed(0)}',
//                     style: const TextStyle(
//                       fontSize: 14,
//                       fontWeight: FontWeight.bold,
//                       color: Colors.green,
//                     ),
//                   ),
//                   const SizedBox(width: 6),
//                   if (mrp > salePrice)
//                     Text(
//                       '₹${mrp.toStringAsFixed(0)}',
//                       style: const TextStyle(
//                         fontSize: 11,
//                         color: Colors.grey,
//                         decoration: TextDecoration.lineThrough,
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       );
//     } else {
//       final String name = item['M1_NAME']?.toString() ?? '';
//       final String imagePath = item['M1_DC1']?.toString() ?? '';

//       return Container(
//         width: 130,
//         margin: const EdgeInsets.only(right: 12, bottom: 12),
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 6,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Column(
//           children: [
//             ImageService.buildProductImage(
//               imageUrl: imagePath,
//               width: double.infinity,
//               height: 80,
//               fit: BoxFit.cover,
//             ),
//             const SizedBox(height: 8),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 8),
//               child: Text(
//                 name,
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 13,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ),
//             const SizedBox(height: 8),
//           ],
//         ),
//       );
//     }
//   }

//   Widget _buildProductCard(Map<String, dynamic> product) {
//     final name = product['M1_NAME']?.toString() ?? 'Unknown Product';
//     final price = double.tryParse(product['M1_RATE']?.toString() ?? '0') ?? 0.0;
//     final imageUrl = product['M1_IMAGE']?.toString();

//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.05),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: InkWell(
//         onTap: () {
//           Navigator.pushNamed(context, '/product_details', arguments: product);
//         },
//         borderRadius: BorderRadius.circular(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Product Image
//             ImageService.buildGridProductImage(imageUrl),

//             const SizedBox(height: 12),

//             // Product Details
//             Expanded(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       name,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: Colors.black87,
//                       ),
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                     ),
//                     const Spacer(),
//                     Text(
//                       '₹${price.toStringAsFixed(2)}',
//                       style: TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                         color: AppConstants.primaryColor,
//                       ),
//                     ),
//                     const SizedBox(height: 8),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
