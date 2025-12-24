import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'package:jan_aushadi/widgets/location_picker.dart';

class AddAddressScreen extends StatefulWidget {
  const AddAddressScreen({super.key});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _customTypeController = TextEditingController();

  String _selectedAddressType = 'Home';
  bool _isDefault = false;
  bool _isLoading = false;
  bool _showCustomTypeField = false;

  final List<String> _addressTypes = [
    'Home',
    'Office',
    'Friends & Family',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _customTypeController.dispose();
    super.dispose();
  }

  void _showCityPicker() {
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
                    'Select City',
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
                  initialLocation: _cityController.text.isNotEmpty
                      ? _cityController.text
                      : null,
                  onLocationSelected: (location) {
                    // Extract city and state from location string
                    final parts = location.split(', ');
                    if (parts.length >= 2) {
                      setState(() {
                        _cityController.text = parts[0];
                        _stateController.text = parts[1];
                      });
                    } else {
                      setState(() {
                        _cityController.text = location;
                      });
                    }
                    Navigator.pop(context);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    // Enhanced validation for custom type if "Other" is selected
    if (_selectedAddressType == 'Other') {
      final customType = _customTypeController.text.trim();
      if (customType.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a custom address type'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Additional validation
      if (customType.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address type must be at least 2 characters'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(customType)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address type can only contain letters and spaces'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final dio = Dio();

      final m1Code = await AuthService.getM1Code();
      print('🔑 Retrieved M1_CODE for address: $m1Code');

      if (m1Code == null || m1Code.isEmpty) {
        print('❌ M1_CODE is null or empty - user not authenticated');
        throw Exception('Please login first');
      }

      // Validate M1_CODE format
      if (!RegExp(r'^[0-9]+$').hasMatch(m1Code)) {
        print('⚠️ M1_CODE format warning: $m1Code');
      }

      // Additional debugging - check if user is actually logged in
      final isLoggedIn = await AuthService.isLoggedIn();
      print('🔐 User logged in status: $isLoggedIn');
      
      // Check stored user data
      final userData = await AuthService.getUserData();
      print('👤 Stored user data: $userData');

      // Use custom type if "Other" is selected, with proper formatting
      final addressType = _selectedAddressType == 'Other'
          ? _customTypeController.text
                .trim()
                .toLowerCase()
                .split(' ')
                .map((word) => word[0].toUpperCase() + word.substring(1))
                .join(' ') // Proper case formatting
          : _selectedAddressType;

      // Build full address string exactly like working implementation
      final fullAddress = '${_addressController.text.trim()}, ${_cityController.text.trim()}, ${_stateController.text.trim()}.';

      // Use exact same data structure as working address_details_screen.dart
      final addressData = {
        'M1_CODE': m1Code,
        'M1_TYPE1': addressType,
        'M1_TYPE2': _selectedAddressType == 'Other' ? addressType : '',
        'M1_ADD1': fullAddress,
        'M1_ADD2': _cityController.text.trim(),
        'M1_ADD3': _stateController.text.trim(),
        'M1_ADD4': _pincodeController.text.trim(),
        'M1_ADD5': '', // Latitude
        'M1_ADD6': '', // Longitude  
        'M1_ADD7': _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : 'sadak no 45', // Street
        'M1_ADD8': '', // Landmark
      };

      print('🚀 ========================================');
      print('🚀 ADDING ADDRESS - DETAILED DEBUG INFO');
      print('🚀 ========================================');
      print('🔑 M1_CODE: $m1Code');
      print('📍 Address Type: $addressType');
      print('📍 Selected Type: $_selectedAddressType');
      print('📍 Full Address Data:');
      addressData.forEach((key, value) {
        print('   $key: $value');
      });
      print('🌐 API Endpoint: https://www.onlineaushadhi.in/myadmin/UserApis/add_address');
      print('📤 Request Headers: {Accept: application/json, User-Agent: Jan-Aushadhi-App/1.0, Content-Type: application/x-www-form-urlencoded}');
      print('🚀 ========================================');

      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/add_address',
        data: addressData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      print('📥 ========================================');
      print('📥 API RESPONSE - DETAILED DEBUG INFO');
      print('📥 ========================================');
      print('📥 Status Code: ${response.statusCode}');
      print('📥 Status Message: ${response.statusMessage}');
      print('📥 Response Headers: ${response.headers}');
      print('📥 Response Data Type: ${response.data.runtimeType}');
      print('📥 Response Data: ${response.data}');
      print('📥 ========================================');

      // Handle specific HTTP status codes
      if (response.statusCode == 401) {
        print('❌ ========================================');
        print('❌ 401 UNAUTHORIZED ERROR DETAILS');
        print('❌ ========================================');
        print('❌ M1_CODE used: $m1Code');
        print('❌ M1_CODE length: ${m1Code.length}');
        print('❌ M1_CODE is numeric: ${RegExp(r'^[0-9]+\$').hasMatch(m1Code)}');
        print('❌ Response headers: ${response.headers}');
        print('❌ Response data: ${response.data}');
        print('❌ ========================================');
        throw Exception('Authentication failed. Please login again.');
      }

      if (response.statusCode == 200 && response.data != null) {
        var responseData = response.data;

        if (responseData is String) {
          try {
            responseData = jsonDecode(responseData);
          } catch (e) {
            print('Error parsing response: $e');
          }
        }

        if (responseData is Map &&
            responseData['response']?.toString().toLowerCase() == 'success') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Address saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true); // Return true to indicate success
          }
          return;
        }
      }

      // If the primary endpoint fails, try the alternative endpoint
      print('⚠️ Primary endpoint failed, trying alternative...');
      try {
        final alternativeData = {
          'M1_CODE': m1Code,
          'M1_TYPE1': addressType,
          'M1_ADD1': _nameController.text.trim(),
          'M1_ADD2': _addressController.text.trim(),
          'M1_ADD3':
              '${_cityController.text.trim()}, ${_stateController.text.trim()}',
          'M1_PIN': _pincodeController.text.trim(),
          'M1_MOB': _phoneController.text.trim(),
          'is_default': _isDefault ? '1' : '0',
        };

        final alternativeResponse = await dio.post(
          'https://www.onlineaushadhi.in/myadmin/UserApis/add_user_address',
          data: alternativeData,
          options: Options(
            contentType: Headers.formUrlEncodedContentType,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Jan-Aushadhi-App/1.0',
            },
          ),
        );

        print(
          '📍 Alternative endpoint response: ${alternativeResponse.statusCode}',
        );

        if (alternativeResponse.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Address saved successfully!'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          }
          return;
        }
      } catch (alternativeError) {
        print('❌ Alternative endpoint also failed: $alternativeError');
      }

      throw Exception('Failed to save address');
    } catch (e) {
      print('Error saving address: $e');
      if (mounted) {
        String errorMessage = 'Error: ${e.toString()}';
        if (e.toString().contains('Authentication failed')) {
          errorMessage = 'Please login again to add addresses';
        } else if (e.toString().contains('401')) {
          errorMessage = 'Authentication expired. Please login again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Add Address',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Full Name
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                hintText: 'Enter your full name',
                prefixIcon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your full name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Phone Number
              _buildTextField(
                controller: _phoneController,
                label: 'Phone Number',
                hintText: 'Enter 10-digit phone number',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  if (value.length != 10) {
                    return 'Please enter a valid 10-digit phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),



              // Pincode
              _buildTextField(
                controller: _pincodeController,
                label: 'Pincode',
                hintText: 'Enter 6-digit pincode',
                prefixIcon: Icons.location_on_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter pincode';
                  }
                  if (value.length != 6) {
                    return 'Please enter a valid 6-digit pincode';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Address
              _buildTextField(
                controller: _addressController,
                label: 'Address (House No, Building, Street, Area)',
                hintText: 'Enter your complete address',
                prefixIcon: Icons.home_outlined,
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your address';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // City and State
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'City',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showCityPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_city_outlined,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _cityController.text.isEmpty
                                        ? 'Select city'
                                        : _cityController.text,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _cityController.text.isEmpty
                                          ? Colors.grey[500]
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTextField(
                      controller: _stateController,
                      label: 'State',
                      hintText: 'Enter state',
                      prefixIcon: Icons.map_outlined,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter state';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              // Address Type Selection
              const SizedBox(height: 20),
              const Text(
                'Address Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    // Address type buttons
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: _addressTypes.map((type) {
                          final isSelected = _selectedAddressType == type;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedAddressType = type;
                                  _showCustomTypeField = type == 'Other';
                                  if (type != 'Other') {
                                    _customTypeController.clear();
                                  }
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppConstants.primaryColor.withOpacity(
                                          0.1,
                                        )
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppConstants.primaryColor
                                        : Colors.grey[300]!,
                                    width: isSelected ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      type == 'Home'
                                          ? Icons.home_outlined
                                          : type == 'Office'
                                          ? Icons.business_outlined
                                          : type == 'Friends & Family'
                                          ? Icons.people_outlined
                                          : Icons.location_on_outlined,
                                      color: isSelected
                                          ? AppConstants.primaryColor
                                          : Colors.grey[600],
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      type,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? AppConstants.primaryColor
                                            : Colors.grey[700],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    // Custom type input field (shown when "Other" is selected)
                    if (_showCustomTypeField)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Divider(),
                            const SizedBox(height: 12),
                            const Text(
                              'Custom Address Type',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _customTypeController,
                              decoration: InputDecoration(
                                hintText:
                                    'Enter address type (e.g., Gym, Hospital, School)',
                                prefixIcon: const Icon(Icons.label_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: AppConstants.primaryColor,
                                    width: 2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              textCapitalization: TextCapitalization.words,
                              maxLength: 20, // Add character limit
                              buildCounter:
                                  (
                                    context, {
                                    required currentLength,
                                    maxLength,
                                    required isFocused,
                                  }) {
                                    return Text(
                                      '$currentLength/${maxLength ?? 0}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                              onChanged: (value) {
                                // Optional: Real-time validation feedback
                                setState(() {
                                  // Trigger rebuild to update any visual feedback
                                });
                              },
                              validator: _selectedAddressType == 'Other'
                                  ? (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter a custom address type';
                                      }
                                      if (value.trim().length < 2) {
                                        return 'Address type must be at least 2 characters';
                                      }
                                      if (value.trim().length > 20) {
                                        return 'Address type must be less than 20 characters';
                                      }
                                      // Check for invalid characters
                                      if (!RegExp(
                                        r'^[a-zA-Z\s]+$',
                                      ).hasMatch(value.trim())) {
                                        return 'Address type can only contain letters and spaces';
                                      }
                                      return null;
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Examples: Gym, Hospital, School, Mall, etc.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Default Address Checkbox
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: CheckboxListTile(
                  title: const Text(
                    'Make this my default address',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  subtitle: const Text(
                    'This address will be selected by default for future orders',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  value: _isDefault,
                  onChanged: (value) {
                    setState(() {
                      _isDefault = value ?? false;
                    });
                  },
                  activeColor: AppConstants.primaryColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Address',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(prefixIcon, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppConstants.primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
