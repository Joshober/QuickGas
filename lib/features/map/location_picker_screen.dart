import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/theme/app_theme.dart';
import '../../services/maps_service.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoading = false;
  LatLng _currentLocation = const LatLng(0, 0);
  
  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = []; // Contains placemark and coordinates
  bool _isSearching = false;
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final mapsService = MapsService();
      final position = await mapsService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _selectedLocation = _currentLocation;
        });
        _updateAddress(position.latitude, position.longitude);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get location: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateAddress(double lat, double lng) async {
    try {
      final mapsService = MapsService();
      final address = await mapsService.getAddressFromCoordinates(lat, lng);
      if (mounted) {
        setState(() {
          _selectedAddress = address;
        });
      }
    } catch (e) {
      if (mounted) {
        // If address lookup fails, use coordinates as fallback
        setState(() {
          _selectedAddress = 'Location: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
        });
      }
    }
  }

  void _onMapTap(LatLng location) {
    if (!mounted) return;
    setState(() {
      _selectedLocation = location;
    });
    _updateAddress(location.latitude, location.longitude);
  }

  Future<void> _searchAddress(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    try {
      final mapsService = MapsService();
      final position = await mapsService.getCoordinatesFromAddress(query);
      
      if (position != null && mounted) {
        // Get placemarks for the found location
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (mounted) {
          setState(() {
            // Store placemark with coordinates for easy access
            _searchResults = placemarks.map((placemark) => {
              'placemark': placemark,
              'latitude': position.latitude,
              'longitude': position.longitude,
            }).toList();
            _isSearching = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
        // Don't show error - just silently fail and let user use map instead
        // The search is optional - users can always tap on the map
      }
    }
  }

  Future<void> _selectSearchResult(Map<String, dynamic> result) async {
    try {
      final placemark = result['placemark'] as Placemark;
      final latitude = result['latitude'] as double;
      final longitude = result['longitude'] as double;
      final latLng = LatLng(latitude, longitude);
      
      if (mounted) {
        setState(() {
          _selectedLocation = latLng;
          _selectedAddress = '${placemark.street ?? ''}, ${placemark.locality ?? ''}, ${placemark.administrativeArea ?? ''} ${placemark.postalCode ?? ''}'.trim();
          _showSearchResults = false;
          _searchController.clear();
        });
        
        // Move map to selected location
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(latLng, 15),
        );
        
        _updateAddress(latitude, longitude);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select location: $e')),
        );
      }
    }
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      Navigator.of(context).pop({
        'location': GeoPoint(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        ),
        'address': _selectedAddress,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Use Current Location',
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: _isLoading && _currentLocation.latitude == 0
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation,
                    zoom: 15,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onTap: (LatLng location) {
                    setState(() {
                      _showSearchResults = false;
                    });
                    _onMapTap(location);
                  },
                  markers: _selectedLocation != null
                      ? {
                          Marker(
                            markerId: const MarkerId('selected'),
                            position: _selectedLocation!,
                            draggable: true,
                            onDragEnd: (LatLng newPosition) {
                              _onMapTap(newPosition);
                            },
                          ),
                        }
                      : {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
                // Search bar
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      Card(
                        elevation: 4,
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: 'Search address (optional) or tap map',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _showSearchResults = false;
                                            _searchResults = [];
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              onChanged: (value) {
                                if (value.length > 2) {
                                  _searchAddress(value);
                                } else {
                                  setState(() {
                                    _showSearchResults = false;
                                    _searchResults = [];
                                  });
                                }
                              },
                              onSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  _searchAddress(value);
                                }
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Text(
                                '💡 Tip: You can tap anywhere on the map, even on water or paths',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Search results
                      if (_showSearchResults && _searchResults.isNotEmpty)
                        Card(
                          elevation: 4,
                          margin: const EdgeInsets.only(top: 8),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 200),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final result = _searchResults[index];
                                final place = result['placemark'] as Placemark;
                                return ListTile(
                                  leading: const Icon(Icons.location_on),
                                  title: Text(
                                    place.street ?? place.name ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Text(
                                    '${place.locality ?? ''}, ${place.administrativeArea ?? ''} ${place.postalCode ?? ''}'.trim(),
                                  ),
                                  onTap: () => _selectSearchResult(result),
                                );
                              },
                            ),
                          ),
                        ),
                      if (_isSearching)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedAddress.isEmpty
                                      ? 'Tap on map to select location'
                                      : _selectedAddress,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _selectedLocation != null
                                  ? _confirmSelection
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: const Text(
                                'Confirm Location',
                                style: TextStyle(
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
                ),
              ],
            ),
    );
  }
}
