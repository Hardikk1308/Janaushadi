import 'package:flutter/material.dart';
import 'package:jan_aushadi/services/order_service.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/screens/manage_addresses_screen.dart';
import 'package:jan_aushadi/screens/OrdersPage.dart';
import 'package:jan_aushadi/screens/MainApp.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic> _userData = {};
  String? _m1Code;
  bool _isLoadingProfile = true;
  File? _selectedProfileImage;
  bool _isUploadingProfilePic = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      _m1Code = await AuthService.getM1Code();
      print('DEBUG: Loaded M1_CODE: $_m1Code');

      if (_m1Code != null && _m1Code!.isNotEmpty) {
        await _fetchUserProfile();
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await OrderService().getAllOrders();
      setState(() {
        if (orders is List) {
        } else {
        }
      });
    } catch (e) {
      print('❌ Error loading orders: $e');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            if (!_isLoadingProfile) _buildProfileDetails(),
            _buildAccountSettings(),
            _buildSupportLegal(),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Profile',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.blue[400]!, Colors.blue[600]!],
                      ),
                    ),
                    child: _selectedProfileImage != null
                        ? ClipOval(
                            child: Image.file(
                              _selectedProfileImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(
                            Icons.person,
                            size: 45,
                            color: Colors.white,
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _isUploadingProfilePic
                          ? null
                          : _pickAndUploadProfileImage,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1976D2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isUploadingProfilePic
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.photo_camera,
                                size: 16,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _isLoadingProfile
                        ? const SizedBox(
                            height: 24,
                            width: 150,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Text(
                            _userData['M1_NAME'] ?? 'User Profile',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.phone, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 6),
                        Text(
                          _userData['M1_TEL'] ?? '+1 234 567 8900',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails() {
    final fieldLabels = {
      'M1_CITY': 'City',
      'M1_STATE': 'State',
      'M1_COUNTRY': 'Country',
      'M1_PINCODE': 'Pin Code',
      'M1_ADDRESS': 'Address',
    };

    final detailFields = <Widget>[];

    fieldLabels.forEach((key, label) {
      final value = _userData[key];
      if (value != null && value.toString().isNotEmpty) {
        if (detailFields.isNotEmpty) {
          detailFields.add(const SizedBox(height: 14));
        }
        detailFields.add(_buildDetailRow(label, value.toString()));
      }
    });

    if (detailFields.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(children: detailFields),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not provided' : value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: value.isEmpty ? Colors.grey[400] : Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Text(
            'Account & Settings',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.person_outline,
                  title: 'Personal Details',
                  onTap: () => _showEditProfileDialog(),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.shopping_bag_outlined,
                  title: 'My Orders',
                  onTap: () {
                    // Change to Orders tab (index 1)
                    MainApp.changeTab(context, 1);
                  },
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.location_on_outlined,
                  title: 'Manage Addresses',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ManageAddressesScreen(isSelectMode: false),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportLegal() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),
          Text(
            'Support & Legal',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () =>
                      _launchURL('https://www.onlineaushadhi.in/privacy_m'),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.description_outlined,
                  title: 'Terms & Services',
                  onTap: () =>
                      _launchURL('https://www.onlineaushadhi.in/terms_m'),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.info_outline,
                  title: 'About Us',
                  onTap: () =>
                      _launchURL('https://www.onlineaushadhi.in/about_m'),
                ),
                _buildDivider(),
                _buildMenuItem(
                  icon: Icons.phone_outlined,
                  title: 'Contact Us',
                  onTap: () =>
                      _launchURL('https://www.onlineaushadhi.in/contact_m'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not open the link');
      }
    } catch (e) {
      _showSnackBar('Error opening link: $e');
    }
  }

  Future<void> _fetchUserProfile() async {
    if (_m1Code == null || _m1Code!.isEmpty) {
      _showSnackBar('Unable to load user profile');
      return;
    }

    try {
      final dio = Dio();
      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/user_profile',
        data: {'M1_CODE': _m1Code},
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success' && data['data'] != null) {
          setState(() {
            _userData = Map<String, dynamic>.from(data['data']);
            _isLoadingProfile = false;
          });
        } else {
          _showSnackBar('Failed to load profile');
          setState(() {
            _isLoadingProfile = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching profile: $e');
      setState(() {
        _isLoadingProfile = false;
      });
      _showSnackBar('Error loading profile');
    }
  }

  Future<void> _updateUserProfile({
    required String name,
    required String email,
    required String gender,
    required String dob,
  }) async {
    if (_m1Code == null || _m1Code!.isEmpty) {
      _showSnackBar('Unable to update profile');
      return;
    }

    try {
      final dio = Dio();
      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/update_profile',
        data: {
          'M1_CODE': _m1Code,
          'M1_NAME': name,
          'M1_IT': email,
          'M1_PM': gender,
          'M1_DT1': dob,
        },
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success') {
          setState(() {
            _userData['M1_NAME'] = name;
            _userData['M1_IT'] = email;
            _userData['M1_PM'] = gender;
            _userData['M1_DT1'] = dob;
          });
          _showSnackBar('Profile updated successfully');
        } else {
          _showSnackBar('Failed to update profile');
        }
      }
    } catch (e) {
      print('Error updating profile: $e');
      _showSnackBar('Error updating profile');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showEditProfileDialog() async {
    final nameController = TextEditingController(
      text: _userData['M1_NAME'] ?? '',
    );
    final emailController = TextEditingController(
      text: _userData['M1_IT'] ?? '',
    );
    final dobController = TextEditingController(
      text: _convertToDisplayFormat(_userData['M1_DT1'] ?? ''),
    );
    // Ensure selectedGender is one of the valid dropdown values
    final validGenders = ['Male', 'Female', 'Other'];
    String selectedGender = validGenders.contains(_userData['M1_PM'])
        ? _userData['M1_PM']
        : 'Male';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Male', 'Female', 'Other']
                      .map(
                        (gender) => DropdownMenuItem(
                          value: gender,
                          child: Text(gender),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedGender = value ?? 'Male';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dobController,
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'DD-MM-YYYY',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate:
                              _parseDisplayDate(dobController.text) ??
                              DateTime.now(),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (selectedDate != null) {
                          setState(() {
                            dobController.text = _formatDisplayDate(
                              selectedDate,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  readOnly: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                nameController.dispose();
                emailController.dispose();
                dobController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateUserProfile(
                  name: nameController.text,
                  email: emailController.text,
                  gender: selectedGender,
                  dob: _convertToStorageFormat(dobController.text),
                );
                nameController.dispose();
                emailController.dispose();
                dobController.dispose();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
              ),
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }



  DateTime? _parseDisplayDate(String dateString) {
    if (dateString.isEmpty) return null;
    try {
      final parts = dateString.split('-');
      if (parts.length == 3) {
        return DateTime(
          int.parse(parts[2]),
          int.parse(parts[1]),
          int.parse(parts[0]),
        );
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  String _formatDisplayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
  }

  String _convertToDisplayFormat(String storageDate) {
    if (storageDate.isEmpty) return '';
    try {
      final date = DateTime.parse(storageDate);
      return _formatDisplayDate(date);
    } catch (e) {
      return storageDate;
    }
  }

  String _convertToStorageFormat(String displayDate) {
    if (displayDate.isEmpty) return '';
    try {
      final parts = displayDate.split('-');
      if (parts.length == 3) {
        return '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    } catch (e) {
      return displayDate;
    }
    return displayDate;
  }

  Future<void> _pickAndUploadProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _selectedProfileImage = File(image.path);
        });
        await _uploadProfileImage(File(image.path));
      }
    } catch (e) {
      print('Error picking image: $e');
      _showSnackBar('Error picking image');
    }
  }

  Future<void> _uploadProfileImage(File imageFile) async {
    if (_m1Code == null || _m1Code!.isEmpty) {
      _showSnackBar('Unable to upload profile picture');
      return;
    }

    setState(() {
      _isUploadingProfilePic = true;
    });

    try {
      final dio = Dio();
      final formData = FormData.fromMap({
        'M1_CODE': _m1Code,
        'M1_DC1': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'profile_pic.jpg',
        ),
      });

      final response = await dio.post(
        'https://www.onlineaushadhi.in/myadmin/UserApis/update_profile_pic',
        data: formData,
      );

      if (response.statusCode == 200) {
        var data = response.data;
        if (data is String) {
          data = jsonDecode(data);
        }

        if (data['response'] == 'success') {
          _showSnackBar('Profile picture updated successfully');
          print('✅ Profile picture uploaded successfully');
        } else {
          _showSnackBar('Failed to upload profile picture');
          setState(() {
            _selectedProfileImage = null;
          });
        }
      }
    } catch (e) {
      print('Error uploading profile picture: $e');
      _showSnackBar('Error uploading profile picture');
      setState(() {
        _selectedProfileImage = null;
      });
    } finally {
      setState(() {
        _isUploadingProfilePic = false;
      });
    }
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.red),
                ),
                content: const Text(
                  'Are you sure you want to logout from your account?',
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await AuthService.logout();
                      if (mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/login', (route) => false);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 0,
          ),
          child: const Text(
            'Logout',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF1976D2), size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 56,
      endIndent: 0,
      color: Colors.grey[200],
    );
  }
}
