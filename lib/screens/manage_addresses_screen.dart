import 'package:flutter/material.dart';
import 'package:jan_aushadi/screens/address_details_screen.dart';
import 'package:dio/dio.dart';
import 'package:jan_aushadi/services/auth_service.dart';

class ManageAddressesScreen extends StatefulWidget {
  final bool isSelectMode;
  
  const ManageAddressesScreen({
    super.key,
    this.isSelectMode = false,
  });

  @override
  State<ManageAddressesScreen> createState() => _ManageAddressesScreenState();
}

class _ManageAddressesScreenState extends State<ManageAddressesScreen> {
  List<Address> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAddresses();
  }

  Future<void> _fetchAddresses() async {
    print('🔄 _fetchAddresses called');
    setState(() {
      _isLoading = true;
    });

    try {
      final dio = Dio();
      final m1Code = await AuthService.getM1Code();

      print('👤 M1_CODE: $m1Code');

      if (m1Code == null || m1Code.isEmpty) {
        throw Exception('User not logged in');
      }

      print('📡 Fetching addresses from API...');
      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/get_user_address',
        data: {'M1_CODE': m1Code},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Data: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        print('✅ Response: ${data['response']}');
        
        if (data['response'] == 'success' && data['data'] is List) {
          final addressList = data['data'] as List;
          print('📍 Found ${addressList.length} addresses');
          
          setState(() {
            _addresses = addressList
                .map((item) {
                  print('   - Parsing address: ${item['M1_ADD_ID']} - ${item['M1_TYPE1']}');
                  return Address.fromJson(item);
                })
                .toList();
            _isLoading = false;
          });
          
          print('✅ Addresses loaded: ${_addresses.length}');
        } else {
          print('⚠️ No data in response or response not success');
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching addresses: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load addresses: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAddress(int index) async {
    final address = _addresses[index];
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Address'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete this address?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    address.type,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.fullAddress,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Deleting address...'),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }

    try {
      final dio = Dio();
      final m1Code = await AuthService.getM1Code();

      if (m1Code == null || m1Code.isEmpty) {
        throw Exception('User not logged in');
      }

      print('🗑️ Deleting address ID: ${address.id}');

      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/delete_address',
        data: {
          'M1_CODE': m1Code,
          'M1_ADD_ID': address.id,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      print('🗑️ Delete response: ${response.statusCode} - ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        
        // Check if deletion was successful
        if (data['response'] == 'success' || data['status'] == 'success') {
          // Refresh the list
          await _fetchAddresses();

          if (mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('Address deleted successfully'),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to delete address');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error deleting address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Failed to delete: ${e.toString()}'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _editAddress(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressDetailsScreen(
          address: _addresses[index],
          onSave: (updatedAddress) {
            // Refresh the address list after editing
            _fetchAddresses();
          },
        ),
      ),
    );
  }

  void _addNewAddress() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddressDetailsScreen(
          onSave: (newAddress) {
            // Refresh the address list after adding
            print('🔄 Address saved, refreshing list...');
            _fetchAddresses();
          },
        ),
      ),
    ).then((_) {
      // Also refresh when returning from the screen
      print('🔄 Returned from address screen, refreshing list...');
      _fetchAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Addresses',
          style: TextStyle(color: Colors.black, fontSize: 18),
        ),
        actions: [
          TextButton.icon(
            onPressed: _addNewAddress,
            icon: const Icon(Icons.add, color: Color(0xFF1976D2)),
            label: const Text(
              'Add Address',
              style: TextStyle(color: Color(0xFF1976D2)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
              ),
            )
          : _addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No addresses saved',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first address',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _addNewAddress,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Address'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchAddresses,
                  color: const Color(0xFF1976D2),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _addresses.length,
                    itemBuilder: (context, index) {
                      final address = _addresses[index];
                      return GestureDetector(
                        onTap: widget.isSelectMode
                            ? () {
                                // Return selected address when in select mode
                                Navigator.pop(context, address);
                              }
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.home_outlined, color: Colors.grey),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${address.type}(${address.pincode ?? address.id})',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      address.fullAddress,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (address.latitude != null && 
                                        address.longitude != null && 
                                        address.latitude!.isNotEmpty && 
                                        address.longitude!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Colors.grey[500],
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'GPS: ${address.latitude}, ${address.longitude}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[500],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!widget.isSelectMode) ...[
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF1976D2)),
                                  onPressed: () => _editAddress(index),
                                  tooltip: 'Edit address',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteAddress(index),
                                  tooltip: 'Delete address',
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class Address {
  final String id;
  final String type;
  final String fullAddress;
  final String? pincode;
  final String? houseNumber;
  final String? street;
  final String? landmark;
  final String? city;
  final String? state;
  final String? latitude;
  final String? longitude;
  final String? status;

  Address({
    required this.id,
    required this.type,
    required this.fullAddress,
    this.pincode,
    this.houseNumber,
    this.street,
    this.landmark,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    this.status,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    // Build full address from components
    final houseNo = json['M1_ADD1']?.toString() ?? '';
    final city = json['M1_ADD2']?.toString() ?? '';
    final state = json['M1_ADD3']?.toString() ?? '';
    final pincode = json['M1_ADD4']?.toString() ?? '';
    final landmark = json['M1_ADD8']?.toString() ?? '';
    
    String fullAddr = houseNo;
    if (landmark.isNotEmpty) fullAddr += ', $landmark';
    if (city.isNotEmpty) fullAddr += ', $city';
    if (state.isNotEmpty) fullAddr += ', $state';
    if (pincode.isNotEmpty) fullAddr += ' - $pincode';
    
    return Address(
      id: json['M1_ADD_ID']?.toString() ?? json['M1_ADD4']?.toString() ?? '',
      type: json['M1_TYPE1']?.toString() ?? 'Home',
      fullAddress: fullAddr,
      city: city,
      state: state,
      pincode: pincode,
      latitude: json['M1_ADD5']?.toString() ?? '',
      longitude: json['M1_ADD6']?.toString() ?? '',
      street: json['M1_ADD7']?.toString() ?? '',
      landmark: landmark,
      status: json['M1_BT']?.toString() ?? '',
      houseNumber: houseNo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'M1_ADD_ID': id,
      'M1_TYPE1': type,
      'M1_ADD1': houseNumber ?? '',
      'M1_ADD2': city ?? '',
      'M1_ADD3': state ?? '',
      'M1_ADD4': pincode ?? '',
      'M1_ADD5': latitude ?? '',
      'M1_ADD6': longitude ?? '',
      'M1_ADD7': street ?? '',
      'M1_ADD8': landmark ?? '',
      'M1_BT': status ?? '',
      'fullAddress': fullAddress,
    };
  }
}
