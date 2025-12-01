class DriverPaymentModel {
  final int id;
  final String driverId;
  final String orderId;
  final String? routeId;
  final double amount;
  final String currency;
  final String status; // 'pending', 'paid', 'failed'
  final String? stripePayoutId;
  final String? stripeTransferId;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DriverPaymentModel({
    required this.id,
    required this.driverId,
    required this.orderId,
    this.routeId,
    required this.amount,
    required this.currency,
    required this.status,
    this.stripePayoutId,
    this.stripeTransferId,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverPaymentModel.fromJson(Map<String, dynamic> json) {
    // Handle both snake_case (from backend) and camelCase
    final id = json['id'] ?? json['Id'];
    final driverId = json['driverId'] ?? json['driver_id'];
    final orderId = json['orderId'] ?? json['order_id'];
    final routeId = json['routeId'] ?? json['route_id'];
    final amount = json['amount'] ?? json['Amount'];
    final currency = json['currency'] ?? json['Currency'];
    final status = json['status'] ?? json['Status'];
    final stripePayoutId = json['stripePayoutId'] ?? json['stripe_payout_id'];
    final stripeTransferId = json['stripeTransferId'] ?? json['stripe_transfer_id'];
    final paidAt = json['paidAt'] ?? json['paid_at'];
    final createdAt = json['createdAt'] ?? json['created_at'];
    final updatedAt = json['updatedAt'] ?? json['updated_at'];

    return DriverPaymentModel(
      id: (id as num).toInt(),
      driverId: driverId as String,
      orderId: orderId as String,
      routeId: routeId as String?,
      amount: (amount as num).toDouble(),
      currency: currency as String,
      status: status as String,
      stripePayoutId: stripePayoutId as String?,
      stripeTransferId: stripeTransferId as String?,
      paidAt: paidAt != null 
          ? DateTime.parse(paidAt as String)
          : null,
      createdAt: createdAt != null 
          ? DateTime.parse(createdAt as String)
          : DateTime.now(),
      updatedAt: updatedAt != null
          ? DateTime.parse(updatedAt as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'orderId': orderId,
      'routeId': routeId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'stripePayoutId': stripePayoutId,
      'stripeTransferId': stripeTransferId,
      'paidAt': paidAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

