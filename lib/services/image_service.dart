import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageService {
  static const String baseImageUrl =
      'https://www.onlineaushadhi.in/myadmin/UserApis/';

  static String getProductImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }

    // If it's already a full URL, return as is
    if (imagePath.startsWith('http')) {
      return imagePath;
    }

    // Construct full URL with base URL
    return '$baseImageUrl$imagePath';
  }

  static Widget buildProductImage({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    double borderRadius = 8.0,
  }) {
    final fullImageUrl = getProductImageUrl(imageUrl);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: Colors.grey[100],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: fullImageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: fullImageUrl,
                width: width,
                height: height,
                fit: fit,
                placeholder: (context, url) => Container(
                  color: Colors.grey[100],
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.grey[400]!,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  static Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_information, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'No Image',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  static Widget buildGridProductImage(String? imageUrl) {
    return buildProductImage(
      imageUrl: imageUrl,
      width: double.infinity,
      height: 120,
      fit: BoxFit.cover,
      borderRadius: 8.0,
    );
  }

  static Widget buildListProductImage(String? imageUrl) {
    return buildProductImage(
      imageUrl: imageUrl,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      borderRadius: 8.0,
    );
  }

  static Widget buildDetailProductImage(String? imageUrl) {
    return buildProductImage(
      imageUrl: imageUrl,
      width: double.infinity,
      height: 300,
      fit: BoxFit.cover,
      borderRadius: 12.0,
    );
  }
}
