import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:jan_aushadi/services/auth_service.dart';

class ImageUrlDebugger extends StatefulWidget {
  const ImageUrlDebugger({Key? key}) : super(key: key);

  @override
  State<ImageUrlDebugger> createState() => _ImageUrlDebuggerState();
}

class _ImageUrlDebuggerState extends State<ImageUrlDebugger> {
  List<Map<String, dynamic>> _debugResults = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image URL Debugger'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _runDebugTest),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Image URL Debug Tool',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This tool tests different image URL patterns and API endpoints to find the correct image server configuration.',
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _runDebugTest,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Run Debug Test'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _debugResults.length,
              itemBuilder: (context, index) {
                final result = _debugResults[index];
                final isSuccess = result['status'] == 'success';

                return Card(
                  margin: const EdgeInsets.all(8),
                  color: isSuccess ? Colors.green[50] : Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSuccess ? Icons.check_circle : Icons.error,
                              color: isSuccess ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result['method'] ?? 'Unknown Method',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          result['url'] ?? 'No URL',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (result['response'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Response: ${result['response']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _runDebugTest() async {
    setState(() {
      _isLoading = true;
      _debugResults.clear();
    });

    final dio = Dio();
    final m1Code = await AuthService.getM1Code();
    final testFilename =
        '40ae70ea869bb3e674a9190e21dce3a0.png'; // Crocin Syrup image

    // Test different API endpoints
    final apiTests = [
      {
        'method': 'Original API - get_all_product',
        'url':
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_all_product',
        'data': {'cat_id': '', 'subcat_id': ''},
      },
      {
        'method': 'Hypothetical get_image endpoint',
        'url':
            'https://www.onlineaushadhi.in/myadmin/UserApis/get_image',
        'data': {'image_name': testFilename, 'M1_CODE': m1Code},
      },
      {
        'method': 'Hypothetical product_image endpoint',
        'url':
            'https://www.onlineaushadhi.in/myadmin/UserApis/product_image',
        'data': {'filename': testFilename, 'M1_CODE': m1Code},
      },
    ];

    for (final test in apiTests) {
      try {
        final response = await dio.post(
          test['url'] as String,
          data: test['data'],
          options: Options(
            contentType: 'application/x-www-form-urlencoded',
            validateStatus: (status) => status! < 500,
          ),
        );

        _debugResults.add({
          'method': test['method'],
          'url': test['url'],
          'status': response.statusCode == 200 ? 'success' : 'failed',
          'response':
              'Status: ${response.statusCode}, Data: ${response.data.toString().length > 100 ? response.data.toString().substring(0, 100) + "..." : response.data}',
        });
      } catch (e) {
        _debugResults.add({
          'method': test['method'],
          'url': test['url'],
          'status': 'failed',
          'response': 'Error: ${e.toString().split(':').first}',
        });
      }
      setState(() {}); // Update UI after each test
    }

    // Test direct file access with different base URLs
    final directTests = [
      'https://webdevelopercg.com/janaushadhi/uploads/product_images/$testFilename',
      'https://webdevelopercg.com/janaushadhi/images/$testFilename',
      'https://webdevelopercg.com/janaushadhi/files/$testFilename',
      'https://webdevelopercg.com/uploads/$testFilename',
      'https://webdevelopercg.com/images/$testFilename',
      'https://webdevelopercg.com/files/$testFilename',
    ];

    for (final url in directTests) {
      try {
        final response = await dio.get(
          url,
          options: Options(
            headers: {
              'Accept': 'image/*',
              if (m1Code != null && m1Code.isNotEmpty) 'M1_CODE': m1Code,
            },
            validateStatus: (status) => status! < 500,
          ),
        );

        _debugResults.add({
          'method': 'Direct File Access',
          'url': url,
          'status': response.statusCode == 200 ? 'success' : 'failed',
          'response': 'Status: ${response.statusCode}',
        });
      } catch (e) {
        _debugResults.add({
          'method': 'Direct File Access',
          'url': url,
          'status': 'failed',
          'response': 'Error: ${e.toString().split(':').first}',
        });
      }
      setState(() {}); // Update UI after each test
    }

    setState(() {
      _isLoading = false;
    });
  }
}
