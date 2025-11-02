import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../shared/models/user_model.dart';
import '../shared/models/order_model.dart';
import '../core/constants/app_constants.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

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

    return docRef.id;
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

  Future<void> updateOrderStatus(String orderId, String status) async {
    await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({
          'status': status,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  Future<void> acceptOrder(String orderId, String driverId) async {
    await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({
          'driverId': driverId,
          'status': AppConstants.orderStatusAccepted,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  Future<void> updateOrderWithDeliveryPhoto(
    String orderId,
    String photoUrl,
  ) async {
    await _firestore
        .collection(AppConstants.ordersCollection)
        .doc(orderId)
        .update({
          'deliveryPhotoUrl': photoUrl,
          'deliveryVerifiedAt': Timestamp.fromDate(DateTime.now()),
          'status': AppConstants.orderStatusCompleted,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  Future<String> uploadDeliveryPhoto(String orderId, String filePath) async {
    final ref = _storage.ref().child(
      'delivery_photos/$orderId/${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await ref.putFile(File(filePath));
    return await ref.getDownloadURL();
  }
}
