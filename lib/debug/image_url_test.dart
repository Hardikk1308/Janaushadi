import 'package:flutter/material.dart';
import 'package:jan_aushadi/constants/app_constants.dart';

class ImageUrlTestWidget extends StatelessWidget {
  final String filename;

  const ImageUrlTestWidget({Key? key, required this.filename})
    : super(key: key);

  List<String> getTestUrls() {
    return [
      'https://webdevelopercg.com/janaushadhi/uploads/product_images/$filename',
      'https://webdevelopercg.com/janaushadhi/myadmin/uploads/product_images/$filename',
      'https://webdevelopercg.com/janaushadhi/images/products/$filename',
      'https://webdevelopercg.com/uploads/products/$filename',
      'https://webdevelopercg.com/janaushadhi/assets/images/$filename',
      '${AppConstants.baseImageUrl}/$filename',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final urls = getTestUrls();

    return Scaffold(
      appBar: AppBar(title: Text('Image URL Test: $filename')),
      body: ListView.builder(
        itemCount: urls.length,
        itemBuilder: (context, index) {
          final url = urls[index];
          return Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'URL ${index + 1}:',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(url, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    height: 100,
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.red[100],
                          child: Center(
                            child: Text(
                              'Error: ${error.toString().split(':').first}',
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

void main() {
  runApp(
    MaterialApp(
      home: const ImageUrlTestWidget(
        filename: '40ae70ea869bb3e674a9190e21dce3a0.png',
      ),
    ),
  );
}
