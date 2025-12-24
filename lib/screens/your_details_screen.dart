import 'package:flutter/material.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'package:jan_aushadi/models/Product_model.dart' as product_model;
import 'package:shared_preferences/shared_preferences.dart';

typedef Product = product_model.Product;

class YourDetailsScreen extends StatefulWidget {
  final List<Product> products;
  final Map<int, int> cartItems;
  
  const YourDetailsScreen({
    super.key,
    required this.products,
    required this.cartItems,
  });

  @override
  State<YourDetailsScreen> createState() => _YourDetailsScreenState();
}

class _YourDetailsScreenState extends State<YourDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedGender = 'Male';
  bool _isOrderingForSelf = true;
  
  @override
  void initState() {
    super.initState();
    _loadSavedDetails();
  }
  
  Future<void> _loadSavedDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _firstNameController.text = prefs.getString('user_first_name') ?? '';
        _lastNameController.text = prefs.getString('user_last_name') ?? '';
        _ageController.text = prefs.getString('user_age') ?? '';
        _emailController.text = prefs.getString('user_email') ?? '';
        _selectedGender = prefs.getString('user_gender') ?? 'Male';
        _isOrderingForSelf = prefs.getBool('user_ordering_for_self') ?? true;
      });
      print('✅ Loaded saved personal details');
    } catch (e) {
      print('⚠️ Could not load saved personal details: $e');
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Save the form data to SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_first_name', _firstNameController.text);
        await prefs.setString('user_last_name', _lastNameController.text);
        await prefs.setString('user_age', _ageController.text);
        await prefs.setString('user_email', _emailController.text);
        await prefs.setString('user_gender', _selectedGender);
        await prefs.setBool('user_ordering_for_self', _isOrderingForSelf);
        
        print('✅ Personal details saved successfully');
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Personal details saved successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        print('❌ Error saving personal details: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving details: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Return true to indicate success
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Your details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add personal details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField('First name', _firstNameController, TextInputType.name),
              const SizedBox(height: 12),
              _buildTextField('Last name', _lastNameController, TextInputType.name),
              const SizedBox(height: 12),
              _buildTextField('Age', _ageController, TextInputType.number),
              const SizedBox(height: 12),
              _buildTextField('Enter your email ID', _emailController, TextInputType.emailAddress),
              const SizedBox(height: 16),
              
              // Gender Selection
              const Text(
                'Gender',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: ['Male', 'Female', 'Other'].map((gender) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0, top: 8.0),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: gender,
                          groupValue: _selectedGender,
                          onChanged: (value) {
                            setState(() {
                              _selectedGender = value!;
                            });
                          },
                          activeColor: AppConstants.primaryColor,
                        ),
                        Text(gender),
                      ],
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 16),
              
              // Ordering for
              const Text(
                'Who are you ordering for?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildOrderForButton(
                      text: 'Myself',
                      isSelected: _isOrderingForSelf,
                      onTap: () => setState(() => _isOrderingForSelf = true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOrderForButton(
                      text: 'Someone else',
                      isSelected: !_isOrderingForSelf,
                      onTap: () => setState(() => _isOrderingForSelf = false),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Text(
                'These details will be used for generating prescriptions and invoice.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                await _submitForm();
              },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save and continue',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildTextField(String label, TextEditingController controller, TextInputType keyboardType) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppConstants.primaryColor),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        if (label.contains('email') && !value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildOrderForButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryColor.withOpacity(0.1) : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppConstants.primaryColor : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? AppConstants.primaryColor : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
