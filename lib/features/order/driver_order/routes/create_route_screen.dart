import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../services/maps_service.dart';
import '../../../../services/traffic_service.dart';
import '../../../../shared/models/order_model.dart';
import '../../../map/map_widget.dart';

class CreateRouteScreen extends ConsumerStatefulWidget {
  const CreateRouteScreen({super.key});

  @override
  ConsumerState<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends ConsumerState<CreateRouteScreen> {
  final Set<String> _selectedOrderIds = {};
  Position? _currentLocation;
  List<OrderModel> _availableOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final mapsService = MapsService();
      final position = await mapsService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentLocation = position;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Could not get current location: $e');
      }
    }

    // Load available orders
    final firebaseService = ref.read(firebaseServiceProvider);
    final pendingOrdersStream = firebaseService.getPendingOrders();
    
    pendingOrdersStream.listen((orders) {
      if (mounted) {
        setState(() {
          _availableOrders = orders;
          _isLoading = false;
        });
      }
    });
  }

  void _toggleOrderSelection(String orderId) {
    setState(() {
      if (_selectedOrderIds.contains(orderId)) {
        _selectedOrderIds.remove(orderId);
      } else {
        _selectedOrderIds.add(orderId);
      }
    });
  }

  List<OrderModel> _getSelectedOrders() {
    return _availableOrders
        .where((order) => _selectedOrderIds.contains(order.id))
        .toList();
  }

  List<RoutePoint> _getWaypoints() {
    final waypoints = <RoutePoint>[];
    
    if (_currentLocation != null) {
      waypoints.add(
        RoutePoint(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        ),
      );
    }

    for (final order in _getSelectedOrders()) {
      waypoints.add(
        RoutePoint(
          order.location.latitude,
          order.location.longitude,
        ),
      );
    }

    return waypoints;
  }

  void _createRoute() {
    final selectedOrders = _getSelectedOrders();
    if (selectedOrders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one delivery'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    Navigator.of(context).pop(selectedOrders);
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = ref.watch(firebaseServiceProvider);
    final pendingOrders = firebaseService.getPendingOrders();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Optimized Route'),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: pendingOrders,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final orders = snapshot.data ?? [];

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.route_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No available deliveries',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'There are no pending orders to create a route',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[500],
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          // Sort orders by proximity if location is available
          List<OrderModel> sortedOrders = List.from(orders);
          if (_currentLocation != null) {
            sortedOrders.sort((a, b) {
              final distanceA = Geolocator.distanceBetween(
                _currentLocation!.latitude,
                _currentLocation!.longitude,
                a.location.latitude,
                a.location.longitude,
              );
              final distanceB = Geolocator.distanceBetween(
                _currentLocation!.latitude,
                _currentLocation!.longitude,
                b.location.latitude,
                b.location.longitude,
              );
              return distanceA.compareTo(distanceB);
            });
          }

          return Column(
            children: [
              // Map Section
              Expanded(
                flex: 2,
                child: MapWidget(
                  waypoints: _getWaypoints(),
                  showRoute: false,
                ),
              ),

              // Instructions
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select deliveries to include in your optimized route',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.primaryColor,
                            ),
                      ),
                    ),
                  ],
                ),
              ),

              // Available Deliveries List
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Deliveries (${orders.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (_currentLocation != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Sorted by distance from your location',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: sortedOrders.length,
                          itemBuilder: (context, index) {
                            final order = sortedOrders[index];
                            final isSelected = _selectedOrderIds.contains(order.id);
                            final distance = _currentLocation != null
                                ? Geolocator.distanceBetween(
                                    _currentLocation!.latitude,
                                    _currentLocation!.longitude,
                                    order.location.latitude,
                                    order.location.longitude,
                                  ) / 1000 // Convert to km
                                : null;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: isSelected
                                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                  : null,
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  _toggleOrderSelection(order.id);
                                },
                                title: Text(
                                  'Order #${order.id.substring(0, 8)}',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(order.address),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.water_drop,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${order.gasQuantity} gallons',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                        if (distance != null) ...[
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${distance.toStringAsFixed(1)} km',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                secondary: CircleAvatar(
                                  backgroundColor: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.grey[300],
                                  child: Icon(
                                    isSelected ? Icons.check : Icons.add,
                                    color: isSelected ? Colors.white : Colors.grey[700],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Create Route Button
              if (_selectedOrderIds.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _createRoute,
                      icon: const Icon(Icons.route),
                      label: Text(
                        'Create Route with ${_selectedOrderIds.length} ${_selectedOrderIds.length == 1 ? 'Stop' : 'Stops'}',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

