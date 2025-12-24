import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'otp_verification_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  _PhoneLoginScreenState createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>(debugLabel: 'phoneLoginFormKey');
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('DEBUG: Step 1 - Getting user info for phone: ${_phoneController.text.trim()}');
      
      // Step 1: Call user_login to get M1_CODE
      final loginResponse = await http.post(
        Uri.parse(
          'https://www.onlineaushadhi.in/myadmin/UserApis/user_login',
        ),
        body: {'M1_TEL': _phoneController.text.trim(), 'M1_TYPE1': 'Vendor'},
      );

      print('DEBUG: Login Response Status: ${loginResponse.statusCode}');
      print('DEBUG: Login Response Body: ${loginResponse.body}');

      final loginData = json.decode(loginResponse.body);

      if (loginData['response'] == 'success') {
        final m1Code = loginData['data']['M1_CODE'].toString();
        print('DEBUG: Step 2 - Calling send_otp with M1_CODE: $m1Code');
        
        // Step 2: Call send_otp with M1_CODE (like Postman does)
        final otpResponse = await http.post(
          Uri.parse(
            'https://www.onlineaushadhi.in/myadmin/UserApis/send_otp',
          ),
          body: {'M1_CODE': m1Code, 'M1_TYPE1': 'Vendor'},
        );

        print('DEBUG: OTP Response Status: ${otpResponse.statusCode}');
        print('DEBUG: OTP Response Body: ${otpResponse.body}');

        final otpData = json.decode(otpResponse.body);

        if (otpData['response'] == 'success') {
          print('DEBUG: OTP sent successfully via send_otp endpoint!');
          // Navigate to OTP screen
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpVerificationScreen(
                phoneNumber: _phoneController.text.trim(),
                userData: loginData['data'],
              ),
            ),
          );
        } else {
          print('DEBUG: send_otp failed. Response: $otpData');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(otpData['message'] ?? 'Failed to send OTP')),
          );
        }
      } else {
        print('DEBUG: user_login failed. Response: $loginData');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loginData['message'] ?? 'Failed to get user info')),
        );
      }
    } catch (e) {
      print('DEBUG: Error sending OTP: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Lottie Animation
                  SizedBox(
                    height: 300,
                    child: Lottie.asset(
                      'assets/lottie/login.json',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  const Text(
                    'Login with Phone',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1976D2),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We will send you an OTP for verification',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Phone Number Field
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      prefixIcon: const Icon(
                        Icons.phone_android,
                        color: Color(0xFF1976D2),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF1976D2),
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      } else if (value.length != 10) {
                        return 'Please enter a valid 10-digit phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  // Send OTP Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _sendOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Send OTP',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
