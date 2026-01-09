import 'dart:ui';

class AppConstants {
  // API Endpoints
  static const String baseUrl =
      'https://www.onlineaushadhi.in/myadmin/UserApis';
      
  static const String loginEndpoint = '$baseUrl/user_login';
  static const String verifyOtpEndpoint = '$baseUrl/verify_otp';
  static const String sendOtpEndpoint = '$baseUrl/send_otp';

  // Image Endpoints - Primary and fallback URLs
  // The primary path is being tested first
  static const String baseImageUrl =
      'https://www.onlineaushadhi.in/myadmin/UserApis/uploads/product_images';

  // Storage Keys
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyUserData = 'user_data';
  static const String keyM1Code = 'm1_code';
  static const String keyCustomApiUrl = 'custom_api_url';

  // User Types
  static const String defaultUserType = 'Vendor';

  // Animation Durations
  static const Duration splashAnimationDuration = Duration(seconds: 2);
  static const Duration otpResendCooldown = Duration(seconds: 30);

  // Colors
  static const Color primaryColor = Color(0xFF1976D2);

  // Validation Messages
  static const String invalidPhoneNumber =
      'Please enter a valid 10-digit phone number';
  static const String invalidOtp = 'Please enter a valid 6-digit OTP';
  static const String somethingWentWrong =
      'Something went wrong. Please try again.';

  // UI Constants
  static const double defaultBorderRadius = 12.0;
  static const double defaultPadding = 16.0;
  static const double defaultButtonHeight = 56.0;

  // Colors
  static const int primaryColorValue = 0xFF1976D2;
  static const int secondaryColorValue = 0xFF42A5F5;
  static const int primaryContainerColorValue = 0xFF63A4FF;

  // Text Styles
  static const double heading1Size = 28.0;
  static const double heading2Size = 24.0;
  static const double bodyTextSize = 16.0;
  static const double captionTextSize = 14.0;
}

class ApiResponseMessages {
  static const String success = 'success';
  static const String otpSent =
      'Verification code has been sent to your mobile no. for login';
  static const String otpVerified = 'OTP verified Successfully.';
  static const String otpResent = 'OTP has been resent successfully';
}
