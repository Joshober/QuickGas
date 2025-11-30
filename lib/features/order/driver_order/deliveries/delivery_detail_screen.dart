import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../services/image_service.dart';
import '../../../../services/location_tracking_service.dart';
import '../../../../services/google_maps_service.dart';
import '../../../../shared/models/order_model.dart';
import '../../../map/map_widget.dart';
import '../../../../services/traffic_service.dart';

class DeliveryDetailScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const DeliveryDetailScreen({super.key, required this.order});

  @override
  ConsumerState<DeliveryDetailScreen> createState() =>
      _DeliveryDetailScreenState();
}

class _DeliveryDetailScreenState extends ConsumerState<DeliveryDetailScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;
  LocationTrackingService? _locationTrackingService;
  String? _routePolyline;

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  Future<void> _uploadAndCompleteDelivery() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a delivery photo first')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final backendService = ref.read(backendServiceProvider);

      String? photoUrl;
      String photoBase64 = '';

      // Try to upload to backend first if available
      if (backendService != null && backendService.isAvailable) {
        try {
          photoUrl = await backendService.uploadImage(
            orderId: widget.order.id,
            imageType: 'delivery_photo',
            filePath: _selectedImage!.path,
          );
          // If backend upload returns null, it means backend is unavailable
          if (photoUrl == null) {
            print('Backend upload unavailable, using base64');
          }
        } catch (e) {
          // If backend upload fails, fall back to base64
          print('Backend upload failed, using base64: $e');
        }
      }

      // If backend upload failed or not available, use base64
      if (photoUrl == null) {
        photoBase64 = await ImageService.compressAndEncodeImage(
          _selectedImage!,
        );
      }

      // Update order with photo (URL or base64)
      await firebaseService.updateOrderWithDeliveryPhoto(
        widget.order.id,
        photoBase64,
        backendService: backendService,
        photoUrl: photoUrl,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery completed successfully!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to complete delivery: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _openMapsNavigation() async {
    final lat = widget.order.location.latitude;
    final lng = widget.order.location.longitude;
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to open maps: $e')));
      }
    }
  }

  Future<void> _updateStatus(String status) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final backendService = ref.read(backendServiceProvider);
      await firebaseService.updateOrderStatus(
        widget.order.id,
        status,
        backendService: backendService,
      );

      // Start location tracking when driver starts delivery
      if (status == AppConstants.orderStatusInTransit) {
        _startLocationTracking();
      } else if (status == AppConstants.orderStatusCompleted) {
        _stopLocationTracking();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      _locationTrackingService = LocationTrackingService(firebaseService);
      await _locationTrackingService!.startTracking(
        orderId: widget.order.id,
        destination: widget.order.location,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start location tracking: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _stopLocationTracking() {
    _locationTrackingService?.stopTracking();
    _locationTrackingService = null;
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $amPm';
  }

  @override
  void dispose() {
    _stopLocationTracking();
    super.dispose();
  }

  Future<void> _updateRoutePolyline(OrderModel order) async {
    if (order.driverLocation != null) {
      try {
        final googleMapsService = GoogleMapsDirectionsService();
        final route = await googleMapsService.getRoute(
          originLat: order.driverLocation!.latitude,
          originLng: order.driverLocation!.longitude,
          destLat: order.location.latitude,
          destLng: order.location.longitude,
        );
        if (mounted) {
          setState(() {
            _routePolyline = route['polyline'] as String?;
          });
        }
      } catch (e) {
        print('Failed to get route: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderStream = ref
        .watch(firebaseServiceProvider)
        .getOrderStream(widget.order.id);

    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.order.id.substring(0, 8)}')),
      body: StreamBuilder<OrderModel?>(
        stream: orderStream,
        builder: (context, snapshot) {
          final order = snapshot.data ?? widget.order;

          // Update route polyline when order changes
          if (order.driverLocation != null && _routePolyline == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _updateRoutePolyline(order);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 200,
                    child: MapWidget(
                      waypoints: [
                        if (order.driverLocation != null)
                          RoutePoint(
                            order.driverLocation!.latitude,
                            order.driverLocation!.longitude,
                          ),
                        RoutePoint(
                          order.location.latitude,
                          order.location.longitude,
                        ),
                      ],
                      showRoute: order.driverLocation != null,
                      routePolyline: _routePolyline,
                      currentLocation: order.driverLocation != null
                          ? LatLng(
                              order.driverLocation!.latitude,
                              order.driverLocation!.longitude,
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Details',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildDetailRow(
                          Icons.location_on,
                          'Address',
                          order.address,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          Icons.water_drop,
                          'Gas Quantity',
                          '${order.gasQuantity} gallons',
                        ),
                        if (order.specialInstructions != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.note,
                            'Instructions',
                            order.specialInstructions!,
                          ),
                        ],
                        if (order.estimatedTimeMinutes != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.access_time,
                            'Estimated Arrival',
                            order.estimatedArrivalTime != null
                                ? '${_formatTime(order.estimatedArrivalTime!)} (${order.estimatedTimeMinutes!.toStringAsFixed(0)} min)'
                                : '${order.estimatedTimeMinutes!.toStringAsFixed(0)} minutes',
                          ),
                        ],
                        if (order.driverLocation != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailRow(
                            Icons.my_location,
                            'Driver Location',
                            'Tracking active',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (order.status == AppConstants.orderStatusAccepted)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _updateStatus(AppConstants.orderStatusInTransit),
                      icon: const Icon(Icons.local_shipping),
                      label: const Text('Start Delivery'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.secondaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openMapsNavigation,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Open in Maps'),
                  ),
                ),
                const SizedBox(height: 16),

                if (order.status == AppConstants.orderStatusInTransit) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delivery Verification',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          if (_selectedImage != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _selectedImage!,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.camera_alt, size: 48),
                            ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Take Photo'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isUploading
                                  ? null
                                  : _uploadAndCompleteDelivery,
                              icon: _isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.check),
                              label: const Text('Complete Delivery'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: AppTheme.successColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
