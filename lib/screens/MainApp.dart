import 'package:flutter/material.dart';
import 'package:jan_aushadi/screens/Homescreen.dart';
import 'package:jan_aushadi/screens/OrdersPage.dart';
import 'package:jan_aushadi/screens/ProfilePage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();

  // Static method to change tab from anywhere in the app
  static void changeTab(BuildContext context, int tabIndex) {
    final state = context.findAncestorStateOfType<_MainAppState>();
    if (state != null) {
      state._changeTab(tabIndex);
    }
  }
}

class _MainAppState extends State<MainApp> {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [const HomeScreen(), const OrdersPage(), const ProfilePage()];
    _loadSelectedTab();
  }

  // Method to change tab
  void _changeTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _currentIndex = index;
      });
      _saveSelectedTab(index);
    }
  }

  Future<void> _loadSelectedTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIndex = prefs.getInt('selected_tab_index') ?? 0;
      if (mounted && savedIndex >= 0 && savedIndex < _pages.length) {
        setState(() {
          _currentIndex = savedIndex;
        });
      }
    } catch (e) {
      // Ignore errors and use default index
    }
  }

  Future<void> _saveSelectedTab(int index) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_tab_index', index);
    } catch (e) {
      // Ignore errors
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
            _saveSelectedTab(index);
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_bag_outlined),
              activeIcon: Icon(Icons.shopping_bag),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF1976D2),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          showSelectedLabels: true,
          showUnselectedLabels: true,
        ),
      ),
    );
  }
}
