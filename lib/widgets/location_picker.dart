import 'package:flutter/material.dart';
import 'package:jan_aushadi/services/location_service.dart';
import 'package:jan_aushadi/constants/app_constants.dart';

class LocationPicker extends StatefulWidget {
  final String? initialLocation;
  final Function(String) onLocationSelected;
  final bool showCurrentLocationOption;

  const LocationPicker({
    super.key,
    this.initialLocation,
    required this.onLocationSelected,
    this.showCurrentLocationOption = true,
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  String? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    if (_selectedLocation != null) {
      _controller.text = _selectedLocation!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _searchCities(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _showSuggestions = true;
    });

    try {
      final suggestions = await LocationService.instance.getCitySuggestions(query);
      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final city = await LocationService.instance.getCurrentCity();
      if (city != null && mounted) {
        setState(() {
          _selectedLocation = city;
          _controller.text = city;
          _showSuggestions = false;
          _isLoading = false;
        });
        widget.onLocationSelected(city);
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to get current location. Please select manually.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _selectLocation(String location) {
    setState(() {
      _selectedLocation = location;
      _controller.text = location;
      _showSuggestions = false;
    });
    _focusNode.unfocus();
    widget.onLocationSelected(location);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Field
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Search for your city...',
              prefixIcon: Icon(
                Icons.search,
                color: Colors.grey[400],
              ),
              suffixIcon: _isLoading
                  ? Container(
                      width: 20,
                      height: 20,
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConstants.primaryColor,
                      ),
                    )
                  : _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _suggestions = [];
                              _showSuggestions = false;
                              _selectedLocation = null;
                            });
                          },
                        )
                      : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            onChanged: (value) {
              _searchCities(value);
            },
            onTap: () {
              if (_controller.text.isNotEmpty) {
                _searchCities(_controller.text);
              }
            },
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _selectLocation(value.trim());
              }
            },
            textInputAction: TextInputAction.done,
          ),
        ),

        // Current Location Button
        if (widget.showCurrentLocationOption) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _getCurrentLocation,
              icon: _isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppConstants.primaryColor,
                      ),
                    )
                  : Icon(
                      Icons.my_location,
                      color: AppConstants.primaryColor,
                    ),
              label: Text(
                _isLoading ? 'Getting location...' : 'Use current location',
                style: TextStyle(
                  color: AppConstants.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppConstants.primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],

        // Manual location confirmation button
        if (_controller.text.isNotEmpty && 
            !_isLoading && 
            (_suggestions.isEmpty || !_suggestions.contains(_controller.text))) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final location = _controller.text.trim();
                if (location.isNotEmpty) {
                  _selectLocation(location);
                }
              },
              icon: Icon(
                Icons.add_location,
                color: Colors.white,
              ),
              label: Text(
                'Use "${_controller.text.length > 20 ? _controller.text.substring(0, 20) + '...' : _controller.text}"',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],

        // Suggestions List
        if (_showSuggestions && _suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (context, index) => Divider(
                height: 1,
                color: Colors.grey[200],
              ),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: Icon(
                    Icons.location_on,
                    color: AppConstants.primaryColor,
                    size: 20,
                  ),
                  title: Text(
                    suggestion,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () => _selectLocation(suggestion),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                );
              },
            ),
          ),
        ],

        // No suggestions message with manual input option
        if (_showSuggestions && _suggestions.isEmpty && !_isLoading && _controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              children: [
                Text(
                  'No cities found for "${_controller.text}"',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'You can still use this location by pressing Enter or the button above',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],

        // Help text
        if (_controller.text.isEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Type your city name or use current location',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}