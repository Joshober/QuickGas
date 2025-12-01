import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../shared/models/user_model.dart';
import '../shared/models/order_model.dart';
import '../shared/models/route_model.dart';
import '../core/constants/app_constants.dart';
import 'backend_service.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String role,
    required String defaultRole,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (userCredential.user != null) {
      await createUserProfile(
        userId: userCredential.user!.uid,
        email: email,
        name: name,
        phone: phone,
        role: role,
        defaultRole: defaultRole,
      );
    }

    return userCredential;
  }

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> createUserProfile({
    required String userId,
    required String email,
    required String name,
    required String phone,
    required String role,
    required String defaultRole,
  }) async {
    final userModel = UserModel(
      id: userId,
      email: email,
      name: name,
      phone: phone,
      role: role,
      defaultRole: defaultRole,
      createdAt: DateTime.now(),
    );

    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .set(userModel.toFirestore());
  }

  Future<UserModel?> getUserProfile(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<UserModel?> getUserProfileStream(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  Future<void> updateUserFcmToken(String userId, String? fcmToken) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'fcmToken': fcmToken});
  }

  Future<void> updateUserRole(String userId, String defaultRole) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'defaultRole': defaultRole});
  }

  Future<void> updateUserProfile(
    String userId,
    String name,
    String phone,
  ) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'name': name, 'phone': phone});
  }

  Future<String> createOrder({
    required String customerId,
    required GeoPoint location,
    required String address,
    required double gasQuantity,
    String? specialInstructions,
    required String paymentMethod,
    BackendService? backendService,
  }) async {
    final orderModel = OrderModel(
      id: '', // Will be set by Firestore
      customerId: customerId,
      status: AppConstants.orderStatusPending,
      location: location,
      address: address,
      gasQuantity: gasQuantity,
      specialInstructions: specialInstructions,
      paymentMethod: paymentMethod,
      paymentStatus: AppConstants.paymentStatusPending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection(AppConstants.ordersCollection)
        .add(orderModel.toFirestore());

    // Notify all drivers about new order
    if (backendService != null) {
      _notifyDriversNewOrder(
        backendService,
        docRef.id,
        address,
        gasQuantity,
      ).catchError((e) => print('Failed to notify drivers: $e'));
    }

    return docRef.id;
  }

  Future<void> _notifyDriversNewOrder(
    BackendService backendService,
    String orderId,
    String address,
    double gasQuantity,
  ) async {
    try {
      // Get all drivers
      final driversSnapshot = await _firestore
          .collection(AppConstants.usersCollection)
          .where('role', whereIn: ['driver', 'both'])
          .get();

      final driverTokens = <String>[];
      for (var doc in driversSnapshot.docs) {
        final fcmToken = doc.data()['fcmToken'] as String?;
        if (fcmToken != null && fcmToken.isNotEmpty) {
          driverTokens.add(fcmToken);
        }
      }

      if (driverTokens.isNotEmpty && backendService.isAvailable) {
        final success = await backendService.sendBatchNotifications(
          fcmTokens: driverTokens,
          title: 'New Order Available',
          body: '${gasQuantity.toStringAsFixed(0)} gallons at $address',
          data: {
            'type': 'new_order',
            'orderId': orderId,
            'address': address,
            'gasQuantity': gasQuantity.toString(),
          },
        );
        if (!success) {
          print('Backend batch notification failed, using Firebase-only mode');
        }
      }
    } catch (e) {
      print('Error notifying drivers: $e');
    }
  }

  Future<OrderModel?> getOrder(String orderId) async {
    final doc = await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .get();

    if (doc.exists) {
      return OrderModel.fromFirestore(doc);
    }
    return null;
  }

  Stream<OrderModel?> getOrderStream(String orderId) {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .snapshots()
        .map((doc) => doc.exists ? OrderModel.fromFirestore(doc) : null);
  }

  Stream<List<OrderModel>> getCustomerOrders(String customerId) {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<OrderModel>> getPendingOrders() {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .where('status', isEqualTo: AppConstants.orderStatusPending)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  Stream<List<OrderModel>> getDriverOrders(String driverId) {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .where('driverId', isEqualTo: driverId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList(),
        );
  }

  Future<OrderModel?> getOrderById(String orderId) async {
    final doc = await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .get();

    if (doc.exists) {
      return OrderModel.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    BackendService? backendService,
  }) async {
    await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({
          'status': status,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

    // Send notification if backend service is available
    if (backendService != null) {
      _notifyOrderStatusChange(
        backendService,
        orderId,
        status,
      ).catchError((e) => print('Failed to send status notification: $e'));
    }
  }

  Future<void> _notifyOrderStatusChange(
    BackendService backendService,
    String orderId,
    String status,
  ) async {
    try {
      final orderDoc = await _firestore
          .collection(AppConstants.ordersCollection)
          .doc(orderId)
          .get();

      if (!orderDoc.exists) return;

      final orderData = orderDoc.data()!;
      final customerId = orderData['customerId'] as String?;

      String title;
      String body;
      String? recipientId;
      String notificationType;

      switch (status) {
        case AppConstants.orderStatusAccepted:
          title = 'Order Accepted';
          body = 'A driver has accepted your order';
          recipientId = customerId;
          notificationType = 'order_accepted';
          break;
        case AppConstants.orderStatusInTransit:
          title = 'Order In Transit';
          body = 'Your order is on the way';
          recipientId = customerId;
          notificationType = 'order_in_transit';
          break;
        case AppConstants.orderStatusCompleted:
          title = 'Order Completed';
          body = 'Your order has been delivered';
          recipientId = customerId;
          notificationType = 'order_completed';
          break;
        default:
          return; // Don't send notification for other statuses
      }

      if (recipientId != null) {
        final userDoc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(recipientId)
            .get();

        if (userDoc.exists) {
          final fcmToken = userDoc.data()?['fcmToken'] as String?;
          if (fcmToken != null && fcmToken.isNotEmpty && backendService.isAvailable) {
            final success = await backendService.sendNotification(
              fcmToken: fcmToken,
              title: title,
              body: body,
              data: {
                'type': notificationType,
                'orderId': orderId,
                'status': status,
              },
            );
            // If backend notification fails, we can still use Firebase Cloud Messaging directly
            if (!success) {
              print('Backend notification failed, app will use Firebase-only mode');
            }
          }
        }
      }
    } catch (e) {
      print('Error sending status notification: $e');
    }
  }

  Future<void> acceptOrder(
    String orderId,
    String driverId, {
    BackendService? backendService,
  }) async {
    await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({
          'driverId': driverId,
          'status': AppConstants.orderStatusAccepted,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

    // Notify customer that order was accepted
    if (backendService != null) {
      _notifyOrderStatusChange(
        backendService,
        orderId,
        AppConstants.orderStatusAccepted,
      ).catchError((e) => print('Failed to notify customer: $e'));
    }
  }

  Future<void> updateOrderWithDeliveryPhoto(
    String orderId,
    String photoBase64, {
    BackendService? backendService,
    String? photoUrl, // URL from backend if image was uploaded there
  }) async {
    // Get order details first to calculate driver payment
    final orderDoc = await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .get();
    
    if (!orderDoc.exists) {
      throw Exception('Order not found');
    }
    
    final orderData = orderDoc.data() as Map<String, dynamic>;
    final driverId = orderData['driverId'] as String?;
    final gasQuantity = (orderData['gasQuantity'] as num?)?.toDouble() ?? 0.0;
    
    // Use backend URL if available, otherwise fall back to base64
    final photoUrlToStore = photoUrl ?? photoBase64;

    await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({
          'deliveryPhotoUrl': photoUrlToStore,
          'deliveryVerifiedAt': Timestamp.fromDate(DateTime.now()),
          'status': AppConstants.orderStatusCompleted,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });

    // Notify customer that delivery is completed
    if (backendService != null) {
      _notifyOrderStatusChange(
        backendService,
        orderId,
        AppConstants.orderStatusCompleted,
      ).catchError((e) => print('Failed to notify customer: $e'));
      
      // Create driver payment (80% of order total) when order is completed
      if (driverId != null && driverId.isNotEmpty) {
        // Calculate order total (gas quantity * price per gallon + delivery fee)
        final orderTotal = (gasQuantity * AppConstants.pricePerGallon) + AppConstants.deliveryFee;
        
        try {
          await backendService.createDriverPayment(
            driverId: driverId,
            orderId: orderId,
            orderTotal: orderTotal,
            currency: 'usd',
          );
          print('Driver payment created: driverId=$driverId, orderId=$orderId, amount=${orderTotal * 0.8}');
        } catch (e) {
          print('Failed to create driver payment: $e');
          // Don't fail delivery completion if payment creation fails
        }
      }
    }
  }

  // Real-time location tracking
  Future<void> updateDriverLocation(String orderId, GeoPoint location) async {
    await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({
          'driverLocation': location,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  // Update ETA for an order
  Future<void> updateOrderETA(
    String orderId,
    double estimatedTimeMinutes,
  ) async {
    final estimatedArrival = DateTime.now().add(
      Duration(minutes: estimatedTimeMinutes.round()),
    );

    await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({
          'estimatedTimeMinutes': estimatedTimeMinutes,
          'estimatedArrivalTime': Timestamp.fromDate(estimatedArrival),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  // Update order payment information
  Future<void> updateOrderPayment(
    String orderId, {
    String? stripePaymentId,
    String? paymentStatus,
  }) async {
    final updateData = <String, dynamic>{
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (stripePaymentId != null) {
      updateData['stripePaymentId'] = stripePaymentId;
    }

    if (paymentStatus != null) {
      updateData['paymentStatus'] = paymentStatus;
    }

    await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update(updateData);
  }

  // Update order status and notify customer
  Future<void> updateOrderStatusWithNotification(
    String orderId,
    String status,
    String? customerFcmToken,
    BackendService? backendService,
  ) async {
    await updateOrderStatus(orderId, status);

    // Send notification to customer if FCM token and backend service available
    if (customerFcmToken != null &&
        customerFcmToken.isNotEmpty &&
        backendService != null &&
        backendService.isAvailable) {
      try {
        final success = await backendService.sendNotification(
          fcmToken: customerFcmToken,
          title: 'Order Update',
          body: 'Your order status: ${status.toUpperCase()}',
          data: {'orderId': orderId, 'status': status},
        );
        if (!success) {
          print('Backend notification failed, using Firebase-only mode');
        }
      } catch (e) {
        // Notification failure shouldn't block status update
        print('Failed to send notification: $e');
      }
    }
  }

  // Route Management Methods

  /// Create a new route
  Future<String> createRoute({
    required String driverId,
    required List<String> orderIds,
    required List<GeoPoint> waypoints,
    String? polyline,
    double? totalDistance,
    double? totalDuration,
  }) async {
    final routeModel = RouteModel(
      id: '', // Will be set by Firestore
      driverId: driverId,
      orderIds: orderIds,
      status: AppConstants.routeStatusPlanning,
      polyline: polyline,
      waypoints: waypoints,
      totalDistance: totalDistance,
      totalDuration: totalDuration,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _firestore
        .collection(AppConstants.routesCollection)
        .add(routeModel.toFirestore());

    return docRef.id;
  }

  /// Get all routes for a driver (only active routes)
  Stream<List<RouteModel>> getDriverRoutes(String driverId) {
    return _firestore
        .collection(AppConstants.routesCollection)
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          AppConstants.routeStatusPlanning,
          AppConstants.routeStatusActive
        ])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RouteModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Get a route by ID
  Future<RouteModel?> getRouteById(String routeId) async {
    final doc = await _firestore
        .collection(AppConstants.routesCollection)
        .doc(routeId)
        .get();

    if (doc.exists) {
      return RouteModel.fromFirestore(doc);
    }
    return null;
  }

  /// Update route status
  Future<void> updateRouteStatus(
    String routeId,
    String status, {
    DateTime? startedAt,
    DateTime? completedAt,
  }) async {
    final updateData = <String, dynamic>{
      'status': status,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };

    if (startedAt != null) {
      updateData['startedAt'] = Timestamp.fromDate(startedAt);
    }

    if (completedAt != null) {
      updateData['completedAt'] = Timestamp.fromDate(completedAt);
    }

    await _firestore
        .collection(AppConstants.routesCollection)
        .doc(routeId)
        .update(updateData);
  }

  /// Start a route - updates route status and all orders to in_transit
  Future<void> startRoute(
    String routeId,
    BackendService? backendService,
  ) async {
    final route = await getRouteById(routeId);
    if (route == null) {
      throw Exception('Route not found');
    }

    // Update route status to active
    await updateRouteStatus(
      routeId,
      AppConstants.routeStatusActive,
      startedAt: DateTime.now(),
    );

    // Update all orders in route to in_transit
    await updateOrdersInRoute(route.orderIds, AppConstants.orderStatusInTransit,
        backendService: backendService);
  }

  /// Complete a route - marks as completed and deletes it (only active routes saved)
  Future<void> completeRoute(String routeId) async {
    // Mark route as completed
    await updateRouteStatus(
      routeId,
      AppConstants.routeStatusCompleted,
      completedAt: DateTime.now(),
    );

    // Delete the route (only active routes are saved)
    await _firestore
        .collection(AppConstants.routesCollection)
        .doc(routeId)
        .delete();
  }

  /// Update multiple orders' status in batch
  Future<void> updateOrderStatusBatch(
    List<String> orderIds,
    String status, {
    BackendService? backendService,
  }) async {
    final batch = _firestore.batch();

    for (final orderId in orderIds) {
      final orderRef =
          _firestore.collection(AppConstants.ordersCollection).doc(orderId);
      batch.update(orderRef, {
        'status': status,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    }

    await batch.commit();

    // Send notifications if backend service is available
    if (backendService != null) {
      for (final orderId in orderIds) {
        try {
          final orderDoc = await _firestore
              .collection(AppConstants.ordersCollection)
              .doc(orderId)
              .get();
          if (orderDoc.exists) {
            final orderData = orderDoc.data() as Map<String, dynamic>;
            final customerId = orderData['customerId'] as String?;
            if (customerId != null) {
              final userDoc = await _firestore
                  .collection(AppConstants.usersCollection)
                  .doc(customerId)
                  .get();
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                final fcmToken = userData['fcmToken'] as String?;
                if (fcmToken != null && fcmToken.isNotEmpty) {
                  _notifyOrderStatusChange(
                    backendService,
                    orderId,
                    status,
                  ).catchError((e) => print('Failed to send notification: $e'));
                }
              }
            }
          }
        } catch (e) {
          print('Error sending notification for order $orderId: $e');
        }
      }
    }
  }

  /// Helper method to update orders in a route
  Future<void> updateOrdersInRoute(
    List<String> orderIds,
    String status, {
    BackendService? backendService,
  }) async {
    await updateOrderStatusBatch(orderIds, status, backendService: backendService);
  }
}
