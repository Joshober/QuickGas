import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String id;
  final String customerId;
  final String? driverId;
  final String
  status; // 'pending', 'accepted', 'in_transit', 'completed', 'cancelled'
  final GeoPoint location;
  final String address;
  final double gasQuantity;
  final String? specialInstructions;
  final String paymentMethod; // 'stripe' or 'cash'
  final String paymentStatus; // 'pending', 'paid', 'failed'
  final String? stripePaymentId;
  final String? deliveryPhotoUrl;
  final DateTime? deliveryVerifiedAt;
  final GeoPoint? driverLocation; // Real-time driver location
  final double? estimatedTimeMinutes; // ETA in minutes
  final DateTime? estimatedArrivalTime; // Calculated arrival time
  final String? customerFcmToken; // Customer's FCM token for notifications
  final DateTime createdAt;
  final DateTime updatedAt;

  OrderModel({
    required this.id,
    required this.customerId,
    this.driverId,
    required this.status,
    required this.location,
    required this.address,
    required this.gasQuantity,
    this.specialInstructions,
    required this.paymentMethod,
    required this.paymentStatus,
    this.stripePaymentId,
    this.deliveryPhotoUrl,
    this.deliveryVerifiedAt,
    this.driverLocation,
    this.estimatedTimeMinutes,
    this.estimatedArrivalTime,
    this.customerFcmToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return OrderModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      driverId: data['driverId'],
      status: data['status'] ?? 'pending',
      location: data['location'] as GeoPoint,
      address: data['address'] ?? '',
      gasQuantity: (data['gasQuantity'] ?? 0).toDouble(),
      specialInstructions: data['specialInstructions'],
      paymentMethod: data['paymentMethod'] ?? 'cash',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      stripePaymentId: data['stripePaymentId'],
      deliveryPhotoUrl: data['deliveryPhotoUrl'],
      deliveryVerifiedAt: (data['deliveryVerifiedAt'] as Timestamp?)?.toDate(),
      driverLocation: data['driverLocation'] as GeoPoint?,
      estimatedTimeMinutes: (data['estimatedTimeMinutes'] as num?)?.toDouble(),
      estimatedArrivalTime: (data['estimatedArrivalTime'] as Timestamp?)?.toDate(),
      customerFcmToken: data['customerFcmToken'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'driverId': driverId,
      'status': status,
      'location': location,
      'address': address,
      'gasQuantity': gasQuantity,
      'specialInstructions': specialInstructions,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'stripePaymentId': stripePaymentId,
      'deliveryPhotoUrl': deliveryPhotoUrl,
      'deliveryVerifiedAt': deliveryVerifiedAt != null
          ? Timestamp.fromDate(deliveryVerifiedAt!)
          : null,
      'driverLocation': driverLocation,
      'estimatedTimeMinutes': estimatedTimeMinutes,
      'estimatedArrivalTime': estimatedArrivalTime != null
          ? Timestamp.fromDate(estimatedArrivalTime!)
          : null,
      'customerFcmToken': customerFcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  OrderModel copyWith({
    String? id,
    String? customerId,
    String? driverId,
    String? status,
    GeoPoint? location,
    String? address,
    double? gasQuantity,
    String? specialInstructions,
    String? paymentMethod,
    String? paymentStatus,
    String? stripePaymentId,
    String? deliveryPhotoUrl,
    DateTime? deliveryVerifiedAt,
    GeoPoint? driverLocation,
    double? estimatedTimeMinutes,
    DateTime? estimatedArrivalTime,
    String? customerFcmToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      location: location ?? this.location,
      address: address ?? this.address,
      gasQuantity: gasQuantity ?? this.gasQuantity,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      stripePaymentId: stripePaymentId ?? this.stripePaymentId,
      deliveryPhotoUrl: deliveryPhotoUrl ?? this.deliveryPhotoUrl,
      deliveryVerifiedAt: deliveryVerifiedAt ?? this.deliveryVerifiedAt,
      driverLocation: driverLocation ?? this.driverLocation,
      estimatedTimeMinutes: estimatedTimeMinutes ?? this.estimatedTimeMinutes,
      estimatedArrivalTime: estimatedArrivalTime ?? this.estimatedArrivalTime,
      customerFcmToken: customerFcmToken ?? this.customerFcmToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
