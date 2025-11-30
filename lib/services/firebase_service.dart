import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../shared/models/user_model.dart';
import '../shared/models/order_model.dart';
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

      if (driverTokens.isNotEmpty) {
        await backendService.sendBatchNotifications(
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
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await backendService.sendNotification(
              fcmToken: fcmToken,
              title: title,
              body: body,
              data: {
                'type': notificationType,
                'orderId': orderId,
                'status': status,
              },
            );
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
        backendService != null) {
      try {
        await backendService.sendNotification(
          fcmToken: customerFcmToken,
          title: 'Order Update',
          body: 'Your order status: ${status.toUpperCase()}',
          data: {'orderId': orderId, 'status': status},
        );
      } catch (e) {
        // Notification failure shouldn't block status update
        print('Failed to send notification: $e');
      }
    }
  }
}
