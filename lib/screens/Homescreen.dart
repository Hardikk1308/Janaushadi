import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/services/location_service.dart';
import 'package:jan_aushadi/models/Product_model.dart' as product_model;
import 'package:jan_aushadi/widgets/location_picker.dart';
import 'package:jan_aushadi/screens/categories_screen.dart';
import 'package:jan_aushadi/screens/product_details_screen.dart' hide Product;
import 'package:jan_aushadi/screens/all_products_screen.dart' hide Product;
import 'package:jan_aushadi/screens/cart_screen.dart' hide Product;
import 'package:jan_aushadi/screens/manage_addresses_screen.dart';
import 'package:jan_aushadi/screens/search_screen.dart';
import 'package:path_provider/path_provider.dart';

typedef Product = product_model.Product;

String _getCategoryImageUrl(String? imageFilename) {
  if (imageFilename == null || imageFilename.isEmpty) {
    return '';
  }

  if (imageFilename.startsWith('http')) {
    return imageFilename;
  }

  return 'https://webdevelopercg.com/janaushadhi/myadmin/uploads/category/$imageFilename';
}

// Custom Page Route with slide animation
class SlidePageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;
  final Duration _transitionDuration;

  SlidePageRoute({
    required this.builder,
    Duration transitionDuration = const Duration(milliseconds: 500),
  }) : _transitionDuration = transitionDuration;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  String get barrierLabel => '';

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero)
          .animate(
            CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
          ),
      child: FadeTransition(opacity: animation, child: child),
    );
  }
}

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentCarouselIndex = 0;
  final ImagePicker _imagePicker = ImagePicker();
  late Future<List<MasterCategory>> _categoriesFuture;
  late Future<List<Product>> _productsFuture;
  late Future<List<OfferSection>> _offersFuture;
  String? _m1Code;
  bool _initialized = false;
  Map<int, int> _cartItems = {}; // product_id -> quantity
  late AnimationController _animationController;
  final Map<int, AnimationController> _buttonAnimations = {};

  // Location related variables
  String _currentCity = 'Loading...';
  bool _isLoadingLocation = true;

  // Selected address for prescription upload
  Address? _selectedAddress;
  static const String _selectedAddressKey = 'selected_prescription_address';

  // API Configuration
  static const String UPLOAD_ENDPOINT =
      'https://www.onlineaushadhi.in/myadmin/UserApis/upload_prescription';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    AuthService.debugPrintAllStoredData();
    _loadCartFromStorage();
    _loadSelectedAddress();
    _initializeLocation();
    _initializeCategories();
    _productsFuture = _fetchProducts();
    _offersFuture = _fetchOffers();
  }

  Future<void> _loadSelectedAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressJson = prefs.getString(_selectedAddressKey);
      if (addressJson != null) {
        final addressData = jsonDecode(addressJson);
        setState(() {
          _selectedAddress = Address.fromJson(addressData);
        });
        print('✅ Loaded selected address: ${_selectedAddress?.id}');
      }
    } catch (e) {
      print('❌ Error loading selected address: $e');
    }
  }

  Future<void> _saveSelectedAddress(Address address) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressJson = jsonEncode(address.toJson());
      await prefs.setString(_selectedAddressKey, addressJson);
      setState(() {
        _selectedAddress = address;
      });
      print('✅ Saved selected address: ${address.id}');
    } catch (e) {
      print('❌ Error saving selected address: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    for (var controller in _buttonAnimations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    try {
      // First try to get current city (which will return cached if available)
      final cachedCity = await LocationService.instance.getCurrentCity();
      if (cachedCity != null) {
        setState(() {
          _currentCity = cachedCity;
          _isLoadingLocation = false;
        });
      }

      if (cachedCity == null && mounted) {
        // If no cached city and can't get current location, use default
        setState(() {
          _currentCity = 'Select Location';
          _isLoadingLocation = false;
        });
      }
    } catch (e) {
      print('❌ Error initializing location: $e');
      if (mounted) {
        setState(() {
          _currentCity = 'Select Location';
          _isLoadingLocation = false;
        });
      }
    }
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Location',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Location Picker
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: LocationPicker(
                  initialLocation:
                      _currentCity != 'Loading...' &&
                          _currentCity != 'Select Location'
                      ? _currentCity
                      : null,
                  onLocationSelected: (location) {
                    setState(() {
                      _currentCity = location;
                    });
                    LocationService.instance.setCity(location);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Location updated to $location'),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
    } catch (e) {
      print('❌ Error loading cart: $e');
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

  Future<void> _initializeCategories() async {
    _m1Code = await AuthService.getM1Code();
    print('DEBUG: M1_CODE retrieved in _initializeCategories: $_m1Code');
    _categoriesFuture = _fetchCategories();
    setState(() {
      _initialized = true;
    });
  }

  Future<List<MasterCategory>> _fetchCategories() async {
    try {
      final dio = Dio();

      // Use a fixed valid category code (69 = Digestive Aid)
      // This is independent of the user ID and is needed to fetch all categories
      final categoryCode = '69';
      print('DEBUG: Fetching categories with category code: $categoryCode');

      final response = await dio
          .post(
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_master_data',
            data: {'M1_TYPE': 'Category', 'M1_CODE': categoryCode},
            options: Options(contentType: 'application/x-www-form-urlencoded'),
          )
          .timeout(const Duration(seconds: 30));

      print('DEBUG: Categories API Response Status: ${response.statusCode}');

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

  Future<List<Product>> _fetchProducts() async {
    try {
      final dio = Dio();
      print('DEBUG: Fetching products');

      final response = await dio
          .post(
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_all_product',
            data: {'cat_id': '', 'subcat_id': ''},
            options: Options(contentType: 'application/x-www-form-urlencoded'),
          )
          .timeout(const Duration(seconds: 30));

      print('DEBUG: Products API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        var data = response.data;

        // Parse JSON string if response.data is a string
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success' && data['data'] is List) {
          final products = (data['data'] as List)
              .map((item) => Product.fromJson(item))
              .toList();

          products.sort((a, b) => (a.name).compareTo(b.name));
          return products;
        }
      }
      throw Exception('Failed to load products');
    } catch (e) {
      print('Error fetching products: $e');
      rethrow;
    }
  }

  Future<List<OfferSection>> _fetchOffers() async {
    try {
      final dio = Dio();
      print('🎁 DEBUG: Fetching offers from API...');

      final response = await dio
          .post(
            'https://www.onlineaushadhi.in/myadmin/UserApis/offers',
            options: Options(contentType: 'application/x-www-form-urlencoded'),
          )
          .timeout(const Duration(seconds: 30));

      print('🎁 DEBUG: Offers API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        var data = response.data;

        // Parse JSON string if response.data is a string
        if (data is String) {
          print('🎁 DEBUG: Response is string, parsing JSON...');
          data = jsonDecode(data);
        }

        print('🎁 DEBUG: Response data: $data');

        if (data['response'] == 'success' && data['data'] is List) {
          final offersList = data['data'] as List;
          print('🎁 DEBUG: Found ${offersList.length} offers');

          final offers = offersList
              .map((item) => OfferSection.fromJson(item))
              .toList();

          print('🎁 DEBUG: Successfully parsed ${offers.length} offers');
          return offers;
        } else {
          print(
            '🎁 DEBUG: Response format unexpected - response: ${data['response']}, data type: ${data['data'].runtimeType}',
          );
        }
      }
      throw Exception('Failed to load offers - Status: ${response.statusCode}');
    } catch (e) {
      print('❌ Error fetching offers: $e');
      return []; // Return empty list on error
    }
  }

  // Medical-related carousel images from network
  final List<String> carouselImages = [
    'https://images.unsplash.com/photo-1550572017-54b7f54d1f75?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    'https://plus.unsplash.com/premium_photo-1661526067004-cdedb98baba3?q=80&w=1170&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
    'https://images.unsplash.com/photo-1593086586351-1673fca190cf?q=80&w=1074&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
  ];

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        // First select address, then upload
        await _selectAddressAndUpload(image);
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorSnackbar('Error picking image');
    }
  }

  Future<void> _captureImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (image != null) {
        // First select address, then upload
        await _selectAddressAndUpload(image);
      }
    } catch (e) {
      print('Error capturing image: $e');
      _showErrorSnackbar('Error capturing image');
    }
  }

  Future<void> _selectAddressAndUpload(XFile image) async {
    // Check if address is already selected
    if (_selectedAddress != null) {
      // Show confirmation dialog with option to change address
      final shouldUpload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.upload_file, color: Color(0xFF1976D2)),
              ),
              const SizedBox(width: 12),
              const Text(
                'Upload Prescription',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Delivery Address:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _selectedAddress!.fullAddress,
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload prescription to this address?',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context, false);
                // Change address
                await _changeAddress(image);
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
              ),
              child: const Text(
                'Change Address',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            // ElevatedButton(
            //   onPressed: () => Navigator.pop(context, true),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: const Color(0xFF1976D2),
            //     foregroundColor: Colors.white,
            //     // shape: RoundedRectangleBorder(
            //     //   borderRadius: BorderRadius.circular(8),
            //     // ),
            //   ),
            //   child: const Text('Upload'),
            // ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),

              child: const Text(
                'Upload',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );

      if (shouldUpload == true) {
        await _uploadPrescriptionWithAddress(image, _selectedAddress!.id);
      }
    } else {
      // No address selected, prompt for selection
      await _changeAddress(image);
    }
  }

  Future<void> _changeAddress(XFile image) async {
    // Navigate to address selection screen
    final selectedAddress = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageAddressesScreen(isSelectMode: true),
      ),
    );

    if (selectedAddress != null && selectedAddress is Address) {
      // Save the selected address for future use
      await _saveSelectedAddress(selectedAddress);
      // Upload prescription with selected address
      await _uploadPrescriptionWithAddress(image, selectedAddress.id);
    } else {
      _showErrorSnackbar(
        'Please select a delivery address to upload prescription',
      );
    }
  }

  Future<XFile?> _compressImage(XFile image) async {
    try {
      final file = File(image.path);
      final fileSizeInBytes = await file.length();
      final fileSizeInMB = fileSizeInBytes / (1024 * 1024);

      print('📸 Original image size: ${fileSizeInMB.toStringAsFixed(2)} MB');

      // Only compress if file is larger than 500KB
      if (fileSizeInBytes < 500 * 1024) {
        print('✅ Image size is acceptable, skipping compression');
        return image;
      }

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Compress image
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        image.path,
        targetPath,
        quality: 70,
        minWidth: 1920,
        minHeight: 1080,
      );

      if (compressedFile != null) {
        final compressedSize = await File(compressedFile.path).length();
        final compressedSizeInMB = compressedSize / (1024 * 1024);
        print(
          '✅ Compressed image size: ${compressedSizeInMB.toStringAsFixed(2)} MB',
        );
        print(
          '📉 Reduced by: ${((1 - compressedSize / fileSizeInBytes) * 100).toStringAsFixed(1)}%',
        );
        return XFile(compressedFile.path);
      }

      return image;
    } catch (e) {
      print('⚠️ Compression failed, using original: $e');
      return image;
    }
  }

  Future<void> _uploadPrescriptionWithAddress(
    XFile image,
    String addressId,
  ) async {
    try {
      // Compress image before upload
      _showLoadingDialog('Preparing image...');
      final compressedImage = await _compressImage(image);
      if (compressedImage == null) {
        if (mounted) Navigator.of(context).pop();
        _showErrorSnackbar('Failed to process image');
        return;
      }

      if (mounted) Navigator.of(context).pop();
      _showLoadingDialog('Uploading prescription...');

      final dio = Dio();

      // Configure Dio with timeout
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(seconds: 30);

      print('Starting upload for: ${compressedImage.path}');
      print('File name: ${compressedImage.name}');
      print('📍 Using selected address ID: $addressId');

      // Get M1_CODE from secure storage
      final m1Code = await AuthService.getM1Code();
      print('DEBUG: Retrieved M1_CODE from storage: $m1Code');
      if (m1Code == null || m1Code.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop();
        }
        _showErrorSnackbar('User ID not found. Please login again.');
        print('ERROR: M1_CODE is null or empty');
        print('DEBUG: All stored data:');
        await AuthService.debugPrintAllStoredData();
        return;
      }

      // Validate M1_CODE format - should be numeric
      if (!RegExp(r'^[0-9]+$').hasMatch(m1Code)) {
        print('WARNING: M1_CODE contains non-numeric characters: $m1Code');
      }

      print('Using M1_CODE: $m1Code');

      print(
        'DEBUG: File size: ${await compressedImage.readAsBytes().then((b) => b.length)} bytes',
      );
      print('DEBUG: File name: ${compressedImage.name}');
      print('DEBUG: File path: ${compressedImage.path}');

      // Get custom API URL if configured
      final customApiUrl = await AuthService.getCustomApiUrl();

      // Build endpoints list with custom URL if available
      final endpoints = <String>[
        if (customApiUrl != null && customApiUrl.isNotEmpty) ...[
          customApiUrl,
          customApiUrl.replaceFirst('https://', 'http://'),
        ],
        UPLOAD_ENDPOINT,
        UPLOAD_ENDPOINT.replaceFirst('https://', 'http://'),
      ];

      print('Using endpoints: $endpoints');
      print('Custom API URL: $customApiUrl');

      Response? response;
      String? lastError;

      for (String endpoint in endpoints) {
        try {
          print('Trying endpoint: $endpoint');
          // Create FormData matching the backend expectations
          final formData = FormData();

          // Required text fields
          formData.fields.add(MapEntry('M1_CODE', m1Code));
          if (addressId.isNotEmpty) {
            formData.fields.add(MapEntry('M1_ADD_ID', addressId));
          }

          // Single prescription image as F4_TXT21[0] (matches Postman)
          final multipartFile = await MultipartFile.fromFile(
            compressedImage.path,
            filename: compressedImage.name,
          );
          formData.files.add(MapEntry('F4_TXT21[0]', multipartFile));

          print(
            'FormData fields before send: ${formData.fields.map((f) => f.key).toList()}',
          );
          print(
            'FormData files before send: ${formData.files.map((f) => f.key).toList()}',
          );

          response = await dio
              .post(
                endpoint,
                data: formData,
                options: Options(
                  contentType: 'multipart/form-data',
                  validateStatus: (status) => true,
                ),
              )
              .timeout(
                const Duration(seconds: 60),
                onTimeout: () {
                  throw Exception('Request timeout');
                },
              );

          print('Response status: ${response.statusCode}');
          print('Response data: ${response.data}');
          print('Response headers: ${response.headers}');

          // Exit endpoint loop if we have a response
          break;
        } catch (e) {
          lastError = e.toString();
          print('Failed with $endpoint: $e');
          continue;
        }
      }

      if (response == null) {
        throw Exception('All endpoints failed: $lastError');
      }

      // Pop loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        print('Full API Response: $data');

        // Check for success in different possible response formats
        final isSuccess =
            data is Map &&
            (data['response'] == 'success' ||
                data['status'] == 'success' ||
                data['success'] == true);

        if (isSuccess) {
          _showSuccessSnackbar('Prescription uploaded successfully!');
          print('Upload successful: ${data['data'] ?? data}');
        } else {
          final errorMsg = data is Map
              ? (data['message'] ?? data['error'] ?? data.toString())
              : data.toString();
          _showErrorSnackbar(errorMsg);
          print('API Error: $errorMsg');
          print('Full response data: $data');
        }
      } else if (response.statusCode == 500) {
        // Server error - show user-friendly message
        print('❌ Server Error 500: Database error on server side');
        print('Full response: ${response.data}');
        _showErrorDialog(
          'Server Error',
          'The server is experiencing technical difficulties. Your prescription upload could not be processed at this time.\n\nPlease try again later or contact support if the issue persists.',
        );
      } else {
        final errorMsg = 'Upload failed with status: ${response.statusCode}';
        _showErrorSnackbar(errorMsg);
        print('HTTP Error: $errorMsg');
        print('Full response data: ${response.data}');
      }
    } on DioException catch (dioError) {
      if (mounted) {
        Navigator.of(context).pop();
      }

      String errorMessage = 'Network error occurred';

      if (dioError.type == DioExceptionType.connectionTimeout) {
        errorMessage = 'Connection timeout - server not responding';
      } else if (dioError.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Download timeout - slow connection';
      } else if (dioError.type == DioExceptionType.sendTimeout) {
        errorMessage = 'Upload timeout - slow connection';
      } else if (dioError.type == DioExceptionType.unknown) {
        errorMessage = 'Connection error: ${dioError.message}';
      } else if (dioError.type == DioExceptionType.badResponse) {
        errorMessage = 'Server error: ${dioError.response?.statusCode}';
      }

      print('DioException: $errorMessage');
      print('DioException details: ${dioError.error}');
      _showErrorSnackbar(errorMessage);
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      print('Error uploading prescription: $e');
      _showErrorSnackbar('Error uploading prescription: ${e.toString()}');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(color: Color(0xFF1976D2)),
            ),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showErrorDialog(String title, String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to manage addresses screen
                Navigator.pushNamed(context, '/manage_addresses');
              },
              child: const Text('Add Address'),
            ),
          ],
        ),
      );
    }
  }

  AnimationController _getOrCreateButtonAnimation(int productId) {
    if (!_buttonAnimations.containsKey(productId)) {
      _buttonAnimations[productId] = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
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

  void _navigateWithAnimation(Widget page) {
    Navigator.push(context, SlidePageRoute(builder: (context) => page));
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      await launchUrl(launchUri);
    } catch (e) {
      print('Error launching phone call: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone call')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _cartItems.values.fold<int>(0, (sum, qty) => sum + qty);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  _buildHeader(),

                  // Search Bar
                  _buildSearchBar(),

                  const SizedBox(height: 16),

                  // Auto-moving Carousel Banner
                  _buildCarouselBanner(),

                  const SizedBox(height: 24),

                  // Quick Actions Section
                  _buildQuickActionsSection(),

                  const SizedBox(height: 24),

                  // Categories Section
                  _buildCategoriesSection(),

                  const SizedBox(height: 24),

                  // Products Section
                  _buildProductsSection(),

                  const SizedBox(height: 24),

                  // Offers Section
                  _buildOffersSection(),

                  const SizedBox(
                    height: 60,
                  ), // Add padding for cart bar and bottom nav
                ],
              ),
            ),
          ),
          // Floating Cart Bar
          if (totalItems > 0)
            Positioned(
              left: 15,
              right: 15,
              bottom: 15, // Position just above bottom navigation bar
              child: FutureBuilder<List<Product>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final totalPrice = _calculateCartTotal(snapshot.data!);
                    return _buildCartBar(totalItems, totalPrice);
                  }
                  return _buildCartBar(totalItems, 0.0);
                },
              ),
            ),
        ],
      ),
    );
  }

  double _calculateCartTotal(List<Product> products) {
    double total = 0;
    for (final entry in _cartItems.entries) {
      try {
        final product = products.firstWhere(
          (p) => int.parse(p.id) == entry.key,
        );
        total += product.salePrice * entry.value;
      } catch (e) {
        // Product not found, skip
      }
    }
    return total;
  }

  Widget _buildCartBar(int totalItems, double totalPrice) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FutureBuilder<List<Product>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return CartScreen(
                    cartItems: _cartItems,
                    products: snapshot.data!,
                  );
                }
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        ).then((result) {
          if (result is Map) {
            setState(() {
              _cartItems = Map<int, int>.from(result);
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
            // Price and item count
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
            // View Cart Button
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

  Widget _buildHeader() {
    final totalItems = _cartItems.values.fold<int>(0, (sum, qty) => sum + qty);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jan Aushadhi',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              GestureDetector(
                onTap: _showLocationPicker,
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      _isLoadingLocation ? 'Loading...' : _currentCity,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),

          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FutureBuilder<List<Product>>(
                        future: _productsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return CartScreen(
                              cartItems: _cartItems,
                              products: snapshot.data!,
                            );
                          }
                          return const Scaffold(
                            body: Center(child: CircularProgressIndicator()),
                          );
                        },
                      ),
                    ),
                  ).then((result) {
                    // Update cart items if they were modified in CartScreen
                    if (result is Map) {
                      setState(() {
                        _cartItems = Map<int, int>.from(result);
                      });
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
                    child: Text(
                      '$totalItems',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Expanded(
                child: IgnorePointer(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search medicines, health...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1976D2),
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Icon(Icons.tune, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselBanner() {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 150,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 4),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            enlargeCenterPage: true,
            onPageChanged: (index, reason) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
          ),
          items: carouselImages.map((image) {
            int imageIndex = carouselImages.indexOf(image);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.grey[200],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return Container(
                          color: Colors.grey[200],
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              color: const Color(0xFF1976D2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.blue[50],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.local_pharmacy,
                                  size: 60,
                                  color: Color(0xFF1976D2),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Quality Medicines',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Up to 50% off on all medicines',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    // Text Overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),

                    // Text Overlay
                    // Container(
                    //   decoration: BoxDecoration(
                    //     gradient: LinearGradient(
                    //       begin: Alignment.topCenter,
                    //       end: Alignment.bottomCenter,
                    //       colors: [
                    //         Colors.black.withOpacity(0.1),
                    //         Colors.black.withOpacity(0.4),
                    //       ],
                    //     ),
                    //   ),
                    // ),
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (imageIndex == 0)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Quality Medicines',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Up to 50% off on all medicines',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  )
                                else if (imageIndex == 1)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Healthcare Products',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Premium health & wellness items',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Trusted Pharmacy',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Fast delivery & authentic products',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Carousel Indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            carouselImages.length,
            (index) => Container(
              height: 8,
              width: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentCarouselIndex == index
                    ? const Color(0xFF1976D2)
                    : Colors.grey[300],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Prescription Upload Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.description,
                        color: Colors.orange[700],
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add a prescription',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'to place your order',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: _showUploadOptions,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF1976D2)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.cloud_upload_outlined,
                              color: Color(0xFF1976D2),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'Upload',
                              style: TextStyle(
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Show saved address if available
                if (_selectedAddress != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green[600],
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Saved Address',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedAddress!.fullAddress,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            final newAddress = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ManageAddressesScreen(
                                      isSelectMode: true,
                                    ),
                              ),
                            );
                            if (newAddress != null && newAddress is Address) {
                              await _saveSelectedAddress(newAddress);
                            }
                          },
                          child: Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Call for Medicine Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Or call us to order on ',
                        style: TextStyle(fontSize: 14, color: Colors.black),
                      ),
                      const Text(
                        '9098044880',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _makePhoneCall('9098044880');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Upload Prescription',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Show selected address
            if (_selectedAddress != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Address',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedAddress!.fullAddress,
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () async {
                        Navigator.pop(context);
                        final newAddress = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const ManageAddressesScreen(isSelectMode: true),
                          ),
                        );
                        if (newAddress != null && newAddress is Address) {
                          await _saveSelectedAddress(newAddress);
                        }
                      },
                      tooltip: 'Change Address',
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No address selected. You\'ll be asked to select one.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildUploadOptionButton(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                ),
                _buildUploadOptionButton(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    Navigator.pop(context);
                    _captureImage();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    if (!_initialized) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF1976D2)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Categories',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  _navigateWithAnimation(CategoriesScreen());
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1976D2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<MasterCategory>>(
          future: _categoriesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF1976D2)),
                ),
              );
            } else if (snapshot.hasError) {
              return SizedBox(
                height: 100,
                child: Center(
                  child: Text('Error loading categories: ${snapshot.error}'),
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return SizedBox(
                height: 100,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.category_outlined,
                        size: 32,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'No categories available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }

            final categories = snapshot.data!;

            return SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    child: _buildCategoryCardFromAPI(category),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryCardFromAPI(MasterCategory category) {
    final imageUrl = _getCategoryImageUrl(category.imageUrl);
    final hasValidUrl = imageUrl.isNotEmpty;

    return GestureDetector(
      onTap: () {
        _navigateWithAnimation(CategoriesScreen());
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 6,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.blue[50],
                child: hasValidUrl
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(
                              Icons.category,
                              size: 40,
                              color: Color(0xFF1976D2),
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
                              color: const Color(0xFF1976D2),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.category,
                          size: 40,
                          color: Color(0xFF1976D2),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 90,
            child: Text(
              category.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSection() {
    if (!_initialized) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF1976D2)),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Featured Products',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () {
                  _navigateWithAnimation(const AllProductsScreen());
                },
                child: const Text(
                  'View All',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1976D2),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        // const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: FutureBuilder<List<Product>>(
            future: _productsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1976D2)),
                  ),
                );
              } else if (snapshot.hasError) {
                return SizedBox(
                  height: 150,
                  child: Center(
                    child: Text('Error loading products: ${snapshot.error}'),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SizedBox(
                  height: 150,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_bag_outlined,
                          size: 32,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No products available',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final products = snapshot.data!;
              // Show only first 4 products
              final displayProducts = products.take(4).toList();

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.55,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                ),
                itemCount: displayProducts.length,
                itemBuilder: (context, index) {
                  final product = displayProducts[index];
                  return _buildProductCard(product);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final quantity = _cartItems[int.parse(product.id)] ?? 0;
    final controller = _getOrCreateButtonAnimation(int.parse(product.id));

    if (quantity == 0 && controller.status == AnimationStatus.completed) {
      controller.reset();
    } else if (quantity > 0 && controller.status == AnimationStatus.dismissed) {
      controller.forward(from: 0.0);
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push<Map<int, int>>(
          context,
          SlidePageRoute(
            builder: (context) =>
                ProductDetailsScreen(product: product, cartItems: _cartItems),
          ),
        );
        if (result != null) {
          setState(() {
            _cartItems = result;
          });
          _saveCartToStorage();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.4),
              spreadRadius: 1,
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with discount badge
            Expanded(
              flex: 1,
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
                        fit: BoxFit.contain,
                        m1Code: _m1Code,
                      ),
                    ),
                  ),
                  // Discount Badge
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
                  // In Stock Badge
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
            // Product Details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Brand
                        Text(
                          product.brand,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Product Name
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        // Rating
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
                    SizedBox(height: 8),
                    // Price and Cart
                    Column(
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
                            SizedBox(height: 20),
                            AnimatedCrossFade(
                              firstChild: SizedBox(
                                width: 40,
                                height: 40,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.8, end: 1.0)
                                      .animate(
                                        CurvedAnimation(
                                          parent: controller,
                                          curve: Curves.elasticOut,
                                        ),
                                      ),
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _cartItems[int.parse(product.id)] = 1;
                                        controller.forward(from: 0.0);
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
                                          parent: controller,
                                          curve: Curves.easeOutCubic,
                                        ),
                                      ),
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.8, end: 1.0)
                                        .animate(
                                          CurvedAnimation(
                                            parent: controller,
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
                                              child: const Icon(
                                                Icons.remove,
                                                size: 16,
                                                color: Color(0xFF1976D2),
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
                                                    parent: controller,
                                                    curve: Curves.elasticInOut,
                                                  ),
                                                ),
                                            child: Center(
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
                                                  controller.forward(from: 0.0);
                                                });
                                                _saveCartToStorage();
                                              },
                                              child: const Icon(
                                                Icons.add,
                                                size: 16,
                                                color: Color(0xFF1976D2),
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

  Widget _buildOffersSection() {
    return FutureBuilder<List<OfferSection>>(
      future: _offersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFF1976D2)),
            ),
          );
        } else if (snapshot.hasError) {
          print('❌ Offers Error: ${snapshot.error}');
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                children: [
                  const Icon(Icons.local_offer, color: Colors.orange, size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'Offers temporarily unavailable',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          print('⚠️ No offers data available');
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.local_offer_outlined,
                    color: Colors.blue,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No offers available at the moment',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Check back later for exciting deals!',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final offers = snapshot.data!;
        print('🎁 Rendering ${offers.length} offers on screen');

        return Column(
          children: offers.map((offer) {
            print('🎁 Rendering offer: ${offer.name} (${offer.pm})');
            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Offer Header with Banner
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color.fromARGB(255, 32, 143, 255),
                          const Color.fromARGB(255, 84, 169, 255),
                          const Color.fromARGB(
                            255,
                            107,
                            166,
                            225,
                          ).withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1976D2).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_offer,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                offer.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (offer.description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  offer.description,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Offer Items
                  if (offer.pm == 'Product')
                    _buildOfferProducts(offer)
                  else if (offer.pm == 'Category')
                    _buildOfferCategories(offer),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildOfferProducts(OfferSection offer) {
    print('🎁 Building offer products: ${offer.items.length} items');
    final products = offer.items
        .map((item) => OfferProduct.fromJson(item))
        .toList();
    print('🎁 Parsed ${products.length} products');

    if (offer.scrollDirection == 'Horizontal') {
      return SizedBox(
        height: 260,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return Container(
              width: 160,
              margin: const EdgeInsets.only(right: 12),
              child: _buildOfferProductCard(product),
            );
          },
        ),
      );
    } else {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55,
          crossAxisSpacing: 15,
          mainAxisSpacing: 15,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _buildOfferProductCard(product);
        },
      );
    }
  }

  Widget _buildOfferProductCard(OfferProduct product) {
    final mrp = double.tryParse(product.mrp) ?? 0;
    final salePrice = double.tryParse(product.salePrice) ?? 0;
    final discount = mrp > 0 ? ((mrp - salePrice) / mrp * 100).round() : 0;
    final productId = int.parse(product.id);
    final quantity = _cartItems[productId] ?? 0;
    final controller = _getOrCreateButtonAnimation(productId);

    if (quantity == 0 && controller.status == AnimationStatus.completed) {
      controller.reset();
    } else if (quantity > 0 && controller.status == AnimationStatus.dismissed) {
      controller.forward(from: 0.0);
    }

    return GestureDetector(
      onTap: () async {
        // Convert OfferProduct to Product and navigate to details
        final productModel = product.toProduct();
        final result = await Navigator.push<Map<int, int>>(
          context,
          SlidePageRoute(
            builder: (context) => ProductDetailsScreen(
              product: productModel,
              cartItems: _cartItems,
            ),
          ),
        );
        if (result != null) {
          setState(() {
            _cartItems = result;
          });
          _saveCartToStorage();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.4),
              spreadRadius: 1,
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with discount badge
            Expanded(
              flex: 1,
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
                      child: product.images.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl:
                                  'https://webdevelopercg.com/janaushadhi/myadmin/uploads/product/${product.images.values.first}',
                              fit: BoxFit.contain,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.blue[50]!,
                                      Colors.blue[100]!,
                                    ],
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.local_pharmacy,
                                      color: Color(0xFF1976D2),
                                      size: 28,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Jan Aushadhi',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Color(0xFF1976D2),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Colors.blue[50]!, Colors.blue[100]!],
                                ),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_pharmacy,
                                    color: Color(0xFF1976D2),
                                    size: 28,
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Jan Aushadhi',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Color(0xFF1976D2),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                  if (discount > 0)
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
                          '$discount% OFF',
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
            // Product details
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand
                    Text(
                      product.brand,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Product Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Rating
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
                    const SizedBox(height: 6),
                    // Price
                    Text(
                      '₹${salePrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                      ),
                    ),
                    if (mrp > salePrice)
                      Text(
                        '₹${mrp.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    const SizedBox(height: 8),
                    AnimatedCrossFade(
                      firstChild: SizedBox(
                        width: 40,
                        height: 40,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                            CurvedAnimation(
                              parent: controller,
                              curve: Curves.elasticOut,
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _cartItems[productId] = 1;
                                controller.forward(from: 0.0);
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
                                  parent: controller,
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                              CurvedAnimation(
                                parent: controller,
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
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (quantity > 1) {
                                            _cartItems[productId] =
                                                quantity - 1;
                                          } else {
                                            _cartItems.remove(productId);
                                          }
                                        });
                                        _saveCartToStorage();
                                      },
                                      child: const Icon(
                                        Icons.remove,
                                        size: 16,
                                        color: Color(0xFF1976D2),
                                      ),
                                    ),
                                  ),
                                  ScaleTransition(
                                    scale: Tween<double>(begin: 0.9, end: 1.1)
                                        .animate(
                                          CurvedAnimation(
                                            parent: controller,
                                            curve: Curves.elasticInOut,
                                          ),
                                        ),
                                    child: Center(
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
                                          _cartItems[productId] = quantity + 1;
                                          controller.forward(from: 0.0);
                                        });
                                        _saveCartToStorage();
                                      },
                                      child: const Icon(
                                        Icons.add,
                                        size: 16,
                                        color: Color(0xFF1976D2),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCategories(OfferSection offer) {
    print('🎁 Building offer categories: ${offer.items.length} items');
    final categories = offer.items
        .map((item) => OfferCategory.fromJson(item))
        .toList();
    print('🎁 Parsed ${categories.length} categories');

    if (offer.scrollDirection == 'Horizontal') {
      return SizedBox(
        height: 140,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return Container(
              width: 110,
              margin: const EdgeInsets.only(right: 16),
              child: _buildOfferCategoryCard(category),
            );
          },
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return _buildOfferCategoryCard(category);
          },
        ),
      );
    }
  }

  Widget _buildOfferCategoryCard(OfferCategory category) {
    return GestureDetector(
      onTap: () {
        // Navigate to category products
        _navigateWithAnimation(CategoriesScreen());
      },
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.blue[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1976D2).withOpacity(0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.15),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl:
                    'https://webdevelopercg.com/janaushadhi/myadmin/uploads/category/${category.image}',
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.category),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class Category {
  final int id;
  final String name;
  final String icon;

  Category({required this.id, required this.name, required this.icon});
}

// Offer Models
class OfferSection {
  final String code;
  final String type;
  final String pm; // Product or Category
  final String name;
  final String description;
  final String scrollDirection; // Horizontal or Vertical
  final String bannerImage;
  final List<dynamic> items; // Can be products or categories

  OfferSection({
    required this.code,
    required this.type,
    required this.pm,
    required this.name,
    required this.description,
    required this.scrollDirection,
    required this.bannerImage,
    required this.items,
  });

  factory OfferSection.fromJson(Map<String, dynamic> json) {
    return OfferSection(
      code: json['M1_CODE'] ?? '',
      type: json['M1_TYPE'] ?? '',
      pm: json['M1_PM'] ?? '',
      name: json['M1_NAME'] ?? '',
      description: json['M1_TXT1'] ?? '',
      scrollDirection: json['M1_CR'] ?? 'Horizontal',
      bannerImage: json['M1_DC1'] ?? '',
      items: json['items'] ?? [],
    );
  }
}

class OfferProduct {
  final String id;
  final String name;
  final String mrp;
  final String salePrice;
  final Map<String, String> images;
  final String brand;
  final double rating;
  final String description;
  final String composition;
  final String hsnCode;
  final String unit;

  OfferProduct({
    required this.id,
    required this.name,
    required this.mrp,
    required this.salePrice,
    required this.images,
    this.brand = 'Generic',
    this.rating = 0.0,
    this.description = '',
    this.composition = '',
    this.hsnCode = '',
    this.unit = '',
  });

  factory OfferProduct.fromJson(Map<String, dynamic> json) {
    return OfferProduct(
      id: json['product_id'] ?? '',
      name: json['product_name'] ?? '',
      mrp: json['mrp'] ?? '0',
      salePrice: json['sale_price'] ?? '0',
      images: Map<String, String>.from(json['image'] ?? {}),
      brand: json['brand_name']?.toString() ?? 'Generic',
      rating: double.tryParse(json['rating']?.toString() ?? '0') ?? 0.0,
      description: json['description']?.toString() ?? '',
      composition: json['composition']?.toString() ?? '',
      hsnCode: json['hsn_code']?.toString() ?? '',
      unit: json['unit_name']?.toString() ?? '',
    );
  }

  // Convert OfferProduct to Product for navigation
  Product toProduct() {
    final mrpValue = double.tryParse(mrp) ?? 0.0;
    final salePriceValue = double.tryParse(salePrice) ?? 0.0;
    final discountPercent = mrpValue > 0
        ? ((mrpValue - salePriceValue) / mrpValue * 100).round()
        : 0;

    return Product(
      id: id,
      name: name,
      brand: brand,
      originalPrice: mrpValue,
      salePrice: salePriceValue,
      rating: rating,
      discountPercent: discountPercent,
      imageUrl: images.isNotEmpty ? images.values.first : '',
      imageUrls: images.values.toList(),
      description: description,
      composition: composition,
      hsn_code: hsnCode,
      unit: unit,
      description1: '',
      description2: '',
      description3: '',
      description4: '',
      description5: '',
      description6: '',
      description7: '',
    );
  }
}

class OfferCategory {
  final String code;
  final String name;
  final String shortName;
  final String image;

  OfferCategory({
    required this.code,
    required this.name,
    required this.shortName,
    required this.image,
  });

  factory OfferCategory.fromJson(Map<String, dynamic> json) {
    return OfferCategory(
      code: json['M1_CODE'] ?? '',
      name: json['M1_NAME'] ?? '',
      shortName: json['M1_SHNA'] ?? '',
      image: json['M1_DC1'] ?? '',
    );
  }
}
