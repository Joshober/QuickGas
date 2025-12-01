import 'package:cloud_firestore/cloud_firestore.dart';

class RouteModel {
  final String id;
  final String driverId;
  final List<String> orderIds;
  final String status; // 'planning', 'active', 'completed'
  final String? polyline; // Google Maps encoded polyline
  final List<GeoPoint> waypoints; // Route waypoints
  final double? totalDistance; // Total distance in km
  final double? totalDuration; // Total duration in minutes
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  RouteModel({
    required this.id,
    required this.driverId,
    required this.orderIds,
    required this.status,
    this.polyline,
    required this.waypoints,
    this.totalDistance,
    this.totalDuration,
    this.startedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RouteModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse waypoints from Firestore
    List<GeoPoint> waypoints = [];
    if (data['waypoints'] != null) {
      final waypointsData = data['waypoints'] as List;
      waypoints = waypointsData
          .map((wp) {
            final wpMap = wp as Map<String, dynamic>;
            return GeoPoint(
              wpMap['latitude'] as double,
              wpMap['longitude'] as double,
            );
          })
          .toList();
    }
    
    // Parse orderIds
    List<String> orderIds = [];
    if (data['orderIds'] != null) {
      orderIds = List<String>.from(data['orderIds'] as List);
    }

    return RouteModel(
      id: doc.id,
      driverId: data['driverId'] ?? '',
      orderIds: orderIds,
      status: data['status'] ?? 'planning',
      polyline: data['polyline'],
      waypoints: waypoints,
      totalDistance: (data['totalDistance'] as num?)?.toDouble(),
      totalDuration: (data['totalDuration'] as num?)?.toDouble(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'driverId': driverId,
      'orderIds': orderIds,
      'status': status,
      'polyline': polyline,
      'waypoints': waypoints
          .map((wp) => {
                'latitude': wp.latitude,
                'longitude': wp.longitude,
              })
          .toList(),
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RouteModel copyWith({
    String? id,
    String? driverId,
    List<String>? orderIds,
    String? status,
    String? polyline,
    List<GeoPoint>? waypoints,
    double? totalDistance,
    double? totalDuration,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RouteModel(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      orderIds: orderIds ?? this.orderIds,
      status: status ?? this.status,
      polyline: polyline ?? this.polyline,
      waypoints: waypoints ?? this.waypoints,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

