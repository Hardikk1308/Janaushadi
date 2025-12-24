import 'package:flutter/material.dart';
import 'package:jan_aushadi/constants/app_constants.dart';
import 'package:jan_aushadi/screens/Homescreen.dart';
import 'package:jan_aushadi/screens/splash/splash_screen.dart';
import 'package:jan_aushadi/screens/auth/phone_login_screen.dart';
import 'package:jan_aushadi/screens/MainApp.dart';
import 'package:jan_aushadi/screens/all_products_screen.dart';
import 'package:jan_aushadi/screens/search_screen.dart';
import 'package:jan_aushadi/services/cart_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize cart service
  await CartService.initialize();

  runApp(MyApp());
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
        '/all_products': (context) => const AllProductsScreen(),
        '/search': (context) => const SearchScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) =>
              const Scaffold(body: Center(child: Text('Page not found'))),
        );
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
