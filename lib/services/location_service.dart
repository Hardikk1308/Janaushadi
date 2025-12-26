import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const String _locationKey = 'user_location';
  static const String _cityKey = 'user_city';

  static LocationService? _instance;
  static LocationService get instance => _instance ??= LocationService._();
  LocationService._();

  /// Get current location and return city name
  Future<String?> getCurrentCity() async {
    try {
      // Check if location permission is granted
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permissions are denied');
          return await _getCachedCity();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permissions are permanently denied');
        return await _getCachedCity();
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
              throw TimeoutException('Location request timed out');
            },
          );

      // Get city name from coordinates with timeout
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
        final placemark = placemarks.first;
        final city =
            placemark.locality ?? placemark.subAdministrativeArea ?? 'Unknown';

        // Cache the city
        await _cacheCity(city);
        await _cacheLocation(position.latitude, position.longitude);

        print('✅ Current city detected: $city');
        return city;
      }
    } on TimeoutException catch (e) {
      print('⚠️ Location timeout: $e');
      return await _getCachedCity();
    } catch (e) {
      print('❌ Error getting current location: $e');
      return await _getCachedCity();
    }

    return await _getCachedCity();
  }

  /// Get city suggestions based on search query
  Future<List<String>> getCitySuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      // Use geocoding to get location suggestions
      List<Location> locations = await locationFromAddress(query);

      List<String> suggestions = [];
      for (Location location in locations.take(5)) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            location.latitude,
            location.longitude,
          );

          if (placemarks.isNotEmpty) {
            final placemark = placemarks.first;
            final city = placemark.locality ?? placemark.subAdministrativeArea;
            final state = placemark.administrativeArea;

            if (city != null && state != null) {
              final suggestion = '$city, $state';
              if (!suggestions.contains(suggestion)) {
                suggestions.add(suggestion);
              }
            }
          }
        } catch (e) {
          print('❌ Error processing location: $e');
        }
      }

      return suggestions;
    } catch (e) {
      print('❌ Error getting city suggestions: $e');
      return getPopularCities()
          .where((city) => city.toLowerCase().contains(query.toLowerCase()))
          .take(5)
          .toList();
    }
  }

  /// Get popular Indian cities as fallback
  List<String> getPopularCities() {
    return [
      'Mumbai, Maharashtra',
      'Delhi, Delhi',
      'Bangalore, Karnataka',
      'Hyderabad, Telangana',
      'Chennai, Tamil Nadu',
      'Kolkata, West Bengal',
      'Pune, Maharashtra',
      'Ahmedabad, Gujarat',
      'Jaipur, Rajasthan',
      'Surat, Gujarat',
      'Lucknow, Uttar Pradesh',
      'Kanpur, Uttar Pradesh',
      'Nagpur, Maharashtra',
      'Indore, Madhya Pradesh',
      'Thane, Maharashtra',
      'Bhopal, Madhya Pradesh',
      'Visakhapatnam, Andhra Pradesh',
      'Patna, Bihar',
      'Vadodara, Gujarat',
      'Ghaziabad, Uttar Pradesh',
      'Ludhiana, Punjab',
      'Agra, Uttar Pradesh',
      'Nashik, Maharashtra',
      'Faridabad, Haryana',
      'Meerut, Uttar Pradesh',
      'Rajkot, Gujarat',
      'Varanasi, Uttar Pradesh',
      'Bhilai, Chhattisgarh',
    ];
  }

  /// Cache city name
  Future<void> _cacheCity(String city) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cityKey, city);
    } catch (e) {
      print('❌ Error caching city: $e');
    }
  }

  /// Get cached city
  Future<String?> _getCachedCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_cityKey);
    } catch (e) {
      print('❌ Error getting cached city: $e');
      return null;
    }
  }

  /// Cache location coordinates
  Future<void> _cacheLocation(double latitude, double longitude) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_locationKey, '$latitude,$longitude');
    } catch (e) {
      print('❌ Error caching location: $e');
    }
  }

  /// Get cached location coordinates
  Future<Position?> getCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationString = prefs.getString(_locationKey);

      if (locationString != null) {
        final parts = locationString.split(',');
        if (parts.length == 2) {
          final latitude = double.parse(parts[0]);
          final longitude = double.parse(parts[1]);
          return Position(
            latitude: latitude,
            longitude: longitude,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        }
      }
    } catch (e) {
      print('❌ Error getting cached location: $e');
    }
    return null;
  }

  /// Set city manually
  Future<void> setCity(String city) async {
    await _cacheCity(city);
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check location permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }
}
