import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:jan_aushadi/services/fcm_service.dart';
import 'firebase_options.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'package:jan_aushadi/screens/OrdersPage.dart';
import 'package:jan_aushadi/screens/splash/splash_screen.dart';
import 'package:jan_aushadi/screens/auth/phone_login_screen.dart';
import 'package:jan_aushadi/screens/MainApp.dart';
import 'package:jan_aushadi/screens/all_products_screen.dart';
import 'package:jan_aushadi/screens/search_screen.dart';
import 'package:jan_aushadi/screens/notification_test_screen.dart';
import 'package:jan_aushadi/screens/cart_screen.dart';
import 'package:jan_aushadi/services/cart_service.dart';
import 'package:jan_aushadi/widgets/in_app_notification_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Firebase init with error handling
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    // 🔔 Ask notification permission (Android 13+ / iOS)
    try {
      await FirebaseMessaging.instance.requestPermission();
      print('✅ Notification permission requested');
    } catch (e) {
      print('⚠️ Could not request notification permission: $e');
    }
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
    print('ℹ️ Ensure google-services.json is in android/app/ directory');
    print('ℹ️ App will continue without Firebase');
  }

  // 🛒 Init cart
  await CartService.initialize();

  runApp(MyApp());

  // 🚀 Initialize FCM AFTER app start
  FCMService().initializeFCM();
}

// Wrapper for CartScreen to handle route arguments
class CartScreenWrapper extends StatelessWidget {
  final Map<int, int> cartItems;

  const CartScreenWrapper({
    super.key,
    required this.cartItems,
  });

  @override
  Widget build(BuildContext context) {
    return CartScreen(
      cartItems: cartItems,
      products: const [],
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jan Aushadi',
      debugShowCheckedModeBanner: false,
      initialRoute: '/splash',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: const Color(AppConstants.primaryColorValue),
          primaryContainer: const Color(
            AppConstants.primaryContainerColorValue,
          ),
          secondary: const Color(AppConstants.secondaryColorValue),
          surface: Colors.white,
          background: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
          onBackground: Colors.black87,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(AppConstants.primaryColorValue),
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(AppConstants.primaryColorValue),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppConstants.defaultBorderRadius,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            borderSide: const BorderSide(
              color: Color(AppConstants.primaryColorValue),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              AppConstants.defaultBorderRadius,
            ),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.defaultPadding,
            vertical: AppConstants.defaultPadding,
          ),
          hintStyle: TextStyle(color: Colors.grey[500]),
          labelStyle: TextStyle(color: Color(AppConstants.primaryColorValue)),
          floatingLabelStyle: TextStyle(
            color: Color(AppConstants.primaryColorValue),
          ),
        ),
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            fontSize: AppConstants.heading1Size,
            fontWeight: FontWeight.bold,
            color: Color(AppConstants.primaryColorValue),
          ),
          headlineMedium: TextStyle(
            fontSize: AppConstants.heading2Size,
            fontWeight: FontWeight.bold,
            color: Color(AppConstants.primaryColorValue),
          ),
          bodyLarge: TextStyle(
            fontSize: AppConstants.bodyTextSize,
            color: Colors.black87,
          ),
          bodyMedium: TextStyle(
            fontSize: AppConstants.captionTextSize,
            color: Colors.black87,
          ),
          labelLarge: TextStyle(
            fontSize: AppConstants.bodyTextSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const MainApp(),
        '/login': (context) => const PhoneLoginScreen(),
        '/home': (context) => const MainApp(),
        '/order': (context) => const OrdersPage(),
        '/all_products': (context) => const AllProductsScreen(),
        '/search': (context) => const SearchScreen(),
        '/notification_test': (context) => const NotificationTestScreen(),
        '/cart': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          Map<int, int> cartItems = {};
          
          if (args is Map<int, int>) {
            cartItems = args;
          } else if (args is Map) {
            // Handle case where keys might be strings
            cartItems = args.map((key, value) {
              final intKey = key is int ? key : int.tryParse(key.toString()) ?? 0;
              final intValue = value is int ? value : int.tryParse(value.toString()) ?? 0;
              return MapEntry(intKey, intValue);
            }).cast<int, int>();
          }
          
          return CartScreen(
            cartItems: cartItems,
            products: const [],
          );
        },
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) =>
              const Scaffold(body: Center(child: Text('Page not found'))),
        );
      },
      builder: (context, child) {
        return InAppNotificationOverlay(
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
            child: child ?? const SizedBox(),
          ),
        );
      },
    );
  }
}
