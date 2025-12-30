import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jan_aushadi/screens/manage_addresses_screen.dart';
import 'package:dio/dio.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class AddressDetailsScreen extends StatefulWidget {
  final Address? address;
  final Function(Address) onSave;

  const AddressDetailsScreen({super.key, this.address, required this.onSave});

  @override
  State<AddressDetailsScreen> createState() => _AddressDetailsScreenState();
}

class _AddressDetailsScreenState extends State<AddressDetailsScreen> {
  final _searchController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _streetController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String _selectedType = 'Home'; // This will store the type name for UI
  String _selectedTypeId =
      ''; // This will store the actual type ID to send to API
  String _selectedTypeOther = '';
  bool _isLoadingLocation = false;
  bool _isSaving = false;
  bool _isLoadingTypes = true;
  List<AddressType> _addressTypes = [];

  @override
  void initState() {
    super.initState();
    _fetchAddressTypes();
    if (widget.address != null) {
      _pincodeController.text = widget.address!.pincode ?? '';
      _houseNumberController.text = widget.address!.houseNumber ?? '';
      _landmarkController.text = widget.address!.landmark ?? '';
      _cityController.text = widget.address!.city ?? '';
      _stateController.text = widget.address!.state ?? '';
      _streetController.text = widget.address!.street ?? '';
      _latitudeController.text = widget.address!.latitude ?? '';
      _longitudeController.text = widget.address!.longitude ?? '';
      _selectedType = widget.address!.type;
      // Find the type ID for this type name
      final matchingType = _addressTypes.firstWhere(
        (t) => t.name == widget.address!.type,
        orElse: () => AddressType(type: '', name: widget.address!.type),
      );
      _selectedTypeId = matchingType.type;
    }
  }

  Future<void> _fetchAddressTypes() async {
    try {
      final dio = Dio();
      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/get_address_type',
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      print('📡 Address Types API Response: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['response'] == 'success' && data['data'] is List) {
          print('📍 Raw address types data:');
          (data['data'] as List).forEach((item) {
            print('   Item: $item');
          });

          setState(() {
            _addressTypes = (data['data'] as List).map((item) {
              final addressType = AddressType.fromJson(item);
              print(
                '   Parsed: type=${addressType.type}, name=${addressType.name}',
              );
              return addressType;
            }).toList();
            _isLoadingTypes = false;
            // Set default to first type if available
            if (_addressTypes.isNotEmpty && widget.address == null) {
              _selectedType = _addressTypes.first.name;
              _selectedTypeId = _addressTypes.first.type;
              print(
                '📍 Set default type: $_selectedType (ID: $_selectedTypeId)',
              );
            }
          });
        }
      }
    } catch (e) {
      print('Error fetching address types: $e');
      // Fallback to default types
      setState(() {
        _addressTypes = [
          AddressType(type: 'Home', name: 'Home'),
          AddressType(type: 'Office', name: 'Office'),
          AddressType(type: 'Other', name: 'Other'),
        ];
        _isLoadingTypes = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pincodeController.dispose();
    _houseNumberController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _streetController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ Location services are disabled');
        setState(() {
          _isLoadingLocation = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. You can manually enter your address.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('⚠️ Location permissions are denied');
          setState(() {
            _isLoadingLocation = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location permissions are denied. You can manually enter your address.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('⚠️ Location permissions are permanently denied');
        setState(() {
          _isLoadingLocation = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions are permanently denied. You can manually enter your address.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get current position with timeout
      Position position =
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 10),
          ).timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              print('⚠️ Location request timed out');
              throw TimeoutException(
                'Location request timed out after 15 seconds',
              );
            },
          );

      // Save coordinates
      _latitudeController.text = position.latitude.toString();
      _longitudeController.text = position.longitude.toString();

      // Get address from coordinates using reverse geocoding
      try {
        List<Placemark> placemarks =
            await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            ).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print('⚠️ Geocoding request timed out');
                return [];
              },
            );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];

          setState(() {
            // Update address fields with detected location
            if (place.postalCode != null && place.postalCode!.isNotEmpty) {
              _pincodeController.text = place.postalCode!;
            }
            if (place.locality != null && place.locality!.isNotEmpty) {
              _cityController.text = place.locality!;
            }
            if (place.administrativeArea != null &&
                place.administrativeArea!.isNotEmpty) {
              _stateController.text = place.administrativeArea!;
            }
            if (place.street != null && place.street!.isNotEmpty) {
              _streetController.text = place.street!;
            }
            if (place.subLocality != null && place.subLocality!.isNotEmpty) {
              _landmarkController.text = place.subLocality!;
            }

            // Build search text
            _searchController.text =
                '${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.locality ?? ''}'
                    .trim();

            _isLoadingLocation = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Location detected: ${place.locality}, ${place.administrativeArea}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() {
            _isLoadingLocation = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } catch (e) {
        print('⚠️ Geocoding error: $e');
        setState(() {
          _isLoadingLocation = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } on TimeoutException catch (e) {
      print('❌ Location timeout: $e');
      setState(() {
        _isLoadingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location request timed out. Please manually enter your address.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Location error: $e');
      setState(() {
        _isLoadingLocation = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Location error: ${e.toString()}. You can manually enter your address.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _saveAddress() async {
    // Validate all required fields
    if (_pincodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter pincode'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_houseNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter house number/building name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_cityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter city'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_stateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter state'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_streetController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter street/road name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_landmarkController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter landmark'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate pincode format (should be numeric)
    if (!RegExp(r'^\d{6}$').hasMatch(_pincodeController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 6-digit pincode'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dio = Dio();
      final m1Code = await AuthService.getM1Code();

      if (m1Code == null || m1Code.isEmpty) {
        throw Exception('User not logged in');
      }

      // Determine the type to send - send the type name directly
      String typeToSend = _selectedType;
      String type2ToSend = '';

      // If "Other" is selected, M1_TYPE2 must contain the custom type
      if (_selectedType == 'Other') {
        if (_selectedTypeOther.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter a custom address type for "Other"'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }
        type2ToSend = _selectedTypeOther;
      }

      print('🔍 DEBUG: _selectedType = $_selectedType');
      print('🔍 DEBUG: _selectedTypeId = $_selectedTypeId');
      print('🔍 DEBUG: _selectedTypeOther = $_selectedTypeOther');
      print('🔍 DEBUG: typeToSend (M1_TYPE1) = $typeToSend');
      print('🔍 DEBUG: type2ToSend (M1_TYPE2) = $type2ToSend');

      // Prepare data for API
      // Build full address string for M1_ADD1
      final fullAddressLine =
          '${_houseNumberController.text}, ${_streetController.text}';

      final addressData = {
        'M1_CODE': m1Code,
        'M1_TYPE1': typeToSend,
        'M1_TYPE2': type2ToSend,
        'M1_ADD1': fullAddressLine,
        'M1_ADD2': _cityController.text,
        'M1_ADD3': _stateController.text,
        'M1_ADD4': _pincodeController.text,
        'M1_ADD5': _latitudeController.text.isNotEmpty
            ? _latitudeController.text
            : '0',
        'M1_ADD6': _longitudeController.text.isNotEmpty
            ? _longitudeController.text
            : '0',
        'M1_ADD7': _streetController.text,
        'M1_ADD8': _landmarkController.text,
      };

      print('📤 Sending address data:');
      addressData.forEach((key, value) {
        print('   $key: $value');
      });

      // Validate that critical fields are not empty
      if (addressData['M1_ADD1']?.toString().isEmpty ?? true) {
        throw Exception('House number/building name is required');
      }
      if (addressData['M1_ADD2']?.toString().isEmpty ?? true) {
        throw Exception('City is required');
      }
      if (addressData['M1_ADD3']?.toString().isEmpty ?? true) {
        throw Exception('State is required');
      }
      if (addressData['M1_ADD4']?.toString().isEmpty ?? true) {
        throw Exception('Pincode is required');
      }
      if (addressData['M1_ADD7']?.toString().isEmpty ?? true) {
        throw Exception('Street/Road name is required');
      }
      if (addressData['M1_ADD8']?.toString().isEmpty ?? true) {
        throw Exception('Landmark is required');
      }

      // If editing existing address, include the address ID
      final isEditing = widget.address != null;
      if (isEditing && widget.address!.id.isNotEmpty) {
        addressData['M1_ADD_ID'] = widget.address!.id;
        print('📝 Editing address with ID: ${widget.address!.id}');
      } else {
        print('➕ Adding new address');
      }

      final response = await dio.post(
        isEditing
            ? 'https://www.onlineaushadhi.in/myadmin/UserApis/update_address'
            : 'https://www.onlineaushadhi.in/myadmin/UserApis/add_address',
        data: addressData,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      setState(() {
        _isSaving = false;
      });

      print('📥 Response Status: ${response.statusCode}');
      print('📥 Response Data: ${response.data}');

      if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please login again.');
      } else if (response.statusCode == 200) {
        final data = response.data;
        if (data['response'] == 'success') {
          print('✅ Address saved successfully');
          print('📥 API Response: $data');

          // Extract the address ID from the response
          String addressId = '';
          if (isEditing) {
            addressId = widget.address!.id;
          } else {
            // Try to get ID from nested data array first
            if (data['data'] is List && (data['data'] as List).isNotEmpty) {
              final firstItem = (data['data'] as List).first;
              addressId =
                  firstItem['M1_ADD_ID']?.toString() ?? _pincodeController.text;
              print('📍 Got address ID from nested data: $addressId');
            } else {
              // Fallback to top-level M1_ADD_ID
              addressId =
                  data['M1_ADD_ID']?.toString() ?? _pincodeController.text;
              print('📍 Got address ID from top level: $addressId');
            }
          }

          final address = Address(
            id: addressId,
            type: typeToSend,
            fullAddress:
                '${_houseNumberController.text}${_landmarkController.text.isNotEmpty ? ', ${_landmarkController.text}' : ''}, ${_cityController.text}, ${_stateController.text} - ${_pincodeController.text}',
            pincode: _pincodeController.text,
            houseNumber: _houseNumberController.text,
            landmark: _landmarkController.text,
            city: _cityController.text,
            state: _stateController.text,
            street: _streetController.text,
            latitude: _latitudeController.text,
            longitude: _longitudeController.text,
          );

          print('📍 Address object created with ID: ${address.id}');
          print('📍 Address type: ${address.type}');

          // Add delay to ensure backend has processed the address
          await Future.delayed(const Duration(milliseconds: 1000));

          widget.onSave(address);

          if (mounted) {
            // Add another small delay to ensure the list is refreshed before popping
            await Future.delayed(const Duration(milliseconds: 500));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isEditing
                      ? 'Address updated successfully'
                      : 'Address saved successfully',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to save address');
        }
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.statusMessage}',
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.address != null ? 'Edit Address' : 'Add Address',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Address Type selector
            if (_isLoadingTypes)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF1976D2),
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: _addressTypes.map((type) {
                  IconData icon = Icons.home;
                  if (type.name.toLowerCase() == 'office') {
                    icon = Icons.business;
                  } else if (type.name.toLowerCase() == 'other') {
                    icon = Icons.location_on;
                  }

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedType = type.name;
                        _selectedTypeId = type.type;
                        print(
                          '📍 Selected type: $_selectedType (ID: $_selectedTypeId)',
                        );
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Radio<String>(
                          value: type.name,
                          groupValue: _selectedType,
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                              _selectedTypeId = type.type;
                              print(
                                '📍 Selected type via radio: $_selectedType (ID: $_selectedTypeId)',
                              );
                            });
                          },
                          activeColor: const Color(0xFF1976D2),
                        ),
                        Icon(icon, color: const Color(0xFF1976D2), size: 20),
                        const SizedBox(width: 4),
                        Text(type.name, style: const TextStyle(fontSize: 16)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),

            // Custom address type input (only show if "Other" is selected)
            if (_selectedType == 'Other')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please specify the address type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        _selectedTypeOther = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'e.g., School, Hospital, Shop',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Color(0xFF1976D2),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Search for area
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for area, landmark',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF1976D2),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Use current location
            InkWell(
              onTap: _isLoadingLocation ? null : _useCurrentLocation,
              child: Row(
                children: [
                  Icon(
                    Icons.my_location,
                    color: _isLoadingLocation
                        ? Colors.grey
                        : const Color(0xFF1976D2),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Use current location',
                    style: TextStyle(
                      color: _isLoadingLocation
                          ? Colors.grey
                          : const Color(0xFF1976D2),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isLoadingLocation) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF1976D2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // House No, Building
            TextField(
              controller: _houseNumberController,
              decoration: InputDecoration(
                hintText: 'House No, Building',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Street/Road Name
            TextField(
              controller: _streetController,
              decoration: InputDecoration(
                hintText: 'Street/Road Name',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Landmark
            TextField(
              controller: _landmarkController,
              decoration: InputDecoration(
                hintText: 'Landmark',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pincode
            TextField(
              controller: _pincodeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Pincode',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // City
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                hintText: 'City',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // State
            TextField(
              controller: _stateController,
              decoration: InputDecoration(
                hintText: 'State',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Address Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveAddress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        widget.address != null
                            ? 'UPDATE ADDRESS'
                            : 'SAVE ADDRESS',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddressType {
  final String type;
  final String name;

  AddressType({required this.type, required this.name});

  factory AddressType.fromJson(Map<String, dynamic> json) {
    return AddressType(
      type: json['M1_TYPE']?.toString() ?? '',
      name: json['M1_NAME']?.toString() ?? '',
    );
  }
}
