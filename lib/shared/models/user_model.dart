import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String role; // 'customer', 'driver', or 'both'
  final String defaultRole; // 'customer' or 'driver'
  final String? fcmToken;
  final String? stripeAccountId; // Stripe Connect account ID for drivers
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.role,
    required this.defaultRole,
    this.fcmToken,
    this.stripeAccountId,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'customer',
      defaultRole: data['defaultRole'] ?? 'customer',
      fcmToken: data['fcmToken'],
      stripeAccountId: data['stripeAccountId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'defaultRole': defaultRole,
      'fcmToken': fcmToken,
      'stripeAccountId': stripeAccountId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? role,
    String? defaultRole,
    String? fcmToken,
    String? stripeAccountId,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      defaultRole: defaultRole ?? this.defaultRole,
      fcmToken: fcmToken ?? this.fcmToken,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
