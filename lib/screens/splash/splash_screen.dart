import 'package:flutter/material.dart';
import 'package:jan_aushadi/screens/MainApp.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'package:jan_aushadi/screens/auth/phone_login_screen.dart';
import 'package:jan_aushadi/services/auth_service.dart';
import 'package:jan_aushadi/services/fcm_service.dart';
import 'package:jan_aushadi/services/firebase_messaging_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppConstants.splashAnimationDuration,
      vsync: this,
    )..forward();

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    // Check login status after animation
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Initialize Firebase Messaging (optional)
    try {
      final firebaseMessagingService = FirebaseMessagingService();
      await firebaseMessagingService.initializeMessaging();
    } catch (e) {
      print('⚠️ Firebase Messaging initialization failed: $e');
      print('ℹ️ App will continue without Firebase');
    }

    // Initialize FCM
    final fcmService = FCMService();
    await fcmService.initializeFCM();

    final isLoggedIn = await AuthService.isLoggedIn();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) =>
              isLoggedIn ? const MainApp() : const PhoneLoginScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/janaushadi.jpeg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: const Color(AppConstants.primaryColorValue).withValues(alpha: 0.1),
                        child: const Icon(
                          Icons.medical_services_outlined,
                          size: 100,
                          color: Color(AppConstants.primaryColorValue),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'janAushadi',
                style: TextStyle(
                  fontSize:
                      24, // Replaced with a fixed size since AppConstants.heading1Size might not be defined
                  fontWeight: FontWeight.bold,
                  color: const Color(AppConstants.primaryColorValue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
