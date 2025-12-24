import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:jan_aushadi/services/auth_service.dart';

class SecureImageWidget extends StatefulWidget {
  final List<String> imageUrls;
  final BoxFit fit;
  final double? width;
  final double? height;

  const SecureImageWidget({
    Key? key,
    required this.imageUrls,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  }) : super(key: key);

  @override
  State<SecureImageWidget> createState() => _SecureImageWidgetState();
}

class _SecureImageWidgetState extends State<SecureImageWidget> {
  String? _validImageUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _findValidImageUrl();
  }

  Future<void> _findValidImageUrl() async {
    final dio = Dio();
    final m1Code = await AuthService.getM1Code();

    // First, try API-based image retrieval
    if (widget.imageUrls.isNotEmpty) {
      final firstUrl = widget.imageUrls.first;
      final filename = firstUrl.split('/').last;

      try {
        print('🔄 Trying API-based image retrieval for: $filename');

        final apiResponse = await dio.post(
          'https://www.onlineaushadhi.in/myadmin/UserApis/get_product_image',
          data: {
            'image_name': filename,
            if (m1Code != null && m1Code.isNotEmpty) 'M1_CODE': m1Code,
          },
          options: Options(
            contentType: 'application/x-www-form-urlencoded',
            validateStatus: (status) => status! < 500,
          ),
        );

        print('📡 API Response Status: ${apiResponse.statusCode}');
        print('📡 API Response Data: ${apiResponse.data}');

        if (apiResponse.statusCode == 200 && apiResponse.data != null) {
          // Check if API returns image data or URL
          if (apiResponse.data is Map &&
              apiResponse.data['image_url'] != null) {
            final imageUrl = apiResponse.data['image_url'].toString();
            print('✅ API returned image URL: $imageUrl');
            setState(() {
              _validImageUrl = imageUrl;
              _isLoading = false;
            });
            return;
          }
        }
      } catch (e) {
        print('❌ API-based approach failed: $e');
      }
    }

    // Fallback: Try direct URL access with original logic
    for (String url in widget.imageUrls) {
      try {
        print('🔄 Testing direct URL: $url');

        // Try different authentication methods
        final List<Map<String, String>> authMethods = [
          // Method 1: No auth
          {},
          // Method 2: M1_CODE as header
          if (m1Code != null && m1Code.isNotEmpty) {'M1_CODE': m1Code},
          // Method 3: M1_CODE as query parameter
          if (m1Code != null && m1Code.isNotEmpty) {},
        ];

        for (int i = 0; i < authMethods.length; i++) {
          try {
            String testUrl = url;
            if (i == 2 && m1Code != null && m1Code.isNotEmpty) {
              // Add M1_CODE as query parameter
              testUrl = url.contains('?')
                  ? '$url&M1_CODE=$m1Code'
                  : '$url?M1_CODE=$m1Code';
            }

            final response = await dio.get(
              testUrl,
              options: Options(
                headers: {'Accept': 'image/*', ...authMethods[i]},
                validateStatus: (status) => status! < 400,
              ),
            );

            if (response.statusCode == 200) {
              print('✅ Direct URL works: $testUrl');
              setState(() {
                _validImageUrl = testUrl;
                _isLoading = false;
              });
              return;
            }
          } catch (e) {
            // Only print errors for the first URL to avoid spam
            if (url == widget.imageUrls.first) {
              print(
                '❌ Method ${i + 1} failed for $url: ${e.toString().split(':').first}',
              );
            }
          }
        }
      } catch (e) {
        print('❌ Failed to load $url: $e');
      }
    }

    // No valid image found - use placeholder for now
    print('🛑 No valid image found from ${widget.imageUrls.length} URLs');
    print('💡 Using placeholder image until server configuration is resolved');

    // For now, use a medical-themed placeholder
    const placeholderUrl =
        'https://via.placeholder.com/300x300/E3F2FD/1976D2?text=Medicine';

    setState(() {
      _validImageUrl = placeholderUrl;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[100],
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_hasError || _validImageUrl == null) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: Colors.grey[200],
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
            const SizedBox(height: 4),
            Text(
              'Image not available',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Image.network(
      _validImageUrl!,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
        );
      },
    );
  }
}
