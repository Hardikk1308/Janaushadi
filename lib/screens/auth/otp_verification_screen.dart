import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:lottie/lottie.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final Map<String, dynamic> userData;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.userData,
  });

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResendLoading = false;
  int _resendCooldown = 30;
  bool _canResend = false;
  String _errorText = '';
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  void _startResendCooldown() {
    _canResend = false;
    _resendCooldown = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
      });
      if (_resendCooldown <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _canResend = true;
          });
        }
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.length != 6) {
      setState(() {
        _errorText = 'Please enter a valid 6-digit OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = '';
    });

    try {
      print('Verifying OTP: ${_otpController.text}');
      print('User Data: ${widget.userData}');

      final response = await http
          .post(
            Uri.parse(
              'https://www.onlineaushadhi.in/myadmin/UserApis/verify_otp',
            ),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {
              'M1_CODE': widget.userData['M1_CODE'] ?? '',
              'M1_OPP': _otpController.text,
            },
          )
          .timeout(const Duration(seconds: 10));

      print('Verify OTP Response Status: ${response.statusCode}');
      print('Verify OTP Response Body: ${response.body}');

      final data = json.decode(response.body);

      if (data['response'] == 'success') {
        // Save login state and user data
        print('DEBUG OTP: Response data[data]: ${data['data']}');
        print('DEBUG OTP: Full response: $data');
        await AuthService.setLoggedIn(
          true,
          userData: json.encode(data['data']),
        );

        if (!mounted) return;

        // Navigate to home screen
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _errorText =
              data['message'] ?? 'Verification failed. Please try again.';
        });
      }
    } on TimeoutException {
      setState(() {
        _errorText = 'Request timed out. Please try again.';
      });
    } catch (e) {
      print('OTP Verification Error: $e');
      setState(() {
        _errorText = 'An error occurred: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend) return;

    setState(() {
      _isResendLoading = true;
      _errorText = '';
    });

    try {
      print('Resending OTP for code: ${widget.userData['M1_CODE']}');

      final response = await http
          .post(
            Uri.parse(
              'https://www.onlineaushadhi.in/myadmin/UserApis/send_otp',
            ),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: {'M1_CODE': widget.userData['M1_CODE'] ?? ''},
          )
          .timeout(const Duration(seconds: 10));

      print('Resend OTP Response Status: ${response.statusCode}');
      print('Resend OTP Response Body: ${response.body}');

      final data = json.decode(response.body);

      if (data['response'] == 'success') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP has been resent successfully')),
          );
          _startResendCooldown();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorText = data['message'] ?? 'Failed to resend OTP';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'An error occurred. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResendLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF1976D2)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lottie Animation
              SizedBox(
                height: 250,
                child: Lottie.asset(
                  'assets/lottie/otp.json',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              // Header
              const Text(
                'Verify OTP',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the 6-digit code sent to +91 ${widget.phoneNumber}',
                style: const TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // OTP Input
              PinCodeTextField(
                appContext: context,
                length: 6,
                controller: _otpController,
                keyboardType: TextInputType.number,
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(8),
                  fieldHeight: 50,
                  fieldWidth: 45,
                  activeFillColor: Colors.white,
                  activeColor: const Color(0xFF1976D2),
                  selectedColor: const Color(0xFF1976D2),
                  inactiveColor: Colors.grey[300],
                  selectedFillColor: Colors.white,
                  inactiveFillColor: Colors.white,
                ),
                cursorColor: const Color(0xFF1976D2),
                animationDuration: const Duration(milliseconds: 300),
                enableActiveFill: true,
                onChanged: (value) {
                  setState(() {
                    _errorText = '';
                  });
                },
              ),

              if (_errorText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _errorText,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              // Verify Button
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
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
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),

              const SizedBox(height: 24),

              // Resend OTP
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Didn\'t receive the code? ',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  TextButton(
                    onPressed: _canResend && !_isResendLoading
                        ? _resendOtp
                        : null,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _isResendLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _canResend
                                ? 'Resend'
                                : 'Resend in $_resendCooldown',
                            style: TextStyle(
                              color: _canResend
                                  ? const Color(0xFF1976D2)
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
