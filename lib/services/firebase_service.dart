import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../shared/models/user_model.dart';
import '../shared/models/order_model.dart';
import '../shared/models/route_model.dart';
import '../core/constants/app_constants.dart';
import 'backend_service.dart';

/// Exception thrown when account linking is required
class AccountLinkingRequiredException implements Exception {
  final String email;
  final AuthCredential credential;

  AccountLinkingRequiredException({
    required this.email,
    required this.credential,
  });

  @override
  String toString() {
    return 'Account linking required for email: $email';
  }
}

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

  Future<UserCredential> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    if (googleUser == null) {
      // User canceled the sign-in
      throw Exception('Google sign-in was canceled');
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    try {
      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user and create profile if needed
      if (userCredential.user != null) {
        final userId = userCredential.user!.uid;
        final existingProfile = await getUserProfile(userId);

        if (existingProfile == null) {
          // New user - create profile with Google account info
          final displayName = userCredential.user!.displayName ?? 'User';
          final email = userCredential.user!.email ?? '';
          final phone = userCredential.user!.phoneNumber ?? '';

          await createUserProfile(
            userId: userId,
            email: email,
            name: displayName,
            phone: phone,
            role: AppConstants.roleCustomer,
            defaultRole: AppConstants.roleCustomer,
          );
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Handle account exists with different credential
      if (e.code == 'account-exists-with-different-credential') {
        // Extract the email from the error
        final email = e.email;
        if (email != null) {
          // Throw a custom exception with the email and credential for linking
          throw AccountLinkingRequiredException(
            email: email,
            credential: credential,
          );
        }
      }
      // Re-throw other Firebase auth exceptions
      rethrow;
    }
  }

  /// Link a Google account to an existing email/password account
  Future<UserCredential> linkGoogleAccount({
    required String email,
    required String password,
    required AuthCredential googleCredential,
  }) async {
    // First, sign in with email/password
    final emailCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Then link the Google credential to the existing account
    await emailCredential.user!.linkWithCredential(googleCredential);

    // Return the updated user credential
    return emailCredential;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
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

  Future<void> updateUserStripeAccountId(String userId, String? stripeAccountId) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'stripeAccountId': stripeAccountId});
  }

  Future<void> updateEmailNotificationsEnabled(String userId, bool enabled) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .update({'emailNotificationsEnabled': enabled});
  }

  Future<String?> getUserStripeAccountId(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      return data['stripeAccountId'] as String?;
    }
    return null;
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
    // Get customer's FCM token to store in order (for notifications)
    String? customerFcmToken;
    try {
      final userDoc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(customerId)
          .get();
      if (userDoc.exists) {
        customerFcmToken = userDoc.data()?['fcmToken'] as String?;
        print('Retrieved customer FCM token for order creation: ${customerFcmToken != null ? "${customerFcmToken.substring(0, 30)}..." : "null"}');
      }
    } catch (e) {
      print('Warning: Could not retrieve customer FCM token when creating order: $e');
      // Continue without FCM token - notification will be skipped if needed
    }

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
      customerFcmToken: customerFcmToken,
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
          (snapshot) {
            // Filter out orders that already have a driverId assigned
            // This ensures drivers can't see orders that are already active/assigned
            return snapshot.docs
                .map((doc) => OrderModel.fromFirestore(doc))
                .where((order) => order.driverId == null || order.driverId!.isEmpty)
                .toList();
          },
        );
  }

  Stream<List<OrderModel>> getDriverOrders(String driverId) {
    return _firestore
        .collection(AppConstants.ordersCollection)
        .where('driverId', isEqualTo: driverId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) {
            // Deduplicate orders by ID to prevent duplicates
            final Map<String, OrderModel> uniqueOrders = {};
            for (final doc in snapshot.docs) {
              final order = OrderModel.fromFirestore(doc);
              // Use the most recent order if duplicate IDs exist
              if (!uniqueOrders.containsKey(order.id) ||
                  order.updatedAt.isAfter(uniqueOrders[order.id]!.updatedAt)) {
                uniqueOrders[order.id] = order;
              }
            }
            return uniqueOrders.values.toList()
              ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          },
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
    BackendService? backendService,
    String orderId,
    String status,
  ) async {
    try {
      print('Attempting to send notification for order $orderId with status $status');
      
      final orderDoc = await _firestore
          .collection(AppConstants.ordersCollection)
          .doc(orderId)
          .get();

      if (!orderDoc.exists) {
        print('Order $orderId not found, cannot send notification');
        return;
      }

      final orderData = orderDoc.data()!;
      final customerId = orderData['customerId'] as String?;

      if (customerId == null || customerId.isEmpty) {
        print('No customerId found for order $orderId, cannot send notification');
        return;
      }

      String title;
      String body;
      String notificationType;

      switch (status) {
        case AppConstants.orderStatusAccepted:
          title = 'Order Accepted';
          body = 'A driver has accepted your order';
          notificationType = 'order_accepted';
          break;
        case AppConstants.orderStatusInTransit:
          title = 'Order In Transit';
          body = 'Your order is on the way';
          notificationType = 'order_in_transit';
          break;
        case AppConstants.orderStatusCompleted:
          title = 'Order Completed';
          body = 'Your order has been delivered';
          notificationType = 'order_completed';
          break;
        default:
          print('No notification needed for status: $status');
          return; // Don't send notification for other statuses
      }

      // Get customer's FCM token from order document (avoids permission issues)
      // The FCM token is stored in the order when it's created
      String? fcmToken = orderData['customerFcmToken'] as String?;
      
      if (fcmToken == null || fcmToken.isEmpty) {
        print('No FCM token found in order document for customer $customerId');
        print('Note: FCM token should be stored in order when created. Trying to get from user document as fallback...');
        
        // Fallback: Try to get from user document (may fail due to permissions)
        try {
          final userDoc = await _firestore
              .collection(AppConstants.usersCollection)
              .doc(customerId)
              .get();

          if (userDoc.exists) {
            final fallbackToken = userDoc.data()?['fcmToken'] as String?;
            if (fallbackToken != null && fallbackToken.isNotEmpty) {
              print('Found FCM token in user document (fallback) - using it for notification');
              fcmToken = fallbackToken;
              // Update order document with FCM token for future use
              try {
                await _firestore
                    .collection(AppConstants.ordersCollection)
                    .doc(orderId)
                    .update({'customerFcmToken': fallbackToken});
                print('Updated order document with FCM token for future notifications');
              } catch (e) {
                print('Could not update order with FCM token: $e');
              }
            }
          }
        } catch (e) {
          print('Fallback FCM token retrieval failed (permission denied expected): $e');
        }
        
        if (fcmToken == null || fcmToken.isEmpty) {
          print('Cannot send notification - no FCM token available');
          return;
        }
      }

      print('Found FCM token for user $customerId, attempting to send notification');
      print('FCM Token (first 30 chars): ${fcmToken.substring(0, fcmToken.length > 30 ? 30 : fcmToken.length)}...');

      // Try to send via backend - always attempt even if marked unavailable
      // (availability might have changed, or we want to retry)
      bool notificationSent = false;
      
      if (backendService != null) {
        print('Backend service exists, checking availability...');
        // Re-check availability if marked as unavailable (might have recovered)
        // But don't block on slow health checks - try sending notification anyway
        if (!backendService.isAvailable) {
          print('Backend marked as unavailable, re-checking availability...');
          // Check availability but don't wait too long
          bool recheckResult = false;
          try {
            recheckResult = await backendService.checkAvailability().timeout(
              const Duration(seconds: 6),
            );
          } catch (e) {
            print('⚠️ Backend availability check timed out or failed - will attempt notification anyway');
            recheckResult = false;
          }
          print('Backend availability re-check result: $recheckResult');
        } else {
          print('Backend is marked as available');
        }
        
        // Try to send notification even if health check failed
        // The backend might be slow but still functional
        // Always attempt to send - don't block on slow health checks
        print('=== ATTEMPTING TO SEND NOTIFICATION VIA BACKEND ===');
        print('Title: $title');
        print('Body: $body');
        print('Type: $notificationType');
        print('OrderId: $orderId');
        
        try {
          notificationSent = await backendService.sendNotification(
            fcmToken: fcmToken,
            title: title,
            body: body,
            data: {
              'type': notificationType,
              'orderId': orderId,
              'status': status,
            },
          );
          
          if (notificationSent) {
            print('✅ SUCCESS: Notification sent successfully via backend');
          } else {
            print('❌ FAILED: Backend notification returned false - backend may have become unavailable');
          }
        } catch (e, stackTrace) {
          print('❌ ERROR: Exception sending notification via backend: $e');
          print('Stack trace: $stackTrace');
          // Mark backend as unavailable on error (but don't block future attempts)
          backendService.checkAvailability().catchError((err) {
            print('Error checking backend availability: $err');
            return false;
          });
        }
      } else {
        print('⚠️ Backend service is null - cannot send notification via backend');
      }

      // If backend failed or is not available, store notification in Firestore
      // Cloud Function will automatically process it and send via Firebase
      if (!notificationSent) {
        print('Storing notification in Firestore for Cloud Function processing');
        try {
          await _firestore
              .collection('pending_notifications')
              .add({
            'fcmToken': fcmToken,
            'title': title,
            'body': body,
            'data': {
              'type': notificationType,
              'orderId': orderId,
              'status': status,
            },
            'createdAt': Timestamp.fromDate(DateTime.now()),
            'attempts': 0,
          });
          print('✅ Notification stored in Firestore - Cloud Function will send it automatically');
        } catch (e) {
          print('Error storing notification in Firestore: $e');
        }
      }
    } catch (e, stackTrace) {
      print('Error sending status notification: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> acceptOrder(
    String orderId,
    String driverId, {
    BackendService? backendService,
  }) async {
    // Use a transaction to atomically check and accept the order
    // This prevents race conditions where multiple drivers try to accept the same order
    await _firestore.runTransaction((transaction) async {
      final orderRef = _firestore
          .collection(AppConstants.ordersCollection)
          .doc(orderId);
      
      final orderDoc = await transaction.get(orderRef);
      
      if (!orderDoc.exists) {
        throw Exception('Order not found');
      }
      
      final orderData = orderDoc.data()!;
      final currentStatus = orderData['status'] as String?;
      final currentDriverId = orderData['driverId'] as String?;
      
      // Check if order is still pending and not assigned to another driver
      if (currentStatus != AppConstants.orderStatusPending) {
        throw Exception('Order is no longer available. Status: $currentStatus');
      }
      
      if (currentDriverId != null && currentDriverId.isNotEmpty) {
        throw Exception('Order has already been assigned to another driver');
      }
      
      // Atomically update the order
      transaction.update(orderRef, {
        'driverId': driverId,
        'status': AppConstants.orderStatusAccepted,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    });

    // Notify customer that order was accepted (always attempt, even if backend is null)
    print('=== NOTIFICATION: Order $orderId accepted by driver $driverId ===');
    print('Backend service: ${backendService != null ? "available" : "null"}');
    if (backendService != null) {
      print('Backend isAvailable: ${backendService.isAvailable}');
    }
    _notifyOrderStatusChange(
      backendService,
      orderId,
      AppConstants.orderStatusAccepted,
    ).then((_) {
      print('Notification process completed for order $orderId');
    }).catchError((e, stackTrace) {
      print('ERROR: Failed to notify customer for order $orderId: $e');
      print('Stack trace: $stackTrace');
    });
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

    // Notify customer that delivery is completed (always attempt, even if backend is null)
    print('=== NOTIFICATION: Order $orderId completed by driver $driverId ===');
    print('Backend service: ${backendService != null ? "available" : "null"}');
    if (backendService != null) {
      print('Backend isAvailable: ${backendService.isAvailable}');
    }
    _notifyOrderStatusChange(
      backendService,
      orderId,
      AppConstants.orderStatusCompleted,
    ).then((_) {
      print('Notification process completed for order $orderId');
    }).catchError((e, stackTrace) {
      print('ERROR: Failed to notify customer for order $orderId: $e');
      print('Stack trace: $stackTrace');
    });
      
    // Create driver payment (80% of order total) when order is completed
    if (backendService != null && driverId != null && driverId.isNotEmpty) {
      // Calculate order total (gas quantity * price per gallon + delivery fee)
      final orderTotal = (gasQuantity * AppConstants.pricePerGallon) + AppConstants.deliveryFee;
      final driverAmount = orderTotal * 0.8;
      
      print('Attempting to create driver payment: driverId=$driverId, orderId=$orderId, orderTotal=$orderTotal, driverAmount=$driverAmount');
      
      // Try to check availability if not already available
      if (!backendService.isAvailable) {
        print('Backend not marked as available, attempting to check availability...');
        await backendService.checkAvailability();
      }
      
      try {
        final success = await backendService.createDriverPayment(
          driverId: driverId,
          orderId: orderId,
          orderTotal: orderTotal,
          currency: 'usd',
        );
        
        if (success) {
          print('SUCCESS: Driver payment created successfully - driverId=$driverId, orderId=$orderId, amount=$driverAmount');
        } else {
          print('WARNING: Driver payment creation returned false - driverId=$driverId, orderId=$orderId');
          // Don't fail delivery completion if payment creation fails, but log it
        }
      } catch (e, stackTrace) {
        print('ERROR: Exception creating driver payment: $e');
        print('Stack trace: $stackTrace');
        // Don't fail delivery completion if payment creation fails
      }
    } else {
      if (driverId == null || driverId.isEmpty) {
        print('WARNING: Cannot create driver payment - driverId is null or empty for orderId=$orderId');
      }
      if (backendService == null) {
        print('WARNING: Backend service is null, cannot create driver payment');
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
